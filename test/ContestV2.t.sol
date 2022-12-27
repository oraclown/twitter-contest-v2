// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

import "../src/ContestV2.sol";
import "usingtellor/TellorPlayground.sol";


contract ContestV2Test is Test {
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
    string public handle1 = "zip";
    string public handle2 = "zap";
    string public handle3 = "zop";

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
        // try to register with no twitter handle included
        vm.startPrank(bob);
        vm.expectRevert("Handle cannot be empty");
        contest.register("");

        // register successfully
        uint256 balanceBefore = token.balanceOf(bob);
        string[] memory handlesList = contest.getHandlesList();
        assertEq(handlesList.length, 0, "handlesList not empty");
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle1);
        uint256 balanceAfter = token.balanceOf(bob);
        ContestV2.Member memory memberInfo;
        memberInfo = contest.getMemberInfo(bob);
        assertEq(memberInfo.handle, handle1, "twitter handle not set correctly");
        assertEq(memberInfo.inTheRunning, true, "inTheRunning not set correctly");
        assertEq(memberInfo.claimedFunds, false, "claimedFunds not set correctly");
        assertEq(balanceBefore - balanceAfter, wager + protocolFee, "wager and protocol fee not deducted correctly");
        assertEq(contest.remainingCount(), 1, "remainingCount not incremented");
        assertEq(contest.pot(), wager, "pot not correct");
        assertEq(contest.handleToAddress(handle1), bob, "handle not mapped to address");
        handlesList = contest.getHandlesList();
        assertEq(handlesList.length, 1, "handlesList not updated");
        assertEq(handlesList[0], handle1, "handlesList not updated");

        // try to register with same account
        token.approve(address(contest), wager + protocolFee);
        vm.expectRevert("Account already registered");
        contest.register(handle2);
        vm.stopPrank();
   
        // try to register with already used twitter handle
        vm.startPrank(alice);
        token.approve(address(contest), wager + protocolFee);
        vm.expectRevert("Handle already registered");
        contest.register(handle1);

        // try to register after start deadline
        console.log("block.timestamp before warp", block.timestamp);
        vm.warp(startDeadlineDays * 86400 + block.timestamp + 1);
        console.log("block.timestamp after warp", block.timestamp);
        vm.expectRevert("Contest already started");
        contest.register(handle2);
        vm.stopPrank();
    }
}
