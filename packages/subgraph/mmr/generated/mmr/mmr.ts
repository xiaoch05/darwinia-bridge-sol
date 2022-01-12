// THIS IS AN AUTOGENERATED FILE. DO NOT EDIT THIS FILE DIRECTLY.

import {
  ethereum,
  JSONValue,
  TypedMap,
  Entity,
  Bytes,
  Address,
  BigInt
} from "@graphprotocol/graph-ts";

export class Test extends ethereum.Event {
  get params(): Test__Params {
    return new Test__Params(this);
  }
}

export class Test__Params {
  _event: Test;

  constructor(event: Test) {
    this._event = event;
  }

  get sender(): Address {
    return this._event.parameters[0].value.toAddress();
  }
}

export class mmr extends ethereum.SmartContract {
  static bind(address: Address): mmr {
    return new mmr("mmr", address);
  }
}
