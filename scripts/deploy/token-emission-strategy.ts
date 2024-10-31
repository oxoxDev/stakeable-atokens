import hre from "hardhat";
import { waitForTx } from "../../utils/utils";

async function main() {
  const AEROUSDC_LP_ATOKEN = "0xB6ccD85f92FB9a8bBC99b55091855714aAeEBFEE";
  const AEROUSDC_LP = "0x6cDcb1C4A4D1C3C6d054b27AC5B77e89eAFb971d";
  const POOL_ADDRESS_PROVIDER = "0x5213ab3997a596c75Ac6ebF81f8aEb9cf9A31007";
  const EMISSIONS_MANAGER = "0x0f9bfa294bE6e3CA8c39221Bb5DFB88032C8936E";
  const INCENTIVES_CONTROLLER = "0x73a7a4B40f3FE11e0BcaB5538c75D3B984082CAE";
  const AERODROME = "0x940181a94A35A4569E4529A3CDfB74e38FD98631";
  const TREASURY = "0x6F5Ae60d89dbbc4EeD4B08d08A68dD5679Ac61B4";
  const DEPLOYER = "0x0F6e98A756A40dD050dC78959f45559F98d3289d";
  const GAUGE = "0x4F09bAb2f0E15e2A078A227FE1537665F55b8360";
  const POOL_CONFIGURATOR = "0xB40e21D5cD8E9E192B0da3107883f8b0f4e4e6E3";
  const POOL = "0x766f21277087E18967c1b10bF602d8Fe56d0c671";
  const AERO_ORACLE = "0x4EC5970fC728C5f65ba413992CD5fF6FD70fcfF0";

  const [deployer] = await hre.ethers.getSigners();

  const strategyD = await hre.deployments.deploy("TokenEmissionsStrategy", {
    from: deployer.address,
    skipIfAlreadyDeployed: true,
    contract: "TokenEmissionsStrategy",
    autoMine: true,
    log: true,
    proxy: {
      owner: "0x00000ab6ee5a6c1a7ac819b01190b020f7c6599d",
      proxyContract: "OpenZeppelinTransparentProxy",
      execute: {
        init: {
          methodName: "initialize",
          args: [
            deployer.address, // address _owner,
            POOL, // address _pool,
            EMISSIONS_MANAGER, // address _emissionManager,
            INCENTIVES_CONTROLLER, // address _incentiveController
          ],
        },
      },
    },
  });

  const strategy = await hre.ethers.getContractAt(
    "TokenEmissionsStrategy",
    strategyD.address
  );

  console.log(`strategy deployed to`, strategyD.address);

  // whitelist some addresses
  await waitForTx(await strategy.whitelist(AEROUSDC_LP, true));
  await waitForTx(await strategy.whitelist(AERODROME, true));
  await waitForTx(await strategy.whitelist(deployer.address, true));
  await waitForTx(await strategy.whitelist(AERO_ORACLE, true));

  // verify contract for tesnet & mainnet
  if (hre.network.name !== "hardhat") {
    await hre.run("verify:verify", { address: strategyD.address });
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
