// const sc = artifacts.require('DigiCollect');

// module.exports = function (deployer) {
//   deployer.deploy(sc);
// };

const CyberSyndicate = artifacts.require("CyberSyndicate");

module.exports = function (deployer) {
  deployer.deploy(CyberSyndicate, 62000, "0xf37Dc8A322e93e94bdf1d8C6a8ddB1b28e4eE16d");
};

