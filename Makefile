NETWORK = fantom

# reads
read_tomb:
	npx hardhat run scripts/read/readTomb.ts --network $(NETWORK)

read_tshare:
	npx hardhat run scripts/read/readTShare.ts --network $(NETWORK)

read_tshare_reward_pool:
	npx hardhat run scripts/read/readTShareRewardPool.ts --network $(NETWORK)

read_treasury:
	npx hardhat run scripts/read/readTreasury.ts --network $(NETWORK)

read_masonry:
	npx hardhat run scripts/read/readMasonry.ts --network $(NETWORK)

read_genesis:
	npx hardhat run scripts/read/readGenesisPool.ts --network $(NETWORK)

# writes
dep:
	npx hardhat run scripts/write/deploy.ts --network $(NETWORK) 

distribute_reward_tomb:
	npx hardhat run scripts/write/distributeRewardTomb.ts --network $(NETWORK) 

distribute_reward_tshare:
	npx hardhat run scripts/write/distributeRewardTshare.ts --network $(NETWORK) 

add_tshare_reward_pool:
	npx hardhat run scripts/write/addTShareRewardPool.ts --network $(NETWORK)

add_tomb_genesis_reward_pool:
	npx hardhat run scripts/write/addTombGenesisRewardPool.ts --network $(NETWORK)

set_oracle:
	npx hardhat run scripts/write/setTombOracle.ts --network $(NETWORK)

init_treasury:
	npx hardhat run scripts/write/initTreasury.ts --network $(NETWORK)

set_extra_funds_on_treasury:
	npx hardhat run scripts/write/setExtraFundsOnTreasury.ts --network $(NETWORK)

init_masonry:
	npx hardhat run scripts/write/initMasonry.ts --network $(NETWORK)

set_operator_on_masonry:
	npx hardhat run scripts/write/setOperatorOnMasonry.ts --network $(NETWORK)

transfer_operator_on_tomb:
	npx hardhat run scripts/write/transferOperatorOnTomb.ts --network $(NETWORK)

transfer_operator_on_tshare:
	npx hardhat run scripts/write/transferOperatorOnTshare.ts --network $(NETWORK)

transfer_operator_on_tbond:
	npx hardhat run scripts/write/transferOperatorOnTbond.ts --network $(NETWORK)

claim_rewards:
	npx hardhat run scripts/write/claimRewards.ts --network $(NETWORK)

deploy_vault:
	npx hardhat run scripts/vault/deployBeefyVault.ts --network $(NETWORK)

harvest_vault:
	npx hardhat run scripts/vault/harvestVaultStrategy.ts --network $(NETWORK)



###


readTShareRewardPool:
	npx hardhat run scripts/readTShareRewardPool.ts --network maticMainnet


addTombGenesisRewardPool:
	npx hardhat run scripts/addTombGenesisRewardPool.ts --network maticMainnet