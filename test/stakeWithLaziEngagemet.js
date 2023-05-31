// // We have tested these:
// // * Attempt to unstake before the stake duration has passed.
// // * Ensure that the right amount of rewards is given based on the weighted contribution.
// // * Attempt to unstake more than what was staked.
// // * Try to stake zero tokens.
// // * Attempt to stake with an invalid ERC721 token ID.
// // * Ensure that penalties apply correctly based on the staking duration.

// const { expect } = require("chai")
// const { BN, ether, time } = require("@openzeppelin/test-helpers")

// const fromWei = web3.utils.fromWei

// const Staking = artifacts.require("LaziEngagementRewards")
// const ERC20 = artifacts.require("LAZI")
// const ERC721 = artifacts.require("LaziName")
// const viewStruct = (obj) =>
//     Object.keys(obj).forEach(
//         (k) =>
//             isNaN(k) &&
//             (k === "stakedLazi" || k === "stakedLaziWeighted" ? console.log(k + " " + fromWei("" + obj[k])) : console.log(k + " " + obj[k]))
//     )

// contract("Staking", (accounts) => {
//     const [owner, user1, user2] = accounts
//     let staking, erc20, erc721

//     beforeEach(async () => {
//         erc20 = await ERC20.new({ from: owner })
//         erc721 = await ERC721.new({ from: owner })

//         staking = await Staking.new(erc20.address, erc721.address, { from: owner })
//         await erc20.grantRole(await erc20.MINTER_ROLE(), staking.address, { from: owner })

//         await erc20.mint(user1, ether("100"), { from: owner })
//         await erc20.mint(user2, ether("100"), { from: owner })
//         // await erc20.mint(staking.address, ether("200000000"), { from: owner })

//         await erc721.airdrop([user1, user1, user1], ["1 one", "2 two", "3 three"], { from: owner })
//         await erc721.airdrop([user2, user2, user2, user2, user2], ["4 f", "5 f", "6 s", "7 s", "8 e"], { from: owner })
//     })

//     it("should stake ERC20 tokens and ERC721 tokens", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("1"), 30 * 86400, erc721Ids, { from: user1 })

//         const stakeInfo = await staking.users(user1)

//         console.log("Staked ERC721 IDs:")
//         viewStruct(stakeInfo)
//     })

//     it("should allow users to stake ERC20, ERC721 and unstake and claim rewards", async () => {
//         // Approve and stake tokens
//         const stakedLazi = ether("100")
//         const days = 86400
//         const stakeDuration = 0.5 * days
//         const erc721TokenId = 1
//         await erc20.approve(staking.address, stakedLazi, { from: user1 })
//         await erc721.approve(staking.address, erc721TokenId, { from: user1 })
//         await erc20.approve(staking.address, stakedLazi, { from: user2 })
//         await erc721.setApprovalForAll(staking.address, true, { from: user2 })

//         {
//             console.log()

//             const stakeInfo = await staking.users(user1)
//             console.log("stakeInfo before stake")
//             viewStruct(stakeInfo)
//             const stakeReward = await staking.getUserRewards(user1, "50", "100")
//             console.log("stakeReward before stake " + fromWei(stakeReward))
//         }

//         await staking.stake(stakedLazi, stakeDuration, [4, 5], { from: user2 })
//         await staking.stake(stakedLazi, stakeDuration, [erc721TokenId], { from: user1 })

//         {
//             console.log()

//             const stakeInfo = await staking.users(user1)
//             console.log("after stake")
//             viewStruct(stakeInfo)
//             const stakeReward = await staking.getUserRewards(user1, "50", "100")
//             console.log("stakeReward after stake " + fromWei(stakeReward))
//         }
//         // Fast-forward time to complete the stake duration
//         const unstakeAtDays = 1
//         await time.increase(time.duration.days(unstakeAtDays))

//         {
//             console.log()

