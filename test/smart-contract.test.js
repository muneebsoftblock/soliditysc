const { ecsign } = require('ethereumjs-util');

const AletheaNFT = artifacts.require('AletheaNFT');
const AliERC20v2 = artifacts.require('AliERC20v2');

contract('AletheaNFT', ([alice, bob, carol, owner]) => {
  it('should assert true', async () => {
    //

    const nft = await AletheaNFT.new('name', 'symbol', { from: owner }); // deploy smartContract
    const coin = await AliERC20v2.new(owner, { from: owner }); // deploy smartContract

    await nft.mint(alice, 0, { from: owner }); // write api

    console.log(alice);
    console.log('0xd912AeCb07E9F4e1eA8E6b4779e7Fb6Aa1c3e4D8');
    const alicePrivateKey = '0x133be114715e5fe528a1b8adf36792160601a2d63ab59d1fd454275b31328791';

    await coin.updateFeatures('65535', { from: owner }); // write api
    await coin.transfer(alice, '10000', { from: owner }); // write api
    await coin.transferFrom(owner, alice, '10000', { from: owner }); // write api

    await coin.transfer(carol, '10000', { from: alice }); // write api

    const DOMAIN_SEPARATOR = await nft.DOMAIN_SEPARATOR();
    console.log({ DOMAIN_SEPARATOR });

    const PERMIT_FOR_ALL_TYPEHASH = await nft.PERMIT_FOR_ALL_TYPEHASH();
    console.log({ PERMIT_FOR_ALL_TYPEHASH });

    const permitNonces = 1 + Number('' + (await nft.permitNonces(alice))); // +1 to get next nonce to use
    console.log({ permitNonces });

    // signEIP712(domainSeparator, typeHash, types, parameters, USER_KEY)
    const signature = signEIP712(
      DOMAIN_SEPARATOR,
      PERMIT_FOR_ALL_TYPEHASH,
      ['address', 'address', 'bool', 'uint256', 'uint256'],
      [alice, owner, true, permitNonces, Math.floor(Date.now() / 1000 + 86400)],
      alicePrivateKey,
    );
    console.log({ signature });

    //
  });
});

const signEIP712 = (domainSeparator, typeHash, types, parameters, privateKey) => {
  const digest = web3.utils.keccak256(
    '0x1901' + strip0x(domainSeparator) + strip0x(web3.utils.keccak256(web3.eth.abi.encodeParameters(['bytes32', ...types], [typeHash, ...parameters]))),
  );

  console.log(typeof digest);
  return ecSign(digest, privateKey);
};

// ---- THE FOLLOWING CODE WAS COPIED FROM THE COINBASE STABLECOIN TESTS ----
// https://github.com/CoinbaseStablecoin/eip-3009/blob/a9c3362f62232ab44b0c7c697146d2533203303b/test/helpers/index.ts

function strip0x(v) {
  return v.replace(/^0x/, '');
}

function hexStringFromBuffer(buf) {
  return '0x' + buf.toString('hex');
}

function bufferFromHexString(hex) {
  return Buffer.from(strip0x(hex), 'hex');
}

function ecSign(digest, privateKey) {
  const { v, r, s } = ecsign(bufferFromHexString(digest), bufferFromHexString(privateKey));

  return { v, r: hexStringFromBuffer(r), s: hexStringFromBuffer(s) };
}

// const smartContractOwner = await s.owner(); // read api
// await s.mint(alice, 0, { from: owner, value: '0' }); // write api
// const smartContractAddress = s.address; // util read address
// console.log({ acc: await web3.eth.getAccounts() }); // util, get web3 object injected by default in truffle framework
