// SPDX-License-Identifier: MIT

/**
 * @title StakingLazi
 * @notice A staking contract that allows users to stake ERC20 tokens along with ERC721 tokens to earn rewards.
 * Users can stake their tokens for a specified lock period and earn rewards based on the staked amount and the number of staked ERC721 tokens.
 * The contract also provides functions to unstake tokens, harvest rewards, and view distributions for different lock periods.
 * Maths explanation:
    example 2 * 1.5 = 3, but to do this on solidity we have to do (2 * (1.5 * 1e18)) / 1e18
    we use 1e18 style to preserve decimal values. 1.5 can not be stores in uint256 so use it as 1.5 * 1e18
    1e18 must remain in multiplier. when multiplier is multiplied with desired value. then divide 1e18 with desired value to remove it 
 */

pragma solidity ^0.8.0;

import "./LaziToken.sol"; // Importing the LaziToken contract.

import "@openzeppelin/contracts/access/Ownable.sol"; // Importing the Ownable contract from the OpenZeppelin library.
import "@openzeppelin/contracts/utils/math/Math.sol"; // Importing the Math library from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Importing the IERC20 interface from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Importing the IERC721 interface from the OpenZeppelin library.
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Importing the ReentrancyGuard contract from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; // Importing the ERC721Holder contract from the OpenZeppelin library.

