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
    uint256 public shieldCostBefore = 100 wei;
    uint256 public shieldCostAfter = 200 wei;
    uint256 public wager = 500 wei;
    bytes public queryData = abi.encode("TwitterContestV1", abi.encode(bytes("")));
    bytes32 public queryId = keccak256(queryData);
    address alice = address(0x1);
    address bob = address(0x2);
    address ricky = address(0x3);
    address kevin = address(0x4);
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
            protocolFee,
            shieldCostBefore,
            shieldCostAfter
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
        assertEq(contest.shieldCostBefore(), shieldCostBefore, "shield cost before not set correctly");
        assertEq(contest.shieldCostAfter(), shieldCostAfter, "shield cost after not set correctly");
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

    function testClaimLoser() public {
        // register one account
        vm.startPrank(bob);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle1);
        vm.stopPrank();

        // try to claim loser with only one account
        vm.startPrank(alice);
        vm.expectRevert("Only one user left");
        contest.claimLoser(1);

        // register two more accounts
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle2);
        vm.stopPrank();
        vm.startPrank(ricky);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle3);

        // try to claim loser before contest start
        vm.expectRevert("Contest has not started");
        contest.claimLoser(0);

        // try to claim loser when no oracle value has been submitted. Simulates invalid index input as well
        vm.warp(startDeadlineDays * 86400 + block.timestamp + 1);
        vm.expectRevert("No data found");
        contest.claimLoser(0);

        // submitValue to tellor oracle signifying someone broke their tweeting streak
        tellor.submitValue(queryId, abi.encode(handle1), 0, queryData);

        // try to claim loser before oracle dispute period has elapsed
        vm.expectRevert("Oracle dispute period has not passed");
        contest.claimLoser(0);

        // successfully claim loser
        vm.warp(block.timestamp + 12 * 3600 + 1); // advance time past oracle dispute period of 12 hours
        ContestV2.Member memory memberInfoBefore = contest.getMemberInfo(bob);
        assertEq(memberInfoBefore.inTheRunning, true, "member should be in the running");
        contest.claimLoser(0);
        ContestV2.Member memory memberInfo = contest.getMemberInfo(bob);
        assertEq(memberInfo.inTheRunning, false, "inTheRunning not set correctly");

        // try to claim loser on account not "in the money"
        vm.expectRevert("User is not in the running");
        contest.claimLoser(0);

        // try to claim loser after contest has ended
        vm.warp((startDeadlineDays + endDeadlineDays) * 86400 + block.timestamp + 1);
        vm.expectRevert("Contest has ended");
        contest.claimLoser(0);
        vm.stopPrank();
    }

    function testClaimFunds() public {
        // register three accounts
        vm.startPrank(bob);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle1);
        vm.stopPrank();
        vm.startPrank(alice);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle2);
        vm.stopPrank();
        vm.startPrank(ricky);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle3);

        // claim loser on one participant
        vm.warp(startDeadlineDays * 86400 + block.timestamp + 1);
        tellor.submitValue(queryId, abi.encode(handle1), 0, queryData);
        vm.warp(block.timestamp + 12 * 3600 + 1); // advance time past oracle dispute period of 12 hours
        contest.claimLoser(0);
        vm.stopPrank();

        // try to claim funds as non-participant
        vm.prank(kevin);
        vm.expectRevert("not a valid participant");
        contest.claimFunds();

        // try to claim funds before contest has ended
        vm.startPrank(alice);
        vm.expectRevert("Game still active");
        contest.claimFunds();

        // claim funds successfully
        vm.warp((startDeadlineDays + endDeadlineDays) * 86400 + block.timestamp + 1);
        uint256 balanceBefore = token.balanceOf(alice);
        contest.claimFunds();
        uint256 balanceAfter = token.balanceOf(alice);
        uint256 expectedBalance = wager + wager / 2;
        assertEq(balanceAfter - balanceBefore, expectedBalance, "balance not correct");
        
        // try to claim funds again
        vm.expectRevert("funds already claimed");
        contest.claimFunds();
        vm.stopPrank();

        // last eligible participant claims funds successfully
        vm.startPrank(ricky);
        balanceBefore = token.balanceOf(ricky);
        contest.claimFunds();
        balanceAfter = token.balanceOf(ricky);
        assertEq(balanceAfter - balanceBefore, expectedBalance, "balance not correct");
        vm.stopPrank();
  
        // participant who broke their streak tries to claim funds
        vm.prank(bob);
        vm.expectRevert("not a valid participant");
        contest.claimFunds();
    }

    function testGetHandlesList() public {
        // check handles before registration
        string[] memory handlesList = contest.getHandlesList();
        assertEq(handlesList.length, 0, "handlesList should have 0 elements");

        // check handles after 1 registration
        vm.startPrank(bob);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle1);
        handlesList = contest.getHandlesList();
        vm.stopPrank();
        assertEq(handlesList.length, 1, "handlesList should have 1 element");
        assertEq(handlesList[0], handle1, "handlesList should have correct handle");
    
        // check handles after 2 registrations
        vm.startPrank(alice);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle2);
        handlesList = contest.getHandlesList();
        vm.stopPrank();
        assertEq(handlesList.length, 2, "handlesList should have 2 elements");
        assertEq(handlesList[0], handle1, "handlesList should have correct handle");
        assertEq(handlesList[1], handle2, "handlesList should have correct handle");

        // check handles after 3 registrations
        vm.startPrank(ricky);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle3);
        handlesList = contest.getHandlesList();
        vm.stopPrank();
        assertEq(handlesList.length, 3, "handlesList should have 3 elements");
        assertEq(handlesList[0], handle1, "handlesList should have correct handle");
        assertEq(handlesList[1], handle2, "handlesList should have correct handle");
        assertEq(handlesList[2], handle3, "handlesList should have correct handle");
    }

    function testStreakShields() public {
        // register 3 accounts
        vm.startPrank(bob);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle1);
        vm.stopPrank();
        vm.startPrank(alice);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle2);
        vm.stopPrank();
        vm.startPrank(ricky);
        token.approve(address(contest), wager + protocolFee);
        contest.register(handle3);

        // ricky buys 1 shield b4 contest start
        assertEq(contest.getShieldCount(ricky), 0, "shield count not 0");
        uint256 balanceBefore = token.balanceOf(ricky);
        token.approve(address(contest), shieldCostBefore);
        contest.buyStreakShield();
        uint256 balanceAfter = token.balanceOf(ricky);
        assertEq(balanceBefore - shieldCostBefore, balanceAfter, "shield cost before contest start not deducted");
        assertEq(contest.getShieldCount(ricky), 1, "shield count not 1");
        // buys another shield after contest start
        vm.warp(startDeadlineDays * 86400 + block.timestamp + 1);
        balanceBefore = token.balanceOf(ricky);
        token.approve(address(contest), shieldCostAfter);
        contest.buyStreakShield();
        balanceAfter = token.balanceOf(ricky);
        assertEq(balanceBefore - shieldCostAfter, balanceAfter, "shield cost after contest start not deducted");
        assertEq(contest.getShieldCount(ricky), 2, "shield count not 2");
        vm.stopPrank();

        // ricky breaks tweeting streak
        vm.startPrank(bob);
        tellor.submitValue(queryId, abi.encode(handle3), 0, queryData);
        vm.warp(block.timestamp + 12 * 3600 + 1); // advance time past oracle dispute period of 12 hours
        balanceBefore = token.balanceOf(bob);
        contest.claimLoser(0);
        balanceAfter = token.balanceOf(bob);
        assertEq(contest.getShieldCount(ricky), 1, "shield count not 1");
        // ensure ricky is still in the running
        // bob's balance should be before += 10 percent of ricky's wager
        // assertEq(balanceAfter - balanceBefore, wager / 10, "balance not correct");
    
        // ricky breaks streak again
        tellor.submitValue(queryId, abi.encode(handle3), 0, queryData);
        vm.warp(block.timestamp + 12 * 3600 + 1); // advance time past oracle dispute period of 12 hours
        balanceBefore = token.balanceOf(bob);
        contest.claimLoser(1);
        balanceAfter = token.balanceOf(bob);
        assertEq(contest.getShieldCount(ricky), 0, "shield count not 0");
        // ensure ricky still in the running

        // ricky breaks streak 3rd time (no shields left)
        tellor.submitValue(queryId, abi.encode(handle3), 0, queryData);
        vm.warp(block.timestamp + 12 * 3600 + 1); // advance time past oracle dispute period of 12 hours
        balanceBefore = token.balanceOf(bob);
        contest.claimLoser(2);
        balanceAfter = token.balanceOf(bob);
        // ensure ricky is out of the running

        // other tests...
    }
}
