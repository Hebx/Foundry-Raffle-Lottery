// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    // Events
    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    // enterRaffle
    function testRaffleRevertsWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        // Assert
        raffle.enterRaffle();
    }

    // Records players when they enter the raffle
    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayers(0);
        assertEq(playerRecorded, PLAYER);
    }

    function testEmitsEventsOnEntrance() public {
        vm.prank(PLAYER);
        // index of the events
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        // the function that should emit ethe event
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__NotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepIfUserHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen()
        public
        raffleEnteredAndTimePassed
    {
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // assert(!upkeepNeeded);
        assert(upkeepNeeded == false);
    }

    // test performUpkeep
    function testPerformUpkeepCanOnlyRunIfUpkeepIsTrue()
        public
        raffleEnteredAndTimePassed
    {
        // act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // ACT
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        Raffle.RaffleState rState = raffle.getRaffleState();
        // Logs are recordes as bytes32
        // entries[0] = requestId in the mock
        // topics[0] = event signature
        bytes32 requestId = entries[1].topics[1];
        assert(requestId > 0);
        assert(rState == Raffle.RaffleState.CALCULATING_WINNER);
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testGenerateRnCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(this)
        );
    }

    function testFulfillRnPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
    {
        // arrange
        uint256 addiotionalPlayers = 3;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + addiotionalPlayers;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE); // hoax is similar to prank + deal
            raffle.enterRaffle{value: entranceFee}();
        }

        // prize
        uint256 prize = entranceFee * (addiotionalPlayers + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        // We mock the test pretending to be the chainlink node vrf on anvil to call the vrf and get a rn
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLengthOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        console.log("prize", prize);
        console.log("balance", raffle.getRecentWinner().balance);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - entranceFee
        );
    }
}

// function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
//     public
//     raffleEnteredAndTimePassed
// {
//     address expectedWinner = address(1);

//     // Arrange
//     uint256 additionalEntrances = 3;
//     uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

//     for (
//         uint256 i = startingIndex;
//         i < startingIndex + additionalEntrances;
//         i++
//     ) {
//         address player = address(uint160(i));
//         hoax(player, 1 ether); // deal 1 eth to the player
//         raffle.enterRaffle{value: entranceFee}();
//     }

//     uint256 startingTimeStamp = raffle.getLastTimeStamp();
//     uint256 startingBalance = expectedWinner.balance;

//     // Act
//     vm.recordLogs();
//     raffle.performUpkeep(""); // emits requestId
//     Vm.Log[] memory entries = vm.getRecordedLogs();
//     bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

//     VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
//         uint256(requestId),
//         address(raffle)
//     );

//     // Assert
//     address recentWinner = raffle.getRecentWinner();
//     Raffle.RaffleState raffleState = raffle.getRaffleState();
//     uint256 winnerBalance = recentWinner.balance;
//     uint256 endingTimeStamp = raffle.getLastTimeStamp();
//     uint256 prize = entranceFee * (additionalEntrances + 1);

//     assert(recentWinner == expectedWinner);
//     assert(uint256(raffleState) == 0);
//     assert(winnerBalance == startingBalance + prize);
//     assert(endingTimeStamp > startingTimeStamp);
// }
