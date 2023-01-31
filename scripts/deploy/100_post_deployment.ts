import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { waitFor } from "../txHelper";
import { CONTRACTS, INITIAL_REWARD_RATE, INITIAL_INDEX, BOUNTY_AMOUNT } from "../constants";
import {
    GnomeAuthority__factory,
    Distributor__factory,
    GnomeERC20Token__factory,
    GnomeStaking__factory,
    SGnome__factory,
    GGNOME__factory,
    GnomeTreasury__factory,
} from "../../types";

// TODO: Shouldn't run setup methods if the contracts weren't redeployed.
const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    const { deployments, getNamedAccounts, ethers } = hre;
    const { deployer } = await getNamedAccounts();
    const signer = await ethers.provider.getSigner(deployer);

    const authorityDeployment = await deployments.get(CONTRACTS.authority);
    const gnomeDeployment = await deployments.get(CONTRACTS.gnome);
    const sGnomeDeployment = await deployments.get(CONTRACTS.sGnome);
    const gGnomeDeployment = await deployments.get(CONTRACTS.gGnome);
    const distributorDeployment = await deployments.get(CONTRACTS.distributor);
    const treasuryDeployment = await deployments.get(CONTRACTS.treasury);
    const stakingDeployment = await deployments.get(CONTRACTS.staking);

    const authorityContract = await GnomeAuthority__factory.connect(
        authorityDeployment.address,
        signer
    );
    const gnome = GnomeERC20Token__factory.connect(gnomeDeployment.address, signer);
    const sGnome = SGnome__factory.connect(sGnomeDeployment.address, signer);
    const gGnome = GGNOME__factory.connect(gGnomeDeployment.address, signer);
    const distributor = Distributor__factory.connect(distributorDeployment.address, signer);
    const staking = GnomeStaking__factory.connect(stakingDeployment.address, signer);
    const treasury = GnomeTreasury__factory.connect(treasuryDeployment.address, signer);

    // Step 1: Set treasury as vault on authority
    await waitFor(authorityContract.pushVault(treasury.address, true));
    console.log("Setup -- authorityContract.pushVault: set vault on authority");

    // Step 2: Set distributor as minter on treasury
    await waitFor(treasury.enable(8, distributor.address, ethers.constants.AddressZero)); // Allows distributor to mint gnome.
    console.log("Setup -- treasury.enable(8):  distributor enabled to mint gnome on treasury");

    // Step 3: Set distributor on staking
    await waitFor(staking.setDistributor(distributor.address));
    console.log("Setup -- staking.setDistributor:  distributor set on staking");

    // Step 4: Initialize sGNOME and set the index
    if ((await sGnome.gGNOME()) == ethers.constants.AddressZero) {
        await waitFor(sGnome.setIndex(INITIAL_INDEX)); // TODO
        await waitFor(sGnome.setgGNOME(gGnome.address));
        await waitFor(sGnome.initialize(staking.address, treasuryDeployment.address));
    }
    console.log("Setup -- sgnome initialized (index, ggnome");

    // Step 5: Set up distributor with bounty and recipient
    await waitFor(distributor.setBounty(BOUNTY_AMOUNT));
    await waitFor(distributor.addRecipient(staking.address, INITIAL_REWARD_RATE));
    console.log("Setup -- distributor.setBounty && distributor.addRecipient");

    // Approve staking contact to spend deployer's GUTIA
    // TODO: Is this needed?
    // await gnome.approve(staking.address, LARGE_APPROVAL);
};

func.tags = ["setup"];
func.dependencies = [CONTRACTS.gnome, CONTRACTS.sGnome, CONTRACTS.gGnome];

export default func;
