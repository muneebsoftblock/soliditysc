// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is ERC721Holder, Ownable {
    uint256 private constant SECONDS_PER_DAY = 86400;
    uint256 private constant TOTAL_REWARD_TOKENS = 200_000_000;
    uint256 private constant REWARD_PERIOD = 4 * 365 * SECONDS_PER_DAY;

    IERC20 public rewardToken;
    IERC721 public nftToken;

    struct StakeInfo {
        uint256 stakedTimestamp;
        uint256 erc20Amount;
        uint256[] erc721Ids;
        uint256 claimedRewards;
    }

    mapping(address => StakeInfo) public stakes;

    mapping(uint256 => uint256) private lockPeriodDistribution;
    mapping(uint256 => uint256) private stakedTokensDistribution;
    mapping(uint256 => uint256) private rewardTokensDistribution;
    mapping(uint256 => uint256) private apyDistribution;

    constructor(IERC20 _rewardToken, IERC721 _nftToken) {
        rewardToken = _rewardToken;
        nftToken = _nftToken;
    }

    function getRewardMultiplier(uint256 stakingDays, uint256 erc721Tokens) public pure returns (uint256) {
        uint256 timeMultiplier;

        if (stakingDays < 90) {
            timeMultiplier = 100;
        } else if (stakingDays < 180) {
            timeMultiplier = 125;
        } else if (stakingDays < 365) {
            timeMultiplier = 150;
        } else if (stakingDays < 545) {
            timeMultiplier = 200;
        } else if (stakingDays < 730) {
            timeMultiplier = 275;
        } else {
            timeMultiplier = 350;
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

        return (timeMultiplier * erc721Multiplier) / 100;
    }

    function stake(uint256 erc20Amount, uint256 daysToStake, uint256[] calldata erc721Ids) external {
        require(erc20Amount > 0, "Must stake a positive amount");
        require(daysToStake > 0, "Must stake for a positive number of days");
        require(stakes[msg.sender].erc20Amount == 0, "Must unstake before staking again");

        uint256 erc721Amount = erc721Ids.length;
        for (uint256 i = 0; i < erc721Amount; i++) {
            nftToken.safeTransferFrom(msg.sender, address(this), erc721Ids[i]);
        }

        rewardToken.transferFrom(msg.sender, address(this), erc20Amount);

        stakes[msg.sender] = StakeInfo({stakedTimestamp: block.timestamp, erc20Amount: erc20Amount, erc721Ids: erc721Ids, claimedRewards: 0});

        updateDistributions(daysToStake, erc20Amount, 0);
    }

    function unstake() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.erc20Amount > 0, "No tokens staked");

        rewardToken.transfer(msg.sender, stakeInfo.erc20Amount);

        for (uint256 i = 0; i < stakeInfo.erc721Ids.length; i++) {
            nftToken.safeTransferFrom(address(this), msg.sender, stakeInfo.erc721Ids[i]);
        }

        delete stakes[msg.sender];
    }

    function harvestRewards() external {
        uint256 rewards = getUserRewards(msg.sender);
        require(rewards > 0, "No rewards available");

        rewardToken.transfer(msg.sender, rewards);
        stakes[msg.sender].claimedRewards += rewards;

        updateDistributions(0, 0, rewards);
    }

    function compoundRewards() external {
        uint256 rewards = getUserRewards(msg.sender);
        require(rewards > 0, "No rewards available");

        stakes[msg.sender].erc20Amount += rewards;
        stakes[msg.sender].claimedRewards += rewards;
    }

    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];

        if (stakeInfo.erc20Amount == 0) {
            return 0;
        }

        uint256 stakingDays = (block.timestamp - stakeInfo.stakedTimestamp) / SECONDS_PER_DAY;
        uint256 rewardMultiplier = getRewardMultiplier(stakingDays, stakeInfo.erc721Ids.length);

        uint256 totalRewards = (stakeInfo.erc20Amount * REWARD_PERIOD * rewardMultiplier) / (TOTAL_REWARD_TOKENS * 10000);
        uint256 pendingRewards = totalRewards - stakeInfo.claimedRewards;

        return pendingRewards;
    }

    function updateDistributions(uint256 daysToStake, uint256 erc20Amount, uint256 rewards) private {
        lockPeriodDistribution[daysToStake] += 1;
        stakedTokensDistribution[daysToStake] += erc20Amount;
        rewardTokensDistribution[daysToStake] += rewards;
        apyDistribution[daysToStake] = getCurrentAPY();
    }

    function getLockPeriodDistribution(uint256 daysToStake) public view returns (uint256) {
        return lockPeriodDistribution[daysToStake];
    }

    function getStakedTokensDistribution(uint256 daysToStake) public view returns (uint256) {
        return stakedTokensDistribution[daysToStake];
    }

    function getRewardTokensDistribution(uint256 daysToStake) public view returns (uint256) {
        return rewardTokensDistribution[daysToStake];
    }

    function getAPYDistribution(uint256 daysToStake) public view returns (uint256) {
        return apyDistribution[daysToStake];
    }

    function getCurrentAPR() public view returns (uint256) {
        uint256 totalStaked = rewardToken.balanceOf(address(this));

        // Check for division by zero
        if (totalStaked == 0) {
            return 0;
        }

        uint256 totalRewardsPerYear = (TOTAL_REWARD_TOKENS * SECONDS_PER_DAY) / REWARD_PERIOD;
        return (totalRewardsPerYear * 100) / totalStaked;
    }

    function getCurrentAPY() public view returns (uint256) {
        uint256 apr = getCurrentAPR();
        return ((1 + apr / 100) ** 365) - 1;
    }
}
