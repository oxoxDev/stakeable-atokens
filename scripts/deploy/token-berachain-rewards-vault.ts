import hre from "hardhat";

async function main() {
  if(hre.network.name === "berachain_bartio") {
    const [deployer] = await hre.ethers.getSigners();

    const deployedAToken = await hre.deployments.deploy("ATokenBerachain", {
      from: deployer.address,
      skipIfAlreadyDeployed: true,
      contract: "ATokenBerachain",
      autoMine: true,
      args: ["0x431B8680f2BbDEB51ee366C51Db3aC60d58a3789"],
      log: true,
    });

    // verify contract for tesnet & mainnet
    await hre.run("verify:verify", {
        address: deployedAToken.address,
        constructorArguments: ["0x431B8680f2BbDEB51ee366C51Db3aC60d58a3789"],
    });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
