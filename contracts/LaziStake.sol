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

import "./LaziToken.sol"; // Importing the LaziToken contract.

import "@openzeppelin/contracts/access/Ownable.sol"; // Importing the Ownable contract from the OpenZeppelin library.
import "@openzeppelin/contracts/utils/math/Math.sol"; // Importing the Math library from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Importing the IERC20 interface from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Importing the IERC721 interface from the OpenZeppelin library.
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; // Importing the ReentrancyGuard contract from the OpenZeppelin library.
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol"; // Importing the ERC721Holder contract from the OpenZeppelin library.

contract StakeLaziThings is Ownable, ERC721Holder, ReentrancyGuard {
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
    mapping(uint256 => uint256) public txDistribution; // Mapping of lock periods to the number of transactions.
    mapping(uint256 => uint256) public stakedTokensDistribution; // Mapping of lock periods to the total amount of staked tokens.
    mapping(uint256 => uint256) public rewardTokensDistribution; // Mapping of lock periods to the total amount of reward tokens.

    uint256 public REWARD_STOP_TIME = block.timestamp + 4 * 365 days; // The stop time for reward distribution.
    uint256 public REWARD_PER_SEC = 1.5856 * 1e18; // The amount of reward tokens distributed per second.
    uint256 public MIN_LOCK_DURATION = 7 days; // The minimum lock duration in seconds.
    uint256 public MAX_LOCK_DURATION = 365 days; // The maximum lock duration in seconds.

    constructor(IERC20 _stakingToken, LAZI _rewardToken, IERC721 _erc721) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        erc721 = _erc721;
    }

    function _getMultiplier(uint256 erc721Tokens, uint256 lockPeriod) private view returns (uint256) {
        if (lockPeriod == 0) return 1 * 1e18;

        uint256 lockPeriodMultiplier = 1 * 1e18 + lockPeriod * multiplierIncrementLockPeriod;

        uint256 erc721Multiplier = 1 * 1e18 + erc721Tokens * multiplierIncrementErc721;

        return (lockPeriodMultiplier * erc721Multiplier) / 1e18;
    }

    function _mintRewardTokens(address recipient, uint256 amount) private {
        rewardToken.mint(recipient, amount);
    }

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

    function harvest() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 rewardAmount = getUserRewards(msg.sender);
        require(rewardAmount > 0, "No rewards to harvest");

        _mintRewardTokens(msg.sender, rewardAmount);
        stakeInfo.claimedRewards += rewardAmount;

        rewardTokensDistribution[stakeInfo.lockPeriod] += rewardAmount;
        txDistribution[stakeInfo.lockPeriod]++;
    }

    function withdrawERC20(address _erc20) external onlyOwner {
        IERC20 token = IERC20(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint checkPoint = Math.min(REWARD_STOP_TIME, block.timestamp);

        if (checkPoint <= stakeInfo.stakeStartTime || totalWeightedStake == 0) return 0;

        uint256 secondsPassed = checkPoint - stakeInfo.stakeStartTime;
        uint256 rewardAmount = (stakeInfo.weightedStake * secondsPassed * REWARD_PER_SEC) / totalWeightedStake;

        if (rewardAmount <= stakeInfo.claimedRewards) return 0;

        return rewardAmount - stakeInfo.claimedRewards;
    }

    function stake(uint256 erc20Amount, uint256 lockPeriod, uint256[] calldata erc721TokenIds) external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        // clean old variables
        stakedTokensDistribution[stakeInfo.lockPeriod] -= stakeInfo.stakingAmount;

        stakeInfo.stakingAmount += erc20Amount;
        stakeInfo.lockPeriod += lockPeriod;

        // requirements
        require(stakeInfo.lockPeriod + lockPeriod <= MAX_LOCK_DURATION, "Can not stake more than maximum lock period");
        require(lockPeriod == 0 || lockPeriod >= MIN_LOCK_DURATION, "Can not stake less than minimum lock period");

        // store the staked assets
        stakingToken.transferFrom(msg.sender, address(this), erc20Amount);
        for (uint256 i = 0; i < erc721TokenIds.length; i++) {
            erc721.safeTransferFrom(msg.sender, address(this), erc721TokenIds[i]);
            stakeInfo.stakedTokenIds.push(erc721TokenIds[i]);
        }

        // Calculations
        if (lockPeriod == 0) {
            // add assets to same lock period
            uint256 multiplier = _getMultiplier(erc721TokenIds.length, lockPeriod);
            uint256 weightedStake = (erc20Amount * multiplier) / 1e18;
            stakeInfo.weightedStake += weightedStake;
            totalWeightedStake += weightedStake;
        } else {
            // renew lock period
            stakeInfo.stakeStartTime = block.timestamp;
            totalWeightedStake -= stakeInfo.weightedStake;
            uint256 multiplier = _getMultiplier(stakeInfo.stakedTokenIds.length, stakeInfo.lockPeriod);
            uint256 weightedStake = (stakeInfo.stakingAmount * multiplier) / 1e18;
            stakeInfo.weightedStake = weightedStake;
            totalWeightedStake += weightedStake;
        }

        totalStaked += erc20Amount;
        txDistribution[stakeInfo.lockPeriod]++;

        stakedTokensDistribution[stakeInfo.lockPeriod] += stakeInfo.stakingAmount;
    }

    function getDistributions(
        uint256[] calldata timeToStake
    ) external view returns (uint256[] memory txDistributions, uint256[] memory stakedTokenDistributions, uint256[] memory rewardTokenDistributions) {
        uint256 length = timeToStake.length;
        txDistributions = new uint256[](length);
        stakedTokenDistributions = new uint256[](length);
        rewardTokenDistributions = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 time = timeToStake[i];
            txDistributions[i] = txDistribution[time];
            stakedTokenDistributions[i] = stakedTokensDistribution[time];
            rewardTokenDistributions[i] = rewardTokensDistribution[time];
        }
    }

    function set_REWARD_PER_SEC(uint256 _REWARD_PER_SEC) external onlyOwner {
        REWARD_PER_SEC = _REWARD_PER_SEC;
    }

    function set_REWARD_STOP_TIME(uint256 _REWARD_STOP_TIME) external onlyOwner {
        REWARD_STOP_TIME = _REWARD_STOP_TIME;
    }

    function set_multiplierIncrementErc721(uint256 _multiplierIncrementErc721) external onlyOwner {
        multiplierIncrementErc721 = _multiplierIncrementErc721;
    }

    function set_multiplierIncrementLockPeriod(uint256 _multiplierIncrementLockPeriod) external onlyOwner {
        multiplierIncrementLockPeriod = _multiplierIncrementLockPeriod;
    }

    function set_MIN_LOCK_DURATION(uint256 _MIN_LOCK_DURATION) external onlyOwner {
        MIN_LOCK_DURATION = _MIN_LOCK_DURATION;
    }

    function set_MAX_LOCK_DURATION(uint256 _MAX_LOCK_DURATION) external onlyOwner {
        MAX_LOCK_DURATION = _MAX_LOCK_DURATION;
    }
}
