// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

/**

@title LaziEngagementRewards

@notice A smart contract that allows users to stake LAZI tokens along with ERC721 tokens to earn rewards.

Users can stake their tokens for a specified duration and earn rewards based on the staked amount, duration, and the number of staked ERC721 tokens.
*/
contract LaziEngagementRewards is Ownable, ERC721Holder {
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

    uint256 public w1 = 60;
    uint256 public w2 = 25;
    uint256 public w3 = 15;

    uint256 public REWARD_PERIOD = 4 * 365 days;
    uint256 public TOTAL_REWARD_TOKENS = 200_000_000 * (10 ** 18);

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

    function harvest(uint256 contributionScoreWeighted, uint256 totalContributionScoreWeighted) external {
        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to claim rewards");

        uint256 reward = getUserRewards(msg.sender, contributionScoreWeighted, totalContributionScoreWeighted);
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
    function stake(uint256 _stakedLazi, uint256 _stakeDuration, uint256[] memory _laziUsernameIds) external {
        User storage user = users[msg.sender];
        require(user.stakedLazi == 0, "Unstake first to stake again");
        require(_stakeDuration <= maxEngagementDays, "Stake duration exceeds maximum allowed");
        require(_laziUsernameIds.length <= maxUserMultiplierTokens, "Too many ERC721 tokens");

        laziToken.transferFrom(msg.sender, address(this), _stakedLazi);

        for (uint256 i = 0; i < _laziUsernameIds.length; i++) {
            erc721Token.transferFrom(msg.sender, address(this), _laziUsernameIds[i]);
        }

        user.stakedLazi = _stakedLazi;
        user.stakeStartTime = block.timestamp;
        user.stakeDuration = _stakeDuration;
        user.erc721TokenIds = _laziUsernameIds;

        totalStakedLazi += _stakedLazi;
        totalStakedDuration += _stakeDuration;
        totalUsers += 1;

        uint256 multiplier = getMultiplier(user);
        totalWeightedStakedLazi += (_stakedLazi * multiplier) / 1e18;
        totalWeightedStakedDuration += (_stakeDuration * multiplier) / 1e18;

        emit Staked(msg.sender, _stakedLazi, _stakeDuration, _laziUsernameIds);
    }

    /**
     * @notice Unstake LAZI tokens and ERC721 tokens
     */

    function unstake() external {
        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to unstake");
        require(block.timestamp >= user.stakeStartTime + user.stakeDuration * 1 days, "Stake duration not completed");

        laziToken.transfer(msg.sender, user.stakedLazi);

        for (uint256 i = 0; i < user.erc721TokenIds.length; i++) {
            erc721Token.transferFrom(address(this), msg.sender, user.erc721TokenIds[i]);
        }

        totalStakedLazi -= user.stakedLazi;
        totalStakedDuration -= user.stakeDuration;
        totalUsers -= 1;
        emit Unstaked(msg.sender, user.stakedLazi, user.erc721TokenIds);

        delete users[msg.sender];
    }

    /**
     * @notice Calculate the multiplier for a user's stake
     * @param user The user information
     * @return The multiplier value
     */
    function getMultiplier(User memory user) public view returns (uint256) {
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
        // (account, contributionScoreWeighted, totalContributionScoreWeighted) = decrypt(encryptedData)
        // require(account == signerAddr, "signer invalid");

        User storage user = users[_user];
        uint256 elapsedTime = block.timestamp - user.stakeStartTime;

        uint256 rate = TOTAL_REWARD_TOKENS / REWARD_PERIOD;
        uint256 reward = elapsedTime * rate;

        // uint256 contribution = contributionScoreWeighted / totalContributionScoreWeighted; // This value can come from database
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

    function setRewardPeriod(uint256 period) external onlyOwner {
        REWARD_PERIOD = period;
    }

    function setTotalRewardTokens(uint256 totalTokens) external onlyOwner {
        TOTAL_REWARD_TOKENS = totalTokens;
    }
}
