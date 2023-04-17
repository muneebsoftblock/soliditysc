// SPDX-License-Identifier: MIT
const StakingRewards = artifacts.require("StakingRewards")
const Token = artifacts.require("Token")

contract("StakingRewards", (accounts) => {
    let stakingRewards
    let token
    const alice = accounts[0]
    const bob = accounts[1]

    beforeEach(async () => {
        token = await Token.new()
        stakingRewards = await StakingRewards.new(token.address)
        await token.transfer(alice, 1000000)
        await token.transfer(bob, 1000000)
        await token.approve(stakingRewards.address, 1000000, { from: alice })
        await token.approve(stakingRewards.address, 1000000, { from: bob })
    })

    it("should stake and unstake tokens", async () => {
        await stakingRewards.stake(100, { from: alice })
        assert.equal(await stakingRewards.totalStaked(), 100)
        assert.equal(await stakingRewards.stakedBalances(alice), 100)
        assert.equal(await token.balanceOf(stakingRewards.address), 100)
        assert.equal(await token.balanceOf(alice), 999900)

        await stakingRewards.withdraw(50, { from: alice })
        assert.equal(await stakingRewards.totalStaked(), 50)
        assert.equal(await stakingRewards.stakedBalances(alice), 50)
        assert.equal(await token.balanceOf(stakingRewards.address), 50)
        assert.equal(await token.balanceOf(alice), 999950)
    })

    it("should distribute rewards to stakers", async () => {
        // Start rewards
        await stakingRewards.startRewards({ from: alice })
        assert.equal(
            await token.balanceOf(stakingRewards.address),
            137000 * 1461
        )
        assert.equal(await token.balanceOf(alice), 1000000 - 137000 * 1461)

        // Alice stakes 100 tokens
        await stakingRewards.stake(100, { from: alice })
        assert.equal(await stakingRewards.rewardsEarned(alice), 0)

        // Bob stakes 200 tokens
        await stakingRewards.stake(200, { from: bob })
        assert.equal(await stakingRewards.rewardsEarned(alice), 0)
        assert.equal(await stakingRewards.rewardsEarned(bob), 0)

        // Wait for 1 day
        await new Promise((resolve) => setTimeout(resolve, 24 * 60 * 60 * 1000))
        await stakingRewards.getReward({ from: alice })
        await stakingRewards.getReward({ from: bob })
        assert.equal(
            await stakingRewards.rewardsEarned(alice),
            (100 * 137000) / 300
        )
        assert.equal(
            await stakingRewards.rewardsEarned(bob),
            (200 * 137000) / 300
        )
        assert.equal(
            await token.balanceOf(stakingRewards.address),
            137000 * 1460
        )
        assert.equal(
            await token.balanceOf(alice),
            1000000 - 137000 * 1460 + (100 * 137000) / 300
        )
        assert.equal(
            await token.balanceOf(bob),
            1000000 - 137000 * 1460 + (200 * 137000) / 300
        )
    })
})
