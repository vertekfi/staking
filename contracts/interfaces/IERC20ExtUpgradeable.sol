// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20ExtUpgradeable is IERC20Upgradeable {
    function decimals() external returns (uint);
}
