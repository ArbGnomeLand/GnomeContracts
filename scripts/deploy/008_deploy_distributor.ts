import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);
    const authorityDeployment = await deployments.get(CONTRACTS.authority);

    // TODO: firstEpochBlock is passed in but contract constructor param is called _nextEpochBlock
    await deploy(CONTRACTS.distributor, {
        from: deployer,
        args: [
            treasuryDeployment.address,
            gnomeDeployment.address,
            stakingDeployment.address,
            authorityDeployment.address,
        ],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.distributor, "staking"];
func.dependencies = [
    CONTRACTS.treasury,
    CONTRACTS.gnome,
    CONTRACTS.bondingCalculator,
    CONTRACTS.olympusAuthority,
];

export default func;
