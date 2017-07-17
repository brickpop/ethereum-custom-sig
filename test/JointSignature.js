var JointSignature = artifacts.require("./JointSignature.sol");

var Web3 = require('web3');
var web3 = new Web3();
web3.setProvider(new web3.providers.HttpProvider('http://localhost:8545'));

contract('JointSignature', function(accounts) {
  var instance;
  const manager = accounts[0];
  const shareholders = accounts.slice(1, 4);
  const receivers = accounts.slice(4, 9);
  const nonManagers = accounts.slice(1);
  
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

  it("should let the manager register a payment", function() {
    return instance.createPayment(web3.toWei(1, 'ether'), receivers[0], {from: manager})
    .then(result => {
      assert(result && result.tx && result.receipt, "transaction should have succeeded")

      return web3.eth.getBalance(instance.address)
    })
    .then(balance => {
      assert(balance.toNumber() == 0, "balance should be zero")
      return web3.eth.getBalance(receivers[0])
    })
    .then(balance => {
      assert(balance.toNumber() == 100000000000000000000, "invalid balance");
    })
    .catch(function(err) {
      assert(false, "failed loading the instance: " + err.message);
    })
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

  it("should have the right manager and only allow the manager to thange this role", function() {
    var proms = nonManagers.map(acc => {
      return instance.setManager(accounts[0], {from: acc})
      .then(returnValue => {
        assert(false, "setManager was supposed to reject a non-manager but didn't.");
      }).catch(error => {
        assert(error.toString().indexOf("invalid opcode") > 0, error.toString());
      })
    });

    return Promise.all(proms)
    .then(() => instance.setManager(accounts[1], {from: manager}))
    .catch(error => {
      assert(false, error.toString());
    })
    .then(() => instance.setManager(accounts[1], {from: manager}))
    .then(returnValue => {
      assert(false, "setManager was supposed to reject the original manager but didn't.");
    }).catch(error => {
      assert(error.toString().indexOf("invalid opcode") > 0, error.toString());
    })
    .then(() => instance.setManager(accounts[0], {from: accounts[1]}));
  });

});
