// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.17;

import "./IERC20.sol";

// Old wsGNOME interface
interface IwsGNOME is IERC20 {
    function wrap(uint256 _amount) external returns (uint256);

    function unwrap(uint256 _amount) external returns (uint256);

    function wGNOMETosGNOME(uint256 _amount) external view returns (uint256);

    function sGNOMETowGNOME(uint256 _amount) external view returns (uint256);
}
