// SPDX-License-Identifier: MIT

/**
 * @title StakingLazi
 * @notice A staking contract that allows users to stake ERC20 tokens along with ERC721 tokens to earn rewards.
 * Users can stake their tokens for a specified lock period and earn rewards based on the staked amount and the number of staked ERC721 tokens.
 * The contract also provides functions to unstake tokens, harvest rewards, and view distributions for different lock periods.
 */

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract StakeERC20 is ERC721Holder, Ownable {
    struct StakeInfo {
        uint256 stakingAmount;
        uint256 lockPeriod;
        uint256[] stakedTokenIds;
        uint256 stakeStartTime;
        uint256 weightedStake;
        uint256 claimedRewards;
    }

    IERC20 public stakingToken;
    IERC20 public rewardToken;
    IERC721 public erc721;
    uint256 public totalStaked;
    uint256 public totalWeightedStake;
    mapping(address => StakeInfo) public stakes;
    mapping(uint256 => uint256) public lockPeriodDistribution;
    mapping(uint256 => uint256) public stakedTokensDistribution;
    mapping(uint256 => uint256) public rewardTokensDistribution;

    uint256 public REWARD_PERIOD = 4 * 365 days;
    uint256 public TOTAL_REWARD_TOKENS = 200_000_000 * (10 ** 18);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, IERC721 _erc721) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        erc721 = _erc721;
    }

    function unstake() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.stakingAmount > 0, "No stake found");
        require(block.timestamp >= stakeInfo.stakeStartTime + stakeInfo.lockPeriod, "Lock period not reached");

        uint256 rewardAmount = getUserRewards(msg.sender);
        stakingToken.transfer(msg.sender, stakeInfo.stakingAmount + rewardAmount);

        for (uint256 i = 0; i < stakeInfo.stakedTokenIds.length; i++) {
            erc721.safeTransferFrom(address(this), msg.sender, stakeInfo.stakedTokenIds[i]);
        }

        uint256 daysToStake = stakeInfo.lockPeriod / 1 days;
        updateDistributions(daysToStake, 0, rewardAmount);

        totalWeightedStake -= stakeInfo.weightedStake;
        totalStaked -= stakeInfo.stakingAmount;
        delete stakes[msg.sender];
    }

    function harvest() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 rewardAmount = getUserRewards(msg.sender);
        require(rewardAmount > 0, "No rewards to harvest");

        rewardToken.transfer(msg.sender, rewardAmount);
        stakeInfo.claimedRewards += rewardAmount;
        updateDistributions(0, 0, rewardAmount);
    }

    function withdrawERC20(address _erc20) external onlyOwner {
        IERC20 token = IERC20(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint256 elapsedTime = block.timestamp - stakeInfo.stakeStartTime;
        uint256 rewardAmount = (stakeInfo.weightedStake * elapsedTime * TOTAL_REWARD_TOKENS) / (totalWeightedStake * REWARD_PERIOD);
        return rewardAmount - stakeInfo.claimedRewards;
    }

    function _getMultiplier(uint256 erc721Tokens, uint256 lockPeriod) private pure returns (uint256) {
        uint256 erc20Multiplier;
        if (lockPeriod < 90 days) {
            erc20Multiplier = 100;
        } else if (lockPeriod < 180 days) {
            erc20Multiplier = 125;
        } else if (lockPeriod < 365 days) {
            erc20Multiplier = 150;
        } else if (lockPeriod < 545 days) {
            erc20Multiplier = 200;
        } else if (lockPeriod < 730 days) {
            erc20Multiplier = 275;
        } else {
            erc20Multiplier = 350;
        }

        uint256 erc721Multiplier;
        if (erc721Tokens == 0) {
            erc721Multiplier = 100;
        } else if (erc721Tokens == 1) {
            erc721Multiplier = 120;
        } else if (erc721Tokens == 2) {
            erc721Multiplier = 140;
        } else if (erc721Tokens == 3) {
            erc721Multiplier = 160;
        } else if (erc721Tokens == 4) {
            erc721Multiplier = 180;
        } else {
            erc721Multiplier = 200;
        }

        return (erc20Multiplier * erc721Multiplier) / 100;
    }

    function stake(uint256 erc20Amount, uint256 lockPeriodInDays, uint256[] calldata erc721TokenIds) external {
        require(stakes[msg.sender].stakingAmount == 0, "Existing stake found. Unstake before staking again.");
        require(erc20Amount > 0, "Staking amount must be greater than 0");

        uint256 lockPeriod = lockPeriodInDays * 1 days;
        uint256 numErc721Tokens = erc721TokenIds.length;
        uint256 multiplier = _getMultiplier(numErc721Tokens, lockPeriod);
        uint256 weightedStake = (erc20Amount * multiplier) / 100;

        stakingToken.transferFrom(msg.sender, address(this), erc20Amount);

        for (uint256 i = 0; i < numErc721Tokens; i++) {
            erc721.safeTransferFrom(msg.sender, address(this), erc721TokenIds[i]);
        }

        stakes[msg.sender] = StakeInfo({
            stakingAmount: erc20Amount,
            lockPeriod: lockPeriod,
            stakedTokenIds: erc721TokenIds,
            stakeStartTime: block.timestamp,
            weightedStake: weightedStake,
            claimedRewards: 0
        });

        totalStaked += erc20Amount;
        totalWeightedStake += weightedStake;
        updateDistributions(lockPeriodInDays, erc20Amount, 0);
    }

    function updateDistributions(uint256 daysToStake, uint256 erc20Amount, uint256 rewards) private {
        lockPeriodDistribution[daysToStake] += 1;
        stakedTokensDistribution[daysToStake] += erc20Amount;
        rewardTokensDistribution[daysToStake] += rewards;
    }

    function getDistributions(
        uint256[] calldata daysToStake
    )
        external
        view
        returns (uint256[] memory lockPeriodDistributions, uint256[] memory stakedTokenDistributions, uint256[] memory rewardTokenDistributions)
    {
        uint256 length = daysToStake.length;
        lockPeriodDistributions = new uint256[](length);
        stakedTokenDistributions = new uint256[](length);
        rewardTokenDistributions = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 day = daysToStake[i];
            lockPeriodDistributions[i] = lockPeriodDistribution[day];
            stakedTokenDistributions[i] = stakedTokensDistribution[day];
            rewardTokenDistributions[i] = rewardTokensDistribution[day];
        }
    }

    function setRewardPeriod(uint256 period) external onlyOwner {
        REWARD_PERIOD = period;
    }

    function setTotalRewardTokens(uint256 totalTokens) external onlyOwner {
        TOTAL_REWARD_TOKENS = totalTokens;
    }
}
