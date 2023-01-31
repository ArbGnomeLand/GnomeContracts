import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import {
    CONTRACTS,
    EPOCH_LENGTH_IN_BLOCKS,
    FIRST_EPOCH_TIME,
    FIRST_EPOCH_NUMBER,
} from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);
    const sGnomeDeployment = await deployments.get(CONTRACTS.sGnome);
    const gGnomeDeployment = await deployments.get(CONTRACTS.gGnome);

    await deploy(CONTRACTS.staking, {
        from: deployer,
        args: [
            gnomeDeployment.address,
            sGnomeDeployment.address,
            gGnomeDeployment.address,
            EPOCH_LENGTH_IN_BLOCKS,
            FIRST_EPOCH_NUMBER,
            FIRST_EPOCH_TIME,
            authorityDeployment.address,
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.staking, "staking"];
func.dependencies = [CONTRACTS.gnome, CONTRACTS.sGnome, CONTRACTS.gGnome];

export default func;
