require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.0",
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
      allowUnlimitedContractSize: true
    },
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    okchain_mainnet: {
      url: process.env.RPC_URL_OK_MAINNET || "",
      network_id: 66,
      gasPrice: 100000000,
      accounts:
        process.env.PRIVATE_KEY_OK_MAINNET !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    okchain_test: {
      url: process.env.RPC_URL_OK_TESTNET || "",
      network_id: "65",
      from: '0xbA6116f1abDce2Cc2313aBc0Ab8e6cF452aDb4f5',
      accounts:
        process.env.PRIVATE_KEY_OK_TESTNET !== undefined ? [process.env.PRIVATE_KEY] : [],
    }

    // okchain_mainnet: {
    //   provider: function() {
    //     return new HDWalletProvider({
    //       privateKeys: [privateKeyOEC_MAINNET],
    //       providerOrUrl: enabledWs ? okchainUrlWs : okchainUrl,
    //       pollingInterval: 600000,
    //       chainId: 66
    //     });
    //   },
    //   gasPrice: 100000000,
    //   networkCheckTimeout: 600000,
    //   timeoutBlocks: 50000,
    //   network_id: "66",
    //   skipDryRun: true,
    //   confirmations: 2,
    //   websocket: enabledWs,
    // }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
