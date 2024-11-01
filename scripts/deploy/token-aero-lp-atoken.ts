import hre from "hardhat";

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const strategyD = await hre.deployments.deploy("ATokenAerodromeLP", {
    from: deployer.address,
    skipIfAlreadyDeployed: true,
    contract: "ATokenAerodromeLP",
    autoMine: true,
    args: ["0x766f21277087E18967c1b10bF602d8Fe56d0c671"],
    log: true,
  });

  // verify contract for tesnet & mainnet
  if (hre.network.name !== "hardhat") {
    await hre.run("verify:verify", {
      address: strategyD.address,
      constructorArguments: ["0x766f21277087E18967c1b10bF602d8Fe56d0c671"],
    });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
