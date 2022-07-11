const John = artifacts.require('John');

contract('John', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await John.new({ from: owner });

    const scOwner = await sc.owner();
    const scAddr = sc.address;
    console.log({ scOwner, scAddr });

    await sc.setSaleActiveTime(0, 0, { from: owner });
    await sc.setFreeJohnPerWallet(2, { from: owner });
    await sc.setMaxJohnPerWallet(5, 0, { from: owner });

    {
      const qty = 1;
      const from = alice;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyJohn(qty, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
