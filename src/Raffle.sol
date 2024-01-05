/**  Layout of Contract: */
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions....

/**  Layout of Functions: */
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

error NotEnoughEth();
error NotEnoughTime();

/**
 * @title Raffle Lottery contract
 * @author Ihab Heb
 * @notice This contract is for creating a raffle lottery
 * @dev using Chainlink VRFv2
 */

contract Raffle {
    uint256 private immutable i_entranceFee;
    // @dev interval is the duration of the lottery in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /** Events */
    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    // External because we assume no one will call this function from within the contract
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ether");
        if (msg.value < i_entranceFee) {
            revert NotEnoughEth();
        }
        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // Get a random number
    // random number pick a winner
    // be automatically called

    function pickWinner() external {
        // Check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert NotEnoughTime();
        }
        // Request RNG
        // Callback a Random Number
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
