const LaziName = artifacts.require('LaziName')

contract('LaziName', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    const sc = await LaziName.new({ from: owner })
    await sc.set_saleActiveTime(0, { from: owner })
    {
      const names = ['muneeb.lazi', 'adil.lazi']
      const from = alice
      const qty = names.length;
      const price = '' + (await sc.getPrice(qty, { from }))
      console.log({ price })
      await sc.buyLaziNames(names, {
        from,
        value: price,
      })
    }

    const balanceBefore = await web3.eth.getBalance(owner)
    await sc.withdraw({ from: owner })
    const balanceAfter = await web3.eth.getBalance(owner)
    console.log(
      `balanceBefore ${balanceBefore} balanceAfter ${balanceAfter} type ${typeof balanceBefore}`
    )

    assert(balanceAfter > balanceBefore)
  })
})
