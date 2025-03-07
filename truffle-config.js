const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config();
const MNEMONIC = process.env.MNEMONIC;
const INFURA_TOKEN = process.env.INFURA_TOKEN;
const ETHERSCAN_KEY = process.env.ETHERSCAN_KEY;

module.exports = {
  networks: {
    development: {
      network_id: '*',
      port: 8545,
      host: '127.0.0.1',
    },
    ethMainnet: {
      network_id: '1',
      provider: () => {
        return new HDWalletProvider(MNEMONIC, 'https://mainnet.infura.io/v3/' + INFURA_TOKEN);
      },
    },
    goerli: {
      network_id: '5',
      provider: () => {
        return new HDWalletProvider(MNEMONIC, 'https://goerli.infura.io/v3/' + INFURA_TOKEN);
      },
    },
  },
  mocha: {
    reporter: 'eth-gas-reporter',
  },
  compilers: {
    solc: {
      version: '0.8.14',
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  api_keys: {
    etherscan: ETHERSCAN_KEY,
  },
  plugins: ['truffle-plugin-verify'],
};