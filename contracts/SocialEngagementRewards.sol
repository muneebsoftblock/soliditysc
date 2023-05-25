// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./LaziToken.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**

@title LaziEngagementRewards

@notice A smart contract that allows users to stake LAZI tokens along with ERC721 tokens to earn rewards.

Users can stake their tokens for a specified duration and earn rewards based on the staked amount, duration, and the number of staked ERC721 tokens.
*/
contract LaziEngagementRewards is Ownable, ERC721Holder, ReentrancyGuard {
    using ECDSA for bytes32;

    address public smartContractLinkedAddressAPI = 0xCb1345D9bb0658d8424Bb092C62795204E3994Fd;
    mapping(bytes32 => bool) public processedValues;

    LAZI public laziToken;
    IERC721 public erc721Token;

    /// @notice admin can change these weights depending on the project situation
    uint256 public w1 = 50;
    uint256 public w2 = 35;
    uint256 public w3 = 15;

    uint256 public REWARD_STOP_TIME = block.timestamp + 4 * 365 days;
    uint256 public REWARD_PER_DAY = 137_000 ether;
    uint256 public maxEngagementDays = 2000 days;

    // Define penalty variables
    uint256 public stakePenaltyUnder50 = 30;
    uint256 public stakePenaltyBetween50And80 = 15;
    uint256 public stakePenaltyBetween80And100 = 5;

    uint256 public rewardPenaltyUnder50 = 50;
    uint256 public rewardPenaltyBetween50And80 = 25;
    uint256 public rewardPenaltyBetween80And100 = 15;

    struct User {
        uint256 stakedLazi;
        uint256 stakedLaziWeighted;
        uint256 stakeStartTime;
        uint256 stakeDuration;
        uint256 stakeDurationWeighted;
        uint256[] erc721TokenIds;
    }

    mapping(address => User) public users;

    uint256 public totalUsers;

    uint256 public totalStakedLazi;
    uint256 public totalStakedDuration;

    uint256 public totalWeightedStakedLazi;
    uint256 public totalWeightedStakedDuration;

    uint256 public PENALTY_POOL;
    uint256[] public multiplierValues;
    mapping(bytes => bool) public _signatureUsed;

    event Staked(address indexed user, uint256 stakedLazi, uint256 stakeDuration, uint256[] erc721TokenIds);
    event Unstaked(address indexed user, uint256 stakedLazi, uint256[] erc721TokenIds);
    event RewardsClaimed(address indexed user, uint256 reward);

    /**
    @notice Contract constructor
    @param _laziToken The LAZI token contract address
    @param _laziName The ERC721 token contract address
    */
    constructor(address _laziToken, address _laziName) {
        laziToken = LAZI(_laziToken);
        erc721Token = IERC721(_laziName);
        multiplierValues = new uint256[](6);
        initializeMultiplierValues();
    }

    /**

    @notice Stake LAZI tokens and ERC721 tokens

    @param _stakedLazi Amount of LAZI tokens to stake

    @param _stakeDuration Duration of the stake in days

    @param _laziUsernameIds Array of ERC721 token IDs to stake
    */
    function stake(uint256 _stakedLazi, uint256 _stakeDuration, uint256[] memory _laziUsernameIds) external nonReentrant {
        User storage user = users[msg.sender];
        require(user.stakedLazi == 0, "Unstake first to stake again");
        require(_stakedLazi > 0, "Staking amount must be greater than 0");
        require(_stakeDuration <= maxEngagementDays, "Stake duration exceeds maximum allowed");

        laziToken.transferFrom(msg.sender, address(this), _stakedLazi);

        for (uint256 i = 0; i < _laziUsernameIds.length; i++) {
            erc721Token.transferFrom(msg.sender, address(this), _laziUsernameIds[i]);
        }

        user.stakedLazi = _stakedLazi;
        user.stakeDuration = _stakeDuration;
        user.stakeStartTime = block.timestamp;
        user.erc721TokenIds = _laziUsernameIds;

        totalStakedLazi += _stakedLazi;
        totalStakedDuration += _stakeDuration;
        totalUsers += 1;

        uint256 multiplier = getMultiplier(user);
        user.stakedLaziWeighted = (_stakedLazi * multiplier) / 1e18;
        user.stakeDurationWeighted = (_stakeDuration * multiplier) / 1e18;
        totalWeightedStakedLazi += user.stakedLaziWeighted;
        totalWeightedStakedDuration += user.stakeDurationWeighted;

        emit Staked(msg.sender, _stakedLazi, _stakeDuration, _laziUsernameIds);
    }

    /**
     * @notice Unstake LAZI tokens and ERC721 tokens
     */

    function unstake(
        uint256 contributionWeighted,
        uint256 totalWeightedContribution,
        uint256 timestamp,
        bytes memory _signature
    ) external nonReentrant {
        bytes32 message = keccak256(abi.encodePacked(contributionWeighted, totalWeightedContribution, timestamp));
        require(smartContractLinkedAddressAPI == message.toEthSignedMessageHash().recover(_signature), "Invalid Signature!");

        require(_signatureUsed[_signature] == false, "Signature is Already Used");
        _signatureUsed[_signature] = true;

        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to unstake");

        uint256 reward = getUserRewards(msg.sender, contributionWeighted, totalWeightedContribution);

        uint256 completedDurationPercentage = ((block.timestamp - user.stakeStartTime) * 100) / user.stakeDuration;
        uint256 stakedPenalty;
        uint256 rewardPenalty;
        if (completedDurationPercentage < 50) {
            stakedPenalty = (user.stakedLazi * stakePenaltyUnder50) / 100;
            rewardPenalty = (reward * rewardPenaltyUnder50) / 100;
        } else if (completedDurationPercentage >= 50 && completedDurationPercentage < 80) {
            stakedPenalty = (user.stakedLazi * stakePenaltyBetween50And80) / 100;
            rewardPenalty = (reward * rewardPenaltyBetween50And80) / 100;
        } else if (completedDurationPercentage >= 80 && completedDurationPercentage < 100) {
            stakedPenalty = (user.stakedLazi * stakePenaltyBetween80And100) / 100;
            rewardPenalty = (reward * rewardPenaltyBetween80And100) / 100;
        }

        laziToken.mint(msg.sender, reward - rewardPenalty);
        laziToken.transfer(msg.sender, user.stakedLazi - stakedPenalty);
        if (completedDurationPercentage < 100) {
            laziToken.mint(owner(), (stakedPenalty / 2) + (rewardPenalty / 2));
            PENALTY_POOL += (stakedPenalty / 2) + (rewardPenalty / 2);
        }

        for (uint256 i = 0; i < user.erc721TokenIds.length; i++) {
            erc721Token.transferFrom(address(this), msg.sender, user.erc721TokenIds[i]);
        }

        totalStakedLazi -= user.stakedLazi;
        totalStakedDuration -= user.stakeDuration;
        totalWeightedStakedLazi -= user.stakedLaziWeighted;
        totalWeightedStakedDuration -= user.stakeDurationWeighted;
        totalUsers -= 1;

        emit RewardsClaimed(msg.sender, reward - rewardPenalty);
        emit Unstaked(msg.sender, user.stakedLazi, user.erc721TokenIds);
        delete users[msg.sender];
    }

    /**
     * @notice Calculate the multiplier for a user's stake
     * @param user The user information
     * @return The multiplier value
     */
    function getMultiplier(User memory user) internal view returns (uint256) {
        uint256 S = totalWeightedStakedLazi == 0 ? 1e18 : (user.stakedLazi * 1e18) / totalWeightedStakedLazi;
        uint256 T = totalWeightedStakedDuration == 0 ? 1e18 : (user.stakeDuration * 1e18) / totalWeightedStakedDuration;
        uint256 U = getMultiplierValue(user.erc721TokenIds.length);

        if (S < 1e18) S = 1e18;
        if (T < 1e18) T = 1e18;
        if (U < 1e18) U = 1e18;

        return (S * T * U) / 1e36;
    }

    /**
     * @notice Initialize the multiplier values
     */
    function initializeMultiplierValues() internal onlyOwner {
        multiplierValues[0] = 1.00 * 1e18;
        multiplierValues[1] = 1.20 * 1e18;
        multiplierValues[2] = 1.40 * 1e18;
        multiplierValues[3] = 1.60 * 1e18;
        multiplierValues[4] = 1.80 * 1e18;
        multiplierValues[5] = 2.00 * 1e18;
    }

    /**
     * @notice Update the multiplier values
     * @param _multiplierValues An array of multiplier values
     */
    function updateMultiplierValues(uint256[] calldata _multiplierValues) external onlyOwner {
        multiplierValues = _multiplierValues;
    }

    /**
     * @notice Get a multiplier value at a specific index
     * @param index The index of the multiplier value to retrieve
     * @return The multiplier value
     */
    function getMultiplierValue(uint256 index) internal view returns (uint256) {
        if (index >= multiplierValues.length) index = multiplierValues.length - 1;
        return multiplierValues[index];
    }

    /**
     * @notice Calculate the reward for a user's stake
     * @param _user The address of the user
     * @return The reward value
     */

    function getUserRewards(address _user, uint256 contributionWeighted, uint256 totalWeightedContribution) public view returns (uint256) {
        require(contributionWeighted <= totalWeightedContribution, "Incorrect Values for contribution score");
        User storage user = users[_user];
        uint checkPoint = Math.min(block.timestamp, REWARD_STOP_TIME);

        if (user.stakeStartTime == 0) return 0;
        if (checkPoint <= user.stakeStartTime) return 0;

        uint256 elapsedTime = checkPoint - user.stakeStartTime;
        uint256 reward = elapsedTime * REWARD_PER_DAY;

        uint256 rewardContribution = (contributionWeighted * reward * w1) / (100 * totalWeightedContribution * 1 days);
        uint256 rewardStakedDuration = (user.stakeDurationWeighted * reward * w2) / (100 * totalWeightedStakedDuration * 1 days);
        uint256 rewardStakedAmount = (user.stakedLaziWeighted * reward * w3) / (100 * totalWeightedStakedLazi * 1 days);

        uint totalReward = rewardContribution + rewardStakedDuration + rewardStakedAmount;
        return totalReward;
    }

    function withdrawERC20(address _erc20) external onlyOwner {
        LAZI token = LAZI(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    /**
     * @notice Update the weight parameters
     * @param _w1 The weight for weightedContribution
     * @param _w2 The weight for weightedDuration
     * @param _w3 The weight for weightedStakedAmount
     */
    function updateWeights(uint256 _w1, uint256 _w2, uint256 _w3) external onlyOwner {
        require(_w1 + _w2 + _w3 == 100, "Weights must add up to 100");

        w1 = _w1;
        w2 = _w2;
        w3 = _w3;
    }

    function set_REWARD_PER_DAY(uint256 _REWARD_PER_DAY) external onlyOwner {
        REWARD_PER_DAY = _REWARD_PER_DAY;
    }

    function set_REWARD_STOP_TIME(uint256 _REWARD_STOP_TIME) external onlyOwner {
        REWARD_STOP_TIME = _REWARD_STOP_TIME;
    }

    function set_maxEngagementDays(uint256 _maxEngagementDays) external onlyOwner {
        maxEngagementDays = _maxEngagementDays;
    }

    function set_smartContractLinkedAddressAPI(address _smartContractLinkedAddressAPI) external onlyOwner {
        smartContractLinkedAddressAPI = _smartContractLinkedAddressAPI;
    }

    function updatePenalties(
        uint256 _stakePenaltyUnder50,
        uint256 _stakePenaltyBetween50And80,
        uint256 _stakePenaltyBetween80And100,
        uint256 _rewardPenaltyUnder50,
        uint256 _rewardPenaltyBetween50And80,
        uint256 _rewardPenaltyBetween80And100
    ) external onlyOwner {
        require(
            stakePenaltyUnder50 < 100 && stakePenaltyBetween50And80 < 100 && stakePenaltyBetween80And100 < 100,
            "Unstake penalty values must be less than 100"
        );
        require(
            rewardPenaltyUnder50 < 100 && rewardPenaltyBetween50And80 < 100 && rewardPenaltyBetween80And100 < 100,
            "Reward penalty values must be less than 100"
        );

        stakePenaltyUnder50 = _stakePenaltyUnder50;
        stakePenaltyBetween50And80 = _stakePenaltyBetween50And80;
        stakePenaltyBetween80And100 = _stakePenaltyBetween80And100;
        rewardPenaltyUnder50 = _rewardPenaltyUnder50;
        rewardPenaltyBetween50And80 = _rewardPenaltyBetween50And80;
        rewardPenaltyBetween80And100 = _rewardPenaltyBetween80And100;
    }
}
