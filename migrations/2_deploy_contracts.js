var JointSignature = artifacts.require("./JointSignature.sol");

// NOTE: Change the addresses below to match the four available accounts from testrpc

const debug = true;
const manager = "0x33e610033f1e9dc80651f2722fd9ac055088c044";
const shareholders = [
  "0xc56ac56f0c2d3926c0aee28fd69db562f1efbc32",
  "0x48b69b9a877d1fb86bf259ac3d253df49a91ea72",
  "0x32f57bc476f423d39f58e39a2dbe23aa724a522c"
];

module.exports = function(deployer) {
  deployer.deploy(JointSignature, debug, manager, shareholders[0], shareholders[1], shareholders[2]);
};
