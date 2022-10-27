// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

contract Staker {
    event Stake(address indexed sender, uint256 amount);
    event Received(address receiver, uint256 amount);
    event Execute(address indexed sender, uint256 amount);

    uint256 public constant REWARD_RATE_PER_SECOND = 0.1 ether;

    ExampleExternalContract public exampleExternalContract;

    mapping(address => uint256) balances;
    mapping(address => uint256) depositTimestamps;

    uint256 public depositDeadline;
    uint256 public claimDeadline;
    uint256 public currentBlock = 0;

    constructor(address exampleExternalContractAddress) {
        exampleExternalContract = ExampleExternalContract(
            exampleExternalContractAddress
        );
        depositDeadline = block.timestamp + 120 seconds;
        claimDeadline = block.timestamp + 240 seconds;
    }

    function depositTimeLeft() public view returns (uint256) {
        if (block.timestamp >= depositDeadline) {
            return (0);
        } else {
            return (depositDeadline - block.timestamp);
        }
    }

    function claimPeriodLeft() public view returns (uint256) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    modifier depositDeadlineReached(bool requireReached) {
        uint256 timeRemaining = depositTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    modifier claimDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim deadline is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim deadline has been reached");
        }
        _;
    }

    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    modifier isCompleted() {
        bool completed = exampleExternalContract.completed();
        require(completed, "Stake not completed!");
        _;
    }

    // Stake function for a user to stake ETH in our contract

    function stake() public payable depositDeadlineReached(false) {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);
    }

    /*
  Withdraw function for a user to remove their staked ETH inclusive
  of both the principle balance and any accrued interest
  */

    function withdraw()
        public
        depositDeadlineReached(true)
        claimDeadlineReached(false)
        notCompleted
    {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");
        uint256 individualBalance = balances[msg.sender];

        uint256 indBalanceRewards = individualBalance +
            (2**((block.timestamp - depositTimestamps[msg.sender]) / 20) *
                REWARD_RATE_PER_SECOND);
        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example.org/sending-ether
        (
            bool sent, /*bytes memory data*/

        ) = msg.sender.call{value: indBalanceRewards}("");
        require(sent, "RIP; withdrawal failed :( ");
    }

    /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */

    function execute() public claimDeadlineReached(true) notCompleted {
        exampleExternalContract.complete{value: address(this).balance}();
    }

    function newRound() public claimDeadlineReached(true) isCompleted {
        exampleExternalContract.redeposit();
        killTime();
    }

    function killTime() public {
        currentBlock = block.timestamp;
        depositDeadline = currentBlock + 120 seconds;
        claimDeadline = currentBlock + 250 seconds;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
