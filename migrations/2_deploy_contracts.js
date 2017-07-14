var JointSignature = artifacts.require("./JointSignature.sol");

module.exports = function(deployer) {
  deployer.deploy(JointSignature);
};
