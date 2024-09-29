import hre from "hardhat";

async function main() {
  const aero = "0x940181a94A35A4569E4529A3CDfB74e38FD98631";
  const aeroOracle = "0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0";
  const emissionManager = "0x0f9bfa294bE6e3CA8c39221Bb5DFB88032C8936E";
  const incentiveController = "0x73a7a4B40f3FE11e0BcaB5538c75D3B984082CAE";

  const [deployer] = await hre.ethers.getSigners();

  const proxyAdmin = await hre.deployments.deploy("ProxyAdmin", {
    from: deployer.address,
    contract: "ProxyAdmin",
    autoMine: true,
    skipIfAlreadyDeployed: true,
    log: true,
  });

  console.log("proxy admin at", proxyAdmin.address);

  const aeroEmissionsStrategy = await hre.deployments.deploy(
    "AeroEmissionsStrategy",
    {
      from: deployer.address,
      skipIfAlreadyDeployed: true,
      contract: "AeroEmissionsStrategy",
      autoMine: true,
      log: true,
      proxy: {
        owner: proxyAdmin.address,
        proxyContract: "OpenZeppelinTransparentProxy",
        execute: {
          init: {
            methodName: "initialize",
            args: [
              deployer.address, // address _owner,
              aero, // address _aero,
              aeroOracle, // address _oracle,
              emissionManager, // address _emissionManager,
              incentiveController, // address _incentiveController
            ],
          },
        },
      },
    }
  );

  console.log(
    `aeroEmissionsStrategy deployed to`,
    aeroEmissionsStrategy.address
  );

  // verify contract for tesnet & mainnet
  if (hre.network.name !== "hardhat") {
    await hre.run("verify:verify", { address: proxyAdmin.address });
    await hre.run("verify:verify", { address: aeroEmissionsStrategy.address });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
