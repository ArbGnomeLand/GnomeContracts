import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS, INITIAL_MINT } from "../../constants";
import { GnomeERC20Token__factory, GnomeTreasury__factory, DAI__factory } from "../../../types";
import { waitFor } from "../../txHelper";

const faucetContract = "GnomeFaucet";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, network, ethers } = hre;

    if (network.name == "mainnet") {
        console.log("Faucet cannot be deployed to mainnet");
        return;
    }

    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const daiDeployment = await deployments.get(CONTRACTS.DAI);

    const gnome = GnomeERC20Token__factory.connect(gnomeDeployment.address, signer);
    const mockDai = DAI__factory.connect(daiDeployment.address, signer);
    const treasury = GnomeTreasury__factory.connect(treasuryDeployment.address, signer);

    // Deploy Faucuet
    await deploy(faucetContract, {
        from: deployer,
        args: [gnomeDeployment.address],
        log: true,
        skipIfAlreadyDeployed: false,
    });
    const faucetDeployment = await deployments.get(faucetContract);

    let faucetBalance = await gnome.balanceOf(faucetDeployment.address);
    if (faucetBalance.gt(10000)) {
        // short circuit if faucet balance is above 10k gnome
        console.log("Sufficient faucet balance");
        console.log("Faucet Balance: ", faucetBalance.toString());
        return;
    }
    // Mint Dai
    const daiAmount = INITIAL_MINT;
    await waitFor(mockDai.mint(deployer, daiAmount));
    const daiBalance = await mockDai.balanceOf(deployer);
    console.log("Dai minted: ", daiBalance.toString());

    // Treasury Actions
    await waitFor(treasury.enable(0, deployer, ethers.constants.AddressZero)); // Enable the deployer to deposit reserve tokens
    await waitFor(treasury.enable(2, daiDeployment.address, ethers.constants.AddressZero)); // Enable Dai as a reserve Token

    // Deposit and mint gnome
    await waitFor(mockDai.approve(treasury.address, daiAmount)); // Approve treasury to use the dai
    await waitFor(treasury.deposit(daiAmount, daiDeployment.address, 0)); // Deposit Dai into treasury
    const gnomeMinted = await gnome.balanceOf(deployer);
    console.log("gnome minted: ", gnomeMinted.toString());

    // Fund faucet w/ newly minted dai.
    await waitFor(gnome.approve(faucetDeployment.address, gnomeMinted));
    await waitFor(gnome.transfer(faucetDeployment.address, gnomeMinted));

    faucetBalance = await gnome.balanceOf(faucetDeployment.address);
    console.log("Faucet balance:", faucetBalance.toString());
};

func.tags = ["faucet", "testnet"];
func.dependencies = [CONTRACTS.gnome, CONTRACTS.DAI, CONTRACTS.treasury];
func.runAtTheEnd = true;

export default func;