//             const stakeInfo = await staking.users(user1)
//             console.log("after stake after 1 day")
//             viewStruct(stakeInfo)
//             const stakeReward = await staking.getUserRewards(user1, "50", "100")
//             console.log("stakeReward after stake after 1 day " + fromWei(stakeReward))
//             {
//                 const stakeReward = await staking.getUserRewards(user2, "50", "100")
//                 console.log("stakeReward after stake after 1 day USER 2 " + fromWei(stakeReward))
//             }
//         }
//         // Unstake and claim rewards
//         const publicKey = "0xCb1345D9bb0658d8424Bb092C62795204E3994Fd"
//         const privateKey = "dfbeda793c0d2bebee953029221fcc5a7c2cfa38403a27ad0fe0cf399cba9fc4"
//         const contributionWeighted = "50"
//         const totalWeightedContribution = "100"
//         const timestamp = Date.now().toString()
//         const messagePacked = web3.eth.abi.encodeParameters(
//             ["uint256", "uint256", "uint256"],
//             [contributionWeighted, totalWeightedContribution, timestamp]
//         )
//         const message = web3.utils.keccak256(messagePacked)
//         const signature = web3.eth.accounts.sign(message, privateKey)
//         await staking.unstake(contributionWeighted, totalWeightedContribution, timestamp, signature.signature, { from: user1 })

//         {
//             console.log()
//             const stakeInfo = await staking.users(user1)
//             console.log("after UNSTAKE")
//             viewStruct(stakeInfo)
//             const stakeReward = await staking.getUserRewards(user1, "50", "100")
//             console.log("stakeReward after unstake " + fromWei(stakeReward))
//         }
//         // doing same thing of smart contract in javascript
//         const recoveredAddress = web3.eth.accounts.recover(message, signature.signature)
//         console.log({ publicKey, recoveredAddress })
//         /*
//             signature!  {
//                 message: '0x365372aa06668dfe5b67a5003a8b07784c09e85a19a70be8979d7cde1e2aeab7',
//                 messageHash: '0x513e8f04306ab540d0bedafa1fb46706e3a8539a2bae4a59eaa93df810b0de1f',
//                 v: '0x1b',
//                 r: '0x640c8a165a44f0782dc8c4ac86c1bbec11027bacbfe23499f365fd8314cad138',
//                 s: '0x6d014392e77e2e295a86a7bf0e7372c92a2dfb1c7bd30574055a2789130f33ef',
//                 signature: '0x640c8a165a44f0782dc8c4ac86c1bbec11027bacbfe23499f365fd8314cad1386d014392e77e2e295a86a7bf0e7372c92a2dfb1c7bd30574055a2789130f33ef1b'
//             }
//     */

//         // Check user balance after un staking
//         const userBalance = await erc20.balanceOf(user1)
//         expect(userBalance).to.be.bignumber.greaterThan(ether("60000"))
//         expect(userBalance).to.be.bignumber.lessThan(ether("70000"))
//         // expect(userBalance).to.be.bignumber.equal(stakedLazi)

//         // Check contract balance after un staking
//         const contractBalance = await erc20.balanceOf(staking.address)
//         expect(contractBalance).to.be.bignumber.equal(ether("100")) // 100 remaining tokens of other user

//         // Check ERC721 token ownership after un staking
//         const ownerOfERC721 = await erc721.ownerOf(erc721TokenId)
//         expect(ownerOfERC721).to.equal(user1)
//     })

//     // Add remaining test cases for unstake, harvestRewards, compoundRewards, and other functions

//     it("should get user rewards", async () => {
//         await erc20.approve(staking.address, ether("100"), { from: user1 })

//         const erc721Ids = [1, 2, 3]
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })

//         await staking.stake(ether("100"), 30, erc721Ids, { from: user1 })

//         // Fast forward 30 days to make sure the staking period has passed
//         await time.increase(time.duration.days(30))

//         const userRewards = await staking.getUserRewards(user1, "50", "100")

//         console.log("User Rewards:", userRewards.toString())

//         const REWARD_PER_DAY = await staking.REWARD_PER_DAY()
//         const totalStaked = await staking.totalStakedLazi()

//         if (totalStaked.isZero()) {
//             console.log("No tokens staked.")
//         } else {
//             const APR = REWARD_PER_DAY.muln(365).muln(100).div(totalStaked)
//             console.log("APR = " + APR.toNumber() + "%")
//         }
//     })

