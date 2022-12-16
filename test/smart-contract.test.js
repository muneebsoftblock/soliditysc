const { ecsign } = require('ethereumjs-util');

const AletheaNFT = artifacts.require('AletheaNFT');
const AliERC20v2 = artifacts.require('AliERC20v2');

contract('AletheaNFT', ([USER_WALLET, THIRD_PARTY_WALLET, TREASURY_WALLET, w1,w2,w3]) => {
  it('NFT signEIP712', async () => {
    //
    const nft = await AletheaNFT.new('name', 'symbol', { from: TREASURY_WALLET }); // deploy smartContract
    await nft.updateFeatures(65535, { from: TREASURY_WALLET }); // write api // enable transfers, permits
    
    const nftId = 0; // nft id AvailableForMint // get from DB
    await nft.mint(USER_WALLET, nftId, { from: TREASURY_WALLET }); // write api

    assert.equal(USER_WALLET, '0xd912AeCb07E9F4e1eA8E6b4779e7Fb6Aa1c3e4D8');
    const USER_WALLET_PV_KEY = '0x133be114715e5fe528a1b8adf36792160601a2d63ab59d1fd454275b31328791';
    
    const DOMAIN_SEPARATOR = await nft.DOMAIN_SEPARATOR();
    const PERMIT_FOR_ALL_TYPEHASH = await nft.PERMIT_FOR_ALL_TYPEHASH();
    const permitNonces = await nft.permitNonces(USER_WALLET);
    const expiry = Math.floor(Date.now() / 1000 + 86400);

    const sign = signEIP712(
      DOMAIN_SEPARATOR,
      PERMIT_FOR_ALL_TYPEHASH,
      ['address', 'address', 'bool', 'uint256', 'uint256'],
      [USER_WALLET, TREASURY_WALLET, true, permitNonces, expiry],
      USER_WALLET_PV_KEY,
    );

    await nft.permitForAll(USER_WALLET, TREASURY_WALLET, true, expiry, sign.v, sign.r, sign.s, {
      from: TREASURY_WALLET,
    });

    await nft.transferFrom(USER_WALLET, THIRD_PARTY_WALLET, nftId, { from: TREASURY_WALLET }); // special call // write api

    //
  });
  it('ERC20 signEIP712', async () => {
    //
    const coin = await AliERC20v2.new(TREASURY_WALLET, { from: TREASURY_WALLET }); // deploy smartContract
    await coin.updateFeatures(65535, { from: TREASURY_WALLET }); // write api // enable transfers, permits
    const qty = '100';
    await coin.transfer(USER_WALLET, qty, { from: TREASURY_WALLET }); // write api

    assert.equal(USER_WALLET, '0xd912AeCb07E9F4e1eA8E6b4779e7Fb6Aa1c3e4D8');
    const USER_WALLET_PV_KEY = '0x133be114715e5fe528a1b8adf36792160601a2d63ab59d1fd454275b31328791';
    const DOMAIN_SEPARATOR = await coin.DOMAIN_SEPARATOR();
    const TRANSFER_WITH_AUTHORIZATION_TYPEHASH = await coin.TRANSFER_WITH_AUTHORIZATION_TYPEHASH();
    const nonce = web3.utils.randomHex(32);
    const nonceUsed = await coin.authorizationState(USER_WALLET, DOMAIN_SEPARATOR);
    const now = Math.floor(Date.now() / 1000);
    const issue = now - 10,
      expiry = now + 60 * 60;

    if (nonceUsed) {
      console.log('nonce already used try again');
      return;
    }

    const sign = signEIP712(
      DOMAIN_SEPARATOR,
      TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
      ['address', 'address', 'uint256', 'uint256', 'uint256', 'bytes32'],
      [USER_WALLET, w1, qty, issue, expiry, nonce],
      USER_WALLET_PV_KEY,
    );

    await coin.transferWithAuthorization(USER_WALLET, w1, qty, issue, expiry, nonce, sign.v, sign.r, sign.s, {
      from: w2,
    });
  });
});

// util
const signEIP712 = (domainSeparator, typeHash, types, parameters, privateKey) => {
  const digest = web3.utils.keccak256(
    '0x1901' + strip0x(domainSeparator) + strip0x(web3.utils.keccak256(web3.eth.abi.encodeParameters(['bytes32', ...types], [typeHash, ...parameters]))),
  );
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

// util code for syntax
// const smartContractOwner = await s.owner(); // read api
// await s.mint(alice, 0, { from: owner, value: '0' }); // write api
// const smartContractAddress = s.address; // util read address
// console.log({ acc: await web3.eth.getAccounts() }); // util, get web3 object injected by default in truffle framework
