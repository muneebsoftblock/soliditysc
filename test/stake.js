// const { expect } = require("chai")
// const { BN, ether, time } = require("@openzeppelin/test-helpers")

// const Staking = artifacts.require("Staking")
// const ERC20 = artifacts.require("LAZI")
// const ERC721 = artifacts.require("LaziName")

// contract("Staking", (accounts) => {
//     const [owner, user1, user2] = accounts
//     let staking, erc20, erc721

//     beforeEach(async () => {
//         erc20 = await ERC20.new({ from: owner })
//         erc721 = await ERC721.new({ from: owner })

//         staking = await Staking.new(erc20.address, erc721.address, { from: owner })

//         await erc20.mint(user1, ether("500"), { from: owner })
//         await erc20.mint(user2, ether("500"), { from: owner })
//         await erc20.mint(staking.address, ether("200000000"), { from: owner })

//         await erc721.airdrop([user1, user1, user1], ["1 one", "2 two", "3 three"], { from: owner })
//     })

//     it("should stake ERC20 tokens and ERC721 tokens", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         const stakeInfo = await staking.stakes(user1)

//         // console.log("Staked ERC20 Amount:", stakeInfo.erc20Amount.toString())
//         // console.log(
//         //     "Staked ERC721 IDs:",
//         //     stakeInfo.erc721Ids.map((id) => id.toString())
//         // )
//         console.log(
//             "Staked ERC721 IDs:",
//             Object.keys(stakeInfo)
//         )
//         console.log(
//             "Staked ERC721 IDs:",
//             stakeInfo
//         )
//     })

//     // Add remaining test cases for unstake, harvestRewards, compoundRewards, and other functions

//     it("should unstake ERC20 tokens and ERC721 tokens", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         await staking.unstake({ from: user1 })

//         const stakeInfo = await staking.stakes(user1)

//         console.log(
//             "Unstaked ERC721 IDs:",
//             stakeInfo
//         )
//     })

//     it("should harvest rewards", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         await staking.harvestRewards({ from: user1 })

//         const stakeInfo = await staking.stakes(user1)

//         console.log("Claimed Rewards:", stakeInfo.claimedRewards.toString())
//     })

//     it("should compound rewards", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         await staking.compoundRewards({ from: user1 })

//         const stakeInfo = await staking.stakes(user1)

//         const apy = await staking.getCurrentAPY()
//         console.log("Current APY:", apy.toString())
        
//         console.log("Compounded ERC20 Amount:", stakeInfo.erc20Amount.toString())
//     })

//     it("should get user rewards", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         const userRewards = await staking.getUserRewards(user1)

//         console.log("User Rewards:", userRewards.toString())
//     })

//     it("should get current APY", async () => {
//         const apy = await staking.getCurrentAPY()
//         console.log("Current APY:", apy.toString())
//     })

//     it("should get lock period distribution", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         const lockPeriodDistribution = await staking.getLockPeriodDistribution(30)
//         console.log("Lock Period Distribution:", lockPeriodDistribution.toString())
//     })

//     it("should get staked tokens distribution", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         const stakedTokensDistribution = await staking.getStakedTokensDistribution(30)
//         console.log("Staked Tokens Distribution:", stakedTokensDistribution.toString())
//     })

//     it("should get reward tokens distribution", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         await staking.harvestRewards({ from: user1 })

//         const rewardTokensDistribution = await staking.getRewardTokensDistribution(30)
//         console.log("Reward Tokens Distribution:", rewardTokensDistribution.toString())
//     })

//     it("should get APY distribution", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         const apyDistribution = await staking.getAPYDistribution(30)
//         console.log("APY Distribution:", apyDistribution.toString())
//     })
// })
