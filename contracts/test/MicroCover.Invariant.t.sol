// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// Drives bounded create/join actions from a fixed set of synthetic actors.
contract MicroCoverHandler is Test {
    MicroCover public cover;
    MockUSDC public usdc;
    address[] public actors;

    constructor(MicroCover cover_, MockUSDC usdc_) {
        cover = cover_;
        usdc = usdc_;
        string[5] memory names = ["provider", "alice", "bob", "carol", "dave"];
        for (uint256 i; i < names.length; i++) {
            address a = makeAddr(names[i]);
            actors.push(a);
            usdc.mint(a, type(uint96).max);
            vm.prank(a);
            usdc.approve(address(cover), type(uint256).max);
        }
    }

    function create(uint256 actorSeed, uint256 comp, uint256 escrow, uint256 maxC) external {
        // Cap the number of guarantees so the per-call invariant loop stays cheap.
        if (cover.nextGuaranteeId() > 12) return;
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(who);
        cover.createGuarantee(
            uint128(bound(comp, 1, 1e9)),
            uint128(bound(escrow, 1, 1e9)),
            uint32(bound(maxC, 1, 100)),
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            bytes32(0)
        );
    }

    function join(uint256 actorSeed, uint256 idSeed) external {
        uint256 next = cover.nextGuaranteeId();
        if (next == 1) return;
        uint256 id = bound(idSeed, 1, next - 1);
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        vm.prank(who);
        // Expected reverts (full / duplicate / provider) are tolerated; state must stay consistent.
        try cover.joinCohort(id) {} catch {}
    }
}

contract MicroCoverInvariantTest is Test {
    MicroCover internal cover;
    MockUSDC internal usdc;
    MicroCoverHandler internal handler;

    function setUp() public {
        usdc = new MockUSDC();
        cover = new MicroCover(IERC20(address(usdc)));
        handler = new MicroCoverHandler(cover, usdc);
        targetContract(address(handler));
    }

    /// PROPERTY: contract's USDC balance == sum(bondOf + escrowedOf) over created guarantees.
    function invariant_UsdcBalanceEqualsBondsPlusEscrow() public view {
        uint256 total;
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            total += cover.bondOf(id) + cover.escrowedOf(id);
        }
        assertEq(usdc.balanceOf(address(cover)), total);
    }

    /// PROPERTY: cohortSize never exceeds maxCohort and escrow == escrowAmount * cohortSize.
    function invariant_CohortBoundedAndEscrowConsistent() public view {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            assertLe(g.cohortSize, g.maxCohort);
            assertEq(cover.escrowedOf(id), uint256(g.escrowAmount) * g.cohortSize);
            assertEq(cover.bondOf(id), uint256(g.compensation) * g.maxCohort);
        }
    }
}