//     it("should distribute rewards correctly after one day", async () => {
//         // User A stakes
//         const userA = accounts[1]
//         const userAStakeAmount = "50" + "0".repeat(18)
//         const userALockPeriod = 365 * 86400
//         const userAERC721TokenIds = [1, 2, 3]

//         await erc20.approve(staking.address, userAStakeAmount, { from: userA })
//         await erc721.setApprovalForAll(staking.address, true, { from: userA })
//         await staking.stake(userAStakeAmount, userALockPeriod, userAERC721TokenIds, { from: userA })

//         // User B stakes
//         const userB = accounts[2]
//         const userBStakeAmount = "100" + "0".repeat(18)
//         const userBLockPeriod = 15 * 30 * 86400
//         const userBERC721TokenIds = [4, 5, 6, 7]

//         await erc20.approve(staking.address, userBStakeAmount, { from: userB })
//         await erc721.setApprovalForAll(staking.address, true, { from: userB })
//         await staking.stake(userBStakeAmount, userBLockPeriod, userBERC721TokenIds, { from: userB })

//         // Advance time by 1 day
//         await time.increase(time.duration.days(1))
//         // await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_increaseTime", params: [24 * 60 * 60], id: 0 }, () => {})
//         // await web3.currentProvider.send({ jsonrpc: "2.0", method: "evm_mine", id: 0 }, () => {})

//         // Harvest rewards
//         // await staking.harvest({ from: userA })
//         // await staking.harvest({ from: userB })

//         // Check rewards
//         const userARewards = await staking.getUserRewards(userA, "50", "100")
//         const userBRewards = await staking.getUserRewards(userB, "50", "100")
//         const totalRewards = userARewards.add(userBRewards)

//         console.log("User A rewards:", userARewards.toString())
//         console.log("User B rewards:", userBRewards.toString())
//         console.log("Total rewards:", totalRewards.toString())

//         expect(totalRewards).to.be.bignumber.greaterThan(ether("137000"))
//         expect(totalRewards).to.be.bignumber.lessThan(ether("137010"))
//         // assert(totalRewards.toString().includes("137000"), "Total rewards should be 137,000 tokens")
//     })

//     it("should apply penalties correctly", async () => {
//         const userStakeAmount = ether("50")
//         const userLockPeriod = 86400
//         const userERC721TokenIds = [1, 2, 3]
//         const penaltyRateUnder50 = await staking.stakePenaltyUnder50()

//         // Stake tokens
//         await erc20.approve(staking.address, userStakeAmount, { from: user1 })
//         await erc721.setApprovalForAll(staking.address, true, { from: user1 })
//         await staking.stake(userStakeAmount, userLockPeriod, userERC721TokenIds, { from: user1 })

//         // Increase time by less than the stake duration to trigger penalty
//         await time.increase(time.duration.days(0.4))

//         // Attempt to unstake
//         const unstakeAmount = new BN("25" + "0".repeat(18)) // Unstake 50% of tokens
//         const publicKey = "0xCb1345D9bb0658d8424Bb092C62795204E3994Fd"
//         const privateKey = "dfbeda793c0d2bebee953029221fcc5a7c2cfa38403a27ad0fe0cf399cba9fc4"
//         const contributionWeighted = "50"
//         const totalWeightedContribution = "100"
//         const timestamp = Date.now().toString()
//         const messagePacked = web3.eth.abi.encodeParameters(
//             ["uint256", "uint256", "uint256"],
//             [contributionWeighted, totalWeightedContribution, timestamp]
//         )
//         const message = web3.utils.keccak256(messagePacked)
//         const signature = web3.eth.accounts.sign(message, privateKey)
//         await staking.unstake(contributionWeighted, totalWeightedContribution, timestamp, signature.signature, { from: user1 })

//         // Check if penalty was applied
//         // const remainingStake = await staking.users(user1)
//         // const expectedRemainingStake = userStakeAmount.sub(unstakeAmount).mul(new BN(100).sub(penaltyRateUnder50)).div(new BN(100))
//         // expect(remainingStake.stakedLazi).to.be.bignumber.equal(expectedRemainingStake)
//     })
// })
