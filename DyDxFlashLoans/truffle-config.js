require("@babel/register");
require ('core-js/stable');
require ('regenerator-runtime/runtime');

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*" // Match any network id
    },
  },

  contracts_directory: './src/contracts/dydx-flashloans/',
  contracts_build_directory: './src/abis/',
  
  compilers: {
    solc: {
      version: "0.8.0", // Fetch exact version from solc-bin (default: truffle's version)

      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
}