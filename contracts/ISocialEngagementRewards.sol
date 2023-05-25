// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ILaziEngagementRewards {
    function smartContractLinkedAddressAPI() external view returns (address);

    function processedValues(bytes32) external view returns (bool);

    function w1() external view returns (uint256);

    function w2() external view returns (uint256);

    function w3() external view returns (uint256);

    function REWARD_STOP_TIME() external view returns (uint256);

    function REWARD_PER_DAY() external view returns (uint256);

    function maxEngagementDays() external view returns (uint256);

    function stakePenaltyUnder50() external view returns (uint256);

    function stakePenaltyBetween50And80() external view returns (uint256);

    function stakePenaltyBetween80And100() external view returns (uint256);

    function rewardPenaltyUnder50() external view returns (uint256);

    function rewardPenaltyBetween50And80() external view returns (uint256);

    function rewardPenaltyBetween80And100() external view returns (uint256);

    function users(
        address
    )
        external
        view
        returns (
            uint256 stakedLazi,
            uint256 stakedLaziWeighted,
            uint256 stakeStartTime,
            uint256 stakeDuration,
            uint256 stakeDurationWeighted,
            uint256[] memory erc721TokenIds
        );

    function totalUsers() external view returns (uint256);

    function totalStakedLazi() external view returns (uint256);

    function totalStakedDuration() external view returns (uint256);

    function totalWeightedStakedLazi() external view returns (uint256);

    function totalWeightedStakedDuration() external view returns (uint256);

    function PENALTY_POOL() external view returns (uint256);

    function multiplierValues(uint256) external view returns (uint256);

    function _signatureUsed(bytes memory) external view returns (bool);

    function stake(uint256 _stakedLazi, uint256 _stakeDuration, uint256[] memory _laziUsernameIds) external;

    function unstake(uint256 contributionWeighted, uint256 totalWeightedContribution, uint256 timestamp, bytes memory _signature) external;

    function getUserRewards(address _user, uint256 contributionWeighted, uint256 totalWeightedContribution) external view returns (uint256);

    function withdrawERC20(address _erc20) external;

    function updateWeights(uint256 _w1, uint256 _w2, uint256 _w3) external;

    function set_REWARD_PER_DAY(uint256 _REWARD_PER_DAY) external;

    function set_REWARD_STOP_TIME(uint256 _REWARD_STOP_TIME) external;

    function set_maxEngagementDays(uint256 _maxEngagementDays) external;

    function set_smartContractLinkedAddressAPI(address _smartContractLinkedAddressAPI) external;

    function updatePenalties(
        uint256 _stakePenaltyUnder50,
        uint256 _stakePenaltyBetween50And80,
        uint256 _stakePenaltyBetween80And100,
        uint256 _rewardPenaltyUnder50,
        uint256 _rewardPenaltyBetween50And80,
        uint256 _rewardPenaltyBetween80And100
    ) external;
}
