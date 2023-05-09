// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**

@title LaziEngagementRewards

@notice A smart contract that allows users to stake LAZI tokens along with ERC721 tokens to earn rewards.

Users can stake their tokens for a specified duration and earn rewards based on the staked amount, duration, and the number of staked ERC721 tokens.
*/
contract LaziEngagementRewards {
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

    // TODO: make setters, onlyOwner
    uint256 public REWARD_PERIOD = 4 * 365 days;
    uint256 public TOTAL_REWARD_TOKENS = 200_000_000 * (10 ** 18);

    event Staked(address indexed user, uint256 stakedLazi, uint256 stakeDuration, uint256[] erc721TokenIds);
    event Unstaked(address indexed user, uint256 stakedLazi, uint256[] erc721TokenIds);

    /**
    @notice Contract constructor
    @param _laziToken The LAZI token contract address
    @param _laziUsername The ERC721 token contract address
    */
    constructor(address _laziToken, address _laziUsername) {
        laziToken = IERC20(_laziToken);
        erc721Token = IERC721(_laziUsername);
    }

    /**

    @notice Stake LAZI tokens and ERC721 tokens

    @param _stakedLazi Amount of LAZI tokens to stake

    @param _stakeDuration Duration of the stake in days

    @param _laziUsernameIds Array of ERC721 token IDs to stake
    */
    function stake(uint256 _stakedLazi, uint256 _stakeDuration, uint256[] memory _laziUsernameIds) external {
        // require(unstake first to stake again);

        require(_stakeDuration <= maxEngagementDays, "Stake duration exceeds maximum allowed");
        require(_laziUsernameIds.length <= maxUserMultiplierTokens, "Too many ERC721 tokens");

        laziToken.transferFrom(msg.sender, address(this), _stakedLazi);

        for (uint256 i = 0; i < _laziUsernameIds.length; i++) {
            erc721Token.transferFrom(msg.sender, address(this), _laziUsernameIds[i]);
        }

        User storage user = users[msg.sender];
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

    function getUserRewards(address _user, uint256 contributionScoreWeighted, uint256 totalContributionScoreWeighted) public view returns (uint256) {
        // ECDSA
        // bytes calldata encryptedData
        // (account, contributionScoreWeighted, totalContributionScoreWeighted) = decrypt(encryptedData)
        // require(account == signerAddr, "signer invalid");
        // require(contributionScoreWeighted > 0, "Contribution score missing");
        // ((user’s contribution score * user’s multiplier)/ total of all user’s (user’s contribution score * user’s multiplier))  *  49315

        User storage user = users[_user];
        uint256 elapsedTime = block.timestamp - user.stakeStartTime;

        uint256 weightedContribution = (((contributionScoreWeighted * elapsedTime * TOTAL_REWARD_TOKENS) / totalWeightedStakedDuration) *
            REWARD_PERIOD) * w1;
        uint256 weightedDuration = (((user.stakeDurationWeighted * elapsedTime * TOTAL_REWARD_TOKENS) / totalWeightedStakedDuration) *
            REWARD_PERIOD) * w2;
        uint256 weightedStakedAmount = (((user.stakedLaziWeighted * elapsedTime * TOTAL_REWARD_TOKENS) / totalWeightedStakedLazi) * REWARD_PERIOD) *
            w3;

        uint256 totalReward = weightedContribution + weightedDuration + weightedStakedAmount;
        return totalReward;
    }

    /**
     * @notice Update the weight parameters
     * @param _w1 The weight for weightedContribution
     * @param _w2 The weight for weightedDuration
     * @param _w3 The weight for weightedStakedAmount
     */
    function updateWeights(uint256 _w1, uint256 _w2, uint256 _w3) external {
        require(_w1 + _w2 + _w3 == 100, "Weights must add up to 100");

        w1 = _w1;
        w2 = _w2;
        w3 = _w3;
    }
}
