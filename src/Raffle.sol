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

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error NotEnoughEth();
error NotEnoughTime();

/**
 * @title Raffle Lottery contract
 * @author Ihab Heb
 * @notice This contract is for creating a raffle lottery
 * @dev using Chainlink VRFv2
 */

contract Raffle {
    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    /**  @dev interval is the duration of the lottery in seconds */
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    /** Events */
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        VRFCoordinatorV2Interface vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = vrfCoordinator;
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
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
        uint256 requestId = i_vrfCoordinator.requestRandomWords( // vrf coordinator different from chains
            i_gasLane, // gas lane
            i_subscriptionId, // the id of the subscription
            REQUEST_CONFIRMATIONS, // block of confirmation
            i_callbackGasLimit, // max callback gas limit
            NUM_WORDS // number of random numbers
        );
    }

    /** Getter Functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
