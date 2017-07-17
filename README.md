Joint Signature smart contract
---

This project is a demonstration of a Joint Signature company, powered by an Ethereum Smart Contract

A manager is entitled to register the payments that the company should fulfill and shareholders can approve or reject payments and the contract will execute them when appropriate. 

- Payments under `amountSoftLimit = 0.5 ether` can be made directly, once a day (avoid spamming the shareholders for small payments)
- Payments with more than 50% of shareholders approving will be executed
- Payments with more than 50% of shareholders rejecting will not be executed
- Payments with no majority of approvals/rejections can be executed by the admin if the amount is below `amountHardLimit` and no shareholder consensus has been reached within a week (avoid blocking the company if shareholders do not vote within a reasonable period of time)

This yields the best of both worlds (single administrator vs. traditional joint signature): 
* Agility for day-to-day payments
* Shareholder control over relevant payments (needing consensus)

The JointSignature contract features the following operations: 

* `function JointSignature(bool _debug, address _manager, address _shareHolder1, address _shareHolder2, address _shareHolder3)`
* `function setManager(address _newManager) onlyManager`
* `function createPayment(uint256 _amount, address _receiver) onlyManager`
* `function getDebt(address _receiver) onlyShareHolders constant returns (uint debt)`
* `function approvePayment(address _receiver) onlyShareHolders`
* `function rejectPayment(address _receiver) onlyShareHolders`
* `function executePayment(address _receiver) onlyManager`
* `function kill() ownerOnly`


### Compile and run

Install `truffle` on your computer

```bash
$ npm install -g truffle ethereumjs-testrpc
```

In one terminal window, launch `testrpc`

* Copy the first addresses
* Paste them into `migrations/2_deploy_contracts.js` > `manager` and `shareholders [...]`

In the other one, use `truffle` to compile and deploy the app to your local net.

```bash
$ truffle compile
Compiling ./contracts/Migrations.sol...
Compiling ./contracts/JointSignature.sol...
Writing artifacts to ./build/contracts
```

```bash
$ truffle migrate
Using network 'development'.

Running migration: 1_initial_migration.js
  Deploying Migrations...
  Migrations: 0xedd7cc2bb0ad2770f65228163f8853eb83c27af1
Saving successful migration to network...
Saving artifacts...
Running migration: 2_deploy_contracts.js
  Deploying JointSignature...
  JointSignature: 0x0c110d9d3626d2d3cdb888f305d3aedde83772f8
Saving successful migration to network...
Saving artifacts...
```

```bash
$ truffle console
truffle(development)> 
```

And then interact with the contracts as you need.

### Testing

```bash
$ truffle test
```
