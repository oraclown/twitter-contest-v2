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
    uint256 public shieldCostAfter = 300 wei;
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
        vm.prank(alice);
        token.approve(address(contest), wager + protocolFee);
        vm.prank(bob);
        token.approve(address(contest), wager + protocolFee);
        vm.prank(ricky);
        token.approve(address(contest), wager + protocolFee);
    }

    function testContestE2E() public {
        // register
        vm.prank(bob);
        contest.register(handle1);
        vm.prank(alice);
        contest.register(handle2);
        vm.prank(ricky);
        contest.register(handle3);

        // advance time to start deadline
        vm.warp(contest.startDeadline());

        // submit data
        vm.startPrank(bob);
        tellor.submitValue(queryId, abi.encode(handle3), 0, queryData);
        vm.warp(block.timestamp + 12 hours + 1);

        // claim loser
        contest.claimLoser(0);
        vm.stopPrank();

        // advance time past contest end
        vm.warp(contest.endDeadline() + contest.reportingWindow() + 1);

        // claim funds
        vm.prank(alice);
        contest.claimFunds();
        vm.prank(bob);
        contest.claimFunds();

        contest.ownerClaim();
    }
    }