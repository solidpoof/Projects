// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IVeDist {
    function checkpointToken() external;

    function checkpointTotalSupply() external;
}
