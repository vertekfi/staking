import 'dotenv/config';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-deploy-ethers';
import '@nomiclabs/hardhat-web3';
import '@openzeppelin/hardhat-upgrades';

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config = {
  solidity: {
    version: '0.8.13',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },

  networks: {
    bsc: {
      url: process.env.BSC_RPC || '',
      chainId: 56,
      accounts: [process.env.DEV_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN,
  },
};

export default config;
