import config, { contractNameMapper } from '../config';

const { ethers } = require('hardhat');

async function main() {
  const deployer = await ethers.getSigner(
    '0xe9a274F0153c9D24a6C081465e0641ff0bBD0286'
  );

  if (deployer.address !== config.deployer) {
    throw Error('Mismatch on deployer address. Check mneumonmic');
  }

  const tomb = await ethers.getContractAt(
    contractNameMapper.aceLab,
    config.aceLab
  );

  console.log('tomb', tomb);

  const result = await tomb
    .connect(deployer)
    // ['deposit(uint _pid, uint _amount)'](0, 1);
    ['deposit(uint256,uint256)'](0, 1);

  console.log('result: ' + JSON.stringify(result));

  console.log('==================================');
}

main()
  .then(() => process.exit())
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
