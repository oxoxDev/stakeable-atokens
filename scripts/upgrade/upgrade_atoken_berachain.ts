import hre from "hardhat";
import { IPoolConfigurator } from "../../typechain-types";
async function main() {
    const rewardVault = "0x3A16ADDa53d51B783FeC19E8A7019fBc6Ef77055";

    const asset = "0xb0811a1FC9Fb9972ee683Ba04c32Cb828Bcf587B"; // WETH
    const treasury = "0xC3B6dDc1c9876a922754f1d01D18893C7956A74D";
    const incentivesController = "0x7E0156852ce91FAA50C6286b1585c449430f542d";
    const name = "Berachain WETH";
    const symbol = "BERAWETH";

    const encodedRewardVaultAddress = hre.ethers.AbiCoder.defaultAbiCoder().encode(["address"], [rewardVault]);
    const owner = await hre.ethers.getImpersonatedSigner("0x6F5Ae60d89dbbc4EeD4B08d08A68dD5679Ac61B4")
    const ZEROLEND_LENDING_POOL = "0xf98b241C1b60f695D5e88268797cC0cEd4D9DD68";
    const PoolConfigurator: IPoolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", "0x752Bef11C0e74eee1Bc5B16e2155f9558A183690");

    const newATokenFactory = await hre.ethers.getContractFactory("ATokenBerachain");
    const newAToken = await newATokenFactory.deploy(ZEROLEND_LENDING_POOL);
    await newAToken.waitForDeployment();

    await PoolConfigurator.connect(owner).updateAToken({
        asset: asset,
        treasury: treasury,
        incentivesController: incentivesController,
        name: name,
        symbol: symbol,
        implementation: newAToken.target,
        params: encodedRewardVaultAddress,
    });
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
