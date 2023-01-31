import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { GnomeERC20Token__factory } from "../../types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);
    const gnome = await GnomeERC20Token__factory.connect(gnomeDeployment.address, signer);

    await deploy(CONTRACTS.bondingCalculator, {
        from: deployer,
        args: [gnome.address],
        log: true,
        skipIfAlreadyDeployed: false,
    });
};

func.tags = [CONTRACTS.bondingCalculator, "staking", "bonding"];
func.dependencies = [CONTRACTS.gnome];

export default func;
