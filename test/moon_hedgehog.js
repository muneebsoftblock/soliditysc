const MoonHedgehog = artifacts.require('MoonHedgehog');

contract('MoonHedgehog', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await MoonHedgehog.new({ from: owner });

    const scOwner = await sc.owner();
    const scAddr = sc.address;
    console.log({ scOwner, scAddr });

    await sc.setSaleActiveTime(0, 0, { from: owner });
    await sc.setFirstFreeMints(5, { from: owner });

    {
      const qty = 3;
      const price = '' + (await sc.getPrice(qty, { from: bob }));
      console.log({ price });
      await sc.buyHedgehog(qty, {
        from: bob,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
