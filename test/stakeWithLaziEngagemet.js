const { expect } = require("chai")
const { BN, ether, time } = require("@openzeppelin/test-helpers")

const fromWei = web3.utils.fromWei

const Staking = artifacts.require("LaziEngagementRewards")
const ERC20 = artifacts.require("LAZI")
const ERC721 = artifacts.require("LaziName")
const viewStruct = (obj) =>
    Object.keys(obj).forEach(
        (k) =>
            isNaN(k) &&
            (k === "stakedLazi" || k === "stakedLaziWeighted" ? console.log(k + " " + fromWei("" + obj[k])) : console.log(k + " " + obj[k]))
    )

contract("Staking", (accounts) => {
    const [owner, user1, user2] = accounts
    let staking, erc20, erc721

    beforeEach(async () => {
        erc20 = await ERC20.new({ from: owner })
        erc721 = await ERC721.new({ from: owner })

        staking = await Staking.new(erc20.address, erc721.address, { from: owner })

        await erc20.mint(user1, ether("5000"), { from: owner })
        await erc20.mint(user2, ether("5000"), { from: owner })
        await erc20.mint(staking.address, ether("200000000"), { from: owner })

        await erc721.airdrop([user1, user1, user1], ["1 one", "2 two", "3 three"], { from: owner })
        await erc721.airdrop([user2, user2, user2, user2, user2], ["4 f", "5 f", "6 s", "7 s", "8 e"], { from: owner })
    })

    it("should stake ERC20 tokens and ERC721 tokens", async () => {
        await erc20.approve(staking.address, ether("100"), { from: user1 })

        const erc721Ids = [1, 2, 3]
        await erc721.setApprovalForAll(staking.address, true, { from: user1 })

        await staking.stake(ether("1"), 30 * 86400, erc721Ids, { from: user1 })

        const stakeInfo = await staking.users(user1)

        console.log("Staked ERC721 IDs:")
        viewStruct(stakeInfo)
    })

    // Add remaining test cases for unstake, harvestRewards, compoundRewards, and other functions

    // it("should unstake ERC20 tokens and ERC721 tokens", async () => {
    //     await erc20.approve(staking.address, ether("100"), { from: user1 })

    //     const erc721Ids = [1, 2, 3]
    //     await erc721.setApprovalForAll(staking.address, true, { from: user1 })

    //     await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

    //     // Fast forward 30 days to make sure the staking period has passed
    //     await time.increase(time.duration.days(30))

    //     await staking.unstake({ from: user1 })

    //     const stakeInfo = await staking.stakes(user1)

    //     console.log("Unstaked ERC721 IDs:")
    //     viewStruct(stakeInfo)
    // })

    // it("should get user rewards", async () => {
    //     await erc20.approve(staking.address, ether("100"), { from: user1 })

    //     const erc721Ids = [1, 2, 3]
    //     await erc721.setApprovalForAll(staking.address, true, { from: user1 })

    //     await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

    //     // Fast forward 30 days to make sure the staking period has passed
    //     await time.increase(time.duration.days(30))

    //     const userRewards = await staking.getUserRewards(user1)

    //     console.log("User Rewards:", userRewards.toString())

    //     const REWARD_PER_DAY = await staking.REWARD_PER_DAY()
    //     const totalStaked = await staking.totalStaked()

    //     if (totalStaked.isZero()) {
    //         console.log("No tokens staked.")
    //     } else {
    //         const APR = REWARD_PER_DAY.muln(365).muln(100).div(totalStaked)
    //         console.log("APR = " + APR.toNumber() + "%")
    //     }
    // })

    // it("should distribute rewards correctly after one day", async () => {
    //     // User A stakes
    //     const userA = accounts[1]
    //     const userAStakeAmount = "25000" + "0".repeat(18)
    //     const userALockPeriod = 365 * 24 * 60 * 60
    //     const userAERC721TokenIds = [1, 2, 3]

    //     await erc20.approve(staking.address, userAStakeAmount, { from: userA })
    //     await erc721.setApprovalForAll(staking.address, true, { from: userA })
    //     await staking.stake(userAStakeAmount, userALockPeriod, userAERC721TokenIds, { from: userA })

    //     // User B stakes
    //     const userB = accounts[2]
    //     const userBStakeAmount = "75000" + "0".repeat(18)
    //     const userBLockPeriod = 15 * 30 * 24 * 60 * 60
    //     const userBERC721TokenIds = [4, 5, 6, 7]

    //     await erc20.approve(staking.address, userBStakeAmount, { from: userB })
    //     await erc721.setApprovalForAll(staking.address, true, { from: userB })
    //     await staking.stake(userBStakeAmount, userBLockPeriod, userBERC721TokenIds, { from: userB })

    //     // Advance time by 1 day
    //     await time.increase(time.duration.days(1))
    //     // await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_increaseTime", params: [24 * 60 * 60], id: 0 }, () => {})
    //     // await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_mine", id: 0 }, () => {})

    //     // Harvest rewards
    //     // await staking.harvest({ from: userA })
    //     // await staking.harvest({ from: userB })

    //     // Check rewards
    //     const userARewards = await staking.getUserRewards(userA)
    //     const userBRewards = await staking.getUserRewards(userB)
    //     const totalRewards = userARewards.add(userBRewards)

    //     console.log("User A rewards:", userARewards.toString())
    //     console.log("User B rewards:", userBRewards.toString())
    //     console.log("Total rewards:", totalRewards.toString())

    //     assert(totalRewards.toString().includes("137000"), "Total rewards should be 137,000 tokens")
    // })
})
