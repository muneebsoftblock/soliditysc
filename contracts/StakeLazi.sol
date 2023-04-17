// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StakingRewards {
    IERC20 public token;
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256) public lastRewardPerTokenPaid;
    mapping(address => uint256) public rewardsEarned;

    uint256 public rewardRate = 137000; // 137,000 tokens per day
    uint256 public rewardDuration = 4 * 365 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0 tokens");
        updateReward(msg.sender);
        stakedBalances[msg.sender] += amount;
        totalStaked += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Cannot withdraw 0 tokens");
        updateReward(msg.sender);
        stakedBalances[msg.sender] -= amount;
        totalStaked -= amount;
        token.transfer(msg.sender, amount);
    }

    function getReward() external {
        updateReward(msg.sender);
        uint256 reward = rewardsEarned[msg.sender];
        if (reward > 0) {
            rewardsEarned[msg.sender] = 0;
            token.transfer(msg.sender, reward);
        }
    }

    function startRewards() external {
        require(block.timestamp >= rewardDuration, "Rewards have already started");
        lastUpdateTime = block.timestamp;
    }

    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewardsEarned[account] = earned(account);
        lastRewardPerTokenPaid[account] = rewardPerTokenStored;
    }

    function lastTimeRewardApplicable() internal view returns (uint256) {
        return block.timestamp < rewardDuration ? block.timestamp : rewardDuration;
    }

    function rewardPerToken() internal view returns (uint256) {
        if (totalStaked == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18 / totalStaked);
    }

    function earned(address account) internal view returns (uint256) {
        return (stakedBalances[account] * (rewardPerToken() - lastRewardPerTokenPaid[account]) / 1e18) + rewardsEarned[account];
    }

    function calculateUserRewards(address account) external view returns (uint256) {
        return earned(account);
    }
}
