const CyberSyndicate = artifacts.require("CyberSyndicate");

contract("CyberSyndicate", (accounts) => {
  let contractInstance;

  before(async () => {
    contractInstance = await CyberSyndicate.deployed();
  });

  it("should mint max supply of NFTs to creator", async () => {
    const maxSupply = 5;
    await contractInstance.set_buyActiveTime(0);
    await contractInstance.buyNft(maxSupply, { value: maxSupply * 0.0001 * 1e18 });
    const totalSupply = await contractInstance.totalSupply();
    assert.equal(totalSupply, maxSupply, "total supply does not match max supply");
  });
