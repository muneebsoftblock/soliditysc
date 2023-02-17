const MoonHedgehogs = artifacts.require('LaziName');

contract('LaziName', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await MoonHedgehogs.new({ from: owner });

    const scOwner = await sc.owner();
    const scAddr = sc.address;
    console.log({ scOwner, scAddr });

    await sc.setSaleActiveTime(0, 0, { from: owner });
    await sc.setFirstFreeMints(2, { from: owner });
    await sc.setMaxLaziNamePerWallet(5, 0, { from: owner });

    {
      const qty = 1;
      const from = alice;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyLaziName(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 1;
      const from = bob;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyLaziName(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 1;
      const from = carol;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyLaziName(qty, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
