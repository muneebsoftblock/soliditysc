const Nft = artifacts.require('Nft');

contract('Nft', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await Nft.new({ from: owner });

    const scOwner = await sc.owner();
    const scAddr = sc.address;
    console.log({ scOwner, scAddr });

    await sc.setSaleActiveTime(0, 0, { from: owner });
    await sc.setFirstFreeMints(2, { from: owner });
    await sc.setMaxNftPerWallet(5, 0, { from: owner });

    {
      const qty = 1;
      const from = alice;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyNft(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 3;
      const from = bob;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyNft(qty, {
        from,
        value: price,
      });
    }
    {
      const qty = 5;
      const from = carol;
      const price = '' + (await sc.getPrice(qty, { from }));
      console.log({ price });
      await sc.buyNft(qty, {
        from,
        value: price,
      });
    }

    await sc.withdraw({ from: owner });

    return assert.isTrue(true);
  });
});
