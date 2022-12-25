// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

import "../src/ContestV2.sol";
import "usingtellor/TellorPlayground.sol";


contract CounterTest is Test {
    TellorPlayground public tellor;
    TellorPlayground public token;
    ContestV2 public contest;
    uint256 public startDeadlineDays = 1;
    uint256 public endDeadlineDays = 100;
    uint256 public protocolFee = 10 wei;
    uint256 public wager = 500 wei;
    bytes public queryData = abi.encode("TwitterContestV1", abi.encode(bytes("")));
    bytes32 public queryId = keccak256(queryData);
    address alice = address(0x12341234);
    address bob = address(0x67896789);
    address ricky = address(0x12345678);

    function setUp() public {
        tellor = new TellorPlayground();
        token = new TellorPlayground();
        contest = new ContestV2(
            payable(address(tellor)),
            payable(address(token)),
            wager,
            startDeadlineDays,
            endDeadlineDays,
            protocolFee
        );
        token.faucet(alice);
        token.faucet(bob);
        token.faucet(ricky);
    }

    function testConstructor() public {
        // console.log("queryId:", queryId)
        // console.log("queryData:", queryData)
        assertEq(address(contest.tellor()), address(tellor), "tellor address not set correctly");
        assertEq(contest.startDeadline(), startDeadlineDays * 86400 + block.timestamp, "start deadline not set correctly");
        assertEq(contest.endDeadline(), (startDeadlineDays + endDeadlineDays) * 86400 + block.timestamp, "end deadline not set correctly");
        assertEq(contest.protocolFee(), protocolFee, "protocol fee not set correctly");
        assertEq(contest.wager(), wager, "wager not set correctly");
    }

    function testRegister() public {
        console.log("balance alice:", token.balanceOf(alice));
    }
}
