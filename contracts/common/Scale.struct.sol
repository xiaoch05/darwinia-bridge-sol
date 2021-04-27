// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.7.0;

library ScaleStruct {
    struct LockEvent {
        bytes2 index;
        bytes32 sender;
        address recipient;
        address token;
        uint128 value;
    }

    struct IssuingEvent {
        bytes2 index;
        uint8 eventType;
        address backing;
        address payable recipient;
        address token;
        address target;
        uint256 value;
    }

    struct BackingEvent {
        bytes2 index;
        uint8 eventType;
        address source;
        // transfer used
        uint32 chainId;
        address recipient;
        uint256 value;
        // register used
        bytes32 name;
        bytes32 symbol;
        uint8 decimals;
    }
}
