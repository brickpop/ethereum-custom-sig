var JointSignature = artifacts.require("./JointSignature.sol");

// NOTE: Change the addresses below to match the four available accounts from testrpc

const debug = true;
const manager = "0xf2ecebfc7fe75d23e610444e3c40100124a0e17c";
const shareholders = [
  "0x84fb14a1e276d0c743d56c5a809d952b2da3a0b4",
  "0xe572610579445779669ad1b186bdb8db8537659c",
  "0xa1c1d48f6a41761d3448ec71c65115c4bb087a3d"
];

module.exports = function(deployer) {
  deployer.deploy(JointSignature, debug, manager, shareholders[0], shareholders[1], shareholders[2]);
};
