import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-dependency-compiler";
import "hardhat-deploy";

import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.12",
  networks: {
    base: {
      url: `https://mainnet.base.org/`,
      accounts: [process.env.PRIVATE_KEY || ""],
    },
  },
  dependencyCompiler: {
    paths: ["@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol"],
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_KEY || "",
    },
  },
};

export default config;