contract StakeLP is Ownable, ERC721Holder, ReentrancyGuard {
    struct StakeInfo {
        uint256 stakingAmount; // The amount of tokens staked.
        uint256 lockPeriod; // The lock period in seconds.
        uint256[] stakedTokenIds; // The IDs of the staked ERC721 tokens.
        uint256 stakeStartTime; // The start time of the stake.
        uint256 weightedStake; // The weighted stake based on the staking amount and multipliers.
        uint256 claimedRewards; // The amount of claimed rewards.
    }

    IERC20 public stakingToken; // The ERC20 token used for staking.
    LAZI public rewardToken; // The reward token.
    IERC721 public erc721; // The ERC721 token used for staking.

    uint256 private multiplierIncrementErc721 = 0.4 * 1e18; // The increment value for the ERC721 multiplier.
    uint256 private multiplierIncrementLockPeriod = 0.00000066 * 1e18; // The increment value for the lock period multiplier.

    uint256 public totalStaked; // The total amount of tokens staked.
    uint256 public totalWeightedStake; // The total weighted stake.
    mapping(address => StakeInfo) public stakes; // Mapping of user addresses to their stake information.
    mapping(uint256 => uint256) private txDistribution; // Mapping of lock periods to the number of transactions.
    mapping(uint256 => uint256) private stakedTokensDistribution; // Mapping of lock periods to the total amount of staked tokens.
    mapping(uint256 => uint256) private rewardTokensDistribution; // Mapping of lock periods to the total amount of reward tokens.

    uint256 public REWARD_STOP_TIME = block.timestamp + 4 * 365 days; // The stop time for reward distribution.
    uint256 public REWARD_PER_SEC = 1.5856 * 1e18; // The amount of reward tokens distributed per second.
    uint256 public MIN_LOCK_DURATION = 7 days; // The minimum lock duration in seconds.
    uint256 public MAX_LOCK_DURATION = 365 days; // The maximum lock duration in seconds.

    constructor(IERC20 _stakingToken, LAZI _rewardToken, IERC721 _erc721) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        erc721 = _erc721;
    }

    /**
     * @dev Calculates the weighted stake multiplier based on the number of ERC721 tokens and lock period.
     * @param erc721Tokens The number of ERC721 tokens staked.
     * @param lockPeriod The lock period in seconds.
     * @return The weighted stake multiplier.
     */
    function _getMultiplier(uint256 erc721Tokens, uint256 lockPeriod) private view returns (uint256) {
        if (lockPeriod == 0) return 1 * 1e18;

        uint256 lockPeriodMultiplier = 1 * 1e18 + lockPeriod * multiplierIncrementLockPeriod;

        uint256 erc721Multiplier = 1 * 1e18 + erc721Tokens * multiplierIncrementErc721;

        return (lockPeriodMultiplier * erc721Multiplier) / 1e18;
    }

    /**
     * @dev Mints reward tokens to the specified recipient.
     * @param recipient The address to receive the reward tokens.
     * @param amount The amount of reward tokens to mint.
     */
    function _mintRewardTokens(address recipient, uint256 amount) private {
        rewardToken.mint(recipient, amount);
    }

    /**
     * @dev Unstakes the staked tokens and transfers them back to the user.
     * @dev Also transfers the earned reward tokens to the user and removes the staked ERC721 tokens from the contract.
     */
    function unstake() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.stakingAmount > 0, "No stake found");
        require(block.timestamp >= stakeInfo.stakeStartTime + stakeInfo.lockPeriod, "Lock period not reached");

        uint256 rewardAmount = getUserRewards(msg.sender);
        stakingToken.transfer(msg.sender, stakeInfo.stakingAmount);
        _mintRewardTokens(msg.sender, rewardAmount);

        for (uint256 i = 0; i < stakeInfo.stakedTokenIds.length; i++) {
            erc721.safeTransferFrom(address(this), msg.sender, stakeInfo.stakedTokenIds[i]);
        }

        stakedTokensDistribution[stakeInfo.lockPeriod] -= stakeInfo.stakingAmount;
        rewardTokensDistribution[stakeInfo.lockPeriod] += rewardAmount;
        txDistribution[stakeInfo.lockPeriod]++;

        totalWeightedStake -= stakeInfo.weightedStake;
        totalStaked -= stakeInfo.stakingAmount;
        delete stakes[msg.sender];
    }

    /**
     * @dev Harvests the earned reward tokens for the caller and adds them to the user's balance.
     */
    function harvest() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 rewardAmount = getUserRewards(msg.sender);
        require(rewardAmount > 0, "No rewards to harvest");

        _mintRewardTokens(msg.sender, rewardAmount);
        stakeInfo.claimedRewards += rewardAmount;

        rewardTokensDistribution[stakeInfo.lockPeriod] += rewardAmount;
        txDistribution[stakeInfo.lockPeriod]++;
    }

    /**
     * @dev Withdraws the specified ERC20 tokens from the contract and transfers them to the contract owner.
     * @param _erc20 The address of the ERC20 token to withdraw.
     */
    function withdrawERC20(address _erc20) external onlyOwner {
        IERC20 token = IERC20(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    /**
     * @dev Calculates the rewards earned by the user based on their stake and the current time.
     * @param user The address of the user.
     * @return The amount of reward tokens earned.
     */
    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint checkPoint = Math.min(REWARD_STOP_TIME, block.timestamp);

        if (checkPoint <= stakeInfo.stakeStartTime || totalWeightedStake == 0) return 0;

        uint256 secondsPassed = checkPoint - stakeInfo.stakeStartTime;
        uint256 rewardAmount = (stakeInfo.weightedStake * secondsPassed * REWARD_PER_SEC) / totalWeightedStake;

        if (rewardAmount <= stakeInfo.claimedRewards) return 0;

        return rewardAmount - stakeInfo.claimedRewards;
    }

    /**
     * @dev Stakes the specified amount of ERC20 tokens and ERC721 tokens for the specified lock period.
     * @param erc20Amount The amount of ERC20 tokens to stake.
     * @param lockPeriod The lock period in seconds.
     * @param erc721TokenIds The IDs of the ERC721 tokens to stake.
     */
    function stake(uint256 erc20Amount, uint256 lockPeriod, uint256[] calldata erc721TokenIds) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        // Clean old variables
        if (stakedTokensDistribution[stakeInfo.lockPeriod] >= stakeInfo.stakingAmount)
            stakedTokensDistribution[stakeInfo.lockPeriod] -= stakeInfo.stakingAmount;

        // Increase the staking amount and lock period for the user
        stakeInfo.stakingAmount += erc20Amount;
        stakeInfo.lockPeriod += lockPeriod;

        // Check requirements for the lock period
        require(stakeInfo.lockPeriod + lockPeriod <= MAX_LOCK_DURATION, "Cannot stake more than maximum lock period");
        require(lockPeriod == 0 || lockPeriod >= MIN_LOCK_DURATION, "Cannot stake less than minimum lock period");

        // Store the staked assets
        stakingToken.transferFrom(msg.sender, address(this), erc20Amount);
        for (uint256 i = 0; i < erc721TokenIds.length; i++) {
            erc721.safeTransferFrom(msg.sender, address(this), erc721TokenIds[i]);
            stakeInfo.stakedTokenIds.push(erc721TokenIds[i]);
        }

        // Perform calculations based on the lock period
        if (lockPeriod == 0) {
            // Add assets to the same lock period
            uint256 multiplier = _getMultiplier(erc721TokenIds.length, lockPeriod); // Calculate the multiplier based on the number of ERC721 tokens and the lock period
            uint256 weightedStake = (erc20Amount * multiplier) / 1e18; // Calculate the weighted stake by multiplying the ERC20 amount with the multiplier and dividing by 1e18
            stakeInfo.weightedStake += weightedStake; // Update the weighted stake for the user in the stakeInfo storage
            totalWeightedStake += weightedStake; // Add the new weighted stake to the total weighted stake
        } else {
            stakeInfo.stakeStartTime = block.timestamp; // Set the stake start time to the current block timestamp
            totalWeightedStake -= stakeInfo.weightedStake; // Subtract the previous weighted stake from the total weighted stake

            // Renew the lock period
            uint256 multiplier = _getMultiplier(stakeInfo.stakedTokenIds.length, stakeInfo.lockPeriod); // Calculate the multiplier based on the number of staked tokens and the lock period
            uint256 weightedStake = (stakeInfo.stakingAmount * multiplier) / 1e18; // Calculate the new weighted stake by multiplying the staking amount with the multiplier and dividing by 1e18
            stakeInfo.weightedStake = weightedStake; // Update the weighted stake for the user in the stakeInfo storage
            totalWeightedStake += stakeInfo.weightedStake; // Add the new weighted stake to the total weighted stake
        }

        // Update staked tokens distribution and transaction distribution to show on UI
        stakedTokensDistribution[stakeInfo.lockPeriod] += stakeInfo.stakingAmount;
        txDistribution[stakeInfo.lockPeriod]++;

        // Update the total staked amount
        totalStaked += erc20Amount;
    }

    /**
     * @dev Updates the reward per second rate.
     * @param rewardPerSec The new reward per second rate.
     */
    function updateRewardPerSec(uint256 rewardPerSec) external onlyOwner {
        REWARD_PER_SEC = rewardPerSec;
    }

    /**
     * @dev Updates the stop time for reward distribution.
     * @param stopTime The new stop time for reward distribution.
     */
    function updateRewardStopTime(uint256 stopTime) external onlyOwner {
        REWARD_STOP_TIME = stopTime;
    }

    /**
     * @dev Updates the minimum lock duration.
     * @param minLockDuration The new minimum lock duration.
     */
    function updateMinLockDuration(uint256 minLockDuration) external onlyOwner {
        MIN_LOCK_DURATION = minLockDuration;
    }

    /**
     * @dev Updates the maximum lock duration.
     * @param maxLockDuration The new maximum lock duration.
     */
    function updateMaxLockDuration(uint256 maxLockDuration) external onlyOwner {
        MAX_LOCK_DURATION = maxLockDuration;
    }

    /**
     * @dev Updates the multiplier increment for ERC721 tokens.
     * @param increment The new multiplier increment for ERC721 tokens.
     */
    function updateMultiplierIncrementErc721(uint256 increment) external onlyOwner {
        multiplierIncrementErc721 = increment;
    }

    /**
     * @dev Updates the multiplier increment for the lock period.
     * @param increment The new multiplier increment for the lock period.
     */
    function updateMultiplierIncrementLockPeriod(uint256 increment) external onlyOwner {
        multiplierIncrementLockPeriod = increment;
    }

    /**
     * @notice Retrieves the distributions of transactions, staked tokens, and reward tokens for the given time periods.
     * @dev This function allows retrieving multiple distributions at once for efficiency.
     * @param timeToStake An array of time periods for which to retrieve the distributions.
     * @return txDistributions An array containing the transaction distributions for each specified time period.
     * @return stakedTokenDistributions An array containing the staked token distributions for each specified time period.
     * @return rewardTokenDistributions An array containing the reward token distributions for each specified time period.
     */

    function getDistributions(
        uint256[] calldata timeToStake
    ) external view returns (uint256[] memory txDistributions, uint256[] memory stakedTokenDistributions, uint256[] memory rewardTokenDistributions) {
        uint256 length = timeToStake.length;
        txDistributions = new uint256[](length); // Array to store transaction distributions
        stakedTokenDistributions = new uint256[](length); // Array to store staked token distributions
        rewardTokenDistributions = new uint256[](length); // Array to store reward token distributions

        for (uint256 i = 0; i < length; i++) {
            uint256 time = timeToStake[i];
            txDistributions[i] = txDistribution[time]; // Get transaction distribution for the specified time
            stakedTokenDistributions[i] = stakedTokensDistribution[time]; // Get staked token distribution for the specified time
            rewardTokenDistributions[i] = rewardTokensDistribution[time]; // Get reward token distribution for the specified time
        }
    }
}
