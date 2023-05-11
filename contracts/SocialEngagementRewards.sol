// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**

@title LaziEngagementRewards

@notice A smart contract that allows users to stake LAZI tokens along with ERC721 tokens to earn rewards.

Users can stake their tokens for a specified duration and earn rewards based on the staked amount, duration, and the number of staked ERC721 tokens.
*/
contract LaziEngagementRewards is Ownable, ERC721Holder, ReentrancyGuard {
    address public trustedAddress = msg.sender;
    mapping(bytes32 => bool) public processedValues;

    IERC20 public laziToken;
    IERC721 public erc721Token;
    uint256 public maxEngagementDays = 2000;
    uint256 public maxUserMultiplierTokens = 5;

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

    /// @notice admin can change these weights depending on the project situation
    uint256 public w1 = 60;
    uint256 public w2 = 25;
    uint256 public w3 = 15;

    uint256 public REWARD_PERIOD = 4 * 365 days;
    uint256 public TOTAL_REWARD_TOKENS = 200_000_000 * 1e18;

    event Staked(address indexed user, uint256 stakedLazi, uint256 stakeDuration, uint256[] erc721TokenIds);
    event Unstaked(address indexed user, uint256 stakedLazi, uint256[] erc721TokenIds);
    event RewardsClaimed(address indexed user, uint256 reward);

    /**
    @notice Contract constructor
    @param _laziToken The LAZI token contract address
    @param _erc721Token The ERC721 token contract address
    */
    constructor(address _laziToken, address _erc721Token) {
        laziToken = IERC20(_laziToken);
        erc721Token = IERC721(_erc721Token);
    }

    // function harvest(uint256 contribution, uint timestamp, bytes32 timeContributionHash, uint8 v, bytes32 r, bytes32 s) external {
    function harvest(uint256 contribution) external nonReentrant {
        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to claim rewards");

        // address signer = ecrecover(timeContributionHash, v, r, s);
        // require(signer == trustedAddress, "Not signed by trusted address");
        // bytes32 expectedMessageHash = keccak256(abi.encodePacked(timestamp, contribution));
        // require(timeContributionHash == expectedMessageHash, "Message hash mismatch");
        // require(!processedValues[timeContributionHash], "Time Contribution Hash has been processed already");
        // processedValues[timeContributionHash] = true;

        uint256 reward = getUserRewards(msg.sender, contribution);
        require(reward > 0, "No rewards to claim");

        laziToken.transfer(msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
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
        require(_stakeDuration <= maxEngagementDays, "Stake duration exceeds maximum allowed");
        require(_laziUsernameIds.length <= maxUserMultiplierTokens, "Too many ERC721 tokens");

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

    function unstake() external nonReentrant {
        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to unstake");
        require(block.timestamp >= user.stakeStartTime + user.stakeDuration * 1 days, "Stake duration not completed");

        laziToken.transfer(msg.sender, user.stakedLazi);

        for (uint256 i = 0; i < user.erc721TokenIds.length; i++) {
            erc721Token.transferFrom(address(this), msg.sender, user.erc721TokenIds[i]);
        }

        totalStakedLazi -= user.stakedLazi;
        totalStakedDuration -= user.stakeDuration;
        totalWeightedStakedLazi -= user.stakedLaziWeighted;
        totalWeightedStakedDuration -= user.stakeDurationWeighted;
        totalUsers -= 1;

        emit Unstaked(msg.sender, user.stakedLazi, user.erc721TokenIds);
        delete users[msg.sender];
    }

    /**
     * @notice Calculate the multiplier for a user's stake
     * @param user The user information
     * @return The multiplier value
     */
    function getMultiplier(User memory user) internal view returns (uint256) {
        uint256 S = (user.stakedLazi * 1e18) / totalWeightedStakedLazi;
        uint256 T = (user.stakeDuration * 1e18) / totalWeightedStakedDuration;
        uint256 U;

        uint erc721Tokens = user.erc721TokenIds.length;
        if (erc721Tokens == 0) {
            U = 1.00 * 1e18;
        } else if (erc721Tokens == 1) {
            U = 1.20 * 1e18;
        } else if (erc721Tokens == 2) {
            U = 1.40 * 1e18;
        } else if (erc721Tokens == 3) {
            U = 1.60 * 1e18;
        } else if (erc721Tokens == 4) {
            U = 1.80 * 1e18;
        } else {
            U = 2.00 * 1e18;
        }

        return (S * T * U) / 1e18;
    }

    /**
     * @notice Calculate the reward for a user's stake
     * @param _user The address of the user
     * @return The reward value
     */

    function getUserRewards(address _user, uint256 contribution) public view returns (uint256) {
        User storage user = users[_user];
        uint256 elapsedTime = block.timestamp - user.stakeStartTime;

        uint256 rate = TOTAL_REWARD_TOKENS / REWARD_PERIOD;
        uint256 reward = elapsedTime * rate;

        uint256 stakedDuration = user.stakeDurationWeighted / totalWeightedStakedDuration;
        uint256 stakedAmount = user.stakedLaziWeighted / totalWeightedStakedLazi;

        uint256 totalReward = contribution * reward * w1 + stakedDuration * reward * w2 + stakedAmount * reward * w3;
        return totalReward;
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

    function set_REWARD_PERIOD(uint256 period) external onlyOwner {
        REWARD_PERIOD = period;
    }

    function set_TOTAL_REWARD_TOKENS(uint256 totalTokens) external onlyOwner {
        TOTAL_REWARD_TOKENS = totalTokens;
    }

    function set_trustedAddress(address _trustedAddress) external onlyOwner {
        trustedAddress = _trustedAddress;
    }
}
