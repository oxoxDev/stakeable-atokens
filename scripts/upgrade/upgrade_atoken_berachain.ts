import hre from "hardhat";
import { IPoolConfigurator } from "../../typechain-types";
import path from "path";
import fs from "fs/promises";

async function main() {
  if (hre.network.name === "berachain_bartio") {
    const AToken = await hre.ethers.getContractAt("AToken", "0xEc93009f7cDc8b15A48cAB34680a0b60e49D3FC5")
    const rewardVault = "0x0c853787bd9a9AE2A2478BC7Cbf70F35Ca5280f6";

    const asset = await AToken.UNDERLYING_ASSET_ADDRESS();
    const treasury = await AToken.RESERVE_TREASURY_ADDRESS();
    const incentivesController = await AToken.getIncentivesController();
    const name = await AToken.name();
    const symbol = await AToken.symbol();
    const encodedRewardVaultAddress = hre.ethers.AbiCoder.defaultAbiCoder().encode(["address"], [rewardVault]);
    const PoolConfigurator: IPoolConfigurator = await hre.ethers.getContractAt("IPoolConfigurator", "0x8aaF2E3080b64129D09cf5847065A20FD14F5a7D");
    const [deployer] = await hre.ethers.getSigners();

    const newATokenImpl = getAddressFromJson("berachain_bartio", "ATokenBerachain");

    await PoolConfigurator.connect(deployer).updateAToken({
        asset: asset,
        treasury: treasury,
        incentivesController: incentivesController,
        name: name,
        symbol: symbol,
        implementation: newATokenImpl,
        params: encodedRewardVaultAddress,
    });

    console.log("AToken updated: ", name);
  }
}

const getAddressFromJson = async (network: string, id: string) => {
  const artifactPath = path.join(
    __dirname,
    "../../deployments",
    network,
    `${id}.json`
  );
  const artifact = await fs.readFile(artifactPath, "utf8");
  const artifactJson = JSON.parse(artifact);

  if (artifactJson.address) {
    return artifactJson.address;
  }
  throw `Missing artifact at ${artifactPath}`;
};


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
