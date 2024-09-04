import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  gasReporter: {
    enabled: true
  },
  networks: {
    hardhat: {
    },
  },
  paths: {
    tests: "./test"
  }
};

export default config;
