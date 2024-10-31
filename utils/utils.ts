import { TransactionReceipt, TransactionResponse } from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import fs from "fs";
import path from "path";

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export async function waitForTx(
  tx: TransactionResponse,
  confirmations = 1
): Promise<TransactionReceipt | null> {
  console.log("waiting for tx", tx.hash);
  return await tx.wait(confirmations);
}

export async function verify(
  hre: HardhatRuntimeEnvironment,
  contractAddress: string,
  constructorArguments: any[] = []
) {
  try {
    console.log(`- Verifying ${contractAddress}`);

    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: constructorArguments,
    });
  } catch (error) {
    console.log("Verify Error: ", contractAddress);
    console.log(error);
  }
}

export async function deployContract(
  hre: HardhatRuntimeEnvironment,
  implementation: string,
  args: any[],
  name: string,
  verify = true,
  libraries: { [key: string]: string } = {}
) {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  console.log("deploying", implementation, "from", deployer);

  const contract = await deploy(name, {
    from: deployer,
    contract: implementation,
    skipIfAlreadyDeployed: true,
    args: args,
    libraries: libraries,
    autoMine: true,
    log: true,
  });

  if (hre.network.name !== "hardhat" && verify) {
    console.log("verifying contracts");

    await hre.run("verify:verify", {
      address: contract.address,
      constructorArguments: args,
    });
  }

  return contract;
}

export const loadTasks = (): void => {
  const tasksPath = path.join(__dirname, "../tasks");
  fs.readdirSync(tasksPath)
    .filter((pth) => pth.includes(".ts") || pth.includes(".js"))
    .forEach((task) => {
      require(`${tasksPath}/${task}`);
    });
};
