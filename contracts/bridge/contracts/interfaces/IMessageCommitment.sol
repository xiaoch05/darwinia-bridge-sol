// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

interface IMessageCommitment {
    function thisChainPosition() external view returns (uint32);
    function thisLanePosition() external view returns (uint32);
    function bridgedChainPosition() external view returns (uint32);
    function bridgedLanePosition() external view returns (uint32);
    function commitment() external view returns (bytes32);
    function getLaneInfo() external view returns (uint32,uint32,uint32,uint32);
}
