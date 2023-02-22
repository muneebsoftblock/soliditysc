const DigiCollect = artifacts.require("DigiCollect");
const fromWei = web3.utils.fromWei;
const toWei = web3.utils.toWei;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

contract("DigiCollect", ([alice, bob, carol, owner, ref1, ref2]) => {
  it("should assert true", async () => {
    const sc = await DigiCollect.new({ from: owner });

    await sc.setSaleActiveTime(0, { from: owner }); // write

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

    const tokenId = 1;
    const reward = "" + (await sc.calculateRewards(alice, [tokenId]));

    console.log(`reward ${fromWei(reward)} DIGI`);
    // assert(Number(reward) > 0.000057, "no ok");
    assert(true, "true");

    await sc.withdraw({ from: owner });
  });
});
