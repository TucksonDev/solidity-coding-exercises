// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contains only the needed functions for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    address public owner;
    mapping (address => uint256) public balances;
    uint256 public totalSupply;

    modifier onlyOwner {
        require(owner == msg.sender, "NotOwner");
        _;
    }

    constructor (string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18;
        owner = msg.sender;
    }

    function mintTo(address to, uint256 amount) external onlyOwner {
        balances[to] += amount;
        totalSupply += amount;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
