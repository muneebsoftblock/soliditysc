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
  it("should assert true", async () => {
    const sc = await DigiCollect.new({ from: owner });

    await sc.setSaleActiveTime(0, { from: owner }); // write

    {
      console.log(`------block ${await web3.eth.getBlockNumber()}`);
      const tokenId = 1;
      const reward = "" + (await sc.calculateRewards(alice, [tokenId]));
      console.log(`reward ${fromWei(reward)} DIGI`);
    }

    {
      const qty = 1;
      const from = alice;
      const price = await sc.getPrice(qty);
      await sc.buyDigiCollect(qty, ref1, {
        from,
        value: price,
      });
    }

    // 5 DIGI per day so 86400 sec = 5 digi, 1 sec = 0.000057 DIGI
    // 5 DIGI per 6400 blocks, 1 block = 0.00078125 DIGI, it 100x more

    await advanceBlock();
    {
      console.log(`------block ${await web3.eth.getBlockNumber()}`);
      const tokenId = 1;
      const reward = "" + (await sc.calculateRewards(alice, [tokenId]));
      console.log(`reward ${fromWei(reward)} DIGI`);
    }
    await advanceBlock();
    {
      console.log(`------block ${await web3.eth.getBlockNumber()}`);
      const tokenId = 1;
      const reward = "" + (await sc.calculateRewards(alice, [tokenId]));
      console.log(`reward ${fromWei(reward)} DIGI`);
    }

    // assert(Number(reward) > 0.000057, "no ok");

    await sc.withdraw({ from: owner });
  });
});
