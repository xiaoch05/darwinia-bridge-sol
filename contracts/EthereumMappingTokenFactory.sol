// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./common/Scale.sol";
import "./common/Ownable.sol";
import "./interfaces/IERC20Option.sol";
import "./interfaces/IRelay.sol";
import { ScaleStruct } from "./common/Scale.struct.sol";

pragma experimental ABIEncoderV2;

contract EthereumMappingTokenFactory is Initializable, Ownable {
    using SafeERC20 for IERC20;
    enum BackingEventType { REGISTER, LOCK }

    IRelay public relay;
    bytes public substrateEventStorageKey;
    uint32 public chainId;
    address public backing;
    address public admin;
    address[] public allTokens;
    mapping(bytes32 => address) public tokenMap;
    mapping(address => address) public tokenToSource;
    mapping(string => address) public logic;
    mapping(uint32 => address) public history;

    string constant LOGIC_ERC20 = "erc20";

    event MappingTokenBurned(address token, address recipient, uint256 amount);
    event MappingTokenCreated(address source, address token);
    event NewLogicSetted(string name, address addr);
    event VerifyProof(uint32 blocknumber);

    function initialize(address _relay, uint32 _chainId) public initializer {
        ownableConstructor();
        chainId = _chainId;
        relay = IRelay(_relay);
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    function setBacking(address _backing) external onlyOwner {
        backing = _backing;
    }

    function setERC20Logic(address _logic) external onlyOwner {
        logic[LOGIC_ERC20] = _logic;
        emit NewLogicSetted(LOGIC_ERC20, _logic);
    }

    function setStorageKey(bytes memory key) external onlyOwner {
        substrateEventStorageKey = key;
    }

    function deploy(bytes32 salt, bytes memory code) internal returns (address payable addr) {
        bytes32 newsalt = keccak256(abi.encodePacked(salt, msg.sender)); 
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), newsalt)
            if iszero(extcodesize(addr)) { revert(0, 0) }
        }
    }

    function createERC20Contract(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address source
    ) internal returns (address token) {
        bytes32 salt = keccak256(abi.encodePacked(backing, source));
        require(tokenMap[salt] == address(0), "contract has been deployed");
        bytes memory bytecode = type(TransparentUpgradeableProxy).creationCode;
        bytes memory erc20initdata = 
            abi.encodeWithSignature("initialize(string,string,uint8)",
                                    name,
                                    symbol,
                                    decimals);
        bytes memory bytecodeWithInitdata = abi.encodePacked(bytecode, abi.encode(logic[LOGIC_ERC20], admin, erc20initdata));
        token = deploy(salt, bytecodeWithInitdata);
        tokenMap[salt] = token;
        allTokens.push(token);
        tokenToSource[token] = source;

        emit MappingTokenCreated(source, token);
    }

    function tokenLength() external view returns (uint) {
        return allTokens.length;
    }

    function mappingToken(address source) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(backing, source));
        return tokenMap[salt];
    }

    function crossReceiveSync(
        bytes memory message,
        bytes[] memory signatures,
        bytes32 root,
        uint32 MMRIndex,
        bytes memory blockHeader,
        bytes32[] memory peaks,
        bytes32[] memory siblings,
        bytes memory eventsProofStr
    ) public returns(ScaleStruct.BackingEvent[] memory) {
        if(relay.getMMRRoot(MMRIndex) == bytes32(0)) {
            relay.appendRoot(message, signatures);
        }
        return verifyProof(root, MMRIndex, blockHeader, peaks, siblings, eventsProofStr);
    }

    function verifyProof(
        bytes32 root,
        uint32 MMRIndex,
        bytes memory blockHeader,
        bytes32[] memory peaks,
        bytes32[] memory siblings,
        bytes memory eventsProofStr
    ) public returns(ScaleStruct.BackingEvent[] memory) {
        uint32 blockNumber = Scale.decodeBlockNumberFromBlockHeader(blockHeader);

        require(history[blockNumber] == address(0), "TokenBacking:: verifyProof:  The block has been verified");

        ScaleStruct.BackingEvent[] memory events = getBackingEvent(root, MMRIndex, blockHeader, peaks, siblings, eventsProofStr, blockNumber);

        uint256 len = events.length;
        for( uint i = 0; i < len; i++ ) {
          ScaleStruct.BackingEvent memory item = events[i];
          // we don't use block.chainid, because we cannot control it
          if (item.chainId != chainId) {
              continue;
          }
          if (item.eventType == uint8(BackingEventType.LOCK)) {
              address token = mappingToken(item.source);
              require(token != address(0), "token has not been registered");
              crossReceive(token, item.recipient, item.value);
          } else if (item.eventType == uint8(BackingEventType.REGISTER)) {
              string memory name = string(abi.encodePacked(item.name));
              string memory symbol = string(abi.encodePacked(item.symbol));
              createERC20Contract(name, symbol, item.decimals, item.source);
          }
        }

        history[blockNumber] = msg.sender;
        emit VerifyProof(blockNumber);
        return events;
    }

    function getBackingEvent(
        bytes32 root,
        uint32 MMRIndex,
        bytes memory blockHeader,
        bytes32[] memory peaks,
        bytes32[] memory siblings,
        bytes memory eventsProofStr,
        uint32 blockNumber
    ) public view returns(ScaleStruct.BackingEvent[] memory) {
        Input.Data memory data = Input.from(relay.verifyRootAndDecodeReceipt(root, MMRIndex, blockNumber, blockHeader, peaks, siblings, eventsProofStr, substrateEventStorageKey));
        return Scale.decodeBackingEvent(data);
    }

    function crossReceive(address token, address recipient, uint256 amount) internal {
        require(amount > 0, "can not receive amount zero");
        address source = tokenToSource[token];
        require(source != address(0), "token is not created by factory");
        IERC20Option(token).mint(recipient, amount);
    }

    function crossTransfer(address token, address recipient, uint256 amount) external {
        require(amount > 0, "can not transfer amount zero");
        address source = tokenToSource[token];
        require(source != address(0), "token is not created by factory");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20Option(token).burn(address(this), amount);
        emit MappingTokenBurned(source, recipient, amount);
    }
}

