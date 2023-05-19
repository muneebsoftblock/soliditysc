// SPDX-License-Identifier: MIT

/**
 * @title StakingLazi
 * @notice A staking contract that allows users to stake ERC20 tokens along with ERC721 tokens to earn rewards.
 * Users can stake their tokens for a specified lock period and earn rewards based on the staked amount and the number of staked ERC721 tokens.
 * The contract also provides functions to unstake tokens, harvest rewards, and view distributions for different lock periods.
 */

pragma solidity ^0.8.0;

import "./LaziToken.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract StakeLaziThings is Ownable, ERC721Holder, ReentrancyGuard {
    struct StakeInfo {
        uint256 stakingAmount;
        uint256 lockPeriod;
        uint256[] stakedTokenIds;
        uint256 stakeStartTime;
        uint256 weightedStake;
        uint256 claimedRewards;
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

    uint256 public REWARD_STOP_TIME = block.timestamp + 4 * 365 days;
    uint256 public REWARD_PER_DAY = 137_000 ether;
    uint256[] public lockPeriods;
    mapping(uint256 => uint256) public lockPeriodMultipliers;
    uint256[] public erc721Multipliers;

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
        require(block.timestamp >= stakeInfo.stakeStartTime + stakeInfo.lockPeriod, "Lock period not reached");

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

        _mintRewardTokens(msg.sender, rewardAmount);
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
        uint checkPoint = Math.min(REWARD_STOP_TIME, block.timestamp);

        if (checkPoint <= stakeInfo.stakeStartTime) return 0;

        uint256 secondsPassed = checkPoint - stakeInfo.stakeStartTime;
        uint256 rewardAmount = (stakeInfo.weightedStake * secondsPassed * REWARD_PER_DAY) / (1 days * totalWeightedStake);
        return rewardAmount - stakeInfo.claimedRewards;
    }

    function stake(uint256 erc20Amount, uint256 lockPeriodInDays, uint256[] calldata erc721TokenIds) external nonReentrant {
        require(stakes[msg.sender].stakingAmount == 0, "Existing stake found. Unstake before staking again.");
        require(erc20Amount > 0, "Staking amount must be greater than 0");

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

    function set_REWARD_PER_DAY(uint256 _REWARD_PER_DAY) external onlyOwner {
        REWARD_PER_DAY = _REWARD_PER_DAY;
    }

    function set_REWARD_STOP_TIME(uint256 _REWARD_STOP_TIME) external onlyOwner {
        REWARD_STOP_TIME = _REWARD_STOP_TIME;
    }
}
