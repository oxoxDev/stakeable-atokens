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
    berachain_bartio: {
      url: "https://bartio.rpc.berachain.com/",
      accounts: [process.env.PRIVATE_KEY || ""],
    } 
  },
  dependencyCompiler: {
    paths: ["@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol"],
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_KEY || "",
      berachain_bartio: "BARTIO_KEY",
    },
    customChains: [
      {
        network: "berachain_bartio",
        chainId: 80084,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/testnet/evm/80084/etherscan",
          browserURL: "https://bartio.beratrail.io"
        },
      },
    ]
  },
};

export default config;
