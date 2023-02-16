const DigiCollect = artifacts.require('StakeDigiCollect');
const fromWei = web3.utils.fromWei;
const toWei = web3.utils.toWei;
contract('DigiCollect', ([alice, bob, carol, owner, ref1, ref2]) => {
  it('should assert true', async () => {
    const sc = await DigiCollect.new({ from: owner });

    const scOwner = await sc.owner(); // read
    assert.equal(owner, scOwner, 'Owner issue');

    await sc.setSaleActiveTime(0, { from: owner }); // write
    await sc.toggleStart({ from: owner }); // write

    {
      const qty = 1;
      const from = alice;
      const price = await sc.getPrice(qty);
      assert.equal(price, toWei('0.01'));
      await sc.buyDigiCollect(qty, ref1, {
        from,
        value: price,
      });
    }
    {
      const qty = 1;
      const from = bob;
      const price = await sc.getPrice(qty);
      assert.equal(price, toWei('0.01'));
      await sc.buyDigiCollect(qty, ref1, {
        from,
        value: price,
      });
    }
    {
      const qty = 1;
      const from = carol;
      const price = await sc.getPrice(qty);
      assert.equal(price, toWei('0.01'));
      await sc.buyDigiCollect(qty, ref2, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });
    return assert.isTrue(true);
  });
});
