// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./LaziPost.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LaziPostFactory is Ownable {
    // Variables
    string public laziPostImages;
    address[] public deployedLaziPosts;
    uint256 public royalty = 0.0 ether; // 0%
    address public API_ADDRESS = msg.sender;

    // Event
    event LaziPostCreated(address postAddress);

    // Transaction
    function createLaziPost() public returns (address) {
        LaziPost newLaziPost = new LaziPost(); // Deploy the LaziPost contract
        deployedLaziPosts.push(address(newLaziPost));
        emit LaziPostCreated(address(newLaziPost));
        newLaziPost.transferOwnership(msg.sender);
        return address(newLaziPost);
    }

    // Getters
    function getDeployedLaziPostsCount() public view returns (uint256) {
        return deployedLaziPosts.length;
    }

    function getDeployedLaziPosts() public view returns (address[] memory) {
        return deployedLaziPosts;
    }

    // Setters
    function set_laziPostImages(string calldata _laziPostImages) external onlyOwner {
        laziPostImages = _laziPostImages;
    }

    function set_API_ADDRESS(address _API_ADDRESS) public onlyOwner {
        API_ADDRESS = _API_ADDRESS;
    }

    /// @notice 5% royalty = 50000000000000000 = 0.05 ether, 1 ether = 100%
    function set_royaltyLaziApp(uint _royalty) external onlyOwner {
        require(royalty <= 1 ether, "values should between 0 and 1 ether as 0% and 100%");
        royalty = _royalty;
    }
}
