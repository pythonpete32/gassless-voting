require("dotenv").config();
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-etherscan";

const { GOERLI_RPC_URL, POLYGON_RPC_URL, PRIVATE_KEY, ETHERSCAN_KEY } = process.env

const config: HardhatUserConfig = {
  solidity: "0.8.15",
  networks: {
    local: {
      url: "http://127.0.0.1:8545"
    },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY],
      forking: {
        url: GOERLI_RPC_URL,
      }
    },
    polygon: {
      URL: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY],
    }
  },
  etherscan: {
    apiKey: ETHERSCAN_KEY
  }
};

export default config;
