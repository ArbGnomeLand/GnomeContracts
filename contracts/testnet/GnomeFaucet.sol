// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import "../interfaces/IERC20.sol";
import "../types/Ownable.sol";

contract GnomeFaucet is Ownable {
    IERC20 public gnome;

    constructor(address _gnome) {
        gnome = IERC20(_gnome);
    }

    function setGnome(address _gnome) external onlyOwner {
        gnome = IERC20(_gnome);
    }

    function dispense() external {
        gnome.transfer(msg.sender, 1e9);
    }
}
