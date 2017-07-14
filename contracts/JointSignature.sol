pragma solidity ^0.4.11;

contract owned {
  address owner;
  function owned() {
		owner = msg.sender;
	}

  modifier ownerOnly {
		if (msg.sender == owner) _ ;
		else throw;
	}
}

contract mortal is owned {
  function kill() ownerOnly {
    suicide(owner);
  }
}

contract JointSignature is owned, mortal {
	uint256 constant amountSoftLimit = 0.5 ether; // allow the manager to spend 0.5 eth directly once a day
	uint256 constant amountHardLimit = 5 ether;   // allow the manager to make payments below 5 eth if no majority rejects it within a day
	uint directPaymentsTimeThreshold = 1 days; // time frame for payments below amountSoftLimit
	uint paymentTimeThreshold = 1 weeks; // time frame for payments without enough consensus
	uint lastDirectPayment = 0; // timestamp

	address manager;
	address[3] shareHolders;

  modifier onlyManager {
		if(msg.sender == manager) _ ;
		else throw;
	}
	modifier onlyShareHolders {
		for(uint8 i = 0; i < shareHolders.length; i++){
			if(shareHolders[i] == msg.sender) {
				_ ;
				return;
			}
		}
		throw;
	}

	enum PaymentChoice { Pending, Approve, Reject }

	struct Payment {
		uint debt;
		uint maxDate; // timestamp after which, the payment can be made if >50% is not against
		PaymentChoice[3] approvals;
	}

	// @receiver => payment
	mapping (address => Payment) private debts;

	// constructor
	function JointSignature(bool _debug, address _manager, address _shareHolder1, address _shareHolder2, address _shareHolder3) {
		if(_debug) directPaymentsTimeThreshold = 3 seconds;
		manager = _manager;
		shareHolders = [_shareHolder1, _shareHolder2, _shareHolder3];
	}

	// new CEO
	function setManager(address _newManager) onlyManager {
		manager = _newManager;
	}

	// manager registers a payment
	function createPayment(uint256 _amount, address _receiver) onlyManager {
		if(_amount == 0) return; // noop

		bool enoughTimeSinceLastDirectPayment = (lastDirectPayment + directPaymentsTimeThreshold) < now;
		bool belowAmountSoftLimit = (_amount + debts[_receiver].debt) <= amountSoftLimit;

		if(enoughTimeSinceLastDirectPayment && belowAmountSoftLimit){
			_receiver.transfer(_amount + debts[_receiver].debt);
			debts[_receiver].debt = 0;
			debts[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
			lastDirectPayment = now;
		}
		else if(debts[_receiver].debt > 0) { // increase + discard previous approvals
			debts[_receiver].debt += _amount;
			debts[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
		}
		else {
			uint maxDate = now + paymentTimeThreshold;
			debts[_receiver] = Payment({
				debt: _amount,
				maxDate: maxDate,
				approvals: [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending]
			});
		}
	}

	// how much is it owed to a receiver
	function getDebt(address _receiver) onlyShareHolders constant returns (uint debt){
		debt = debts[_receiver].debt;
	}

	// a shareholder accepts a payment
	function approvePayment(address _receiver) onlyShareHolders {
		if(debts[_receiver].debt == 0) return;
		
		uint8 i;
		uint8 approved;
		for(i = 0; i < shareHolders.length; i++){
			if(msg.sender == shareHolders[i]) break;
		}

		if(debts[_receiver].approvals[i] == PaymentChoice.Approve) return; // save gas
		debts[_receiver].approvals[i] = PaymentChoice.Approve;

		for(i = 0; i < debts[_receiver].approvals.length; i++){
			if(debts[_receiver].approvals[i] == PaymentChoice.Approve) approved++;
		}
		
		if((100 * approved / shareHolders.length) < 50) return; // nothing yet

		_receiver.transfer(debts[_receiver].debt);
		debts[_receiver].debt = 0;
		debts[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
	}

	// a shareholder rejects a payment
	function rejectPayment(address _receiver) onlyShareHolders {
		if(debts[_receiver].debt == 0) return;
		
		uint8 i;
		uint8 rejected;
		for(i = 0; i < shareHolders.length; i++){
			if(msg.sender == shareHolders[i]) break;
		}

		if(debts[_receiver].approvals[i] == PaymentChoice.Reject) return; // save gas
		debts[_receiver].approvals[i] = PaymentChoice.Reject;
	
		for(i = 0; i < debts[_receiver].approvals.length; i++){
			if(debts[_receiver].approvals[i] == PaymentChoice.Reject) rejected++;
		}

		if((100 * rejected / shareHolders.length) > 50) { // payment rejected
			delete debts[_receiver];
		}
	}

	// the manager tries to execute a payment under amountHardLimit, only after maxDate
	function executePayment(address _receiver) onlyManager {
		if(debts[_receiver].debt == 0) return;
		else if(debts[_receiver].maxDate < now) throw;
		else if(debts[_receiver].debt > amountHardLimit) throw;

		uint8 i;
		uint8 rejected;

		for(i = 0; i < debts[_receiver].approvals.length; i++){
			if(debts[_receiver].approvals[i] == PaymentChoice.Reject) rejected++;
		}

		if((100 * rejected / shareHolders.length) < 50) { // rejected votes are minoritary
			_receiver.transfer(debts[_receiver].debt);
			debts[_receiver].debt = 0;
			debts[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
		}
	}
}
