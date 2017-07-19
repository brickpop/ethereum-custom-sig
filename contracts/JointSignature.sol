pragma solidity ^0.4.11;

contract owned {
	address owner;
	function owned() {
		owner = msg.sender;
	}

	modifier ownerOnly {
		if (msg.sender == owner) _ ;
	}
	function kill() ownerOnly {
		suicide(owner);
	}
}

contract JointSignature is owned {
	address manager;
	address[3] shareHolders;

	event Approve(address recipient, uint amount);
	event Reject(address recipient, uint amount);
	event Execute(address recipient, uint amount);
	event Withdraw(address recipient, uint amount);
	// event Log(string text);

	uint256 constant amountSoftLimit = 0.5 ether; // allow the manager to spend 0.5 eth directly once a day
	uint256 constant amountHardLimit = 5 ether;	 // allow the manager to make payments below 5 eth if no majority rejects it within a day
	uint directPaymentsTimeThreshold = 1 days; // minimum time frame between payments below amountSoftLimit
	uint paymentsUnlockThreshold = 1 weeks; // time after which payments without enough votes can be unlocked
	uint lastDirectPayment = 0; // timestamp

	modifier onlyManager {
		require(msg.sender == manager); // will throw if false
		_ ;
	}
	modifier onlyShareHolders {
		require(shareHolders[0] == msg.sender || shareHolders[1] == msg.sender || shareHolders[2] == msg.sender); // will throw if false
		_ ;
	}

	enum PaymentVote { Pending, Approve, Reject }

	struct Payment {
		uint debt;
		uint unlockDate; // payments (below amountHardLimit) are unlocked after this timestamp provided that > 50% is not against
		PaymentVote[3] approvals;
	}

	// @receiver => payment
	mapping (address => Payment) private payments; // still to be approved

	mapping (address => uint) private approvedPayments; // available

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
	function createPayment(uint256 _amount, address _receiver) onlyManager returns (bool) {
		if(_amount == 0) return false; // save gas
		uint prevAmount = payments[_receiver].debt;
		uint newAmount = _amount + prevAmount;
		require(newAmount > prevAmount); // prevent overflow

		if(canPaymentBeDirect(_amount, _receiver)){
			lastDirectPayment = now;
			payments[_receiver].debt = 0;
			payments[_receiver].approvals = [PaymentVote.Pending, PaymentVote.Pending, PaymentVote.Pending];
			
			require(approvedPayments[_receiver] + newAmount > approvedPayments[_receiver]);
			approvedPayments[_receiver] += newAmount;
		}
		else if(prevAmount > 0) { // increase + discard previous approvals
			payments[_receiver].debt = newAmount;
			payments[_receiver].approvals = [PaymentVote.Pending, PaymentVote.Pending, PaymentVote.Pending];
		}
		else {
			uint unlockDate = now + paymentsUnlockThreshold;
			payments[_receiver] = Payment({
				debt: newAmount,
				unlockDate: unlockDate,
				approvals: [PaymentVote.Pending, PaymentVote.Pending, PaymentVote.Pending]
			});
		}
		return true;
	}

	function canPaymentBeDirect(uint256 _amount, address _receiver) private constant returns (bool){
		bool enoughTimeSinceLastDirectPayment = (lastDirectPayment + directPaymentsTimeThreshold) < now;
		if(!enoughTimeSinceLastDirectPayment) return false;

		bool belowSoftLimit = (_amount + payments[_receiver].debt) <= amountSoftLimit;
		return belowSoftLimit;
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

		if(payments[_receiver].approvals[i] == PaymentVote.Approve) return; // save gas
		payments[_receiver].approvals[i] = PaymentVote.Approve;

		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentVote.Approve) approving++;
		}
		
		if((100 * approving / shareHolders.length) <= 50) return; // nothing to do at this point

		Approve(_receiver, payments[_receiver].debt);
		uint amount = payments[_receiver].debt;
		payments[_receiver].debt = 0;
		payments[_receiver].approvals = [PaymentVote.Pending, PaymentVote.Pending, PaymentVote.Pending];
		
		require(approvedPayments[_receiver] + amount > approvedPayments[_receiver]);
		approvedPayments[_receiver] += amount;
	}

	// a shareholder rejects a payment
	function rejectPayment(address _receiver) onlyShareHolders {
		if(payments[_receiver].debt == 0) return;
		
		uint8 i;
		uint8 rejecting;
		for(i = 0; i < shareHolders.length; i++){
			if(msg.sender == shareHolders[i]) break;
		}

		if(payments[_receiver].approvals[i] == PaymentVote.Reject) return; // save gas
		payments[_receiver].approvals[i] = PaymentVote.Reject;
	
		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentVote.Reject) rejecting++;
		}

		if((100 * rejecting / shareHolders.length) > 50) { // payment rejected
			Reject(_receiver, payments[_receiver].debt);
			delete payments[_receiver];
		}
	}

	// the manager tries to execute a payment under amountHardLimit, only after unlockDate
	function executePayment(address _receiver) onlyManager returns (bool) {
		if(payments[_receiver].debt == 0) return false;
		else if(payments[_receiver].unlockDate > now) return false;
		else if(payments[_receiver].debt > amountHardLimit) return false;

		uint8 i;
		uint8 approving;
		uint8 rejecting;

		for(i = 0; i < payments[_receiver].approvals.length; i++){
			if(payments[_receiver].approvals[i] == PaymentVote.Approve) approving++;
			else if(payments[_receiver].approvals[i] == PaymentVote.Reject) rejecting++;
		}

		if((100 * rejecting / shareHolders.length) > 50) return; // an absolute majority rejects the payment
		else if(approving <= rejecting) return; // no simple majority approves the payment
		else { // approving has simple majority
			Execute(_receiver, payments[_receiver].debt);
			uint amount = payments[_receiver].debt;
			payments[_receiver].debt = 0;
			payments[_receiver].approvals = [PaymentVote.Pending, PaymentVote.Pending, PaymentVote.Pending];
			
			require(approvedPayments[_receiver] + amount > approvedPayments[_receiver]);
			approvedPayments[_receiver] += amount;
		}
	}

	function withdraw() returns (bool){
		if(approvedPayments[msg.sender] == 0) return false;
		Withdraw(msg.sender, approvedPayments[msg.sender]);

		uint amount = approvedPayments[msg.sender];
		approvedPayments[msg.sender] = 0;
		if(!msg.sender.send(amount)) return false;
	}

	// fallback
	function () payable {}
}
