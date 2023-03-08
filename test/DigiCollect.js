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

contract("DigiCollect", ([alice, bob, carol, owner, ref1, ref2, ref3, ref4, ref5, ref6]) => {
  let digi;
  let digiCollect;

  before(async () => {
    digi = await DIGI.new({ from: owner });
    digiCollect = await DigiCollect.new({ from: owner });
    const role = await digi.MINTER_ROLE();

    await digi.grantRole(role, digiCollect.address, { from: owner });
    await digiCollect.setERC20(digi.address, { from: owner });

    await digiCollect.setSaleActiveTime(0, { from: owner });
  });

  it("Case 1: Buy 1 Nft, after 24 hours reward is 5 digi, collect 5 digi, nft can not be transferred because its staked.", async () => {
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

    await digiCollect.claimRewards([tokenId], { from: alice });

    {
      const reward = fromWei("" + (await digi.balanceOf(alice)));
      assert.equal(reward, 2 * Number("0.00078125"));
    }

    try {
      // await digiCollect.withdraw([tokenId]);
      await digiCollect.transferFrom(alice, bob, tokenId, { from: alice });
      assert(false, "Should Revert");
    } catch (e) {}
  });

  it("Case 2: After staking of 60 days reward continues to generate. The token should be unlocked and can be un staked or transferred now.", async () => {
    const expirationBlocks = 2;
    await digiCollect.setExpiration(expirationBlocks, { from: owner });

    const qty = 1;
    const from = alice;
    const price = await digiCollect.getPrice(qty);
    await digiCollect.buyDigiCollect(qty, ref2, {
      from,
      value: price,
    });

    const tokenId = 2;
    try {
      await digiCollect.transferFrom(alice, bob, tokenId, { from: alice });
      assert(false, "It not reverted, it should be reverted");
    } catch (e) {}

    // reward before transfer
    for (let i = 0; i < 2; i++) {
      await advanceBlock();
      const reward = fromWei("" + (await digiCollect.calculateRewards(alice, [tokenId])));
      console.log(`reward ${reward} DIGI`);
    }

    for (let i = 0; i < expirationBlocks; i++) await advanceBlock();

    try {
      await digiCollect.transferFrom(alice, bob, tokenId, { from: alice });
    } catch (e) {
      assert(false, "It reverted, it should not be revert");
    }

    // reward after transfer
    for (let i = 0; i < 2; i++) {
      await advanceBlock();
      const reward = fromWei("" + (await digiCollect.calculateRewards(bob, [tokenId])));
      console.log(`reward ${reward} DIGI`);
    }

    await digiCollect.deposit([tokenId], { from: bob });

    // reward after transfer
    for (let i = 0; i < 2; i++) {
      await advanceBlock();
      const reward = fromWei("" + (await digiCollect.calculateRewards(bob, [tokenId])));
      console.log(`reward ${reward} DIGI`);
    }

    await digiCollect.claimRewards([tokenId], { from: bob });
  });

  it("gift", async () => {
    await digiCollect.giftDigiCollect([alice, bob, carol, owner, ref1, ref2, ref3, ref4, ref5], 1, {
      from: owner,
    });
    await digiCollect.giftDigiCollect([ref6], 100, { from: owner });
  });
});

//
