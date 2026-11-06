// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// Drives bounded Phase 1 actions (create/join/admit/settle/withdraw/warp/donate) from synthetic
/// actors. Expected reverts are tolerated, but every outcome is checked against a model of when
/// each call must (not) succeed; contradictions are recorded in `violations`.
contract MicroCoverHandler is Test {
    MicroCover public cover;
    MockUSDC public usdc;
    address[] public actors;

    uint256 internal constant POOL = 60;
    uint256 internal constant MAX_IDS = 12;
    mapping(address => bool) internal poolReady;

    // ---- ghost state ----
    uint256 public ghostDonations;
    mapping(uint256 id => uint256) public ghostWithdrawn;
    mapping(uint256 id => uint8) internal lastStatus;
    mapping(uint256 id => uint32) internal lastPaid;
    mapping(uint256 id => uint32) internal lastCohort;
    mapping(uint256 id => uint64) internal lastAdmittedAt;
    uint256 public violations;
    string public firstViolation;

    // ---- coverage counters ----
    uint256 public nCreate;
    uint256 public nJoin;
    uint256 public nAdmit;
    uint256 public nSettle;
    uint256 public nSettledBeneficiaries;
    uint256 public nWithdraw;
    uint256 public nClosed;

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

    // ------------------------------------------------------------ helpers

    function _violate(string memory what) internal {
        if (violations == 0) firstViolation = what;
        violations++;
    }

    function _poolUser(uint256 seed) internal returns (address u) {
        u = address(uint160(0x40000 + (seed % POOL)));
        if (!poolReady[u]) {
            poolReady[u] = true;
            usdc.mint(u, type(uint96).max);
            vm.prank(u);
            usdc.approve(address(cover), type(uint256).max);
        }
    }

    function _pickId(uint256 seed) internal view returns (uint256 id, bool ok) {
        uint256 next = cover.nextGuaranteeId();
        if (next == 1) return (0, false);
        return (bound(seed, 1, next - 1), true);
    }

    function _anyCaller(uint256 seed) internal returns (address) {
        if (seed % 3 == 0) return actors[(seed / 3) % actors.length];
        return _poolUser(seed / 3);
    }

    /// Records monotonicity violations (status/paidCount/cohortSize never go backwards).
    function _track() internal {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.GuaranteeState memory s = cover.getState(id);
            if (uint8(s.status) < lastStatus[id]) _violate("status went backwards");
            if (s.paidCount < lastPaid[id]) _violate("paidCount went backwards");
            if (s.enrolled < lastCohort[id]) _violate("cohort shrank");
            if (lastAdmittedAt[id] != 0 && s.failureAdmittedAt != lastAdmittedAt[id]) {
                _violate("failure admission changed");
            }
            lastStatus[id] = uint8(s.status);
            lastPaid[id] = s.paidCount;
            lastCohort[id] = s.enrolled;
            lastAdmittedAt[id] = s.failureAdmittedAt;
        }
    }

    // ------------------------------------------------------------ actions

    function create(uint256 actorSeed, uint256 comp, uint256 escrow, uint256 maxC, uint256 deadline) external {
        // Cap the number of guarantees so the per-call invariant loops stay cheap.
        if (cover.nextGuaranteeId() > MAX_IDS) return;
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        uint64 dl = uint64(block.timestamp + bound(deadline, 1 hours, 3 days));
        vm.prank(who);
        cover.createGuarantee(
            uint128(bound(comp, 1, 1e9)), uint128(bound(escrow, 1, 1e9)), uint32(bound(maxC, 1, 100)),
            dl, dl + 1 days, bytes32(0)
        );
        nCreate++;
        _track();
    }

    function join(uint256 actorSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        _tryJoin(id, who);
        _track();
    }

    /// Enrolls up to ~45 synthetic users so cohorts exceed one settlement batch.
    function joinMany(uint256 idSeed, uint256 count, uint256 offset) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        uint256 n = bound(count, 1, 45);
        offset = bound(offset, 0, 1000);
        for (uint256 i; i < n; i++) {
            _tryJoin(id, _poolUser(offset + i));
        }
        _track();
    }

    function _tryJoin(uint256 id, address who) internal {
        MicroCover.GuaranteeState memory pre = cover.getState(id);
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        vm.prank(who);
        try cover.joinCohort(id) {
            nJoin++;
            if (pre.status != MicroCover.Status.OPEN) _violate("join succeeded after failure");
            if (block.timestamp > g.joinDeadline) _violate("join succeeded after deadline");
            if (g.cohortSize >= g.maxCohort) _violate("join succeeded on full cohort");
            if (who == g.provider) _violate("provider joined own guarantee");
        } catch {
            bool shouldWork = pre.status == MicroCover.Status.OPEN && block.timestamp <= g.joinDeadline
                && g.cohortSize < g.maxCohort && who != g.provider && !cover.isMember(id, who);
            if (shouldWork) _violate("join reverted unexpectedly");
        }
    }

    function admit(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        address prov = cover.getGuarantee(id).provider;
        address caller = callerSeed % 2 == 0 ? prov : actors[(callerSeed / 2) % actors.length];
        MicroCover.Status pre = cover.statusOf(id);
        vm.prank(caller);
        try cover.admitFailure(id) {
            nAdmit++;
            if (caller != prov || pre != MicroCover.Status.OPEN) _violate("admit succeeded illegitimately");
        } catch {
            if (caller == prov && pre == MicroCover.Status.OPEN) _violate("provider admit reverted");
        }
        _track();
    }

    function settle(uint256 callerSeed, uint256 idSeed, uint256 batchSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        uint32 batch = uint32(bound(batchSeed, 0, 24)); // 0 and 21..24 are invalid
        address caller = _anyCaller(callerSeed);
        MicroCover.GuaranteeState memory pre = cover.getState(id);
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        uint256 balBefore = usdc.balanceOf(address(cover));
        bool shouldWork = batch >= 1 && batch <= 20 && pre.status != MicroCover.Status.OPEN
            && pre.paidCount < pre.enrolled;

        vm.prank(caller);
        try cover.settleFailure(id, batch) returns (uint32 settled) {
            nSettle++;
            nSettledBeneficiaries += settled;
            uint32 remaining = pre.enrolled - pre.paidCount;
            if (!shouldWork) _violate("settle succeeded illegitimately");
            if (settled != (batch < remaining ? batch : remaining)) _violate("settled count wrong");
            if (balBefore - usdc.balanceOf(address(cover)) != (uint256(g.escrowAmount) + g.compensation) * settled) {
                _violate("settle moved the wrong amount");
            }
            if (cover.getState(id).paidCount != pre.paidCount + settled) _violate("paidCount mismatch");
            if (cover.statusOf(id) == MicroCover.Status.CLOSED && pre.status != MicroCover.Status.CLOSED) nClosed++;
        } catch {
            if (shouldWork) _violate("settle reverted unexpectedly");
            if (usdc.balanceOf(address(cover)) != balBefore) _violate("reverted settle moved funds");
        }
        _track();
    }

    function withdraw(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        address caller = callerSeed % 3 != 0 ? g.provider : actors[(callerSeed / 3) % actors.length];
        MicroCover.GuaranteeState memory pre = cover.getState(id);
        uint256 balBefore = usdc.balanceOf(address(cover));
        bool shouldWork = caller == g.provider && pre.status == MicroCover.Status.FAILED
            && pre.paidCount == pre.enrolled;

        vm.prank(caller);
        try cover.withdrawRemainingBond(id) returns (uint256 amount) {
            nWithdraw++;
            nClosed++;
            ghostWithdrawn[id] += amount;
            if (!shouldWork) _violate("withdraw succeeded illegitimately");
            if (amount != uint256(g.compensation) * (g.maxCohort - g.cohortSize)) _violate("leftover wrong");
            if (balBefore - usdc.balanceOf(address(cover)) != amount) _violate("withdraw balance mismatch");
        } catch {
            if (shouldWork) _violate("withdraw reverted unexpectedly");
            if (usdc.balanceOf(address(cover)) != balBefore) _violate("reverted withdraw moved funds");
        }
        _track();
    }

    function warp(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 0, 2 days));
        _track();
    }

    /// Unaccounted donations: tracked in a ghost, must never alter any guarantee's ledgers.
    function donate(uint256 amount, uint256 actorSeed) external {
        uint256 amt = bound(amount, 0, 1e9);
        if (actorSeed % 2 == 0) {
            usdc.mint(address(cover), amt);
        } else {
            vm.prank(actors[(actorSeed / 2) % actors.length]);
            usdc.transfer(address(cover), amt);
        }
        ghostDonations += amt;
        _track();
    }
}

