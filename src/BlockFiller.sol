// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlockFiller {
    uint256[] public vault;

    // To burn 32,000,000 we would need less than 1,600 iterations
    // (32,000,000 / 20,000 = 1,600) 
    // This value should be 1,422 if we want to fill a full block, and it costs around 0.0035 ETH each call with a 0.01gwei price
    function fillABlock(uint16 iterations) external {
        require(iterations > 0, "Zero iterations");

        for (uint16 i = 0; i < iterations; i++) {
            vault.push(1);
        }
    }
}