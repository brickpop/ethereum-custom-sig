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

contract killable is owned {
	function kill() ownerOnly {
		suicide(owner);
	}
}

contract JointSignature is owned, killable {
	address manager;
	address[3] shareHolders;

	event Approve(address recipient, uint amount);
	event Reject(address recipient, uint amount);
	event Execute(address recipient, uint amount);

	uint256 constant amountSoftLimit = 0.5 ether; // allow the manager to spend 0.5 eth directly once a day
	uint256 constant amountHardLimit = 5 ether;	 // allow the manager to make payments below 5 eth if no majority rejects it within a day
	uint directPaymentsTimeThreshold = 1 days; // minimum time frame between payments below amountSoftLimit
	uint paymentsUnlockThreshold = 1 weeks; // time after which payments without enough votes can be unlocked
	uint lastDirectPayment = 0; // timestamp

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
		uint unlockDate; // payments (below amountHardLimit) are unlocked after this timestamp provided that > 50% is not against
		PaymentChoice[3] approvals;
	}

	// @receiver => payment
	mapping (address => Payment) private payments;

	// constructor
	function JointSignature(bool _debug, address _manager, address _shareHolder1, address _shareHolder2, address _shareHolder3) {
		if(_debug) {
			directPaymentsTimeThreshold = 5 seconds;
			paymentsUnlockThreshold = 5 seconds;
		}
		manager = _manager;
		shareHolders = [_shareHolder1, _shareHolder2, _shareHolder3];
	}

	// new CEO
	function setManager(address _newManager) onlyManager {
		manager = _newManager;
	}

	// manager registers a payment
	function createPayment(uint256 _amount, address _receiver) onlyManager {
		if(_amount == 0) return; // save gas

		bool enoughTimeSinceLastDirectPayment = (lastDirectPayment + directPaymentsTimeThreshold) < now;
		bool belowSoftLimit = (_amount + payments[_receiver].debt) <= amountSoftLimit;

		if(enoughTimeSinceLastDirectPayment && belowSoftLimit){
			if(!_receiver.send(_amount + payments[_receiver].debt)) throw;
			payments[_receiver].debt = 0;
			payments[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
			lastDirectPayment = now;
		}
		else if(payments[_receiver].debt > 0) { // increase + discard previous approvals
			payments[_receiver].debt += _amount;
			payments[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
		}
		else {
			uint unlockDate = now + paymentsUnlockThreshold;
			payments[_receiver] = Payment({
				debt: _amount,
				unlockDate: unlockDate,
				approvals: [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending]
			});
		}
	}

	// how much is it owed to a receiver
	function getDebt(address _receiver) onlyShareHolders constant returns (uint debt){
		debt = payments[_receiver].debt;
	}

	// a shareholder accepts a payment
	function approvePayment(address _receiver) onlyShareHolders {
		if(payments[_receiver].debt == 0) return; // save gas
		
		uint8 i;
		uint8 approving;
		for(i = 0; i < shareHolders.length; i++){
			if(msg.sender == shareHolders[i]) break;
		}

		if(payments[_receiver].approvals[i] == PaymentChoice.Approve) return; // save gas
		payments[_receiver].approvals[i] = PaymentChoice.Approve;

		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentChoice.Approve) approving++;
		}
		
		if((100 * approving / shareHolders.length) < 50) return; // nothing to do at this point

		if(!_receiver.send(payments[_receiver].debt)) throw;
		Approve(_receiver, payments[_receiver].debt);
		payments[_receiver].debt = 0;
		payments[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
	}

	// a shareholder rejects a payment
	function rejectPayment(address _receiver) onlyShareHolders {
		if(payments[_receiver].debt == 0) return;
		
		uint8 i;
		uint8 rejecting;
		for(i = 0; i < shareHolders.length; i++){
			if(msg.sender == shareHolders[i]) break;
		}

		if(payments[_receiver].approvals[i] == PaymentChoice.Reject) return; // save gas
		payments[_receiver].approvals[i] = PaymentChoice.Reject;
	
		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentChoice.Reject) rejecting++;
		}

		if((100 * rejecting / shareHolders.length) > 50) { // payment rejected
			Reject(_receiver, payments[_receiver].debt);
			delete payments[_receiver];
		}
	}

	// the manager tries to execute a payment under amountHardLimit, only after unlockDate
	function executePayment(address _receiver) onlyManager {
		if(payments[_receiver].debt == 0) return;
		else if(payments[_receiver].unlockDate > now) throw;
		else if(payments[_receiver].debt > amountHardLimit) throw;

		uint8 i;
		uint8 approving;
		uint8 rejecting;

		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentChoice.Approve) approving++;
			else if(payments[_receiver].approvals[i] == PaymentChoice.Reject) rejecting++;
		}

		if((100 * rejecting / shareHolders.length) > 50) return; // an absolute majority rejects the payment
		else if(approving <= rejecting) return; // no simple majority approves the payment
		else { // approving has simple majority
			if(!_receiver.send(payments[_receiver].debt)) throw;
			Execute(_receiver, payments[_receiver].debt);
			payments[_receiver].debt = 0;
			payments[_receiver].approvals = [PaymentChoice.Pending, PaymentChoice.Pending, PaymentChoice.Pending];
		}
	}

	// fallback
	function () payable {}
}
