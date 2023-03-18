// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./utils/Auth.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./interfaces/IERC20ExtUpgradeable.sol";

// The goal of this farm is to allow a stake xBoo earn anything model
// In a flip of a traditional farm, this contract only accepts xBOO as the staking token
// Each new pool added is a new reward token, each with its own start times
// end times, and rewards per second.
contract VertekStaking is Auth, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    // Max total magicat power
    uint public constant MAX_MAGICAT_POWER = 1000;

    // Info of each user.
    struct UserInfo {
        uint amount; // How many tokens the user has provided.
        uint rewardDebt; // Reward debt. See explanation below.
        uint catDebt; // Cat debt. See explanation below.
        uint mp; // Total staked magicat power, sum of all magicat rarities staked by this user in this pool [uint64 enough]
    }

    // Info of each pool.
    struct PoolInfo {
        // Full slot = 32B
        IERC20Upgradeable rewardToken; // 20B Address of reward token contract.
        uint8 tokenPrecision; // 1B The precision factor used for calculations, equals the tokens decimals
        // 7B [free space available here]

        uint vrtkStakedAmount; // 32B # of xboo allocated to this pool
        uint mpStakedAmount; // 32B # of mp allocated to this pool
        uint RewardPerSecond; // 32B reward token per second for this pool in wei
        uint accRewardPerShare; // 32B Accumulated reward per share, times the pools token precision. See below.
        uint accRewardPerShareMagicat; // 32B Accumulated reward per share, times the pools token precision. See below.
        address protocolOwnerAddress; // 20B this address is the owner of the protocol corresponding to the reward token, used for emergency withdraw to them only
        uint32 lastRewardTime; // 4B Last block time that reward distribution occurs.
        uint32 endTime; // 4B end time of pool
        uint32 startTime; // 4B start time of pool
        uint32 magicatBoost; // 4B magicatBoostPerPool
    }

    // Remember that this should be *1000 of the apparent value since onchain rarities are multiplied by 1000,
    // also remember that this is per 1e18 wei of xboo.
    uint private _mpPerXboo;

    // Number of pools
    uint public poolAmount;

    // Sum of all rarities of all staked magicats
    uint public stakedMagicatPower;

    IERC20Upgradeable public xboo;

    IERC721Upgradeable public magicat;

    bool public emergencyCatWithdrawable;

    // Info of each pool.
    mapping(uint => PoolInfo) public poolInfo;

    mapping(uint8 => uint) public precisionOf;

    mapping(address => bool) public isRewardToken;

    // Info of each user that stakes tokens.
    mapping(uint => mapping(address => UserInfo)) public userInfo;

    // Info of each users set of staked magicats per pool (pool => (user => magicats))
    // this data type cant be public, use getter getStakedMagicats()
    mapping(uint => mapping(address => EnumerableSetUpgradeable.UintSet)) private _stakedMagicats;

    // Total staked amount of xboo in all pools by user
    mapping(address => uint) public balanceOf;

    event AdminTokenRecovery(address tokenRecovered, uint amount);
    event Deposit(address indexed user, uint indexed pid, uint amount);
    event Withdraw(address indexed user, uint indexed pid, uint amount);
    event EmergencyWithdraw(address indexed user, uint indexed pid, uint amount);
    event SetRewardPerSecond(uint _pid, uint _gemsPerSecond);
    event SetMagicatBoost(uint _pid, uint _magicatBoost);
    event StakeMagicat(address indexed user, uint indexed pid, uint indexed tokenID);
    event UnstakeMagicat(address indexed user, uint indexed pid, uint indexed tokenID);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /**
         * Prevents later initialization attempts after deployment.
         * If a base contract was left uninitialized, the implementation contracts
         * could potentially be compromised in some way.
         */
        _disableInitializers();
    }

    function initialize(IERC20Upgradeable _xboo, IERC721Upgradeable _magicat) public initializer {
        __Auth_init();
        __ReentrancyGuard_init();

        xboo = _xboo;
        magicat = _magicat;
        // Allow for a stake and earn the same
        // Check in _add will still prevent duplicate VRTK/VRTK pools
        // isRewardToken[address(_xboo)] = true;

        _mpPerXboo = 300 * 1000;
        emergencyCatWithdrawable = false;
    }

    function poolLength() external view returns (uint) {
        return poolAmount;
    }

    // Return reward multiplier over the given _from to _to block.
    function _getMultiplier(uint _from, uint _to, uint startTime, uint endTime) internal pure returns (uint) {
        _from = _from > startTime ? _from : startTime;

        if (_from > endTime || _to < startTime) {
            return 0;
        }

        if (_to > endTime) {
            return endTime - _from;
        }

        return _to - _from;
    }

    // View function to see pending BOOs on frontend.
    function pendingReward(uint _pid, address _user) external view returns (uint) {
        (uint xbooReward, uint magicatReward) = pendingRewards(_pid, _user);
        return xbooReward + magicatReward;
    }

    function pendingRewards(uint _pid, address _user) public view returns (uint xbooReward, uint magicatReward) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint accRewardPerShare = pool.accRewardPerShare;
        uint accRewardPerShareMagicat = pool.accRewardPerShareMagicat;

        if (block.timestamp > pool.lastRewardTime) {
            uint reward = pool.RewardPerSecond *
                _getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);
            if (pool.vrtkStakedAmount != 0)
                accRewardPerShare +=
                    (((reward * (10000 - pool.magicatBoost)) / 10000) * precisionOf[pool.tokenPrecision]) /
                    pool.vrtkStakedAmount;
            if (pool.mpStakedAmount != 0)
                accRewardPerShareMagicat +=
                    (((reward * pool.magicatBoost) / 10000) * precisionOf[pool.tokenPrecision]) /
                    pool.mpStakedAmount;
        }

        xbooReward = ((user.amount * accRewardPerShare) / precisionOf[pool.tokenPrecision]) - user.rewardDebt;

        magicatReward =
            ((effectiveMP(user.amount, user.mp) * accRewardPerShareMagicat) / precisionOf[pool.tokenPrecision]) -
            user.catDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint length = poolAmount;
        for (uint pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }

        uint reward = pool.RewardPerSecond *
            _getMultiplier(pool.lastRewardTime, block.timestamp, pool.startTime, pool.endTime);

        if (pool.vrtkStakedAmount != 0)
            pool.accRewardPerShare +=
                (((reward * (10000 - pool.magicatBoost)) / 10000) * precisionOf[pool.tokenPrecision]) /
                pool.vrtkStakedAmount;
        if (pool.mpStakedAmount != 0)
            pool.accRewardPerShareMagicat +=
                (((reward * pool.magicatBoost) / 10000) * precisionOf[pool.tokenPrecision]) /
                pool.mpStakedAmount;
        pool.lastRewardTime = uint32(block.timestamp);
    }

    function userCurrentStakeableMP(uint _pid, address _user) public view returns (int) {
        return int(_stakeableMP(userInfo[_pid][_user].amount)) - int(userInfo[_pid][_user].mp);
    }

    function stakeableMP(uint _xboo) public view returns (uint) {
        return _stakeableMP(_xboo);
    }

    function stakeableMP(uint _pid, address _user) public view returns (uint) {
        return _stakeableMP(userInfo[_pid][_user].amount);
    }

    function effectiveMP(uint _amount, uint _mp) public view returns (uint) {
        _amount = _stakeableMP(_amount);
        return _mp < _amount ? _mp : _amount;
    }

    function _stakeableMP(uint _xboo) internal view returns (uint) {
        return (_mpPerXboo * _xboo) / 1 ether;
    }

    function deposit(uint _pid, uint _amount) external nonReentrant {
        _deposit(_pid, _amount, msg.sender, new uint[](0));
    }

    function deposit(uint _pid, uint _amount, address to) external nonReentrant {
        _deposit(_pid, _amount, to, new uint[](0));
    }

    function deposit(uint _pid, uint _amount, uint[] memory tokenIDs) external nonReentrant {
        uint numberStaked = userInfo[_pid][msg.sender].mp;
        require(numberStaked == 0, "can only stake one nft");
        _deposit(_pid, _amount, msg.sender, tokenIDs);
    }

    function deposit(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external nonReentrant {
        uint numberStaked = userInfo[_pid][to].mp;
        require(numberStaked == 0, "can only stake one nft");
        _deposit(_pid, _amount, to, tokenIDs);
    }

    // Deposit tokens.
    function _deposit(uint _pid, uint _amount, address to, uint[] memory tokenIDs) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][to];

        updatePool(_pid);

        uint precision = precisionOf[pool.tokenPrecision]; // precision
        uint amount = user.amount;

        uint pending = ((amount * pool.accRewardPerShare) / precision) - user.rewardDebt;
        uint pendingCat = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision - user.catDebt;

        user.amount += _amount;
        amount += _amount;
        pool.vrtkStakedAmount += _amount;
        balanceOf[to] += _amount;

        user.rewardDebt = (amount * pool.accRewardPerShare) / precision;

        if (pending > 0) safeTransfer(pool.rewardToken, to, pending + pendingCat);
        if (_amount > 0) xboo.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _pid, _amount);

        uint len = tokenIDs.length;
        if (len == 0) {
            user.catDebt = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision;
            return;
        }

        // pending = sumOfRarities(tokenIDs);
        pending = tokenIDs.length;
        stakedMagicatPower += pending;

        user.mp += pending;
        user.catDebt = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision;
        pool.mpStakedAmount += pending;

        do {
            unchecked {
                --len;
            }
            pending = tokenIDs[len];
            magicat.transferFrom(msg.sender, address(this), pending);
            _stakedMagicats[_pid][to].add(pending);

            emit StakeMagicat(to, _pid, pending);
        } while (len != 0);
    }

    // Withdraw tokens.
    function withdraw(uint _pid, uint _amount) external nonReentrant {
        _withdraw(_pid, _amount, msg.sender, new uint[](0));
    }

    function withdraw(uint _pid, uint _amount, address to) external nonReentrant {
        _withdraw(_pid, _amount, to, new uint[](0));
    }

    function withdraw(uint _pid, uint _amount, uint[] memory tokenIDs) external nonReentrant {
        _withdraw(_pid, _amount, msg.sender, tokenIDs);
    }

    function withdraw(uint _pid, uint _amount, address to, uint[] memory tokenIDs) external nonReentrant {
        _withdraw(_pid, _amount, to, tokenIDs);
    }

    function _withdraw(uint _pid, uint _amount, address to, uint[] memory tokenIDs) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);

        uint precision = precisionOf[pool.tokenPrecision];
        uint amount = user.amount;

        uint pending = ((amount * pool.accRewardPerShare) / precision) - user.rewardDebt;
        uint pendingCat = ((effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision) - user.catDebt;

        user.amount -= _amount;
        amount -= _amount;
        pool.vrtkStakedAmount -= _amount;
        balanceOf[msg.sender] -= _amount;

        user.rewardDebt = (amount * pool.accRewardPerShare) / precision;

        if (pending > 0) safeTransfer(pool.rewardToken, to, pending + pendingCat);
        if (_amount > 0) safeTransfer(xboo, to, _amount);

        emit Withdraw(to, _pid, _amount);

        uint len = tokenIDs.length;
        if (len == 0) {
            user.catDebt = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision;
            return;
        }

        pending = tokenIDs.length;
        stakedMagicatPower -= pending;

        user.mp -= pending;
        user.catDebt = (effectiveMP(amount, user.mp) * pool.accRewardPerShareMagicat) / precision;
        pool.mpStakedAmount -= pending;

        do {
            unchecked {
                --len;
            }
            pending = tokenIDs[len];
            require(
                _stakedMagicats[_pid][msg.sender].contains(pending),
                "Magicat not staked by this user in this pool!"
            );
            _stakedMagicats[_pid][msg.sender].remove(pending);
            magicat.transferFrom(address(this), to, pending);
            emit UnstakeMagicat(msg.sender, _pid, pending);
        } while (len != 0);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint oldUserAmount = user.amount;
        pool.vrtkStakedAmount -= user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        balanceOf[msg.sender] -= oldUserAmount;

        xboo.safeTransfer(msg.sender, oldUserAmount);

        emit EmergencyWithdraw(msg.sender, _pid, oldUserAmount);
    }

    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    // Withdraw cats without caring about rewards. EMERGENCY ONLY.
    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    // This will set your mp and catDebt to 0 even if you dont withdraw all cats.
    // Make sure to emergency withdraw all your cats if you ever call this.
    // !! DO NOT CALL THIS UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING !!
    function emergencyCatWithdraw(uint _pid, uint[] calldata tokenIDs) external nonReentrant {
        require(emergencyCatWithdrawable);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint userMPs = tokenIDs.length;
        user.mp = 0;
        user.catDebt = 0;
        pool.mpStakedAmount -= userMPs;
        stakedMagicatPower -= userMPs;
        uint len = tokenIDs.length;
        do {
            unchecked {
                --len;
            }
            userMPs = tokenIDs[len];
            require(
                _stakedMagicats[_pid][msg.sender].contains(userMPs),
                "Magicat not staked by this user in this pool!"
            );
            _stakedMagicats[_pid][msg.sender].remove(userMPs);
            magicat.transferFrom(address(this), msg.sender, userMPs);
            emit UnstakeMagicat(msg.sender, _pid, userMPs);
        } while (len != 0);
    }

    // Safe erc20 transfer function, just in case if rounding error causes pool to not have enough reward tokens.
    function safeTransfer(IERC20Upgradeable token, address _to, uint _amount) internal {
        uint bal = token.balanceOf(address(this));
        if (_amount > bal) {
            token.safeTransfer(_to, bal);
        } else {
            token.safeTransfer(_to, _amount);
        }
    }

    function stakeAndUnstakeMagicats(
        uint _pid,
        uint[] memory stakeTokenIDs,
        uint[] memory unstakeTokenIDs
    ) external nonReentrant {
        _withdraw(_pid, 0, msg.sender, unstakeTokenIDs);
        _deposit(_pid, 0, msg.sender, stakeTokenIDs);
    }

    function onERC721Received(
        address operator,
        address /*from*/,
        uint /*tokenId*/,
        bytes calldata /*data*/
    ) external view returns (bytes4) {
        if (operator == address(this)) return this.onERC721Received.selector;
        return 0;
    }

    // Admin functions

    function setEmergencyCatWithdrawable(bool allowed) external onlyAuth {
        emergencyCatWithdrawable = allowed;
    }

    function setCatMultiplier(uint mul) external onlyAdmin {
        _mpPerXboo = mul;
    }

    /// @dev Reset initial testing setup before going live if needed
    function resetPoolStart(uint _pid, uint32 start, uint32 end, uint256 rewardPerSecond) external onlyAuth {
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.vrtkStakedAmount == 0, "Cannot reset pool with deposits");

        uint32 lastRewardTime = uint32(block.timestamp > start ? block.timestamp : start);
        pool.startTime = start;
        pool.endTime = end;
        pool.lastRewardTime = lastRewardTime;
        pool.RewardPerSecond = rewardPerSecond;
    }

    function changeEndTime(uint _pid, uint32 addSeconds) external onlyAuth {
        poolInfo[_pid].endTime += addSeconds;
    }

    function stopReward(uint _pid) external onlyAuth {
        poolInfo[_pid].endTime = uint32(block.timestamp);
    }

    function checkForToken(IERC20Upgradeable _token) private view {
        require(!isRewardToken[address(_token)], "checkForToken: reward token or xboo provided");
    }

    function recoverWrongTokens(address _tokenAddress) external onlyAdmin {
        checkForToken(IERC20Upgradeable(_tokenAddress));

        uint bal = IERC20Upgradeable(_tokenAddress).balanceOf(address(this));
        IERC20Upgradeable(_tokenAddress).safeTransfer(address(msg.sender), bal);

        emit AdminTokenRecovery(_tokenAddress, bal);
    }

    function emergencyRewardWithdraw(uint _pid, uint _amount) external onlyAdmin {
        poolInfo[_pid].rewardToken.safeTransfer(poolInfo[_pid].protocolOwnerAddress, _amount);
    }

    // Add a new token to the pool. Can only be called by the owner.
    function add(
        uint _rewardPerSecond,
        IERC20ExtUpgradeable _token,
        uint32 _startTime,
        uint32 _endTime,
        address _protocolOwner,
        uint32 _magicatBoost
    ) external onlyAuth {
        _add(_rewardPerSecond, _token, _startTime, _endTime, _protocolOwner, _magicatBoost);
    }

    // Add a new token to the pool (internal).
    function _add(
        uint _rewardPerSecond,
        IERC20ExtUpgradeable _token,
        uint32 _startTime,
        uint32 _endTime,
        address _protocolOwner,
        uint32 _magicatBoost
    ) internal {
        require(_rewardPerSecond > 9, "_rewardPerSecond needs to be at least 10 wei");

        checkForToken(_token); // ensure you cant add duplicate pools
        isRewardToken[address(_token)] = true;

        uint32 lastRewardTime = uint32(block.timestamp > _startTime ? block.timestamp : _startTime);
        uint8 decimalsRewardToken = uint8(_token.decimals());
        require(decimalsRewardToken < 30, "Token has way too many decimals");
        if (precisionOf[decimalsRewardToken] == 0) precisionOf[decimalsRewardToken] = 10 ** (30 - decimalsRewardToken);

        PoolInfo storage poolinfo = poolInfo[poolAmount];
        poolinfo.rewardToken = _token;
        poolinfo.RewardPerSecond = _rewardPerSecond;
        poolinfo.tokenPrecision = decimalsRewardToken;
        poolinfo.startTime = _startTime;
        poolinfo.endTime = _endTime;
        poolinfo.lastRewardTime = lastRewardTime;
        poolinfo.protocolOwnerAddress = _protocolOwner;
        poolinfo.magicatBoost = _magicatBoost;
        poolAmount += 1;
    }

    // Update the given pool's reward per second. Can only be called by the owner.
    function setRewardPerSecond(uint _pid, uint _rewardPerSecond) external onlyAdmin {
        updatePool(_pid);
        poolInfo[_pid].RewardPerSecond = _rewardPerSecond;
        emit SetRewardPerSecond(_pid, _rewardPerSecond);
    }

    // Update the given pool's magicatBoost. Can only be called by the owner.
    function setMagicatBoost(uint _pid, uint32 _magicatBoost) external onlyAdmin {
        updatePool(_pid);
        require(_magicatBoost < 5000); // 5000 = 50%
        poolInfo[_pid].magicatBoost = _magicatBoost;

        emit SetMagicatBoost(_pid, _magicatBoost);
    }

    /**
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function getStakedMagicats(uint _pid, address _user) external view returns (uint[] memory) {
        return _stakedMagicats[_pid][_user].values();
    }
}
