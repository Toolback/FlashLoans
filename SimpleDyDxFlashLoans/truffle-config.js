module.exports = {
  contracts_directory: "./contracts/simple-dydx-flashloan/",

  networks: {
      mainnet_fork: {
          host: "127.0.0.1", // Localhost (default: none)
          port: 8545, // Standard Ethereum port (default: none)
          network_id: "989" // Any network (default: none)
      },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
      // timeout: 100000
  },

  // Configure your compilers
  compilers: {
      solc: {
          version: "0.8.0", // Fetch exact version from solc-bin (default: truffle's version)
      },
  },
}