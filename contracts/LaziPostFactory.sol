// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./LaziPost.sol";

contract LaziPostFactory {
    address[] public deployedLaziPosts;
    event LaziPostCreated(address postAddress);

    function getDeployedLaziPostsCount() public view returns (uint256) {
        return deployedLaziPosts.length;
    }

    function createLaziPost() public returns (address) {
        LaziPost newLaziPost = new LaziPost(msg.sender);
        deployedLaziPosts.push(address(newLaziPost));
        emit LaziPostCreated(address(newLaziPost));
        return address(newLaziPost);
    }

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }
}
