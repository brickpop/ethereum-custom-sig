var JointSignature = artifacts.require("./JointSignature.sol");

contract('JointSignature', function(accounts) {
  var instance;
  
  it("should have deployed an instance", function() {
    return JointSignature.deployed()
    .then(function(inst) {
      assert(inst, "is not deployed")
      instance = inst;
    })
    .catch(function(err) {
      assert(false, "failed loading the instance: " + err.message);
    });
  });

  it("should have the right manager", function() {
  });

  it("the manager can not be changed by anyone else", function() {
  });

  it("should change the manager to a new one", function() {
  });

  it("should let the manager register a payment", function() {
  });

  it("should increase the amount for an already existing payment, and reset the existing approvals", function() {
  });

  it("a payment of less than 0.5 ether should be transfered immediately", function() {
  });

  it("additional payments of less than 0.5 ether within a month should require approval", function() {
  });

  it("should not let anyone else to register a payment", function() {
  });

  it("should allow shareholders to accept a payment", function() {
  });

  it("should allow shareholders to reject a payment", function() {
  });

  it("should not allow non-shareholders to accept a payment", function() {
  });

  it("should not allow non-shareholders to reject a payment", function() {
  });

  it("should not fulfill a payment when less than 50% of shareholders have accepted it", function() {
  });

  it("should fulfill a payment whenever more than 50% of shareholders accept it", function() {
  });

  it("should not allow the manager to execute a payment if more than 50% rejected it in less than a week", function() {
  });

  it("should allow the manager to execute a payment if more than 50% did not respond within a week", function() {
  });

  it("should only allow the manager to kill the contract", function() {
  });

});
