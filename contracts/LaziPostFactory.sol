// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

import "./LaziPost.sol";

contract LaziPostFactory {
    address[] public deployedLaziPosts;

    function getDeployedLaziPostsCount() public view returns (uint256) {
    return deployedLaziPosts.length;
}


    function createLaziPost() public returns (address) {
        LaziPost newLaziPost = new LaziPost();
        deployedLaziPosts.push(address(newLaziPost));

        return address(newLaziPost);
    }

//     function createLaziPostDeploy() public returns (LaziPost) {
//     LaziPost newLaziPost = new LaziPost();
//     deployedLaziPosts.push(address(newLaziPost));
//     return newLaziPost;
// }

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }
}