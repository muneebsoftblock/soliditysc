// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./LaziPost.sol";

contract LaziPostFactory {
    address[] public deployedLaziPosts;

    function createLaziPost() public returns (address) {
        LaziPost newLaziPost = new LaziPost();
        deployedLaziPosts.push(address(newLaziPost));
        return address(newLaziPost);
    }

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }
}