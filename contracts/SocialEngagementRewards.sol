// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LaziEngagementRewards {
    using SafeMath for uint256;

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

    constructor(address _laziToken, address _erc721Token) {
        laziToken = IERC20(_laziToken);
        erc721Token = IERC721(_erc721Token);
    }

    function stake(uint256 _stakedLazi, uint256 _stakeDuration, uint256[] memory _erc721TokenIds) external {
        require(_stakeDuration <= maxEngagementDays, "Stake duration exceeds maximum allowed");
        require(_erc721TokenIds.length <= maxUserMultiplierTokens, "Too many ERC721 tokens");

        laziToken.transferFrom(msg.sender, address(this), _stakedLazi);

        for (uint256 i = 0; i < _erc721TokenIds.length; i++) {
            erc721Token.transferFrom(msg.sender, address(this), _erc721TokenIds[i]);
        }

        User storage user = users[msg.sender];
        user.stakedLazi = _stakedLazi;
        user.stakeStartTime = block.timestamp;
        user.stakeDuration = _stakeDuration;
        user.erc721TokenIds = _erc721TokenIds;

        totalStakedLazi = totalStakedLazi.add(_stakedLazi);
        totalStakedDuration = totalStakedDuration.add(_stakeDuration);
        totalUsers = totalUsers.add(1);

        emit Staked(msg.sender, _stakedLazi, _stakeDuration, _erc721TokenIds);
    }

    function unstake() external {
        User storage user = users[msg.sender];
        require(user.stakedLazi > 0, "No stake to unstake");
        require(block.timestamp >= user.stakeStartTime.add(user.stakeDuration.mul(1 days)), "Stake duration not completed");

        laziToken.transfer(msg.sender, user.stakedLazi);

        for (uint256 i = 0; i < user.erc721TokenIds.length; i++) {
            erc721Token.transferFrom(address(this), msg.sender, user.erc721TokenIds[i]);
        }

        totalStakedLazi = totalStakedLazi.sub(user.stakedLazi);
        totalStakedDuration = totalStakedDuration.sub(user.stakeDuration);
        totalUsers = totalUsers.sub(1);
        emit Unstaked(msg.sender, user.stakedLazi, user.erc721TokenIds);

        delete users[msg.sender];
    }

    function getMultiplier(address _user) public view returns (uint256) {
        User storage user = users[_user];
        uint256 S = user.stakedLazi.mul(1e18).div(totalStakedLazi.div(totalUsers));
        uint256 T = user.stakeDuration.mul(1e18).div(totalStakedDuration.div(totalUsers));
        uint256 U = user.erc721TokenIds.length;

        return S.mul(T).mul(U);
    }

    function calculateReward(address _user) public view returns (uint256) {
        User storage user = users[_user];
        uint256 multiplier = getMultiplier(_user);
        uint256 contributionScore = user.stakedLazi.mul(multiplier);
        uint256 weightedContribution = contributionScore.mul(w1);
        uint256 weightedDuration = user.stakeDuration.mul(w2);
        uint256 weightedStakedAmount = user.stakedLazi.mul(w3);

        uint256 totalReward = weightedContribution.add(weightedDuration).add(weightedStakedAmount);
        return totalReward;
    }

    function updateWeights(uint256 _w1, uint256 _w2, uint256 _w3) external {
        require(_w1.add(_w2).add(_w3) == 100, "Weights must add up to 100");

        w1 = _w1;
        w2 = _w2;
        w3 = _w3;
    }
}
