// SPDX-License-Identifier: MIT

/**
 * @title StakingLazi
 * @notice A staking contract that allows users to stake ERC20 tokens along with ERC721 tokens to earn rewards.
 * Users can stake their tokens for a specified lock period and earn rewards based on the staked amount and the number of staked ERC721 tokens.
 * The contract also provides functions to unstake tokens, harvest rewards, and view distributions for different lock periods.
 */

pragma solidity ^0.8.0;

import "./LaziToken.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract StakeLaziThings is Ownable, ERC721Holder, ReentrancyGuard {
    struct StakeInfo {
        uint256 stakingAmount;
        uint256 lockPeriod;
        uint256[] stakedTokenIds;
        uint256 stakeStartTime;
        uint256 weightedStake;
        uint256 claimedRewards;
        uint8 stakeOption;
    }
    enum StakeOption {
        FlexibleStake,
        LockedStake
    }

    IERC20 public stakingToken;
    LAZI public rewardToken;
    IERC721 public erc721;
    uint256 public totalStaked;
    uint256 public totalWeightedStake;
    mapping(address => StakeInfo) public stakes;
    mapping(uint256 => uint256) public lockPeriodDistribution;
    mapping(uint256 => uint256) public stakedTokensDistribution;
    mapping(uint256 => uint256) public rewardTokensDistribution;
    mapping(address => uint256) public lastCompoundingTime;
    // mapping(address => StakeOption) public stakeOption;

    uint256 public REWARD_STOP_TIME = block.timestamp + 4 * 365 days;
    uint256 public REWARD_PER_DAY = 137_000 ether;
    uint256[] public lockPeriods;
    mapping(uint256 => uint256) public lockPeriodMultipliers;
    uint256[] public erc721Multipliers;

    event RewardsCompounded(address indexed staker, uint256 rewards);

    constructor(
        IERC20 _stakingToken,
        LAZI _rewardToken,
        IERC721 _erc721,
        uint256[] memory lockPeriodsInput,
        uint256[] memory lockPeriodMultipliersInput,
        uint256[] memory erc721MultipliersInput
    ) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        erc721 = _erc721;
        setLockPeriods(lockPeriodsInput);
        setLockPeriodMultipliers(lockPeriodMultipliersInput);
        setERC721Multipliers(erc721MultipliersInput);
    }

    //modifiers
    modifier canAutoCompound(address staker) {
        require(block.timestamp >= lastCompoundingTime[staker] + 3 minutes, "Auto-compounding not available yet");
        _;
    }

    function setLockPeriods(uint256[] memory periods) public onlyOwner {
        require(periods.length > 0, "At least one lock period must be provided");
        lockPeriods = periods;
    }

    function setLockPeriodMultipliers(uint256[] memory multipliers) public onlyOwner {
        require(multipliers.length > 0, "At least one lock period multiplier must be provided");
        require(multipliers.length == lockPeriods.length, "Number of lock period multipliers must match the number of lock periods");
        for (uint256 i = 0; i < multipliers.length; i++) {
            lockPeriodMultipliers[lockPeriods[i]] = multipliers[i];
        }
    }

    function setERC721Multipliers(uint256[] memory multipliers) public onlyOwner {
        require(multipliers.length > 0, "At least one ERC721 multiplier must be provided");
        erc721Multipliers = multipliers;
    }

    function getERC721Multiplier(uint256 erc721Tokens) private view returns (uint256) {
        // Get the ERC721 multiplier based on the number of staked ERC721 tokens
        if (erc721Tokens >= erc721Multipliers.length) {
            return erc721Multipliers[erc721Multipliers.length - 1];
        }
        return erc721Multipliers[erc721Tokens];
    }

    function _getMultiplier(uint256 erc721Tokens, uint256 lockPeriod) private view returns (uint256) {
        uint256 lockPeriodMultiplier = lockPeriodMultipliers[lockPeriod];

        uint256 erc721Multiplier = getERC721Multiplier(erc721Tokens);

        return (lockPeriodMultiplier * erc721Multiplier) / 100;
    }

    function _mintRewardTokens(address recipient, uint256 amount) private {
        rewardToken.mint(recipient, amount);
    }

    function unstake() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.stakingAmount > 0, "No stake found");
        if (stakeInfo.stakeOption == LockedStake) {
            require(block.timestamp >= stakeInfo.stakeStartTime + stakeInfo.lockPeriod, "Lock period not reached");
        }

        uint256 rewardAmount = getUserRewards(msg.sender);
        stakingToken.transfer(msg.sender, stakeInfo.stakingAmount);
        _mintRewardTokens(msg.sender, rewardAmount);

        for (uint256 i = 0; i < stakeInfo.stakedTokenIds.length; i++) {
            erc721.safeTransferFrom(address(this), msg.sender, stakeInfo.stakedTokenIds[i]);
        }

        uint256 daysToStake = stakeInfo.lockPeriod / 1 days;
        updateDistributions(daysToStake, 0, rewardAmount);

        totalWeightedStake -= stakeInfo.weightedStake;
        totalStaked -= stakeInfo.stakingAmount;
        delete stakes[msg.sender];
    }

    function harvest() external nonReentrant {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 rewardAmount = getUserRewards(msg.sender);
        require(rewardAmount > 0, "No rewards to harvest");
        lastCompoundingTime[msg.sender] = block.timestamp;

        _mintRewardTokens(msg.sender, rewardAmount);
        stakeInfo.claimedRewards += rewardAmount;
        updateDistributions(0, 0, rewardAmount);
        // Update the last compounding time
    }

    function withdrawERC20(address _erc20) external onlyOwner {
        IERC20 token = IERC20(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint checkPoint = Math.min(REWARD_STOP_TIME, block.timestamp);

        if (checkPoint <= stakeInfo.stakeStartTime) return 0;

        uint256 secondsPassed = checkPoint - stakeInfo.stakeStartTime;
        uint256 rewardAmount = (stakeInfo.weightedStake * secondsPassed * REWARD_PER_DAY) / (1 days * totalWeightedStake);
        return rewardAmount - stakeInfo.claimedRewards;
    }

    function compoundRewards() external canAutoCompound(msg.sender) {
        StakeInfo storage stakeInfo = stakes[msg.sender];

        // Calculate the amount of rewards to compound
        uint256 additionalRewards = getUserRewards(msg.sender);
        require(additionalRewards > 0, "No rewards to compound");

        // Transfer the additional rewards to the staking contract
        rewardToken.transferFrom(msg.sender, address(this), additionalRewards);

        // Update the stake information
        stakeInfo.claimedRewards += additionalRewards;

        // Update the last compounding time
        lastCompoundingTime[msg.sender] = block.timestamp;

        // Call the private `_updateDistributions` function to update distributions
        updateDistributions(stakeInfo.lockPeriod, 0, additionalRewards);

        // Emit an event to notify the user
        emit RewardsCompounded(msg.sender, additionalRewards);
    }

    function lockedStake(uint256 erc20Amount, uint256 lockPeriodInDays, uint256[] calldata erc721TokenIds, uint8 stakeOption) external nonReentrant {
        require(stakes[msg.sender].stakingAmount == 0, "Existing stake found. Unstake before staking again.");
        require(erc20Amount > 0, "Staking amount must be greater than 0");
        require(stakeOption == uint8(StakeOption.FlexibleStake) || stakeOption == uint8(StakeOption.LockedStake), "Invalid stake option");
        require(stakeOption == LockedStake, "Staking must be Locked");

        // Set the stake option for the user
        // stakeOption[msg.sender] = StakeOption(stakeOption);

        uint256 lockPeriod = lockPeriodInDays * 1 days;
        uint256 numErc721Tokens = erc721TokenIds.length;
        uint256 multiplier = _getMultiplier(numErc721Tokens, lockPeriodInDays);
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
            claimedRewards: 0,
            stakeOption: StakeOption(stakeOption)
        });
        // Initialize the last compounding time
        lastCompoundingTime[msg.sender] = block.timestamp;

        totalStaked += erc20Amount;
        totalWeightedStake += weightedStake;
        updateDistributions(lockPeriodInDays, erc20Amount, 0);
    }

    function flexibleStake(uint256 additionalErc20Amount, uint256 additionalLockPeriodInDays, uint256[] calldata additionalErc721TokenIds) external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.stakingAmount > 0, "No stake found");
        require(stakeOption[msg.sender] == StakeOption.flexibleStake, "Not allowed for lockedStake");

        uint256 additionalLockPeriod = additionalLockPeriodInDays * 1 days;
        uint256 numAdditionalErc721Tokens = additionalErc721TokenIds.length;
        uint256 additionalMultiplier = _getMultiplier(numAdditionalErc721Tokens, additionalLockPeriodInDays);
        uint256 additionalWeightedStake = (additionalErc20Amount * additionalMultiplier) / 100;

        // Transfer additional staked tokens to the contract
        stakingToken.transferFrom(msg.sender, address(this), additionalErc20Amount);

        for (uint256 i = 0; i < numAdditionalErc721Tokens; i++) {
            erc721.safeTransferFrom(msg.sender, address(this), additionalErc721TokenIds[i]);
        }

        // Update stake information
        stakeInfo.lockPeriod += additionalLockPeriod;
        stakeInfo.stakingAmount += additionalErc20Amount;
        stakeInfo.weightedStake += additionalWeightedStake;
        for (uint256 i = 0; i < numAdditionalErc721Tokens; i++) {
            stakeInfo.stakedTokenIds.push(additionalErc721TokenIds[i]);
        }

        totalStaked += additionalErc20Amount;
        totalWeightedStake += additionalWeightedStake;

        uint256 totalLockPeriodInDays = stakeInfo.lockPeriod / 1 days;
        updateDistributions(totalLockPeriodInDays, additionalErc20Amount, 0);
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
        require(length > 0, "Empty array");

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

    function set_REWARD_PER_DAY(uint256 _REWARD_PER_DAY) external onlyOwner {
        REWARD_PER_DAY = _REWARD_PER_DAY;
    }

    function set_REWARD_STOP_TIME(uint256 _REWARD_STOP_TIME) external onlyOwner {
        REWARD_STOP_TIME = _REWARD_STOP_TIME;
    }
}
