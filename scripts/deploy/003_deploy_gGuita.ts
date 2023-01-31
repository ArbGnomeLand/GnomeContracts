import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const sGnomeDeployment = await deployments.get(CONTRACTS.sGnome);
    const migratorDeployment = await deployments.get(CONTRACTS.migrator);

    await deploy(CONTRACTS.gGnome, {
        from: deployer,
        args: [migratorDeployment.address, sGnomeDeployment.address],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.gGnome, "migration", "tokens"];
func.dependencies = [CONTRACTS.migrator];

export default func;
