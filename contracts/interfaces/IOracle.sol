// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

interface IOracle {
    function getPrice(address _pool) external returns (uint256);
}
