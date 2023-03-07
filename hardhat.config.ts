import 'dotenv/config';
import 'hardhat-deploy';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-deploy-ethers';
import '@nomiclabs/hardhat-web3';

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
    // fantom: {
    //   url: 'https://rpcapi.fantom.network',
    //   chainId: 250,
    //   accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //   apiKey: process.env.ETHERSCAN,
    // },
    // optomism: {
    //   url: 'https://mainnet.optimism.io',
    //   chainId: 10,
    //   accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //   apiKey: process.env.ETHERSCAN,
    // },
    // fantomTestnet: {
    //     url: 'https://rpc.testnet.fantom.network',
    //     accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //     chainId: 4002,
    //     // gasMultiplier: 2,
    // },
    // maticTestnet: {
    //   url: 'https://rpc-mumbai.maticvigil.com/',
    //   accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //   chainId: 80001,
    //   gasMultiplier: 2,
    // },
    // matic: {
    //   url: 'https://polygon-rpc.com/',
    //   accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //   chainId: 137,
    //   // gasMultiplier: 2,
    // },
    bsc: {
      url: process.env.BSC_RPC || '',
      chainId: 56,
      accounts: [process.env.DEV_KEY],
    },
    // goerli: {
    //   url: 'https://goerli.infura.io/v3/8d73869d68a545d38462b443c801525f',
    //   chainId: 5,
    //   accounts: [process.env.NETWORK_MAINNET_PRIVATE_KEY!],
    //   apiKey: process.env.ETHERSCAN,
    // },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN,
  },
};

export default config;
