// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./LaziPost.sol";

contract LaziPostFactory {
    address public factoryOwner; // New state variable to store the owner address
    address[] public deployedLaziPosts;
    event LaziPostCreated(address postAddress);

    constructor() {
        factoryOwner = msg.sender; // Set the contract deployer as the initial owner
    }

    function getFactoryOwner() public view returns (address) {
        return factoryOwner;
    }

    function getDeployedLaziPostsCount() public view returns (uint256) {
        return deployedLaziPosts.length;
    }

    function createLaziPost() public returns (address) {
        LaziPost newLaziPost = new LaziPost(); // Deploy the LaziPost contract
        deployedLaziPosts.push(address(newLaziPost));
        emit LaziPostCreated(address(newLaziPost));

        // Transfer ownership to the caller
        newLaziPost.transferOwnership(msg.sender);

        return address(newLaziPost);
    }

    function transferOwnership(address newOwner) public {
        require(newOwner != address(0), "Invalid new owner");
        transferOwnership(newOwner);
    }

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }
}
