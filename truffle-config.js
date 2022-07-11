module.exports = {
  networks: {
    development: {
      network_id: '*',
      port: 8545,
      host: '127.0.0.1',
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
};
