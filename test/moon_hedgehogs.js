const AletheaNFT = artifacts.require('AletheaNFT');
const AliERC20v2 = artifacts.require('AliERC20v2');

contract('AletheaNFT', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    //

    const nft = await AletheaNFT.new('name', 'symbol', { from: owner }); // deploy smartContract
    const coin = await AliERC20v2.new(owner, { from: owner }); // deploy smartContract

    await nft.mint(alice, 0, { from: owner }); // write api
    const chickenRole = await coin.userRoles(owner); // read api
    console.log({ roles: ''+chickenRole });

    // await coin.transferFrom(owner, alice, '10000', { from: owner }); // write api

    //
  });
});

// const smartContractOwner = await s.owner(); // read api
// await s.mint(alice, 0, { from: owner, value: '0' }); // write api
// const smartContractAddress = s.address; // util read address
