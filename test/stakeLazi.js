const { expect } = require("chai")
const { BN, ether, time, expectRevert } = require("@openzeppelin/test-helpers")

const fromWei = web3.utils.fromWei
const Staking = artifacts.require("StakeLaziThings")
const ERC20 = artifacts.require("LAZI")
const ERC721 = artifacts.require("LaziName")

const viewStruct = (obj) =>
    Object.keys(obj).forEach(
        (k) =>
            isNaN(k) &&
            (k === "weightedStake" || k === "stakingAmount" || k === "claimedRewards"
                ? console.log(k + " " + fromWei("" + obj[k]))
                : k === "lockPeriod"
                ? console.log(k + " days " + obj[k] / 86400)
                : console.log(k + " " + obj[k]))
    )

contract("Staking", (accounts) => {
    const [owner, user1, user2, user3, user4, user5] = accounts
    let staking, erc20, erc721

    beforeEach(async () => {
        erc20 = await ERC20.new({ from: owner })
        erc721 = await ERC721.new({ from: owner })

        staking = await Staking.new(erc20.address, erc20.address, erc721.address, {
            from: owner,
        })
        await erc20.grantRole(await erc20.MINTER_ROLE(), staking.address, { from: owner })

        // calculate index function

        await erc20.mint(user1, ether("5000000"), { from: owner })
        await erc20.mint(user2, ether("5000000"), { from: owner })
        await erc20.mint(user3, ether("500"), { from: owner })
        await erc20.mint(user4, ether("500"), { from: owner })
        await erc20.mint(user5, ether("500"), { from: owner })
        await erc20.mint(staking.address, ether("200000000"), { from: owner })

        await erc721.airdrop([user1, user1, user1], ["one", "two", "three"], { from: owner })
        await erc721.airdrop([user2, user2, user2, user2, user2], ["four", "five", "six", "seven", "eight"], { from: owner })
        await erc721.airdrop([user3, user3, user3, user3, user3], ["nine", "ten", "eleven", "twelve", "thirteen"], { from: owner })
        await erc721.airdrop([user4, user4, user4, user4, user4], ["fourteen", "fifteen", "sixteen", "seventeen", "eighteen"], { from: owner })
        await erc721.airdrop([user5, user5, user5, user5, user5], ["nineteen", "twenty", "twenty-one", "twenty-two", "twenty-three"], { from: owner })

        await erc20.approve(staking.address, ether("100000"), { from: user1 })
        await erc20.approve(staking.address, ether("100000"), { from: user2 })
        await erc20.approve(staking.address, ether("100000"), { from: user3 })
        await erc20.approve(staking.address, ether("100000"), { from: user4 })
        await erc20.approve(staking.address, ether("100000"), { from: user5 })

        await erc721.setApprovalForAll(staking.address, true, { from: user1 })
        await erc721.setApprovalForAll(staking.address, true, { from: user2 })
        await erc721.setApprovalForAll(staking.address, true, { from: user3 })
        await erc721.setApprovalForAll(staking.address, true, { from: user4 })
        await erc721.setApprovalForAll(staking.address, true, { from: user5 })
    })

    it("should stake ERC20 tokens and ERC721 tokens", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400
        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })
        await time.increase(time.duration.hours(1))
        await staking.stake(ether("100"), lockPeriodInDays, [4, 5, 6], { from: user2 })
        await time.increase(time.duration.hours(2))

        const user1Rewards = await staking.getUserRewards(user1)
        const user2Rewards = await staking.getUserRewards(user2)
        console.log("User 1 rewards:", fromWei(user1Rewards.toString()))
        console.log("User 2 rewards:", fromWei(user2Rewards.toString()))

        const stakeInfo1 = await staking.stakes(user1)
        const stakeInfo2 = await staking.stakes(user2)

        console.log("Staked ERC721 IDs 1:")
        viewStruct(stakeInfo1)

        console.log("Staked ERC721 IDs 2:")
        viewStruct(stakeInfo2)
    })

    it("should unstake ERC20 tokens and ERC721 tokens", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400

        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })

        // Fast forward 30 days to make sure the staking period has passed
        await time.increase(time.duration.days(30))

        await staking.unstake({ from: user1 })

        const stakeInfo = await staking.stakes(user1)

        console.log("Unstaked ERC721 IDs:")
        viewStruct(stakeInfo)
    })

    it("should harvest rewards", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400

        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })

        // Fast forward 30 days to make sure the staking period has passed
        await time.increase(time.duration.days(30))

        await staking.harvest({ from: user1 })

        const stakeInfo = await staking.stakes(user1)

        console.log("Claimed Rewards:")
        viewStruct(stakeInfo)
    })

    it("should get user rewards", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400
        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })

        // Fast forward 30 days to make sure the staking period has passed
        await time.increase(time.duration.days(30))

        const userRewards = await staking.getUserRewards(user1)

        console.log("User Rewards:", fromWei(userRewards.toString()))

        const REWARD_PER_SEC = await staking.REWARD_PER_SEC()
        const totalStaked = await staking.totalStaked()

        if (totalStaked.isZero()) {
            console.log("No tokens staked.")
        } else {
            const APR = REWARD_PER_SEC.muln(86400).muln(365).muln(100).div(totalStaked)
            console.log("APR = " + APR.toNumber() + "%")
        }

        const daysToStake = [0 * 86400, 30 * 86400, 60 * 86400, 90 * 86400, 180 * 86400, 365 * 86400]
        const lockPeriodDistributions = await staking.getDistributions(daysToStake)
        viewStruct(lockPeriodDistributions)
    })

    it("should distribute rewards correctly after one day", async () => {
        // User A stakes
        const userA = accounts[1]
        const userAStakeAmount = "100" + "0".repeat(18)
        const userAERC721TokenIds = [1, 2]
        const lockPeriodInDays = 30 * 86400

        await staking.stake(userAStakeAmount, 0, userAERC721TokenIds, { from: userA })
        {
            const stakeInfo = await staking.stakes(user1)
            console.log("\nStaked info user 1:")
            viewStruct(stakeInfo)
        }
        await staking.stake(userAStakeAmount, lockPeriodInDays, [3], { from: userA })
        {
            const stakeInfo = await staking.stakes(user1)
            console.log("\nStaked info user 1:")
            viewStruct(stakeInfo)
        }
        await staking.stake("0", 0, [], { from: userA })

        {
            const stakeInfo = await staking.stakes(user1)
            console.log("\nStaked info user 1:")
            viewStruct(stakeInfo)
        }

        // User B stakes
        const userB = accounts[2]
        const userBStakeAmount = "75000" + "0".repeat(18)
        const userBERC721TokenIds = [4, 5, 6, 7]

        await staking.stake(userBStakeAmount, lockPeriodInDays, userBERC721TokenIds, { from: userB })

        // Advance time by 1 day
        await time.increase(time.duration.days(1))

        // Harvest rewards
        // await staking.harvest({ from: userA })
        // await staking.harvest({ from: userB })

        // Check rewards
        const userARewards = await staking.getUserRewards(userA)
        const userBRewards = await staking.getUserRewards(userB)
        const totalRewards = userARewards.add(userBRewards)

        console.log("User A rewards:", fromWei(userARewards.toString()))
        console.log("User B rewards:", fromWei(userBRewards.toString()))
        console.log("Total rewards:", fromWei(totalRewards.toString()))

        const daysToStake = [0 * 86400, 30 * 86400, 60 * 86400, 90 * 86400, 180 * 86400, 365 * 86400]
        const lockPeriodDistributions = await staking.getDistributions(daysToStake)
        viewStruct(lockPeriodDistributions)
        console.log("total reward! ", fromWei(totalRewards.toString()))
        // assert(fromWei(totalRewards.toString()).includes("13700"), "Total rewards should be 137,000 tokens")
        expect(totalRewards).to.be.bignumber.greaterThan(ether("136000"))
        expect(totalRewards).to.be.bignumber.lessThan(ether("138000"))
    })

    it("should not allow unstaking before lock period expiration", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400
        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })

        // Try to unstake before the lock period has expired
        await expectRevert(staking.unstake({ from: user1 }), "VM Exception while processing transaction: revert Lock period not reached")
    })

    it("should allow unstaking after lock period expiration", async () => {
        const erc721Ids = [1, 2, 3]
        const lockPeriodInDays = 30 * 86400
        await staking.stake(ether("100"), lockPeriodInDays, erc721Ids, { from: user1 })

        // Fast forward 30 days to make sure the lock period has expired
        await time.increase(time.duration.days(30))

        await staking.unstake({ from: user1 })

        const stakeInfo = await staking.stakes(user1)

        // Assert that the staked amount is reset to zero
        assert(stakeInfo.stakingAmount.isZero())
    })

    it("should allow multiple users to stake, unstake, and harvest rewards", async () => {
        // User 1 stakes
        const lockPeriodInDays1 = 30 * 86400
        await staking.stake(ether("100"), lockPeriodInDays1, [1, 2], { from: user1 })
        {
            const stakeInfo = await staking.stakes(user1)
            console.log("\nStaked info user 1:")
            viewStruct(stakeInfo)
        }

        // User 5 stakes
        const lockPeriodInDays5 = 90 * 86400
        await staking.stake(ether("120"), lockPeriodInDays5, [19, 20, 21, 22], { from: user5 })
        {
            const stakeInfo = await staking.stakes(user5)
            console.log("\nStaked info user 5: " + user5)
            viewStruct(stakeInfo)
        }

        // User 2 stakes
        const lockPeriodInDays2 = 15 * 86400
        await staking.stake(ether("50"), lockPeriodInDays2, [5, 6], { from: user2 })
        {
            const stakeInfo = await staking.stakes(user2)
            console.log("\nStaked info user 2:")
            viewStruct(stakeInfo)
        }

        // User 4 stakes
        const lockPeriodInDays4 = 45 * 86400
        await staking.stake(ether("75"), lockPeriodInDays4, [14, 15, 16], { from: user4 })
        {
            const stakeInfo = await staking.stakes(user4)
            console.log("\nStaked info user 4:" + user4)
            viewStruct(stakeInfo)
        }

        // User 3 stakes
        const lockPeriodInDays3 = 60 * 86400
        await staking.stake(ether("200"), lockPeriodInDays3, [9, 10, 11], { from: user3 })
        {
            const stakeInfo = await staking.stakes(user3)
            console.log("\nStaked info user 3:")
            viewStruct(stakeInfo)
        }

        // Fast forward time to simulate lock period expiration
        await time.increase(time.duration.days(30))

        // User 1 unstakes
        await staking.unstake({ from: user1 })

        // User 2 harvests rewards
        await staking.harvest({ from: user2 })

        // Fast forward time again to simulate lock period expiration for remaining users
        await time.increase(time.duration.days(15))

        // User 4 harvests rewards
        await staking.harvest({ from: user4 })

        // Fast forward time again to simulate lock period expiration for the last user
        await time.increase(time.duration.days(90))

        // User 3 unstakes
        await staking.unstake({ from: user3 })
        // User 5 harvests rewards
        await staking.harvest({ from: user5 })
        {
            const stakeInfo = await staking.stakes(user5)
            console.log("\nStaked info user 5:")
            viewStruct(stakeInfo)
        }

        // User 5 unstakes
        await staking.unstake({ from: user5 })

        {
            const stakeInfo = await staking.stakes(user5)
            console.log("\nStaked info user 5:")
            viewStruct(stakeInfo)
        }

        // Verify user balances after the operations

        // User 1 balance
        const user1Balance = await erc20.balanceOf(user1)
        expect(user1Balance).to.be.bignumber.greaterThan(ether("100"))

        // User 2 balance
        const user2Balance = await erc20.balanceOf(user2)
        expect(user2Balance).to.be.bignumber.greaterThan(ether("50"))

        // User 3 balance
        const user3Balance = await erc20.balanceOf(user3)
        expect(user3Balance).to.be.bignumber.greaterThan(ether("200"))

        // User 4 balance
        const user4Balance = await erc20.balanceOf(user4)
        expect(user4Balance).to.be.bignumber.greaterThan(ether("75"))

        // User 5 balance
        const user5Balance = await erc20.balanceOf(user5)
        expect(user5Balance).to.be.bignumber.greaterThan(ether("120"))

        // Verify user rewards

        // User 2 rewards
        const user2Rewards = await staking.getUserRewards(user2)
        expect(user2Rewards).to.be.bignumber.greaterThan(new BN(0))

        // User 4 rewards
        const user4Rewards = await staking.getUserRewards(user4)
        expect(user4Rewards).to.be.bignumber.greaterThan(new BN(0))

        // User 5 rewards
        const user5Rewards = await staking.getUserRewards(user5)
        expect(user5Rewards).to.be.bignumber.equal(new BN(0))
    })
})

