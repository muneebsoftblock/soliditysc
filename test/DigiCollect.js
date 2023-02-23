const DIGI = artifacts.require("DIGI");
const DigiCollect = artifacts.require("DigiCollect");
const fromWei = web3.utils.fromWei;
const toWei = web3.utils.toWei;
const truffleAssert = require("truffle-assertions");

const advanceBlock = () => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_mine",
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        const newBlockHash = web3.eth.getBlock("latest").hash;

        return resolve(newBlockHash);
      }
    );
  });
};

contract("DigiCollect", ([alice, bob, carol, owner, ref1, ref2]) => {
  let digi;
  let digiCollect;

  before(async () => {
    digi = await DIGI.new({ from: owner });
    digiCollect = await DigiCollect.new({ from: owner });
    const role = await digi.MINTER_ROLE();

    await digi.grantRole(role, digiCollect.address, { from: owner });
    await digiCollect.setERC20(digi.address, { from: owner });

    await digiCollect.setSaleActiveTime(0, { from: owner });
  });

  it("Case 1: Buy 1 Nft, after 24 hours reward is 5 digi, collect 5 digi, nft can not be transferred because its staked.", async () => {
    const qty = 1;
    const from = alice;
    const price = await digiCollect.getPrice(qty);
    await digiCollect.buyDigiCollect(qty, ref1, {
      from,
      value: price,
    });

    const tokenId = 1;

    await advanceBlock();
    {
      const reward = fromWei("" + (await digiCollect.calculateRewards(alice, [tokenId])));
      assert.equal(reward, "0.00078125");
    }

    await digiCollect.claimRewards([tokenId]);

    {
      const reward = fromWei("" + (await digi.balanceOf(alice)));
      assert.equal(reward, 2 * Number("0.00078125"));
    }

    // expect revert
    try {
      await digiCollect.transferFrom(alice, bob, tokenId, { from: alice });
      assert(false, "Should Revert");
    } catch (e) {}
  });
});
