import { getContractAddress } from '@ethersproject/address';
import config, { contractNameMapper } from '../config';

const { ethers } = require('hardhat');

const flags = {
  aceLab: true,
}

async function main() {
  const deployer = await ethers.getSigner("0xe9a274F0153c9D24a6C081465e0641ff0bBD0286");
  const period = 21600 // 6 hours
  if (deployer.address !== config.deployer) {
    throw Error('Mismatch on deployer address. Check mneumonmic');
  }

  const transactionCount = await deployer.getTransactionCount()

  const nextContract = getContractAddress({
    from: '0x26441aE27Ce06D140Ef5b1Bc5E4f43B83bdBa0e4',
    nonce: transactionCount
  })

  console.log('next contract: ', nextContract);

  const { timestamp } = await ethers.provider.getBlock();

  console.log('Deploying contracts with the account: ' + deployer.address);
  console.log('It is now ', timestamp);

  // Deploy AceLab
  if (flags.aceLab) {
    const AceLab = await ethers.getContractFactory(contractNameMapper.aceLab);
    const aceLabAdd = await AceLab.connect(deployer).deploy(config.vtek, config.roar);

    console.log(`aceLab Deployed to: ${config.scanner}${aceLabAdd.address}`);
    console.log("==================================");
  }
}

main()
    .then(() => process.exit())
    .catch(error => {
        console.error(error);
        process.exit(1);
})