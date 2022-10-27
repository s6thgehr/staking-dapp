// SPDX-License-Identifier: MIT
pragma solidity 0.8.4; //Do not change the solidity version as it negativly impacts submission grading

contract ExampleExternalContract {
    bool public completed;
    address owner = 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only Staking contract can");
        _;
    }

    function complete() public payable {
        completed = true;
    }

    function redeposit() public onlyOwner {
        completed = false;
        (bool sent, ) = msg.sender.call{value: address(this).balance}("");
        require(sent, "RIP; withdrawal failed :( ");
    }
}
