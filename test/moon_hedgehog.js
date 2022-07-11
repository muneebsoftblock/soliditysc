const MoonHedgehog = artifacts.require('MoonHedgehog');

contract('MoonHedgehog', ([acc1, acc2, acc3]) => {
  it('should assert true', async () => {
    await MoonHedgehog.deployed();
    return assert.isTrue(true);
  });
});
