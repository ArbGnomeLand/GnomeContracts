// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import {IERC20} from "../interfaces/IERC20.sol";
import {SafeERC20} from "../libraries/SafeERC20.sol";

error OTCEscrow_UnapprovedUser();
error OTCEscrow_NotGnome();
error OTCEscrow_TradeInProgress();

/// @title  Gnome OTC Escrow
/// @notice Gnome OTC Escrow Contract
/// @dev    The Gnome OTC Escrow contract is a reusable contract for handling OTC trades
///         with other crypto institutions
contract OTCEscrow {
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    /// Involved Parties
    address public gnome;
    address public tradePartner;

    /// OTC Tokens
    address public gnomeToken;
    address public externalToken;

    /// Token Amounts
    uint256 public gnomeAmount;
    uint256 public externalAmount;

    constructor(
        address gnome_,
        address tradePartner_,
        address gnomeToken_,
        address externalToken_,
        uint256 gnomeAmount_,
        uint256 externalAmount_
    ) {
        gnome = gnome_;
        tradePartner = tradePartner_;

        gnomeToken = gnomeToken_;
        externalToken = externalToken_;

        gnomeAmount = gnomeAmount_;
        externalAmount = externalAmount_;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyApprovedParties() {
        if (msg.sender != gnome && msg.sender != tradePartner)
            revert OTCEscrow_UnapprovedUser();
        _;
    }

    modifier onlyGnome() {
        if (msg.sender != gnome) revert OTCEscrow_NotGnome();
        _;
    }

    modifier tradeInactive() {
        uint256 gnomeTokenBalance = IERC20(gnomeToken).balanceOf(
            address(this)
        );
        if (gnomeTokenBalance != 0) revert OTCEscrow_TradeInProgress();
        _;
    }

    /* ========== OTC TRADE FUNCTIONS ========== */

    /// @notice Exchanges tokens by transferring tokens from the trade partner to Gnome and
    ///         Gnome's tokens that were escrowed in the contract to the trade partner
    /// @notice Access restricted to Gnome and the trade partner
    function swap() external onlyApprovedParties {
        IERC20(externalToken).safeTransferFrom(
            tradePartner,
            gnome,
            externalAmount
        );
        IERC20(gnomeToken).safeTransfer(tradePartner, gnomeAmount);
    }

    /// @notice Cancels an OTC trade and returns Gnome's escrowed tokens to the multisig
    /// @notice Access restricted to Gnome
    function revoke() external onlyGnome {
        uint256 gnomeTokenBalance = IERC20(gnomeToken).balanceOf(
            address(this)
        );
        IERC20(gnomeToken).safeTransfer(gnome, gnomeTokenBalance);
    }

    /// @notice Allows removal of trade partner tokens if they were accidentally sent to the
    ///         contract rather than exchanged through the swap function
    /// @notice Access restricted to Gnome and the trade partner
    function revokeReceivedToken() external onlyApprovedParties {
        uint256 externalTokenBalance = IERC20(externalToken).balanceOf(
            address(this)
        );
        IERC20(externalToken).safeTransfer(tradePartner, externalTokenBalance);
    }

    /* ========== MANAGEMENT FUNCTIONS ========== */

    /// @notice Sets the trade parameters for a new OTC exchange if no trade is in progress
    /// @notice Access restricted to Gnome
    function newTrade(
        address tradePartner_,
        address gnomeToken_,
        address externalToken_,
        uint256 gnomeAmount_,
        uint256 externalAmount_
    ) external onlyGnome tradeInactive {
        tradePartner = tradePartner_;

        gnomeToken = gnomeToken_;
        externalToken = externalToken_;

        gnomeAmount = gnomeAmount_;
        externalAmount = externalAmount_;
    }
}
