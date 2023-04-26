const LaziName = artifacts.require("LaziPost")
const fromWei = web3.utils.fromWei

contract("LaziPost", ([alice, bob, carol, owner]) => {
    it("should allow user to purchase a token", async () => {
        const lazypost = await LaziPost.deployed()
        const lazypostName = "example.com"
        const tokenId = 1

        // Get the initial balance of the user who is purchasing the token
        const initialBalance = await web3.eth.getBalance(accounts[1])

        // Purchase the token
        const messageHash = await lazypost.getMessageHash(
            lazypostName,
            lazypost.laziPostPrice
        )
        const signature = await web3.eth.sign(messageHash, accounts[1])
        await lazypost.buyLaziPostsSigned(
            lazypostName,
            lazypost.laziPostPrice,
            messageHash,
            signature,
            { from: accounts[1], value: lazypost.laziPostPrice }
        )

        // Verify that the token was minted
        const totalSupply = await lazypost.totalSupply()
        assert.equal(totalSupply, 1, "Token was not minted")

        // Verify that the user's balance was reduced by the token price
        const finalBalance = await web3.eth.getBalance(accounts[1])
        assert.equal(
            finalBalance,
            initialBalance - lazypost.laziPostPrice,
            "User's balance was not reduced by the token price"
        )

        // Verify that the user now owns the token
        const owner = await lazypost.ownerOf(tokenId)
        assert.equal(owner, accounts[1], "User does not own the token")
    })
    it("should not allow non-owner to call lazyMint", async () => {
        const lazypost = await LaziPost.deployed()
        const tokenId = 1
        const lazypostName = "example.com"
        const isPurchased = true
        const isMinted = false

        // Try to call lazyMint from a non-owner account
        await truffleAssert.reverts(
            lazypost.lazyMint(tokenId, lazypostName, { from: accounts[1] })
        )

        // Verify that the token was not minted
        const owner = await lazypost.ownerOf(tokenId)
        assert.equal(owner, address(0))
        assert.equal(await lazypost.isPurchased(tokenId), isPurchased)
        assert.equal(await lazypost.isMinted(lazypostName), isMinted)
    })

    it("should allow owner to lazy mint a token", async () => {
        const lazypost = await LaziPost.deployed()
        const tokenId = 1
        const lazypostName = "example.com"
        const isPurchased = true
        const isMinted = false

        // Purchase the token
        const messageHash = await lazypost.getMessageHash(
            lazypostName,
            lazypost.laziPostPrice
        )
        const signature = await web3.eth.sign(messageHash, accounts[1])
        await lazypost.buyLaziPostsSigned(
            lazypostName,
            lazypost.laziPostPrice,
            messageHash,
            signature,
            { from: accounts[1], value: lazypost.laziPostPrice }
        )

        // Call lazyMint to mint the token
        await lazypost.lazyMint(tokenId, lazypostName)

        // Verify that the token was minted and assigned to the contract
        const owner = await lazypost.ownerOf(tokenId)
        assert.equal(owner, lazypost.address)
        assert.equal(await lazypost.isPurchased(tokenId), isPurchased)
        assert.equal(await lazypost.isMinted(lazypostName), true)
        assert.equal(await lazypost.domainNameOf(tokenId), lazypostName)
    })

    it("should revert if token has not been purchased", async () => {
        const lazypost = await LaziPost.deployed()
        const tokenId = 1
        const lazypostName = "example.com"

        // Try to call lazyMint before purchasing the token
        await truffleAssert.reverts(lazypost.lazyMint(tokenId, lazypostName))
    })
})
