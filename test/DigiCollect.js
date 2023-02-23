const DIGI = artifacts.require("DIGI");
const DigiCollect = artifacts.require("DigiCollect");
const fromWei = web3.utils.fromWei;
const toWei = web3.utils.toWei;
const advanceBlock = () => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_mine",
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        const newBlockHash = web3.eth.getBlock("latest").hash;

        return resolve(newBlockHash);
      }
    );
  });
};

contract("DigiCollect", ([alice, bob, carol, owner, ref1, ref2]) => {
  let digi;
  let digiCollect;

  before(async () => {
    digi = await DIGI.new({ from: owner });
    digiCollect = await DigiCollect.new({ from: owner });
    const role = await digi.MINTER_ROLE();

    await digi.grantRole(role, digiCollect.address, { from: owner });
    await digiCollect.setERC20(digi.address, { from: owner });
  });

  it("Case 1: Buy 1 Nft, after 24 hours reward is 5 digi, collect 5 digi", async () => {
    await digiCollect.setSaleActiveTime(0, { from: owner });

    const qty = 1;
    const from = alice;

    const price = await digiCollect.getPrice(qty);
    await digiCollect.buyDigiCollect(qty, ref1, {
      from,
      value: price,
    });

    const tokenId = 1;

    await advanceBlock();
    {
      const reward = fromWei("" + (await digiCollect.calculateRewards(alice, [tokenId])));
      assert.equal(reward, "0.00078125");
    }

    await digiCollect.claimRewards([tokenId]);

    {
      const reward = fromWei("" + (await digi.balanceOf(alice)));
      assert.equal(reward, 2 * Number("0.00078125"));
    }
  });
});

// const DIGI = artifacts.require("DIGI");
// const DigiCollect = artifacts.require("DigiCollect");
// const fromWei = web3.utils.fromWei;
// const toWei = web3.utils.toWei;
// const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// const advanceBlock = () => {
//   return new Promise((resolve, reject) => {
//     web3.currentProvider.send(
//       {
//         jsonrpc: "2.0",
//         method: "evm_mine",
//         id: new Date().getTime(),
//       },
//       (err, result) => {
//         if (err) {
//           return reject(err);
//         }
//         const newBlockHash = web3.eth.getBlock("latest").hash;

//         return resolve(newBlockHash);
//       }
//     );
//   });
// };

// contract("DigiCollect", ([alice, bob, carol, owner, ref1, ref2]) => {
//   let digi;
//   let digiCollect;
//   const totalSupply = toWei("1000000000");

//   before(async () => {
//     digi = await DIGI.new({ from: owner });
//     digiCollect = await DigiCollect.new(digi.address, { from: owner });
//     // await digi.grantRole(digiCollect.PAUSER_ROLE(), digiCollect.address, { from: owner });
//     await digi.grantRole("0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6", digiCollect.address, { from: owner });
//   });

//   // it("should deploy DIGI contract with correct total supply", async () => {
//   //   const supply = await digi.totalSupply();
//   //   assert.equal(supply.toString(), totalSupply);
//   // });

//   // it("should deploy DigiCollect contract with correct DIGI address", async () => {
//   //   const token = await digiCollect.token();
//   //   assert.equal(token, digi.address);
//   // });

//   it("should set sale active time", async () => {
//     const saleActiveTime = 0;
//     await digiCollect.setSaleActiveTime(saleActiveTime, { from: owner });
//     const activeTime = await digiCollect.saleActiveTime();
//     assert.equal(activeTime, saleActiveTime);
//   });

//   it("should not allow buying DigiCollect before sale active time", async () => {
//     const qty = 1;
//     const from = alice;
//     const price = await digiCollect.getPrice(qty);
//     try {
//       await digiCollect.buyDigiCollect(qty, ref1, {
//         from,
//         value: price,
//       });
//       assert.fail("Expected error not thrown");
//     } catch (err) {
//       assert.include(err.message, "Sale is not active yet");
//     }
//   });

//   it("should allow buying DigiCollect after sale active time", async () => {
//     const qty = 1;
//     const from = alice;
//     const price = await digiCollect.getPrice(qty);
//     await sleep(10000);
//     await digiCollect.buyDigiCollect(qty, ref1, {
//       from,
//       value: price,
//     });
//     const ownerOfToken = await digiCollect.ownerOf(1);
//     assert.equal(ownerOfToken, alice);
//   });

//   it("should calculate and claim rewards for NFT holder after 24 hours", async () => {
//     const tokenId = 1;
//     const nftHolder = alice;
//     const expectedReward = toWei("5");

//     // Wait for 24 hours
//     await sleep(24 * 60 * 60 * 1000);

//     // Calculate rewards
//     const reward = await digiCollect.calculateRewards(nftHolder, [tokenId]);
//     assert.equal(reward.toString(), expectedReward, "Incorrect reward calculated");

//     // Claim rewards
//     const balanceBefore = await digi.balanceOf(nftHolder);
//     await digiCollect.claimRewards([tokenId], { from: nftHolder });
//     const balanceAfter = await digi.balanceOf(nftHolder);

//     assert.equal(balanceAfter.sub(balanceBefore).toString(), expectedReward, "Rewards not claimed correctly");
//   });

// });
