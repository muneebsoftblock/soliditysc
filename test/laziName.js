const LaziName = artifacts.require("LaziName")
const fromWei = web3.utils.fromWei

contract("LaziName", ([alice, bob, carol, owner]) => {
    it("should assert true", async () => {
        const sc = await LaziName.new({ from: owner })
        await sc.set_saleActiveTime(0, { from: owner })
        {
            const names = ["muneeb.lazi", "adil.lazi"]
            const from = alice
            const qty = names.length
            const price = "" + (await sc.getPrice(qty, { from }))
            console.log({ price })
            await sc.buyLaziNames(names, {
                from,
                value: price,
            })
        }

        {
            const domainName = await sc.domainNameOf(1)
            console.log({ domainName })
        }

        const balanceBefore = await web3.eth.getBalance(sc.address)
        await sc.withdraw({ from: owner })
        const balanceAfter = await web3.eth.getBalance(sc.address)
        console.log(
            `balanceBefore ${fromWei(balanceBefore)}
balanceAfter ${fromWei(balanceAfter)} type ${typeof balanceBefore}`
        )

        assert(balanceAfter !== balanceBefore)
    })
})
