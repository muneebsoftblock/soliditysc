// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract StakingLazi is ERC721Holder, Ownable {
    struct StakeInfo {
        uint256 erc20Amount;
        uint256 lockPeriod;
        uint256[] erc721TokenIds;
        uint256 entryTimestamp;
        uint256 weightedStake;
        uint256 claimedRewards;
    }

    IERC20 public erc20;
    IERC721 public erc721;
    uint256 public totalStaked;
    uint256 public totalWeightedStake;
    mapping(address => StakeInfo) public stakes;
    uint256 public constant REWARD_PERIOD = 4 * 365 days;
    mapping(uint256 => uint256) public lockPeriodDistribution;
    mapping(uint256 => uint256) public stakedTokensDistribution;
    mapping(uint256 => uint256) public rewardTokensDistribution;
    uint256 public constant TOTAL_REWARD_TOKENS = 200_000_000 * (10 ** 18);

    constructor(IERC20 _erc20, IERC721 _erc721) {
        erc20 = _erc20;
        erc721 = _erc721;
    }

    function unstake() external {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        require(stakeInfo.erc20Amount > 0, "No stake found");
        require(block.timestamp >= stakeInfo.entryTimestamp + stakeInfo.lockPeriod, "Lock period not reached");

        uint256 rewardAmount = getUserRewards(msg.sender);
        IERC20(erc20).transfer(msg.sender, stakeInfo.erc20Amount + rewardAmount);

        for (uint256 i = 0; i < stakeInfo.erc721TokenIds.length; i++) {
            erc721.safeTransferFrom(address(this), msg.sender, stakeInfo.erc721TokenIds[i]);
        }

        totalWeightedStake -= stakeInfo.weightedStake;
        totalStaked -= stakeInfo.erc20Amount;
        delete stakes[msg.sender];
    }

    function harvest() external {
        uint256 rewardAmount = getUserRewards(msg.sender);
        require(rewardAmount > 0, "No rewards to harvest");

        IERC20(erc20).transfer(msg.sender, rewardAmount);
        stakes[msg.sender].claimedRewards += rewardAmount;
    }

    function withdrawERC20(address _erc20) external onlyOwner {
        IERC20 token = IERC20(_erc20);
        uint256 balance = token.balanceOf(address(this));
        token.transfer(owner(), balance);
    }

    function getUserRewards(address user) public view returns (uint256) {
        StakeInfo storage stakeInfo = stakes[user];
        uint256 elapsedTime = block.timestamp - stakeInfo.entryTimestamp;
        uint256 rewardAmount = (stakeInfo.weightedStake * elapsedTime * TOTAL_REWARD_TOKENS) / (totalWeightedStake * REWARD_PERIOD);
        return rewardAmount - stakeInfo.claimedRewards;
    }

    function _getMultiplier(uint256 numErc721Tokens, uint256 lockPeriod) private pure returns (uint256) {
        uint256 erc20Multiplier;
        if (lockPeriod < 90 days) {
            erc20Multiplier = 1;
        } else if (lockPeriod < 180 days) {
            erc20Multiplier = 125;
        } else if (lockPeriod < 365 days) {
            erc20Multiplier = 150;
        } else if (lockPeriod < 545 days) {
            erc20Multiplier = 200;
        } else if (lockPeriod < 730 days) {
            erc20Multiplier = 275;
        } else {
            erc20Multiplier = 350;
        }

        uint256 erc721Multiplier = 100 + 20 * numErc721Tokens;
        return (erc20Multiplier * erc721Multiplier) / 100;
    }

    function stake(uint256 erc20Amount, uint256 lockPeriodInDays, uint256[] calldata erc721TokenIds) external {
        require(erc20Amount > 0, "Staking amount must be greater than 0");

        uint256 lockPeriod = lockPeriodInDays * 1 days;
        uint256 numErc721Tokens = erc721TokenIds.length;
        uint256 multiplier = _getMultiplier(numErc721Tokens, lockPeriod);
        uint256 weightedStake = (erc20Amount * multiplier) / 100;

        erc20.transferFrom(msg.sender, address(this), erc20Amount);

        for (uint256 i = 0; i < numErc721Tokens; i++) {
            erc721.safeTransferFrom(msg.sender, address(this), erc721TokenIds[i]);
        }

        stakes[msg.sender] = StakeInfo({
            erc20Amount: erc20Amount,
            lockPeriod: lockPeriod,
            erc721TokenIds: erc721TokenIds,
            entryTimestamp: block.timestamp,
            weightedStake: weightedStake,
            claimedRewards: 0
        });

        totalStaked += erc20Amount;
        totalWeightedStake += weightedStake;
    }
}
