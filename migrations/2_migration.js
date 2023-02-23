// const sc = artifacts.require('DigiCollect');

// module.exports = function (deployer) {
//   deployer.deploy(sc);
// };

const DIGI = artifacts.require("DIGI");
const Digicollect = artifacts.require("Digicollect");

module.exports = function (deployer) {
  deployer.deploy(DIGI).then(function() {
    return deployer.deploy(Digicollect, DIGI.address);
  });
};

