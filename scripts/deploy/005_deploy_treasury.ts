import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, TREASURY_TIMELOCK } from "../constants";
//import { DAI, FRAX, OlympusERC20Token, OlympusTreasury } from "../types";
import { GnomeTreasury__factory } from "../../types";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);

    const authorityDeployment = await deployments.get(CONTRACTS.authority);

    // TODO: TIMELOCK SET TO 0 FOR NOW, CHANGE FOR ACTUAL DEPLOYMENT
    const treasuryDeployment = await deploy(CONTRACTS.treasury, {
        from: deployer,
        args: [gnomeDeployment.address, TREASURY_TIMELOCK, authorityDeployment.address],
        log: true,
        skipIfAlreadyDeployed: false,
    });

    await GnomeTreasury__factory.connect(treasuryDeployment.address, signer);
};

func.tags = [CONTRACTS.treasury, "treasury"];
func.dependencies = [CONTRACTS.gnome];

export default func;
