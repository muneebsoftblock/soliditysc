const DigiCollect = artifacts.require('DigiCollect');
const fromWei = web3.utils.fromWei;
contract('DigiCollect', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await DigiCollect.new({ from: owner });

    const scOwner = await sc.owner(); // read
    console.log({ scOwner });
    await sc.setSaleActiveTime(0, { from: owner }); // write

    {
      const qty = 1;
      const from = alice;
      const price = await sc.getPrice(qty);
      console.log({ price: `${fromWei(price)} ETH` });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 200;
      const from = bob;
      const price = await sc.getPrice(qty);
      console.log({ price: `${fromWei(price)} ETH` });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 1;
      const from = carol;
      const price = await sc.getPrice(qty);
      console.log({ price: `${fromWei(price)} ETH` });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
