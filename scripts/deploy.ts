import { ethers, upgrades } from 'hardhat';
import { FoxNFT, VRTK } from './addresses';

async function main() {
  const VertekStaking = await ethers.getContractFactory('VertekStaking');
  const staking = await upgrades.deployProxy(VertekStaking, [VRTK, FoxNFT]);
  await staking.deployed();

  console.log(`VertekStaking deployed to: ` + staking.address);
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
