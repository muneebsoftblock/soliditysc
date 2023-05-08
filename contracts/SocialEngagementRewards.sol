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
        uint256 stakeStartTime;
        uint256 stakeDuration;
        uint256[] erc721TokenIds;
    }

    mapping(address => User) public users;
    uint256 public totalStakedLazi;
    uint256 public totalStakedDuration;
    uint256 public totalUsers;

    uint256 public w1 = 60;
    uint256 public w2 = 25;
    uint256 public w3 = 15;

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

        emit Staked(msg.sender, _stakedLazi, _stakeDuration, _laziUsernameIds);
    }

    /**

@notice Unstake LAZI tokens and ERC721 tokens
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
     * @param _user The address of the user
     * @return The multiplier value
     */
    function getMultiplier(address _user) public view returns (uint256) {
        User storage user = users[_user];
        uint256 S = (user.stakedLazi * 1e18) / (totalStakedLazi / totalUsers);
        uint256 T = (user.stakeDuration * 1e18) / (totalStakedDuration / totalUsers);
        uint256 U = user.erc721TokenIds.length;

        return S * T * U;
    }

    /**
     * @notice Calculate the reward for a user's stake
     * @param _user The address of the user
     * @return The reward value
     */
    function calculateReward(address _user) public view returns (uint256) {
        User storage user = users[_user];
        uint256 multiplier = getMultiplier(_user);
        uint256 contributionScore = user.stakedLazi * multiplier;
        uint256 weightedContribution = contributionScore * w1;
        uint256 weightedDuration = user.stakeDuration * w2;
        uint256 weightedStakedAmount = user.stakedLazi * w3;

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
