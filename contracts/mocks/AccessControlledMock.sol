// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "../types/GnomeAccessControlled.sol";

contract AccessControlledMock is GnomeAccessControlled {
    constructor(address _auth) GnomeAccessControlled(IGnomeAuthority(_auth)) {}

    bool public governorOnlyTest;

    bool public guardianOnlyTest;

    bool public policyOnlyTest;

    bool public vaultOnlyTest;

    function governorTest() external onlyGovernor returns (bool) {
        governorOnlyTest = true;
        return governorOnlyTest;
    }

    function guardianTest() external onlyGuardian returns (bool) {
        guardianOnlyTest = true;
        return guardianOnlyTest;
    }

    function policyTest() external onlyPolicy returns (bool) {
        policyOnlyTest = true;
        return policyOnlyTest;
    }

    function vaultTest() external onlyVault returns (bool) {
        governorOnlyTest = true;
        return governorOnlyTest;
    }
}
