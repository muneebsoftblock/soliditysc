const AletheaNFT = artifacts.require('AletheaNFT');
const AliERC20v2 = artifacts.require('AliERC20v2');

contract('AletheaNFT', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    //

    const nft = await AletheaNFT.new('name', 'symbol', { from: owner }); // deploy smartContract
    const coin = await AliERC20v2.new(owner, { from: owner }); // deploy smartContract

    await nft.mint(alice, 0, { from: owner }); // write api

    await coin.updateFeatures('65535', { from: owner }); // write api
    await coin.transfer(alice, '10000', { from: owner }); // write api
    await coin.transferFrom(owner, alice, '10000', { from: owner }); // write api

    await coin.transfer(carol, '10000', { from: alice }); // write api

    const DOMAIN_SEPARATOR = await nft.DOMAIN_SEPARATOR();
    console.log({ DOMAIN_SEPARATOR });

    const PERMIT_FOR_ALL_TYPEHASH = await nft.PERMIT_FOR_ALL_TYPEHASH();
    console.log({ PERMIT_FOR_ALL_TYPEHASH });

    const permitNonces = '' + (await nft.permitNonces(alice));
    console.log({ permitNonces });
  });
});

// const smartContractOwner = await s.owner(); // read api
// await s.mint(alice, 0, { from: owner, value: '0' }); // write api
// const smartContractAddress = s.address; // util read address
