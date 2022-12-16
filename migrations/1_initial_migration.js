// const Migrations = artifacts.require("Migrations");

// module.exports = function (deployer) {
//   deployer.deploy(Migrations);
// };

const AletheaNFT = artifacts.require('AletheaNFT');

module.exports = function (deployer) {
  deployer.deploy(AletheaNFT, 'name', 'symbol');
};
