import { ethers, upgrades } from 'hardhat';
import { FoxNFT, VRTK } from './addresses';

async function main() {
  // const VertekStaking = await ethers.getContractFactory('VertekStaking');
  // const staking = await upgrades.deployProxy(VertekStaking, [VRTK, FoxNFT]);
  // await staking.deployed();

  // console.log(`VertekStaking deployed to: ` + staking.address);

  const VertekStaking = await ethers.getContractFactory('VertekStaking');
  const staking = await upgrades.upgradeProxy('0x73572B049490BDD43a76b88BD19300E788d6a857', VertekStaking);
  await staking.deployed();

  console.log(`VertekStaking upgrade complete`);
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
