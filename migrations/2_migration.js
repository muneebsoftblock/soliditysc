const MoonHedgehogs = artifacts.require('MoonHedgehogs');

module.exports = function (deployer) {
  deployer.deploy(MoonHedgehogs);
};
