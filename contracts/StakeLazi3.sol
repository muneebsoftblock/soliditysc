// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract StakingLazi is ERC721Holder, Ownable {
    struct StakeInfo {
        uint256 erc20Amount;
        uint256 lockPeriod;
        uint256[] erc721TokenIds;
        uint256 entryTimestamp;
        uint256 weightedStake;
        uint256 claimedRewards;
    }

    IERC20 public erc20;
    IERC721 public erc721;
    uint256 public totalStaked;
    uint256 public totalWeightedStake;
    mapping(address => StakeInfo) public stakes;
    uint256 public constant REWARD_PERIOD = 4 * 365 days;
    mapping(uint256 => uint256) public lockPeriodDistribution;
    mapping(uint256 => uint256) public stakedTokensDistribution;
    mapping(uint256 => uint256) public rewardTokensDistribution;
    uint256 public constant TOTAL_REWARD_TOKENS = 200_000_000 * (10 ** 18);

    function unstake() external {}

    function harvest() external {}

    function compound() external {}

    function withdrawERC20(address _erc20) external onlyOwner {}

    function getUserRewards(address user) public view returns (uint256) {}

    function _getMultiplier(uint256 numErc721Tokens, uint256 lockPeriod) private pure returns (uint256) {}

    function stake(uint256 erc20Amount, uint256 lockPeriodInDays, uint256[] calldata erc721TokenIds) external {}
}
