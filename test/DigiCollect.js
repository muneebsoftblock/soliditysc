const DigiCollect = artifacts.require("DigiCollect");
const fromWei = web3.utils.fromWei;
const toWei = web3.utils.toWei;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
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
  it("Case 1: Buy 1 Nft, after 24 hours reward is 5 digi, collect 5 digi", async () => {
    const sc = await DigiCollect.new({ from: owner });
    await sc.setSaleActiveTime(0, { from: owner }); // write

    const qty = 1;
    const from = alice;
    const price = await sc.getPrice(qty);
    await sc.buyDigiCollect(qty, ref1, {
      from,
      value: price,
    });

    // 5 DIGI per 6400 blocks, 1 block = 0.00078125 DIGI, it 100x more
    const tokenId = 1;

    await advanceBlock();
    {
      const reward = fromWei("" + (await sc.calculateRewards(alice, [tokenId])));
      assert.equal(reward, "0.00078125");
    }

    // await sc.claimRewards([tokenId]);

    // {
    //   const reward = fromWei("" + (await sc.calculateRewards(alice, [tokenId])));
    //   assert.equal(reward, "0");
    // }
  });
});