/// forge-config: default.invariant.runs = 64
/// forge-config: default.invariant.depth = 150
contract MicroCoverInvariantTest is Test {
    MicroCover internal cover;
    MockUSDC internal usdc;
    MicroCoverHandler internal handler;

    function setUp() public {
        usdc = new MockUSDC();
        cover = new MicroCover(IERC20(address(usdc)));
        handler = new MicroCoverHandler(cover, usdc);
        targetContract(address(handler));

        // Only the action entry points; some are listed twice to weight them.
        bytes4[] memory sel = new bytes4[](12);
        sel[0] = handler.create.selector;
        sel[1] = handler.join.selector;
        sel[2] = handler.joinMany.selector;
        sel[3] = handler.joinMany.selector;
        sel[4] = handler.admit.selector;
        sel[5] = handler.settle.selector;
        sel[6] = handler.settle.selector;
        sel[7] = handler.settle.selector;
        sel[8] = handler.withdraw.selector;
        sel[9] = handler.warp.selector;
        sel[10] = handler.donate.selector;
        sel[11] = handler.create.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sel}));
    }

    /// Sanity for the harness itself: scripted sequence proves the handler reaches rich states
    /// (multi-batch settlement, partial cohort + leftover withdrawal, invalid sizes, donations).
    function test_HandlerReachesPartialCohortWithdrawal() public {
        handler.create(0, 5, 3, 50, 1 days); // actor 0 = provider; 50 slots
        handler.joinMany(1, 45, 0); // 45 synthetic users enroll
        handler.donate(1_000, 0);
        handler.settle(1, 1, 0); // invalid batch size 0: must revert, no effect
        handler.settle(1, 1, 21); // invalid
        handler.settle(1, 1, 5); // OPEN: NotFailed
        handler.admit(0, 1); // provider admits
        handler.settle(1, 1, 20);
        handler.settle(1, 1, 20);
        handler.withdraw(1, 1); // provider tries too early: LiabilitiesUnpaid
        handler.settle(1, 1, 20); // pays the last 5
        assertEq(handler.nSettledBeneficiaries(), 45);
        assertEq(handler.nSettle(), 3);
        assertEq(uint8(cover.statusOf(1)), uint8(MicroCover.Status.FAILED));
        handler.withdraw(1, 1);
        assertEq(handler.nWithdraw(), 1);
        assertEq(handler.ghostWithdrawn(1), 5 * (50 - 45));
        assertEq(uint8(cover.statusOf(1)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 1_000, "donation only");
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesFullCohortClosedByPayout() public {
        handler.create(1, 7, 4, 30, 2 days);
        handler.joinMany(1, 45, 3); // 30 join, the other 15 hit CohortFull
        assertEq(cover.getGuarantee(1).cohortSize, 30);
        handler.warp(3 days); // past the deadline
        handler.join(2, 1); // JoinDeadlinePassed (tolerated, model agrees)
        handler.admit(0, 1);
        handler.settle(2, 1, 20);
        handler.settle(3, 1, 20);
        assertEq(handler.nSettledBeneficiaries(), 30);
        assertEq(handler.nClosed(), 1);
        assertEq(uint8(cover.statusOf(1)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    /// PROPERTY: contract's USDC balance == sum(bondOf + escrowedOf) + untracked donations.
    function invariant_UsdcBalanceEqualsBondsPlusEscrowPlusDonations() public view {
        uint256 total;
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            total += cover.bondOf(id) + cover.escrowedOf(id);
        }
        assertEq(usdc.balanceOf(address(cover)), total + handler.ghostDonations());
    }

    /// PROPERTY: cohort bounded; escrow held + escrow paid out == escrowAmount * cohortSize.
    function invariant_CohortBoundedAndEscrowConsistent() public view {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            assertLe(g.cohortSize, g.maxCohort);
            assertLe(g.maxCohort, 100);
            assertEq(cover.escrowedOf(id) + s.paidEscrow, uint256(g.escrowAmount) * g.cohortSize);
        }
    }

    /// PROPERTY: per-guarantee bond/escrow/reserve conservation laws from the contract spec.
    function invariant_PerGuaranteeLedgersConserve() public view {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            uint256 withdrawn = handler.ghostWithdrawn(id);
            uint256 comp = g.compensation;

            assertEq(cover.bondOf(id) + s.paidCompensation + withdrawn, comp * g.maxCohort, "bond law");
            assertEq(cover.escrowedOf(id) + s.paidEscrow, uint256(g.escrowAmount) * g.cohortSize, "escrow law");
            assertEq(cover.reservedOf(id) + s.paidCompensation, comp * g.cohortSize, "reserve law");
            assertLe(cover.reservedOf(id), cover.bondOf(id), "reserved <= bond");
            assertLe(s.paidCount, g.cohortSize);
            assertEq(cover.beneficiaryCount(id), g.cohortSize, "beneficiaries == cohortSize");
            assertEq(s.enrolled, g.cohortSize);
            assertEq(s.paidCompensation, comp * s.paidCount, "paid compensation == comp * paidCount");
            assertEq(s.paidEscrow, uint256(g.escrowAmount) * s.paidCount);
            assertEq(s.remainingOwed, (comp + g.escrowAmount) * (g.cohortSize - s.paidCount), "remainingOwed");
            assertEq(s.bondHeld, cover.bondOf(id));
            assertEq(s.escrowHeld, cover.escrowedOf(id));
            assertEq(s.reservedCompensation, cover.reservedOf(id));
            // The provider only ever recovers the unreserved part of the bond, exactly once.
            assertEq(
                withdrawn,
                s.status == MicroCover.Status.CLOSED ? comp * (g.maxCohort - g.cohortSize) : 0,
                "withdrawn == unreserved bond iff CLOSED"
            );
        }
    }

    /// PROPERTY: lifecycle/status/outcome relationships and no terminal-state residue.
    function invariant_StatusLifecycleConsistent() public view {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            assertEq(uint8(cover.statusOf(id)), uint8(s.status));
            assertEq(uint8(cover.outcomeOf(id)), uint8(s.outcome));
            uint256 comp = g.compensation;
            if (s.status == MicroCover.Status.OPEN) {
                assertEq(s.paidCount, 0, "OPEN => nothing paid");
                assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.NONE));
                assertEq(s.failureAdmittedAt, 0);
                assertEq(s.bondHeld, comp * g.maxCohort, "OPEN bond intact");
                assertEq(s.openSlots, g.maxCohort - g.cohortSize, "openSlots from own bond");
                assertEq(s.withdrawableBond, 0);
                assertEq(
                    cover.isJoinable(id), block.timestamp <= g.joinDeadline && g.cohortSize < g.maxCohort
                );
            } else {
                assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.FAILURE));
                assertTrue(s.failureAdmittedAt != 0);
                assertEq(s.openSlots, 0);
                assertFalse(cover.isJoinable(id));
                if (s.paidCount == g.cohortSize && s.status == MicroCover.Status.FAILED) {
                    assertLt(g.cohortSize, g.maxCohort, "full + all paid must already be CLOSED");
                    assertEq(s.withdrawableBond, comp * (g.maxCohort - g.cohortSize));
                } else {
                    assertEq(s.withdrawableBond, 0);
                }
            }
            if (s.status == MicroCover.Status.CLOSED) {
                assertEq(cover.bondOf(id), 0, "CLOSED => bond 0");
                assertEq(cover.escrowedOf(id), 0, "CLOSED => escrow 0");
                assertEq(cover.reservedOf(id), 0, "CLOSED => reserved 0");
                assertEq(s.paidCount, g.cohortSize, "CLOSED => everyone paid");
            }
        }
    }

    /// PROPERTY: isPaid is true for exactly the first paidCount beneficiaries (enrollment order).
    function invariant_PaidFlagsAreAPrefixOfEnrollmentOrder() public view {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            address[] memory bens = cover.getBeneficiaries(id);
            uint32 paid = cover.getState(id).paidCount;
            for (uint256 i; i < bens.length; i++) {
                assertEq(cover.isPaid(id, bens[i]), i < paid, "paid prefix");
                assertTrue(cover.isMember(id, bens[i]));
            }
            assertFalse(cover.isPaid(id, cover.getGuarantee(id).provider), "provider is never a payee");
        }
    }

    /// PROPERTY: every call outcome matched the model (permissions, amounts, monotonic progress).
    function invariant_NoHandlerViolations() public view {
        assertEq(handler.violations(), 0, handler.firstViolation());
    }
}
