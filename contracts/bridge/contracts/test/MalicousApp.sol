// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

import "../interfaces/ICrossChainFilter.sol";
import "../interfaces/IOnMessageDelivered.sol";
import "../interfaces/IOutboundLane.sol";

contract MalicousApp is ICrossChainFilter, IOnMessageDelivered {

    function crossChainFilter(uint32, uint32, address, bytes calldata) external override view returns (bool) {
        return true;
    }

    function malicious(address outlane, bytes memory large) public payable {
        bytes memory encoded = abi.encode(this.loop.selector, large);
        IOutboundLane(outlane).send_message{value: msg.value}(address(this), encoded);
    }

    function on_messages_delivered(uint256, bool) override external {
        loop("");
    }

    function loop(bytes memory) public pure {
        uint cnt;
        while(true) {
            cnt++;
        }
    }
}
