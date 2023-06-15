// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./LaziPost.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaziPostFactory is Ownable {
    address[] public deployedLaziPosts;
    event LaziPostCreated(address postAddress);

    address public laziPostMintSigner = msg.sender;

    function set_laziPostMintSigner(address _laziPostMintSigner) public onlyOwner {
        laziPostMintSigner = _laziPostMintSigner;
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

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }
}
