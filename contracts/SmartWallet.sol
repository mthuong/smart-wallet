// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.15;

contract Consumer {
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    function deposit() public payable {}
}

contract SmartWallet {
    // Wallet owner
    address public owner;

    mapping(address => uint) public allowance;
    mapping(address => bool) public isAllowedToSend;

    mapping(address => bool) guardians;
    mapping(address => mapping(address => bool)) approvalVoted;
    address payable nextOwner;
    uint8 guardianResetCount;
    uint8 public constant requireGuardianApprovals = 3;

    constructor() {
        owner = payable(msg.sender);
    }

    // Fallback function that allow the contract receive funds
    receive() external payable {}

    function transfer(address payable _to, uint _amount, bytes memory _payload) public returns(bytes memory) {
        require(_amount <= address(this).balance, "Can't send more than the contract owns, aborting.");

        if (msg.sender != owner) {
            require(isAllowedToSend[_to] == true, "You are not allowed to send any transactions, aborting");
            require(allowance[_to] >= _amount, "You are trying to send more than you are allowed to, aborting");
            allowance[_to] -= _amount;
        }

        (bool successful, bytes memory returnData) = _to.call{value: _amount}(_payload);
        require(successful, "Aborting, call was not successful");
        return returnData;
    }

    function setAllowance(address _from, uint _amount) public {
        require(msg.sender == owner, "You're not owner, aborting!");

        allowance[_from] = _amount;
        isAllowedToSend[_from] = true;
    }

    function denyAllowance(address _from) public {
        require(msg.sender == owner, "You're not owner, aborting!");

        allowance[_from] = 0;
        isAllowedToSend[_from] = false;
    }

    function setGuardian(address _guardian, bool _isGuardian) public {
        require(msg.sender == owner, "You're not owner, aborting!");

        guardians[_guardian] = _isGuardian;
    }

    function proposeNewOwner(address payable _newOwner) public {
        require(guardians[msg.sender], "You're not guardian, aborting!");
        require(approvalVoted[_newOwner][msg.sender] == false, "You're already voted, aborting!");

        if (nextOwner != _newOwner) {
            nextOwner = _newOwner;
            guardianResetCount = 0;
        }

        guardianResetCount++;
        approvalVoted[_newOwner][msg.sender] = true;

        if (guardianResetCount >= requireGuardianApprovals) {
            owner = nextOwner;
            nextOwner = payable(address(0));
        }
    }
}