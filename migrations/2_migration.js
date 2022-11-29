const AletheaNFT = artifacts.require('AletheaNFT');

module.exports = function (deployer) {
  deployer.deploy(AletheaNFT, 'name', 'symbol');
};
