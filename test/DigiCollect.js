const DigiCollect = artifacts.require('DigiCollect');

contract('DigiCollect', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await DigiCollect.new({ from: owner });

    const scOwner = await sc.owner();
    const scAddr = sc.address;

    await sc.setSaleActiveTime(0, 0, { from: owner });
    await sc.setMaxDigiCollectPerWallet(5, 0, { from: owner });

    {
      const qty = 1;
      const from = alice;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 3;
      const from = bob;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 5;
      const from = carol;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyDigiCollect(qty, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
