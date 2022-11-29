// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../protocol/OpenSeaFactory.sol";

contract ProxyRegistryMock is ProxyRegistry {
	// an address to return as proxies(address)
	address private owner;

	// creates a registry returning msg.sender as proxies(address)
	constructor() {
		owner = msg.sender;
	}

	// allows to override the owner - proxies(address)
	function setOwner(address _owner) public {
		owner = _owner;
	}

	/**
	 * @inheritdoc ProxyRegistry
	 */
	function proxies(address) public override view returns(OwnableDelegateProxy) {
		return OwnableDelegateProxy(owner);
	}
}
