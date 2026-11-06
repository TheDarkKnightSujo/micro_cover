// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, Vm, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {MicroCover} from "../MicroCover.sol";
import {
    MockUSDC,
    BlocklistUSDC,
    OutgoingFeeUSDC,
    RecipientFeeUSDC,
    ReentrantUSDC,
    FeeOnTransferUSDC
} from "./MockUSDC.sol";
import {Phase1Base} from "./MicroCover.Phase1.t.sol";
import {FeeFromAliceUSDC} from "./MicroCover.t.sol";

/// Shared Phase 2 helpers: lifecycle stepping, exact revert helpers, accounting identities.
abstract contract Phase2Base is Phase1Base {
    // ------------------------------------------------------------ actions
    function _propose(uint256 id) internal {
        vm.prank(operator);
        cover.proposeSuccess(id);
    }

    function _uncertain(uint256 id) internal {
        vm.prank(operator);
        cover.markUncertain(id);
    }

    function _dispute(uint256 id, address who) internal {
        vm.prank(who);
        cover.raiseDispute(id);
    }

    function _finalize(uint256 id) internal {
        vm.prank(stranger);
        cover.finalizeSuccess(id);
    }

    function _release(uint256 id) internal returns (uint256 a) {
        vm.prank(stranger);
        a = cover.releaseSuccessEscrow(id);
    }

    // ------------------------------------------------------------ expected-revert helpers
    function _eInvalid(uint256 id, MicroCover.Status s) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.InvalidStatus.selector, id, s);
    }

    function _eId(bytes4 sel, uint256 id) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(sel, id);
    }

    function _eAddr(bytes4 sel, uint256 id, address who) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(sel, id, who);
    }

    function _xPropose(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.proposeSuccess(id);
    }

    function _xUncertain(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.markUncertain(id);
    }

    function _xDispute(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.raiseDispute(id);
    }

    function _xFinalize(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.finalizeSuccess(id);
    }

    function _xRelease(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.releaseSuccessEscrow(id);
    }

    function _xAdmit(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.admitFailure(id);
    }

    function _xWithdraw(address who, uint256 id, bytes memory err) internal {
        vm.prank(who);
        vm.expectRevert(err);
        cover.withdrawRemainingBond(id);
    }

    function _xSettle(uint256 id, bytes memory err) internal {
        vm.prank(stranger);
        vm.expectRevert(err);
        cover.settleFailure(id, 20);
    }

    // ------------------------------------------------------------ time stepping
    function _earliest(uint256 id) internal view returns (uint256 e) {
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        e = uint256(g.joinDeadline) + 1;
        if (g.settlementTime > e) e = g.settlementTime;
    }

    function _warpTo(uint256 ts) internal {
        if (block.timestamp < ts) vm.warp(ts);
    }

    function _ready(uint256 id) internal view returns (uint64) {
        return cover.getLifecycle(id).successReadyAt;
    }

    function _claimEnds(uint256 id) internal view returns (uint64) {
        return cover.getLifecycle(id).claimEndsAt;
    }

    function _toPending(uint256 id) internal {
        _warpTo(_earliest(id));
        _propose(id);
    }

    function _toSucceeded(uint256 id) internal {
        _toPending(id);
        vm.warp(uint256(_ready(id)) + 1);
        _finalize(id);
    }

    function _toClosedSuccess(uint256 id) internal {
        _toSucceeded(id);
        _release(id);
        _withdraw(id);
    }

    // ------------------------------------------------------------ checks
    function _baseLife(uint256 id) internal view returns (MicroCover.LifecycleView memory e) {
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        e.joinDeadline = g.joinDeadline;
        e.settlementTime = g.settlementTime;
        e.claimEndsAt = g.settlementTime + WINDOW;
        e.demoOperator = operator;
        e.reviewWindow = WINDOW;
    }

    function _checkLife(uint256 id, MicroCover.LifecycleView memory e, string memory tag) internal view {
        MicroCover.LifecycleView memory s = cover.getLifecycle(id);
        assertEq(uint8(s.status), uint8(e.status), string.concat(tag, ": L.status"));
        assertEq(uint8(s.outcome), uint8(e.outcome), string.concat(tag, ": L.outcome"));
        assertEq(s.joinDeadline, e.joinDeadline, string.concat(tag, ": L.joinDeadline"));
        assertEq(s.settlementTime, e.settlementTime, string.concat(tag, ": L.settlementTime"));
        assertEq(s.claimEndsAt, e.claimEndsAt, string.concat(tag, ": L.claimEndsAt"));
        assertEq(s.successProposedAt, e.successProposedAt, string.concat(tag, ": L.successProposedAt"));
        assertEq(s.successReadyAt, e.successReadyAt, string.concat(tag, ": L.successReadyAt"));
        assertEq(s.successFinalizedAt, e.successFinalizedAt, string.concat(tag, ": L.successFinalizedAt"));
        assertEq(s.uncertainAt, e.uncertainAt, string.concat(tag, ": L.uncertainAt"));
        assertEq(s.uncertainBy, e.uncertainBy, string.concat(tag, ": L.uncertainBy"));
        assertEq(s.successEscrowReleased, e.successEscrowReleased, string.concat(tag, ": L.escrowReleased"));
        assertEq(s.releasedSuccessReservation, e.releasedSuccessReservation, string.concat(tag, ": L.relRes"));
        assertEq(s.releasedSuccessEscrow, e.releasedSuccessEscrow, string.concat(tag, ": L.relEsc"));
        assertEq(s.withdrawnBond, e.withdrawnBond, string.concat(tag, ": L.withdrawnBond"));
        assertEq(s.demoOperator, e.demoOperator, string.concat(tag, ": L.demoOperator"));
        assertEq(s.reviewWindow, e.reviewWindow, string.concat(tag, ": L.reviewWindow"));
    }

    /// The three per-guarantee accounting identities from the contract spec.
    function _identities(uint256 id) internal view {
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        MicroCover.GuaranteeState memory s = cover.getState(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(
            cover.bondOf(id) + s.paidCompensation + l.withdrawnBond,
            uint256(g.compensation) * g.maxCohort,
            "identity: bond"
        );
        assertEq(
            cover.escrowedOf(id) + s.paidEscrow + l.releasedSuccessEscrow,
            uint256(g.escrowAmount) * g.cohortSize,
            "identity: escrow"
        );
        assertEq(
            cover.reservedOf(id) + s.paidCompensation + l.releasedSuccessReservation,
            uint256(g.compensation) * g.cohortSize,
            "identity: reserve"
        );
        assertLe(cover.reservedOf(id), cover.bondOf(id), "reserved <= bond");
    }

    /// Per-guarantee digest with no global balances, so it is stable under OTHER guarantees' activity.
    function _gdigest(uint256 id) internal view returns (bytes32) {
        address[] memory bens = cover.getBeneficiaries(id);
        bytes memory acc = abi.encode(
            cover.getState(id), cover.getLifecycle(id), cover.getGuarantee(id),
            cover.bondOf(id), cover.escrowedOf(id), cover.reservedOf(id)
        );
        for (uint256 i; i < bens.length; i++) {
            acc = abi.encode(acc, bens[i], cover.isPaid(id, bens[i]));
        }
        return keccak256(acc);
    }

    /// _snap (Phase 1 ledgers + balances) extended with the full lifecycle view.
    function _lsnap(uint256 id) internal view returns (bytes32) {
        return keccak256(abi.encode(_snap(id), cover.getLifecycle(id)));
    }

    /// Sum of bondOf + escrowedOf over every guarantee created so far.
    function _accounted() internal view returns (uint256 total) {
        for (uint256 id = 1; id < cover.nextGuaranteeId(); id++) {
            total += cover.bondOf(id) + cover.escrowedOf(id);
        }
    }

    function _approxLoose(uint256 used) internal pure returns (bool) {
        return used > 0 && used < 15_000_000;
    }
}

/// Scenarios 1-3: success reference demo, empty / partial / full cohorts.
contract Phase2ReferenceTest is Phase2Base {
    function test_EnumNumericValues() public pure {
        assertEq(uint8(MicroCover.Status.OPEN), 0);
        assertEq(uint8(MicroCover.Status.FAILED), 1);
        assertEq(uint8(MicroCover.Status.CLOSED), 2);
        assertEq(uint8(MicroCover.Status.SUCCESS_PENDING), 3);
        assertEq(uint8(MicroCover.Status.SUCCEEDED), 4);
        assertEq(uint8(MicroCover.Status.UNCERTAIN), 5);
        assertEq(uint8(MicroCover.Outcome.NONE), 0);
        assertEq(uint8(MicroCover.Outcome.FAILURE), 1);
        assertEq(uint8(MicroCover.Outcome.SUCCESS), 2);
    }

    /// (1) Reference success demo with exact balances, events and identities after every step.
    function test_Reference_SuccessDemo_ExactBalancesEventsAndIdentities() public {
        uint256 provStart = usdc.balanceOf(provider);
        address[3] memory bens = [alice, bob, carol];
        uint256[3] memory start;
        for (uint256 i; i < 3; i++) {
            start[i] = usdc.balanceOf(bens[i]);
        }

        uint256 id = _create(provider, 5e6, 2e6, 3);
        MicroCover.GuaranteeState memory e;
        e.openSlots = 3;
        e.bondHeld = 15e6;
        MicroCover.LifecycleView memory l = _baseLife(id);
        _check(id, e, "created");
        _checkLife(id, l, "created");
        _identities(id);
        assertEq(usdc.balanceOf(address(cover)), 15e6);
        assertEq(usdc.balanceOf(provider), provStart - 15e6);

        for (uint256 i; i < 3; i++) {
            _join(id, bens[i]);
            e.enrolled = uint32(i + 1);
            e.openSlots = uint32(2 - i);
            e.reservedCompensation = 5e6 * (i + 1);
            e.escrowHeld = 2e6 * (i + 1);
            e.remainingOwed = 7e6 * (i + 1);
            _check(id, e, "joined");
            _identities(id);
            assertEq(usdc.balanceOf(bens[i]), start[i] - 2e6);
        }
        _checkLife(id, l, "joined");
        assertEq(usdc.balanceOf(address(cover)), 21e6);

        // Nothing is proposable before settlement.
        vm.warp(uint256(joinDeadline) + 1);
        _xPropose(operator, id, abi.encodeWithSelector(MicroCover.ProposalTooEarly.selector, id, uint256(settlementTime)));

        vm.warp(settlementTime);
        uint64 ready = settlementTime + WINDOW;
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.SuccessProposed(id, operator, ready);
        _propose(id);
        e.status = MicroCover.Status.SUCCESS_PENDING;
        e.openSlots = 0;
        l.status = MicroCover.Status.SUCCESS_PENDING;
        l.successProposedAt = settlementTime;
        l.successReadyAt = ready;
        _check(id, e, "proposed");
        _checkLife(id, l, "proposed");
        _identities(id);
        assertEq(usdc.balanceOf(address(cover)), 21e6, "proposal moves nothing");
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE), "no verdict at proposal");

        vm.warp(ready);
        _xFinalize(stranger, id, abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, id, ready));
        vm.warp(uint256(ready) + 1);
        vm.expectEmit(true, false, false, true, address(cover));
        emit MicroCover.SuccessFinalized(id, 15e6);
        _finalize(id);
        e.status = MicroCover.Status.SUCCEEDED;
        e.outcome = MicroCover.Outcome.SUCCESS;
        e.reservedCompensation = 0;
        e.remainingOwed = 0;
        l.status = MicroCover.Status.SUCCEEDED;
        l.outcome = MicroCover.Outcome.SUCCESS;
        l.successFinalizedAt = uint64(block.timestamp);
        l.releasedSuccessReservation = 15e6;
        _check(id, e, "finalized");
        _checkLife(id, l, "finalized");
        _identities(id);
        assertEq(usdc.balanceOf(address(cover)), 21e6, "finalize moves nothing");

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.SuccessEscrowReleased(id, provider, 6e6);
        assertEq(_release(id), 6e6);
        e.escrowHeld = 0;
        e.withdrawableBond = 15e6;
        l.successEscrowReleased = true;
        l.releasedSuccessEscrow = 6e6;
        _check(id, e, "released");
        _checkLife(id, l, "released");
        _identities(id);
        assertEq(usdc.balanceOf(provider), provStart - 15e6 + 6e6, "provider got the beneficiary escrow");
        assertEq(usdc.balanceOf(address(cover)), 15e6);
        assertEq(usdc.balanceOf(stranger), START, "caller receives nothing");

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.RemainingBondWithdrawn(id, provider, 15e6);
        vm.expectEmit(true, false, false, false, address(cover));
        emit MicroCover.GuaranteeClosed(id);
        assertEq(_withdraw(id), 15e6);
        e.status = MicroCover.Status.CLOSED;
        e.bondHeld = 0;
        e.withdrawableBond = 0;
        l.status = MicroCover.Status.CLOSED;
        l.withdrawnBond = 15e6;
        _check(id, e, "closed");
        _checkLife(id, l, "closed");
        _identities(id);

        assertEq(usdc.balanceOf(address(cover)), 0, "contract fully drained");
        assertEq(usdc.balanceOf(provider), provStart + 6e6, "provider net +all beneficiary escrow");
        for (uint256 i; i < 3; i++) {
            assertEq(usdc.balanceOf(bens[i]), start[i] - 2e6, "beneficiary received nothing, out its escrow");
            assertFalse(cover.isPaid(id, bens[i]), "isPaid false on success");
        }
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS), "outcome survives CLOSED");
        assertEq(cover.getState(id).paidCount, 0);
    }

    /// (2) Zero enrollment: zero release emits the event, does no transfer, and happens once.
    function test_EmptyCohort_ZeroReleaseOnceThenFullBondWithdrawn() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 id = _create(provider, 5e6, 2e6, 3);
        _toPending(id);
        vm.warp(uint256(_ready(id)) + 1);

        vm.expectEmit(true, false, false, true, address(cover));
        emit MicroCover.SuccessFinalized(id, 0);
        _finalize(id);
        assertEq(cover.getLifecycle(id).releasedSuccessReservation, 0);
        assertEq(cover.getLifecycle(id).successEscrowReleased, false);
        _identities(id);

        vm.recordLogs();
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.SuccessEscrowReleased(id, provider, 0);
        assertEq(_release(id), 0);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 fromCover;
        for (uint256 i; i < logs.length; i++) {
            assertTrue(logs[i].emitter != address(usdc), "no token Transfer event on a zero release");
            if (logs[i].emitter == address(cover)) fromCover++;
        }
        assertEq(fromCover, 1, "only the release event");
        assertEq(usdc.balanceOf(provider), provStart - 15e6, "no transfer on zero release");
        assertEq(usdc.balanceOf(address(cover)), 15e6);
        assertTrue(cover.getLifecycle(id).successEscrowReleased);
        assertEq(cover.getLifecycle(id).releasedSuccessEscrow, 0);
        _identities(id);

        _xRelease(stranger, id, _eId(MicroCover.SuccessEscrowAlreadyReleased.selector, id));
        assertEq(cover.getState(id).withdrawableBond, 15e6);
        assertEq(_withdraw(id), 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(usdc.balanceOf(provider), provStart, "provider fully refunded");
        assertEq(usdc.balanceOf(address(cover)), 0);
        _identities(id);
        _xWithdraw(provider, id, _eId(MicroCover.NothingToWithdraw.selector, id));
    }

    /// Shared exact-balance success run for an n-member cohort.
    function _successRun(uint32 maxC, uint256 n) internal {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 bond = uint256(COMP) * maxC;
        uint256 id = _create(provider, COMP, ESC, maxC);
        _enroll(id, n);
        assertEq(usdc.balanceOf(address(cover)), bond + ESC * n);
        _toPending(id);
        vm.warp(uint256(_ready(id)) + 1);
        _finalize(id);
        _identities(id);
        assertEq(cover.reservedOf(id), 0);
        assertEq(cover.getLifecycle(id).releasedSuccessReservation, COMP * n);
        assertEq(_release(id), ESC * n);
        assertEq(usdc.balanceOf(provider), provStart - bond + ESC * n);
        assertEq(cover.getState(id).withdrawableBond, bond);
        _identities(id);
        assertEq(_withdraw(id), bond, "whole original bond returned");
        _identities(id);

        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(usdc.balanceOf(provider), provStart + ESC * n, "provider net + all escrow");
        for (uint256 i; i < n; i++) {
            assertEq(usdc.balanceOf(_user(i)), START - ESC, "beneficiary out its escrow, paid nothing");
            assertFalse(cover.isPaid(id, _user(i)));
        }
        MicroCover.GuaranteeState memory s = cover.getState(id);
        assertEq(uint8(s.status), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(s.paidCount, 0);
        assertEq(s.paidCompensation, 0);
        assertEq(s.paidEscrow, 0);
        assertEq(s.remainingOwed, 0);
        assertEq(cover.getLifecycle(id).withdrawnBond, bond);
    }

    /// (3) partial cohort, full cohort, single member, and the 100-member maximum.
    function test_Success_PartialCohortTwoOfThree() public {
        _successRun(3, 2);
    }

    function test_Success_FullCohortThreeOfThree() public {
        _successRun(3, 3);
    }

    function test_Success_SingleMember() public {
        _successRun(1, 1);
    }

    function test_Success_Full100MemberCohort() public {
        _successRun(100, 100);
    }

    function test_Success_Partial37Of100() public {
        _successRun(100, 37);
    }
}

/// Scenario 4: exact timing boundaries.
contract Phase2TimingTest is Phase2Base {
    uint64 internal constant U64MAX = type(uint64).max;

    function _createT(uint64 jd, uint64 st) internal returns (uint256 id) {
        vm.prank(provider);
        id = cover.createGuarantee(COMP, ESC, MAXC, jd, st, TERMS);
    }

    function _tooEarly(uint256 id, uint256 earliest) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.ProposalTooEarly.selector, id, earliest);
    }

    function test_Propose_SettlementEqualsDeadline_TooEarlyAtDeadline_OkAtDeadlinePlusOne() public {
        uint256 id = _createT(joinDeadline, joinDeadline);
        _join(id, alice);
        vm.warp(joinDeadline);
        _join(id, bob); // enrollment is still open at the deadline itself
        _xPropose(operator, id, _tooEarly(id, uint256(joinDeadline) + 1));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));

        vm.warp(uint256(joinDeadline) + 1);
        _propose(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(l.successProposedAt, uint256(joinDeadline) + 1);
        assertEq(l.claimEndsAt, uint256(joinDeadline) + WINDOW);
        assertEq(l.successReadyAt, uint256(joinDeadline) + 1 + WINDOW, "late by one second: full window from now");
    }

    function test_Propose_SettlementOneAfterDeadline() public {
        uint256 id = _createT(joinDeadline, joinDeadline + 1);
        vm.warp(joinDeadline);
        _xPropose(operator, id, _tooEarly(id, uint256(joinDeadline) + 1));
        vm.warp(uint256(joinDeadline) + 1);
        _propose(id);
        assertEq(_ready(id), uint256(joinDeadline) + 1 + WINDOW);
        assertEq(_ready(id), _claimEnds(id), "on-time proposal: ready == claimEndsAt");
    }

    function test_Propose_BeforeSettlement_TooEarlyReportsSettlementAsEarliest() public {
        uint256 id = _createT(joinDeadline, joinDeadline + 1000);
        uint256 st = uint256(joinDeadline) + 1000;
        vm.warp(uint256(joinDeadline) + 1);
        _xPropose(operator, id, _tooEarly(id, st));
        vm.warp(st - 1);
        _xPropose(operator, id, _tooEarly(id, st));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));

        vm.warp(st);
        _propose(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(l.successProposedAt, st);
        assertEq(l.successReadyAt, st + WINDOW);
        assertEq(l.successReadyAt, l.claimEndsAt, "exactly at settlement: ready == claimEndsAt");
    }

    function test_ReadyAt_IsMaxOfClaimEndsAndNowPlusWindow_ForManyProposalTimes() public {
        uint256[8] memory offs = [uint256(0), 1, 60, 119, 120, 121, 1 days, 400 days];
        for (uint256 i; i < offs.length; i++) {
            vm.warp(1_000_000 * (i + 1));
            joinDeadline = uint64(block.timestamp + 100);
            settlementTime = uint64(block.timestamp + 200);
            uint256 id = _create();
            vm.warp(uint256(settlementTime) + offs[i]);
            _propose(id);
            uint256 now_ = block.timestamp + WINDOW;
            uint256 expected = _claimEnds(id) > now_ ? _claimEnds(id) : now_;
            assertEq(_ready(id), expected, "ready == max(claimEndsAt, now + window)");
            assertEq(_ready(id), now_, "a proposal is never earlier than settlement, so now+window wins");
            assertGe(_ready(id), _claimEnds(id));
        }
    }

    function test_LateProposal_FullWindow_DisputePossibleExactlyAtReady_ClosedAfter() public {
        uint256 a = _create();
        uint256 b = _create();
        _join(a, alice);
        _join(b, alice);
        vm.warp(uint256(_claimEnds(a)) + 5000); // far past claimEndsAt
        _propose(a);
        _propose(b);
        uint64 ready = _ready(a);
        assertEq(ready, block.timestamp + WINDOW, "late proposal receives a full window");
        assertGt(ready, _claimEnds(a));

        vm.warp(ready);
        _dispute(a, alice);
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.UNCERTAIN));
        vm.warp(uint256(ready) + 1);
        _xDispute(alice, b, abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, b, ready));
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.SUCCESS_PENDING));
    }

    function test_Finalize_RevertsBeforeAndAtReady_SucceedsAtReadyPlusOne() public {
        uint256 id = _create();
        _join(id, alice);
        _toPending(id);
        uint64 ready = _ready(id);
        bytes memory err = abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, id, ready);
        vm.warp(ready - 1);
        _xFinalize(stranger, id, err);
        vm.warp(ready);
        bytes32 before_ = _lsnap(id);
        _xFinalize(stranger, id, err);
        assertEq(_lsnap(id), before_, "reverted finalize changed nothing");
        vm.warp(uint256(ready) + 1);
        _finalize(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
        assertEq(cover.getLifecycle(id).successFinalizedAt, uint256(ready) + 1);
    }

    function test_Dispute_Open_AtClaimEndsOk_PlusOneClosed() public {
        uint256 a = _create();
        uint256 b = _create();
        _join(a, alice);
        _join(b, alice);
        uint64 ce = _claimEnds(a);
        vm.warp(ce);
        _dispute(a, alice);
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(cover.getLifecycle(a).uncertainAt, ce);

        vm.warp(uint256(ce) + 1);
        _xDispute(alice, b, abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, b, ce));
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.OPEN), "OPEN stays OPEN");
        // The operator can still open a fresh, full review window; the beneficiary may dispute inside it.
        _propose(b);
        assertEq(_ready(b), block.timestamp + WINDOW);
        _dispute(b, alice);
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.UNCERTAIN));
    }

    function test_Dispute_Pending_AtReadyOk_PlusOneClosed_AndFinalizeStillPossible() public {
        uint256 a = _create();
        uint256 b = _create();
        _join(a, alice);
        _join(b, alice);
        _toPending(a);
        _propose(b);
        uint64 ready = _ready(a);
        vm.warp(ready);
        _dispute(a, alice);
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.UNCERTAIN));
        vm.warp(uint256(ready) + 1);
        _xDispute(alice, b, abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, b, ready));
        _finalize(b);
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.SUCCEEDED));
        // Once SUCCEEDED the dispute path is InvalidStatus, not DisputeWindowClosed.
        _xDispute(alice, b, _eInvalid(b, MicroCover.Status.SUCCEEDED));
    }

    function test_Join_AtDeadlineOk_PlusOneRevertsJoinDeadlinePassed() public {
        uint256 id = _create();
        vm.warp(joinDeadline);
        _join(id, alice);
        vm.warp(uint256(joinDeadline) + 1);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.JoinDeadlinePassed.selector, id));
        cover.joinCohort(id);
        assertEq(cover.getGuarantee(id).cohortSize, 1);
    }

    function test_CreationAtTimestampZero_SuccessPathWorks() public {
        vm.warp(0);
        uint256 provStart = usdc.balanceOf(provider);
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, ESC, MAXC, 100, 200, bytes32(0));
        _join(id, alice);
        vm.warp(200);
        _propose(id);
        assertEq(_ready(id), 200 + WINDOW);
        vm.warp(200 + WINDOW + 1);
        _finalize(id);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(_release(id), ESC);
        assertEq(_withdraw(id), uint256(COMP) * MAXC);
        assertEq(usdc.balanceOf(provider), provStart + ESC);
        assertEq(usdc.balanceOf(address(cover)), 0);
        _identities(id);
    }

    function test_ZeroTimeEdge_DeadlineOneSettlementOne() public {
        vm.warp(0);
        uint256 id = _createT(1, 1);
        vm.prank(operator);
        vm.expectRevert(_tooEarly(id, 2));
        cover.proposeSuccess(id); // at t=0
        vm.warp(1);
        _xPropose(operator, id, _tooEarly(id, 2));
        vm.warp(2);
        _propose(id);
        assertEq(cover.getLifecycle(id).successProposedAt, 2);
        assertEq(_ready(id), 2 + WINDOW);
        assertEq(_claimEnds(id), 1 + WINDOW);
        vm.warp(2 + WINDOW);
        _xFinalize(stranger, id, abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, id, uint64(2 + WINDOW)));
        vm.warp(3 + WINDOW);
        _finalize(id);
        assertEq(_release(id), 0);
        assertEq(_withdraw(id), uint256(COMP) * MAXC);
    }

    function test_SettlementPlusWindowOverflow_RevertsAtCreation() public {
        uint256 nextBefore = cover.nextGuaranteeId();
        uint256 provBefore = usdc.balanceOf(provider);
        uint64[3] memory sts = [U64MAX, U64MAX - WINDOW + 1, U64MAX - 1];
        for (uint256 i; i < sts.length; i++) {
            vm.prank(provider);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.TimestampOverflow.selector, uint256(sts[i]) + WINDOW));
            cover.createGuarantee(COMP, ESC, MAXC, joinDeadline, sts[i], TERMS);
        }
        assertEq(cover.nextGuaranteeId(), nextBefore, "no id consumed");
        assertEq(usdc.balanceOf(provider), provBefore, "no bond pulled");
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_NearMaxSettlementThatFits_Works_ButLaterProposalOverflowsAtomically() public {
        uint64 st = U64MAX - WINDOW;
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, ESC, MAXC, joinDeadline, st, TERMS);
        assertEq(_claimEnds(id), U64MAX, "claimEndsAt fits exactly");
        _join(id, alice);
        // One second late: readyAt would be U64MAX + 1.
        vm.warp(uint256(st) + 1);
        bytes32 before_ = _lsnap(id);
        _xPropose(operator, id, abi.encodeWithSelector(MicroCover.TimestampOverflow.selector, uint256(U64MAX) + 1));
        assertEq(_lsnap(id), before_, "overflowing proposal rolled back");
        // Exactly at settlement it fits: readyAt == U64MAX.
        vm.warp(st);
        _propose(id);
        assertEq(_ready(id), U64MAX);
        // Finalization needs a timestamp strictly above U64MAX, which cannot be stored: documented edge.
        vm.warp(uint256(U64MAX) + 1);
        _xFinalize(stranger, id, abi.encodeWithSelector(MicroCover.TimestampOverflow.selector, uint256(U64MAX) + 1));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        // The provider can still resolve it by admitting failure, and everyone is paid.
        _admit(id);
        assertEq(_settle(id, 20), 1);
        assertEq(_withdraw(id), uint256(COMP) * (MAXC - 1));
        assertEq(usdc.balanceOf(address(cover)), 0);
        _identities(id);
    }
}

/// Scenario 5: wrong authority.
contract Phase2AuthTest is Phase2Base {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
        _join(id, alice);
        _join(id, bob);
    }

    function test_ProposeSuccess_OnlyOperator_EvenWhenTooEarlyOrAlreadyPending() public {
        address[5] memory who = [provider, alice, stranger, address(this), address(cover)];
        // Before settlement: authority is checked before timing.
        for (uint256 i; i < who.length; i++) {
            _xPropose(who[i], id, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
        }
        _warpTo(_earliest(id));
        for (uint256 i; i < who.length; i++) {
            _xPropose(who[i], id, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
        _propose(id);
        // Already pending: authority is still checked before status.
        _xPropose(provider, id, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, provider));
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.SUCCESS_PENDING));
    }

    function test_MarkUncertain_OnlyOperator() public {
        address[4] memory who = [provider, alice, stranger, address(this)];
        for (uint256 i; i < who.length; i++) {
            _xUncertain(who[i], id, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
        }
        _toPending(id);
        for (uint256 i; i < who.length; i++) {
            _xUncertain(who[i], id, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        _uncertain(id); // control: the operator can
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.UNCERTAIN));
    }

    function test_RaiseDispute_OnlyEnrolledBeneficiaries() public {
        address[5] memory who = [stranger, provider, operator, dave, address(this)];
        for (uint256 i; i < who.length; i++) {
            _xDispute(who[i], id, _eAddr(MicroCover.NotBeneficiary.selector, id, who[i]));
        }
        // A member of ANOTHER guarantee is not a beneficiary of this one.
        uint256 other = _create(provider2, COMP, ESC, MAXC);
        _join(other, dave);
        _xDispute(dave, id, _eAddr(MicroCover.NotBeneficiary.selector, id, dave));
        _toPending(id);
        for (uint256 i; i < who.length; i++) {
            _xDispute(who[i], id, _eAddr(MicroCover.NotBeneficiary.selector, id, who[i]));
        }
        _xDispute(alice, other, _eAddr(MicroCover.NotBeneficiary.selector, other, alice));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        // Authority is checked before status, even after failure.
        _admit(id);
        _xDispute(stranger, id, _eAddr(MicroCover.NotBeneficiary.selector, id, stranger));
        _xDispute(alice, id, _eInvalid(id, MicroCover.Status.FAILED));
    }

    function test_AdmitFailure_OnlyThisGuaranteesProvider() public {
        address[5] memory who = [operator, alice, stranger, provider2, address(this)];
        for (uint256 i; i < who.length; i++) {
            _xAdmit(who[i], id, _eAddr(MicroCover.NotProvider.selector, id, who[i]));
        }
        _toPending(id);
        for (uint256 i; i < who.length; i++) {
            _xAdmit(who[i], id, _eAddr(MicroCover.NotProvider.selector, id, who[i]));
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE));
    }

    function test_Withdraw_OnlyProvider_OnBothPaths() public {
        address[4] memory who = [operator, alice, stranger, provider2];
        // OPEN: authority before status.
        for (uint256 i; i < who.length; i++) {
            _xWithdraw(who[i], id, _eAddr(MicroCover.NotProvider.selector, id, who[i]));
        }
        _toSucceeded(id);
        _release(id);
        for (uint256 i; i < who.length; i++) {
            _xWithdraw(who[i], id, _eAddr(MicroCover.NotProvider.selector, id, who[i]));
        }
        assertEq(cover.bondOf(id), 15e6, "no one but the provider moved the bond");
        assertEq(_withdraw(id), 15e6);
    }

    function test_Operator_CannotAdmitFailure_FinalizeEarly_OrMoveFunds() public {
        uint256 coverBal = usdc.balanceOf(address(cover));
        _xAdmit(operator, id, _eAddr(MicroCover.NotProvider.selector, id, operator));
        _toPending(id);
        _xAdmit(operator, id, _eAddr(MicroCover.NotProvider.selector, id, operator));
        uint64 ready = _ready(id);
        vm.warp(ready);
        _xFinalize(operator, id, abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, id, ready));
        _xRelease(operator, id, _eInvalid(id, MicroCover.Status.SUCCESS_PENDING));
        _xWithdraw(operator, id, _eAddr(MicroCover.NotProvider.selector, id, operator));
        _xSettle(id, _eInvalid(id, MicroCover.Status.SUCCESS_PENDING));
        assertEq(usdc.balanceOf(address(cover)), coverBal, "operator actions moved no funds");
        assertEq(usdc.balanceOf(operator), 0);
        // Even the operator's markUncertain moves nothing.
        _uncertain(id);
        assertEq(usdc.balanceOf(address(cover)), coverBal);
        assertEq(usdc.balanceOf(operator), 0);
        assertEq(cover.reservedOf(id), 10e6);
        assertEq(cover.escrowedOf(id), 4e6);
        assertEq(cover.bondOf(id), 15e6);
    }

    function test_OperatorDrivingAllPermissionlessCallsReceivesNothing_AndRecipientIsAlwaysProvider() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 aliceStart = usdc.balanceOf(alice);
        _toPending(id);
        vm.warp(uint256(_ready(id)) + 1);
        vm.prank(operator);
        cover.finalizeSuccess(id);
        vm.prank(operator);
        uint256 released = cover.releaseSuccessEscrow(id);
        assertEq(released, 4e6, "amount derived from the ledger, not the caller");
        assertEq(usdc.balanceOf(operator), 0, "operator receives nothing");
        assertEq(usdc.balanceOf(provider), provStart + 4e6, "recipient is always the provider");
        assertEq(usdc.balanceOf(alice), aliceStart, "beneficiary untouched");
        assertEq(usdc.balanceOf(stranger), START);
    }

    function test_UnknownGuarantee_RevertsOnEveryEntryPoint() public {
        uint256 bad = 999;
        bytes memory e = _eId(MicroCover.UnknownGuarantee.selector, bad);
        _xPropose(operator, bad, e);
        _xPropose(stranger, bad, e);
        _xUncertain(operator, bad, e);
        _xDispute(alice, bad, e);
        _xFinalize(stranger, bad, e);
        _xRelease(stranger, bad, e);
        _xAdmit(provider, bad, e);
        _xWithdraw(provider, bad, e);
        _xSettle(bad, e);
        vm.expectRevert(e);
        cover.getLifecycle(bad);
        vm.expectRevert(e);
        cover.outcomeOf(bad);
    }
}

/// Scenario 6: dispute / operator-uncertain freeze semantics.
contract Phase2DisputeTest is Phase2Base {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
    }

    /// Every action that could lead toward success (or touch funds) is blocked on an UNCERTAIN guarantee.
    function _assertFrozen(uint256 gid, string memory tag) internal {
        MicroCover.Status u = MicroCover.Status.UNCERTAIN;
        uint256 coverBal = usdc.balanceOf(address(cover));
        bytes32 before_ = _lsnap(gid);
        _xFinalize(stranger, gid, _eInvalid(gid, u));
        _xFinalize(provider, gid, _eInvalid(gid, u));
        _xRelease(stranger, gid, _eInvalid(gid, u));
        _xPropose(operator, gid, _eInvalid(gid, u));
        _xUncertain(operator, gid, _eInvalid(gid, u));
        _xDispute(alice, gid, _eInvalid(gid, u));
        _xWithdraw(provider, gid, _eInvalid(gid, u));
        _xSettle(gid, _eInvalid(gid, u));
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, gid));
        cover.joinCohort(gid);
        assertFalse(cover.isJoinable(gid), tag);
        assertEq(usdc.balanceOf(address(cover)), coverBal, tag);
        assertEq(_lsnap(gid), before_, tag);
        assertEq(uint8(cover.outcomeOf(gid)), uint8(MicroCover.Outcome.NONE), tag);
    }

    function test_Dispute_FromOpen_FreezesWithoutMovingFunds() public {
        uint256 coverBal = usdc.balanceOf(address(cover));
        vm.expectEmit(true, true, false, false, address(cover));
        emit MicroCover.DisputeRaised(id, bob);
        _dispute(id, bob);

        MicroCover.LifecycleView memory l = _baseLife(id);
        l.status = MicroCover.Status.UNCERTAIN;
        l.uncertainAt = uint64(block.timestamp);
        l.uncertainBy = bob;
        _checkLife(id, l, "disputed-open");
        MicroCover.GuaranteeState memory e;
        e.status = MicroCover.Status.UNCERTAIN;
        e.enrolled = 3;
        e.bondHeld = 15e6;
        e.reservedCompensation = 15e6;
        e.escrowHeld = 6e6;
        e.remainingOwed = 21e6;
        _check(id, e, "disputed-open");
        _identities(id);
        assertEq(usdc.balanceOf(address(cover)), coverBal, "dispute moves no funds");
        assertFalse(cover.isPaid(id, bob), "dispute does not pay the disputer");
        _assertFrozen(id, "before settlement");
        vm.warp(uint256(settlementTime) + 1000 days);
        _assertFrozen(id, "long after");
    }

    function test_Dispute_FromPending_FreezesAndClearsReadyAt() public {
        _toPending(id);
        uint64 proposedAt = uint64(block.timestamp);
        vm.warp(uint256(_ready(id)));
        vm.expectEmit(true, true, false, false, address(cover));
        emit MicroCover.DisputeRaised(id, carol);
        _dispute(id, carol);

        MicroCover.LifecycleView memory l = _baseLife(id);
        l.status = MicroCover.Status.UNCERTAIN;
        l.successProposedAt = proposedAt; // proposal history is preserved
        l.uncertainAt = uint64(block.timestamp);
        l.uncertainBy = carol;
        _checkLife(id, l, "disputed-pending");
        _identities(id);
        assertEq(cover.reservedOf(id), 15e6, "reservation untouched");
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(usdc.balanceOf(address(cover)), 21e6);
        _assertFrozen(id, "pending-disputed");
        vm.warp(block.timestamp + 365 days);
        _assertFrozen(id, "pending-disputed-later");
    }

    function test_OperatorMarkUncertain_FromOpen_AtAnyTime() public {
        uint256 other = _create();
        vm.expectEmit(true, true, false, false, address(cover));
        emit MicroCover.UncertaintyMarked(id, operator);
        _uncertain(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(l.uncertainBy, operator);
        assertEq(l.uncertainAt, block.timestamp);
        assertEq(l.successReadyAt, 0);
        _assertFrozen(id, "operator-open");

        // No time bound: far beyond the dispute window an OPEN guarantee can still be marked.
        vm.warp(uint256(_claimEnds(other)) + 700 days);
        _uncertain(other);
        assertEq(uint8(cover.statusOf(other)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(cover.getLifecycle(other).uncertainAt, block.timestamp);
    }

    function test_OperatorMarkUncertain_FromPending_IncludingAfterReadyBeforeFinalize() public {
        uint256 control = _create();
        _join(control, alice);
        _toPending(id);
        _propose(control);
        uint64 ready = _ready(id);
        vm.warp(uint256(ready) + 5000);
        // Control: an identical guarantee could have been finalized in this gap.
        _finalize(control);
        assertEq(uint8(cover.statusOf(control)), uint8(MicroCover.Status.SUCCEEDED));

        _uncertain(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(l.successReadyAt, 0);
        assertGt(l.successProposedAt, 0);
        assertEq(l.uncertainBy, operator);
        assertEq(uint8(l.outcome), uint8(MicroCover.Outcome.NONE));
        _assertFrozen(id, "operator-pending-late");
        _identities(id);
    }

    function test_OperatorMarkUncertain_BlockedOnSucceededFailedAndClosed() public {
        uint256 s = _create();
        uint256 f = _create();
        uint256 c = _create();
        _toSucceeded(s);
        _admit(f);
        _admit(c);
        _withdraw(c);
        _xUncertain(operator, s, _eInvalid(s, MicroCover.Status.SUCCEEDED));
        _xUncertain(operator, f, _eInvalid(f, MicroCover.Status.FAILED));
        _xUncertain(operator, c, _eInvalid(c, MicroCover.Status.CLOSED));
    }

    /// Provider failure admission is the only way out of UNCERTAIN; payouts are the Phase 1 failure payouts.
    function _uncertainToFailure(bool viaDispute, bool fromPending) internal {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 aStart = usdc.balanceOf(alice);
        uint256 bStart = usdc.balanceOf(bob);
        uint256 cStart = usdc.balanceOf(carol);
        if (fromPending) _toPending(id);
        if (viaDispute) _dispute(id, alice);
        else _uncertain(id);
        uint64 uAt = uint64(block.timestamp);
        address uBy = viaDispute ? alice : operator;
        _assertFrozen(id, "frozen before admission");

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.FailureAdmitted(id, provider, 3, 21e6);
        _admit(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(l.outcome), uint8(MicroCover.Outcome.FAILURE));
        assertEq(l.uncertainAt, uAt, "uncertainty history preserved");
        assertEq(l.uncertainBy, uBy);
        assertEq(l.successReadyAt, 0);
        assertEq(cover.getState(id).failureAdmittedAt, block.timestamp);
        assertEq(usdc.balanceOf(address(cover)), 21e6, "admission moves nothing");
        // Success-side calls are now dead.
        _xFinalize(stranger, id, _eInvalid(id, MicroCover.Status.FAILED));
        _xRelease(stranger, id, _eInvalid(id, MicroCover.Status.FAILED));
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.FAILED));

        assertEq(_settle(id, 20), 3);
        _identities(id);
        assertEq(usdc.balanceOf(alice), aStart + 7e6, "failure payout: escrow back + compensation");
        assertEq(usdc.balanceOf(bob), bStart + 7e6);
        assertEq(usdc.balanceOf(carol), cStart + 7e6);
        assertEq(usdc.balanceOf(provider), provStart, "bond (already paid at creation) fully consumed by payouts");
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(cover.getLifecycle(id).releasedSuccessReservation, 0);
        assertEq(cover.getLifecycle(id).releasedSuccessEscrow, 0);
        assertTrue(cover.isPaid(id, alice) && cover.isPaid(id, bob) && cover.isPaid(id, carol));
    }

    function test_UncertainResolvedByProviderFailure_DisputeFromOpen() public {
        _uncertainToFailure(true, false);
    }

    function test_UncertainResolvedByProviderFailure_DisputeFromPending() public {
        _uncertainToFailure(true, true);
    }

    function test_UncertainResolvedByProviderFailure_OperatorFromOpen() public {
        _uncertainToFailure(false, false);
    }

    function test_UncertainResolvedByProviderFailure_OperatorFromPending() public {
        _uncertainToFailure(false, true);
    }

    function test_Dispute_DoesNotSelectPayouts_PartialCohortFailureLeavesUnreservedBond() public {
        uint256 other = _create();
        _join(other, alice);
        _join(other, bob);
        uint256 provStart = usdc.balanceOf(provider);
        uint256 aStart = usdc.balanceOf(alice);
        uint256 bStart = usdc.balanceOf(bob);
        _dispute(other, bob); // bob disputes; alice does not
        _admit(other);
        assertEq(_settle(other, 20), 2);
        assertEq(usdc.balanceOf(alice) - aStart, 7e6, "alice gross payout == bob gross payout");
        assertEq(usdc.balanceOf(bob) - bStart, 7e6, "disputer gets no premium");
        assertEq(_withdraw(other), 5e6, "unreserved third slot returned");
        assertEq(usdc.balanceOf(provider), provStart + 5e6 - 0);
        _identities(other);
        _identities(id);
    }

    function test_DisputeAfterDispute_DoesNotChangeOriginalDisputer() public {
        _dispute(id, alice);
        _xDispute(bob, id, _eInvalid(id, MicroCover.Status.UNCERTAIN));
        assertEq(cover.getLifecycle(id).uncertainBy, alice);
        _xUncertain(operator, id, _eInvalid(id, MicroCover.Status.UNCERTAIN));
        assertEq(cover.getLifecycle(id).uncertainBy, alice);
    }
}

/// Scenario 7: success and failure are mutually exclusive; duplicate / out-of-order calls.
contract Phase2IncompatTest is Phase2Base {
    uint256 internal id;

    function setUp() public override {
        super.setUp();
        id = _create();
        _join(id, alice);
        _join(id, bob);
    }

    function _failureFlowFromHere() internal {
        uint256 provBefore = usdc.balanceOf(provider);
        uint256 aBefore = usdc.balanceOf(alice);
        uint256 bBefore = usdc.balanceOf(bob);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(_ready(id), 0, "failure clears successReadyAt");
        assertEq(_settle(id, 20), 2);
        _identities(id);
        assertEq(usdc.balanceOf(alice), aBefore + 7e6);
        assertEq(usdc.balanceOf(bob), bBefore + 7e6);
        assertEq(cover.getState(id).withdrawableBond, 5e6);
        assertEq(_withdraw(id), 5e6);
        _identities(id);
        assertEq(usdc.balanceOf(provider), provBefore + 5e6);
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(l.releasedSuccessReservation, 0);
        assertEq(l.releasedSuccessEscrow, 0);
        assertFalse(l.successEscrowReleased);
        assertEq(l.successFinalizedAt, 0);
    }

    function test_AdmitFromPending_BeforeReady_ThenFullFailureSettlement() public {
        _toPending(id);
        vm.warp(uint256(_ready(id)) - 30);
        _admit(id);
        assertEq(cover.getLifecycle(id).successProposedAt, _claimEnds(id) - WINDOW, "proposal history kept");
        _failureFlowFromHere();
    }

    function test_AdmitFromPending_AfterReady_BeforeFinalize_ThenFullFailureSettlement() public {
        _toPending(id);
        vm.warp(uint256(_ready(id)) + 10 days);
        // Control: finalization would have been possible right now.
        assertGt(block.timestamp, _ready(id));
        _admit(id);
        _xFinalize(stranger, id, _eInvalid(id, MicroCover.Status.FAILED));
        _failureFlowFromHere();
    }

    function test_AdmitFromOpen_LongAfterClaimWindow_StillWorks() public {
        vm.warp(uint256(_claimEnds(id)) + 3 days);
        _admit(id);
        _failureFlowFromHere();
    }

    function test_AdmitAfterFinalize_RevertsSuccessAlreadyFinalized_InEverySuccessState() public {
        bytes memory err = _eId(MicroCover.SuccessAlreadyFinalized.selector, id);
        _toSucceeded(id);
        _xAdmit(provider, id, err);
        _release(id);
        _xAdmit(provider, id, err);
        _withdraw(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        _xAdmit(provider, id, err);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS), "verdict unchanged");
    }

    function test_AfterFailure_SuccessSideCallsRevertInvalidStatus_FailedAndClosed() public {
        _admit(id);
        MicroCover.Status f = MicroCover.Status.FAILED;
        _xPropose(operator, id, _eInvalid(id, f));
        _xFinalize(stranger, id, _eInvalid(id, f));
        _xRelease(stranger, id, _eInvalid(id, f));
        _xUncertain(operator, id, _eInvalid(id, f));
        _xDispute(alice, id, _eInvalid(id, f));
        _xAdmit(provider, id, _eId(MicroCover.AlreadyAdmitted.selector, id));
        vm.warp(uint256(_claimEnds(id)) + 1 days);
        _xPropose(operator, id, _eInvalid(id, f));

        _settle(id, 20);
        _withdraw(id);
        MicroCover.Status c = MicroCover.Status.CLOSED;
        assertEq(uint8(cover.statusOf(id)), uint8(c));
        _xPropose(operator, id, _eInvalid(id, c));
        _xFinalize(stranger, id, _eInvalid(id, c));
        _xRelease(stranger, id, _eInvalid(id, c));
        _xUncertain(operator, id, _eInvalid(id, c));
        _xDispute(alice, id, _eInvalid(id, c));
        _xAdmit(provider, id, _eId(MicroCover.AlreadyAdmitted.selector, id));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_Duplicates_ProposeFinalizeReleaseWithdraw() public {
        _toPending(id);
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.SUCCESS_PENDING));
        vm.warp(uint256(_ready(id)) + 1);
        _finalize(id);
        _xFinalize(stranger, id, _eInvalid(id, MicroCover.Status.SUCCEEDED));
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.SUCCEEDED));
        assertEq(_release(id), 4e6);
        _xRelease(stranger, id, _eId(MicroCover.SuccessEscrowAlreadyReleased.selector, id));
        assertEq(_withdraw(id), 15e6);
        // CLOSED: status gate fires before the already-released flag.
        MicroCover.Status c = MicroCover.Status.CLOSED;
        _xRelease(stranger, id, _eInvalid(id, c));
        _xFinalize(stranger, id, _eInvalid(id, c));
        _xPropose(operator, id, _eInvalid(id, c));
        _xWithdraw(provider, id, _eId(MicroCover.NothingToWithdraw.selector, id));
        assertEq(usdc.balanceOf(address(cover)), 0);
        _identities(id);
    }

    function test_Release_BeforeFinalize_OnUncertain_OnFailed_OnOpen_Revert() public {
        uint256 pend = _create();
        uint256 unc = _create();
        uint256 fail = _create();
        _toPending(pend);
        _uncertain(unc);
        _admit(fail);
        _xRelease(stranger, id, _eInvalid(id, MicroCover.Status.OPEN));
        _xRelease(stranger, pend, _eInvalid(pend, MicroCover.Status.SUCCESS_PENDING));
        _xRelease(stranger, unc, _eInvalid(unc, MicroCover.Status.UNCERTAIN));
        _xRelease(stranger, fail, _eInvalid(fail, MicroCover.Status.FAILED));
        assertFalse(cover.getLifecycle(pend).successEscrowReleased);
    }

    function test_Withdraw_StatusMatrix() public {
        uint256 pend = _create();
        uint256 unc = _create();
        uint256 suc = _create();
        _join(pend, alice);
        _join(suc, alice);
        _toPending(pend);
        _uncertain(unc);
        _toSucceeded(suc);
        _xWithdraw(provider, id, _eId(MicroCover.NotFailed.selector, id));
        _xWithdraw(provider, pend, _eInvalid(pend, MicroCover.Status.SUCCESS_PENDING));
        _xWithdraw(provider, unc, _eInvalid(unc, MicroCover.Status.UNCERTAIN));
        _xWithdraw(provider, suc, _eId(MicroCover.SuccessEscrowNotReleased.selector, suc));
        assertEq(cover.bondOf(suc), 15e6);
        assertEq(cover.getState(suc).withdrawableBond, 0, "not withdrawable before escrow release");
        _release(suc);
        assertEq(cover.getState(suc).withdrawableBond, 15e6);
        assertEq(_withdraw(suc), 15e6);
    }

    function test_SettleFailure_OnNonFailureGuarantees_RevertsAndPaysNobody() public {
        uint256 pend = _create();
        uint256 unc = _create();
        uint256 suc = _create();
        uint256 clo = _create();
        uint256 open = _create();
        uint256[5] memory all = [pend, unc, suc, clo, open];
        for (uint256 i; i < all.length; i++) {
            _join(all[i], alice);
            _join(all[i], bob);
        }
        _toPending(pend);
        _uncertain(unc);
        _toSucceeded(suc);
        _toClosedSuccess(clo);

        uint256 coverBal = usdc.balanceOf(address(cover));
        uint256 aliceBal = usdc.balanceOf(alice);
        _xSettle(open, _eId(MicroCover.NotFailed.selector, open));
        _xSettle(pend, _eInvalid(pend, MicroCover.Status.SUCCESS_PENDING));
        _xSettle(unc, _eInvalid(unc, MicroCover.Status.UNCERTAIN));
        _xSettle(suc, _eInvalid(suc, MicroCover.Status.SUCCEEDED));
        _release(suc);
        _xSettle(suc, _eInvalid(suc, MicroCover.Status.SUCCEEDED));
        _xSettle(clo, _eInvalid(clo, MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(alice), aliceBal, "no one paid");
        assertEq(usdc.balanceOf(address(cover)), coverBal - 4e6, "only the legitimate escrow release left");
        for (uint256 i; i < all.length; i++) {
            assertFalse(cover.isPaid(all[i], alice));
            assertFalse(cover.isPaid(all[i], bob));
            assertEq(cover.getState(all[i]).paidCount, 0);
            assertEq(cover.getState(all[i]).paidCompensation, 0);
            assertEq(cover.getState(all[i]).paidEscrow, 0);
            _identities(all[i]);
        }
    }

    function test_GetState_SuccessSemantics() public {
        MicroCover.GuaranteeState memory s = cover.getState(id);
        assertEq(s.remainingOwed, 14e6, "OPEN: prospective obligation");
        _toPending(id);
        s = cover.getState(id);
        assertEq(s.remainingOwed, 14e6, "pending: no verdict, still prospective");
        assertEq(s.withdrawableBond, 0);
        vm.warp(uint256(_ready(id)) + 1);
        _finalize(id);
        s = cover.getState(id);
        assertEq(s.remainingOwed, 0, "SUCCESS verdict: nothing owed");
        assertEq(s.withdrawableBond, 0, "escrow not yet released");
        assertEq(s.reservedCompensation, 0);
        assertEq(s.bondHeld, 15e6);
        assertEq(s.escrowHeld, 4e6);
        _release(id);
        s = cover.getState(id);
        assertEq(s.withdrawableBond, 15e6);
        assertEq(s.remainingOwed, 0);
        _withdraw(id);
        s = cover.getState(id);
        assertEq(s.withdrawableBond, 0);
        assertEq(s.remainingOwed, 0);
        assertEq(uint8(s.status), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(s.openSlots, 0);
    }
}

/// Scenario 8: several simultaneous guarantees in different states never affect each other.
contract Phase2IsolationTest is Phase2Base {
    uint256[5] internal ids; // A OPEN, B SUCCESS_PENDING, C UNCERTAIN, D FAILED, E SUCCESS_PENDING
    bytes32[5] internal dig;

    function setUp() public override {
        super.setUp();
        address[5] memory provs = [provider, provider2, makeAddr("p3"), makeAddr("p4"), makeAddr("p5")];
        for (uint256 i; i < 5; i++) {
            if (i >= 2) _fundProvider(provs[i]);
            ids[i] = _create(provs[i], COMP, ESC, MAXC);
            _join(ids[i], _user(0));
            _join(ids[i], _user(1));
        }
        vm.warp(settlementTime);
        _propose(ids[1]);
        _uncertain(ids[2]);
        _admit(ids[3]);
        _propose(ids[4]);
    }

    function _snapAllExcept(uint256 skip) internal {
        for (uint256 i; i < 5; i++) {
            if (i != skip) dig[i] = _gdigest(ids[i]);
        }
    }

    function _assertOthersSame(uint256 skip, string memory tag) internal view {
        for (uint256 i; i < 5; i++) {
            if (i != skip) assertEq(_gdigest(ids[i]), dig[i], tag);
        }
        assertEq(usdc.balanceOf(address(cover)), _accounted(), tag);
    }

    function test_FinalizeReleaseWithdrawOneGuarantee_LeavesOthersUntouched() public {
        uint256 e = 4;
        vm.warp(uint256(_ready(ids[e])) + 1);
        _snapAllExcept(e);
        _finalize(ids[e]);
        _assertOthersSame(e, "after finalize E");
        assertEq(_release(ids[e]), 4e6);
        _assertOthersSame(e, "after release E");
        assertEq(_withdraw(ids[e]), 15e6);
        _assertOthersSame(e, "after withdraw E");

        assertEq(uint8(cover.statusOf(ids[0])), uint8(MicroCover.Status.OPEN));
        assertEq(uint8(cover.statusOf(ids[1])), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(uint8(cover.statusOf(ids[2])), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(uint8(cover.statusOf(ids[3])), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(cover.statusOf(ids[4])), uint8(MicroCover.Status.CLOSED));
        // B shares E's timing but still needs its own finalization.
        _snapAllExcept(1);
        _finalize(ids[1]);
        _assertOthersSame(1, "after finalize B");
        // Failure settlement of D does not disturb the success guarantees.
        _snapAllExcept(3);
        assertEq(_settle(ids[3], 20), 2);
        _assertOthersSame(3, "after settle D");
        assertEq(_withdraw(ids[3]), 5e6);
        _assertOthersSame(3, "after withdraw D");
        for (uint256 i; i < 5; i++) {
            _identities(ids[i]);
        }
    }

    function test_AdmitOnePendingGuarantee_LeavesSiblingPendingFinalizable() public {
        _snapAllExcept(1);
        _admit(ids[1]);
        _assertOthersSame(1, "after admit B");
        vm.warp(uint256(_ready(ids[4])) + 1);
        _finalize(ids[4]);
        assertEq(uint8(cover.statusOf(ids[4])), uint8(MicroCover.Status.SUCCEEDED));
        assertEq(uint8(cover.statusOf(ids[1])), uint8(MicroCover.Status.FAILED));
        // B (failed) pays out exactly its own liabilities, E keeps its own ledgers.
        assertEq(_settle(ids[1], 20), 2);
        assertEq(cover.escrowedOf(ids[4]), 4e6);
        assertEq(cover.bondOf(ids[4]), 15e6);
        assertEq(usdc.balanceOf(address(cover)), _accounted());
    }

    function test_WrongProviderCannotTouchAnotherGuaranteesSuccessFunds() public {
        vm.warp(uint256(_ready(ids[4])) + 1);
        _finalize(ids[4]);
        _release(ids[4]);
        _xWithdraw(provider, ids[4], _eAddr(MicroCover.NotProvider.selector, ids[4], provider));
        _xWithdraw(provider2, ids[4], _eAddr(MicroCover.NotProvider.selector, ids[4], provider2));
        assertEq(cover.bondOf(ids[4]), 15e6);
    }

    function test_Donations_NeverBecomeWithdrawableOrCapacity_OnSuccessPath() public {
        usdc.mint(address(cover), 333e6); // unaccounted donation
        uint256 e = 4;
        vm.warp(uint256(_ready(ids[e])) + 1);
        _finalize(ids[e]);
        assertEq(_release(ids[e]), 4e6, "release is exactly the ledger escrow");
        address p5 = _providerOf(ids[e]);
        uint256 p5Before = usdc.balanceOf(p5);
        assertEq(_withdraw(ids[e]), 15e6, "withdrawal is exactly the ledger bond");
        assertEq(usdc.balanceOf(p5) - p5Before, 15e6);
        assertEq(usdc.balanceOf(address(cover)), _accounted() + 333e6, "donation stays unaccounted");
        assertEq(cover.getLifecycle(ids[e]).withdrawnBond, 15e6);
        _identities(ids[e]);
    }

    function test_Donations_DoNotCreateJoinCapacity() public {
        vm.warp(1); // rewind so a fresh guarantee (default deadlines) can be created
        uint256 one = _create(provider, COMP, ESC, 1);
        usdc.mint(address(cover), 1000e6);
        _join(one, alice);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, one));
        cover.joinCohort(one);
        assertFalse(cover.isJoinable(one));
        assertEq(cover.bondOf(one), COMP);
    }
}

/// Shared fixture for token-fault suites: a 3-member guarantee finalized as success.
abstract contract Phase2FaultBase is Phase2Base {
    function _threeFinalized() internal returns (uint256 id) {
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _toSucceeded(id);
    }

    function _assertUnreleased(uint256 id) internal view {
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertFalse(l.successEscrowReleased, "flag unchanged");
        assertEq(l.releasedSuccessEscrow, 0);
        assertEq(l.withdrawnBond, 0);
        assertEq(uint8(l.status), uint8(MicroCover.Status.SUCCEEDED), "status unchanged");
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(usdc.balanceOf(address(cover)), 21e6);
    }
}

/// Scenario 9a: a blocklisted provider makes success release / withdrawal revert atomically.
contract Phase2BlocklistTest is Phase2FaultBase {
    BlocklistUSDC internal bl;

    function _deployToken() internal override returns (MockUSDC) {
        bl = new BlocklistUSDC();
        return bl;
    }

    function test_Release_ProviderBlocked_AtomicRevertThenSucceedsAfterUnblock() public {
        uint256 id = _threeFinalized();
        uint256 provBefore = usdc.balanceOf(provider);
        bl.setBlocked(provider, true);
        bytes32 before_ = _lsnap(id);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, provider));
        cover.releaseSuccessEscrow(id);
        assertEq(_lsnap(id), before_, "every ledger/flag/status/balance unchanged");
        _assertUnreleased(id);
        _identities(id);
        _xWithdraw(provider, id, _eId(MicroCover.SuccessEscrowNotReleased.selector, id));

        bl.setBlocked(provider, false);
        assertEq(_release(id), 6e6);
        assertEq(usdc.balanceOf(provider), provBefore + 6e6);
        assertTrue(cover.getLifecycle(id).successEscrowReleased);
        _identities(id);
    }

    function test_Withdraw_ProviderBlocked_AtomicRevertThenSucceedsAfterUnblock() public {
        uint256 id = _threeFinalized();
        _release(id);
        uint256 provBefore = usdc.balanceOf(provider);
        bl.setBlocked(provider, true);
        bytes32 before_ = _lsnap(id);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, provider));
        cover.withdrawRemainingBond(id);
        assertEq(_lsnap(id), before_);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(cover.getLifecycle(id).withdrawnBond, 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
        assertEq(cover.getState(id).withdrawableBond, 15e6);
        assertEq(usdc.balanceOf(address(cover)), 15e6);

        bl.setBlocked(provider, false);
        assertEq(_withdraw(id), 15e6);
        assertEq(usdc.balanceOf(provider), provBefore + 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        _identities(id);
    }

    function test_BlockedBeneficiary_CannotStallTheSuccessPath() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        bl.setBlocked(alice, true);
        _toClosedSuccess(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }
}

/// Scenario 9b: tokens that short-change the recipient.
contract Phase2RecipientFeeTest is Phase2FaultBase {
    RecipientFeeUSDC internal rf;

    function _deployToken() internal override returns (MockUSDC) {
        rf = new RecipientFeeUSDC();
        return rf;
    }

    function test_Release_RecipientFee_IncorrectRecipientReceipt_FullRollback() public {
        uint256 id = _threeFinalized();
        uint256 provBefore = usdc.balanceOf(provider);
        bytes32 before_ = _lsnap(id);
        rf.configure(address(cover), address(0), true); // toggled only after the guarantee is funded
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, provider, 6e6, provBefore, provBefore + 5.4e6)
        );
        cover.releaseSuccessEscrow(id);
        assertEq(_lsnap(id), before_);
        _assertUnreleased(id);

        rf.configure(address(cover), address(0), false);
        assertEq(_release(id), 6e6);
        assertEq(usdc.balanceOf(provider), provBefore + 6e6);
    }

    function test_Withdraw_RecipientFee_IncorrectRecipientReceipt_FullRollback() public {
        uint256 id = _threeFinalized();
        _release(id);
        uint256 provBefore = usdc.balanceOf(provider);
        bytes32 before_ = _lsnap(id);
        rf.configure(address(cover), address(0), true);
        vm.prank(provider);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, provider, 15e6, provBefore, provBefore + 13.5e6)
        );
        cover.withdrawRemainingBond(id);
        assertEq(_lsnap(id), before_);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
        assertEq(cover.getLifecycle(id).withdrawnBond, 0);

        rf.configure(address(cover), address(0), false);
        assertEq(_withdraw(id), 15e6);
        assertEq(usdc.balanceOf(provider), provBefore + 15e6);
    }
}

/// Scenario 9c: tokens that debit the contract by a different amount than requested.
contract Phase2OutgoingFeeTest is Phase2FaultBase {
    OutgoingFeeUSDC internal ft;

    function _deployToken() internal override returns (MockUSDC) {
        ft = new OutgoingFeeUSDC();
        return ft;
    }

    function test_Release_ShortAndExtra_IncorrectUsdcSent_FullRollback() public {
        uint256 id = _threeFinalized();
        bytes32 before_ = _lsnap(id);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.SHORT); // only 5.4e6 leaves
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 6e6, 21e6, 15.6e6));
        cover.releaseSuccessEscrow(id);
        assertEq(_lsnap(id), before_);
        _assertUnreleased(id);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.EXTRA); // 6e6 + 0.6e6 burn leaves
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 6e6, 21e6, 14.4e6));
        cover.releaseSuccessEscrow(id);
        assertEq(_lsnap(id), before_);
        _assertUnreleased(id);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        assertEq(_release(id), 6e6);
        _identities(id);
    }

    function test_Withdraw_ShortAndExtra_IncorrectUsdcSent_FullRollback() public {
        uint256 id = _threeFinalized();
        _release(id);
        usdc.mint(address(cover), 10e6); // donation so the EXTRA burn is affordable
        bytes32 before_ = _lsnap(id);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.SHORT);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 15e6, 25e6, 11.5e6));
        cover.withdrawRemainingBond(id);
        assertEq(_lsnap(id), before_);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.EXTRA);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 15e6, 25e6, 8.5e6));
        cover.withdrawRemainingBond(id);
        assertEq(_lsnap(id), before_);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        assertEq(_withdraw(id), 15e6);
        assertEq(usdc.balanceOf(address(cover)), 10e6, "only the donation remains");
    }
}

/// Scenario 9d: inbound fee-on-transfer tokens are still rejected; the success path is unaffected for others.
contract Phase2InboundFeeTest is Phase2Base {
    function _deployToken() internal override returns (MockUSDC) {
        return new FeeFromAliceUSDC(alice);
    }

    function test_JoinWithInboundFee_RevertsAndLeavesNoTrace_OthersStillSucceed() public {
        uint256 id = _create();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcReceived.selector, ESC, 15e6, 15e6 + 1.8e6));
        cover.joinCohort(id);
        assertFalse(cover.isMember(id, alice));
        assertEq(cover.escrowedOf(id), 0);
        assertEq(cover.reservedOf(id), 0);
        _join(id, bob);
        _toClosedSuccess(id);
        assertEq(usdc.balanceOf(address(cover)), 0);
        _identities(id);
    }

    function test_FullFeeOnTransferToken_CannotEvenCreate() public {
        FeeOnTransferUSDC fee = new FeeOnTransferUSDC();
        MicroCover c = new MicroCover(IERC20(address(fee)), operator, WINDOW);
        fee.mint(provider, 1_000e6);
        vm.startPrank(provider);
        fee.approve(address(c), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcReceived.selector, 15e6, 0, 13.5e6));
        c.createGuarantee(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS);
        vm.stopPrank();
        assertEq(c.nextGuaranteeId(), 1);
    }
}

/// Scenario 10: reentrant token callbacks during success release / withdrawal.
contract Phase2ReentrancyTest is Phase2Base {
    ReentrantUSDC internal rt;
    uint256 internal t0;
    uint256 internal constant N_PAYLOADS = 10;

    function _deployToken() internal override returns (MockUSDC) {
        rt = new ReentrantUSDC();
        return rt;
    }

    function setUp() public override {
        super.setUp();
        t0 = block.timestamp;
    }

    function _reentry() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    }

    function _payload(uint256 k, uint256 id) internal view returns (bytes memory) {
        if (k == 0) return abi.encodeCall(MicroCover.finalizeSuccess, (id));
        if (k == 1) return abi.encodeCall(MicroCover.releaseSuccessEscrow, (id));
        if (k == 2) return abi.encodeCall(MicroCover.withdrawRemainingBond, (id));
        if (k == 3) return abi.encodeCall(MicroCover.proposeSuccess, (id));
        if (k == 4) return abi.encodeCall(MicroCover.raiseDispute, (id));
        if (k == 5) return abi.encodeCall(MicroCover.admitFailure, (id));
        if (k == 6) return abi.encodeCall(MicroCover.settleFailure, (id, 1));
        if (k == 7) return abi.encodeCall(MicroCover.joinCohort, (id));
        if (k == 8) return abi.encodeCall(MicroCover.markUncertain, (id));
        return abi.encodeCall(MicroCover.createGuarantee, (COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS));
    }

    /// Fresh 3-member guarantee finalized as success (time reset so creation is always allowed).
    function _freshFinalized() internal returns (uint256 id) {
        vm.warp(t0);
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _toSucceeded(id);
    }

    function test_Control_CallbackReallyExecutesDuringRelease() public {
        uint256 id = _freshFinalized();
        rt.arm(address(cover), abi.encodeCall(MicroCover.getLifecycle, (id)), false);
        _release(id);
        assertEq(rt.reentries(), 1, "callback fired once for the single outgoing transfer");
        assertTrue(rt.lastOk(), "read-only callbacks are allowed");
    }

    function test_ReentryDuringRelease_Bubbled_RollsEverythingBack() public {
        for (uint256 k; k < N_PAYLOADS; k++) {
            uint256 id = _freshFinalized();
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _lsnap(id);
            vm.prank(stranger);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.releaseSuccessEscrow(id);
            assertEq(_lsnap(id), before_, "ledgers unchanged");
            assertFalse(cover.getLifecycle(id).successEscrowReleased);
            rt.disarm();
            assertEq(_release(id), 6e6, "guard released after the revert");
        }
    }

    function test_ReentryDuringRelease_Swallowed_NoDoublePaymentLedgersConsistent() public {
        for (uint256 k; k < N_PAYLOADS; k++) {
            uint256 id = _freshFinalized();
            uint256 provBefore = usdc.balanceOf(provider);
            uint256 aliceBefore = usdc.balanceOf(alice);
            uint256 nextId = cover.nextGuaranteeId();
            rt.arm(address(cover), _payload(k, id), false);
            assertEq(_release(id), 6e6);
            rt.disarm();
            assertEq(rt.reentries(), 1);
            assertFalse(rt.lastOk(), "re-entry rejected");
            assertEq(rt.lastRet(), _reentry());
            assertEq(usdc.balanceOf(provider) - provBefore, 6e6, "provider paid exactly once");
            assertEq(usdc.balanceOf(alice), aliceBefore, "no beneficiary payment");
            assertEq(cover.nextGuaranteeId(), nextId, "no guarantee created by re-entry");
            assertEq(cover.escrowedOf(id), 0);
            assertEq(cover.bondOf(id), 15e6);
            assertEq(cover.getLifecycle(id).releasedSuccessEscrow, 6e6);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
            _identities(id);
            _xRelease(stranger, id, _eId(MicroCover.SuccessEscrowAlreadyReleased.selector, id));
        }
    }

    function test_ReentryDuringWithdraw_Bubbled_RollsEverythingBack() public {
        for (uint256 k; k < N_PAYLOADS; k++) {
            uint256 id = _freshFinalized();
            _release(id);
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _lsnap(id);
            vm.prank(provider);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.withdrawRemainingBond(id);
            assertEq(_lsnap(id), before_);
            assertEq(cover.bondOf(id), 15e6);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
            rt.disarm();
            assertEq(_withdraw(id), 15e6);
        }
    }

    function test_ReentryDuringWithdraw_Swallowed_PaidExactlyOnce() public {
        for (uint256 k; k < N_PAYLOADS; k++) {
            uint256 id = _freshFinalized();
            _release(id);
            uint256 provBefore = usdc.balanceOf(provider);
            uint256 coverBefore = usdc.balanceOf(address(cover));
            uint256 nextId = cover.nextGuaranteeId();
            rt.arm(address(cover), _payload(k, id), false);
            assertEq(_withdraw(id), 15e6);
            rt.disarm();
            assertEq(rt.reentries(), 1);
            assertFalse(rt.lastOk());
            assertEq(rt.lastRet(), _reentry());
            assertEq(usdc.balanceOf(provider) - provBefore, 15e6, "paid exactly once");
            assertEq(coverBefore - usdc.balanceOf(address(cover)), 15e6);
            assertEq(cover.nextGuaranteeId(), nextId);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
            assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
            assertEq(cover.getLifecycle(id).withdrawnBond, 15e6);
            _identities(id);
        }
    }

    function test_ReentryDuringJoinAndCreatePulls_AllSuccessSideEntryPointsBlocked() public {
        vm.warp(t0);
        uint256 id = _create();
        for (uint256 k; k < N_PAYLOADS; k++) {
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _lsnap(id);
            vm.prank(alice);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.joinCohort(id);
            assertEq(_lsnap(id), before_);
            vm.prank(provider);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.createGuarantee(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS);
            assertEq(cover.nextGuaranteeId(), id + 1);
        }
        rt.disarm();
    }
}

/// Scenario 11: gas observations (cohort of 100, fresh transactions after setUp).
contract Phase2GasTest is Phase2Base {
    uint256 internal pend;
    uint256 internal succ;
    uint256 internal rel;
    uint256 internal prop;

    function setUp() public override {
        super.setUp();
        pend = _create(provider, COMP, ESC, 100);
        succ = _create(provider, COMP, ESC, 100);
        rel = _create(provider, COMP, ESC, 100);
        prop = _create(provider2, COMP, ESC, 100);
        _enroll(pend, 100);
        _enroll(succ, 100);
        _enroll(rel, 100);
        _enroll(prop, 100);
        vm.warp(settlementTime);
        _propose(pend);
        _propose(succ);
        _propose(rel);
        vm.warp(uint256(_ready(pend)) + 1);
        _finalize(succ);
        _finalize(rel);
        _release(rel);
    }

    function test_Gas_FinalizeSuccess_On100Cohort() public {
        vm.prank(stranger);
        uint256 g0 = gasleft();
        cover.finalizeSuccess(pend);
        uint256 used = g0 - gasleft();
        console2.log("gas finalizeSuccess (100-member cohort):", used);
        assertTrue(_approxLoose(used), "sanity bound only");
        assertEq(uint8(cover.statusOf(pend)), uint8(MicroCover.Status.SUCCEEDED));
    }

    function test_Gas_ReleaseSuccessEscrow_On100Cohort() public {
        vm.prank(stranger);
        uint256 g0 = gasleft();
        uint256 amount = cover.releaseSuccessEscrow(succ);
        uint256 used = g0 - gasleft();
        console2.log("gas releaseSuccessEscrow (100-member cohort):", used);
        assertEq(amount, 200e6);
        assertTrue(_approxLoose(used), "sanity bound only");
    }

    function test_Gas_WithdrawRemainingBond_OnSuccess_100Cohort() public {
        vm.prank(provider);
        uint256 g0 = gasleft();
        uint256 amount = cover.withdrawRemainingBond(rel);
        uint256 used = g0 - gasleft();
        console2.log("gas withdrawRemainingBond on success (100-member cohort):", used);
        assertEq(amount, 500e6);
        assertTrue(_approxLoose(used), "sanity bound only");
        assertEq(uint8(cover.statusOf(rel)), uint8(MicroCover.Status.CLOSED));
    }

    function test_Gas_ProposeSuccess_And_RaiseDispute() public {
        uint256 id = prop;
        vm.prank(operator);
        uint256 g0 = gasleft();
        cover.proposeSuccess(id);
        uint256 used = g0 - gasleft();
        console2.log("gas proposeSuccess (100-member cohort):", used);
        assertTrue(_approxLoose(used));
        vm.prank(_user(7));
        g0 = gasleft();
        cover.raiseDispute(id);
        used = g0 - gasleft();
        console2.log("gas raiseDispute (100-member cohort):", used);
        assertTrue(_approxLoose(used));
    }
}

/// Scenario 12: fuzzing paths, amounts, cohort sizes and timings.
contract Phase2FuzzTest is Phase2Base {
    uint32 internal fMax;
    uint32 internal fN;
    uint128 internal fComp;
    uint128 internal fEsc;
    address internal fProv;
    uint256 internal fId;

    function _fCreateAndEnroll() internal {
        fProv = makeAddr("fuzzProvider");
        usdc.mint(fProv, uint256(fComp) * fMax);
        vm.prank(fProv);
        usdc.approve(address(cover), type(uint256).max);
        fId = _create(fProv, fComp, fEsc, fMax);
        for (uint256 i; i < fN; i++) {
            address u = _user(i);
            usdc.mint(u, fEsc); // beneficiary starts with exactly its escrow
            vm.startPrank(u);
            usdc.approve(address(cover), fEsc);
            cover.joinCohort(fId);
            vm.stopPrank();
        }
    }

    /// Single-guarantee solvency + the three identities, valid in every state.
    function _fStep(string memory tag) internal view {
        _identities(fId);
        assertEq(
            usdc.balanceOf(address(cover)),
            cover.bondOf(fId) + cover.escrowedOf(fId),
            string.concat(tag, ": solvent")
        );
    }

    function _fSuccess(uint256 t1, uint256 t2) internal {
        vm.warp(_earliest(fId) + bound(t1, 0, 3000));
        _propose(fId);
        _fStep("proposed");
        assertEq(_ready(fId), block.timestamp + WINDOW);
        vm.warp(uint256(_ready(fId)) + 1 + bound(t2, 0, 3000));
        _finalize(fId);
        _fStep("finalized");
        assertEq(cover.reservedOf(fId), 0);
        assertEq(cover.getLifecycle(fId).releasedSuccessReservation, uint256(fComp) * fN);
        assertEq(_release(fId), uint256(fEsc) * fN);
        _fStep("released");
        assertEq(_withdraw(fId), uint256(fComp) * fMax, "whole original bond");
        _fStep("closed");

        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(usdc.balanceOf(fProv), uint256(fComp) * fMax + uint256(fEsc) * fN, "provider keeps all escrow");
        for (uint256 i; i < fN; i++) {
            assertEq(usdc.balanceOf(_user(i)), 0, "beneficiary lost its escrow, got nothing");
            assertFalse(cover.isPaid(fId, _user(i)));
        }
        assertEq(uint8(cover.outcomeOf(fId)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(cover.getState(fId).paidCount, 0);
    }

    function _fSettleAndWithdraw(uint256 batchSeed) internal {
        assertEq(uint8(cover.outcomeOf(fId)), uint8(MicroCover.Outcome.FAILURE));
        uint32 paid;
        uint256 iter;
        while (paid < fN) {
            uint32 req = uint32(uint256(keccak256(abi.encode(batchSeed, iter))) % 20 + 1);
            uint32 got = _settle(fId, req);
            paid += got;
            iter++;
            _fStep("settling");
        }
        if (fN < fMax) {
            assertEq(_withdraw(fId), uint256(fComp) * (fMax - fN), "leftover is the unreserved bond");
        }
        _fStep("failure closed");
        assertEq(uint8(cover.statusOf(fId)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(usdc.balanceOf(fProv), uint256(fComp) * (fMax - fN), "provider net -compensation * enrolled");
        for (uint256 i; i < fN; i++) {
            assertEq(usdc.balanceOf(_user(i)), uint256(fEsc) + fComp, "escrow back + compensation");
        }
        MicroCover.LifecycleView memory l = cover.getLifecycle(fId);
        assertEq(l.releasedSuccessReservation, 0);
        assertEq(l.releasedSuccessEscrow, 0);
        assertFalse(l.successEscrowReleased);
    }

    function _fFailurePath(uint256 path, uint256 t1, uint256 t2) internal {
        if (path == 1) {
            // dispute -> failure (from OPEN or from SUCCESS_PENDING, depending on t1)
            if (t1 % 2 == 0) {
                vm.warp(_earliest(fId) + bound(t1, 0, 3000));
                _propose(fId);
            }
            if (fN > 0) _dispute(fId, _user(bound(t2, 0, fN - 1)));
            else _uncertain(fId);
        } else if (path == 2) {
            // operator uncertain -> failure (from OPEN at any time, or from SUCCESS_PENDING after ready)
            if (t1 % 2 == 0) {
                vm.warp(_earliest(fId) + bound(t1, 0, 3000));
                _propose(fId);
                vm.warp(uint256(_ready(fId)) + bound(t2, 0, 3000));
            } else {
                vm.warp(block.timestamp + bound(t2, 0, 30 days));
            }
            _uncertain(fId);
        } else if (path == 3) {
            vm.warp(block.timestamp + bound(t1, 0, 30 days)); // direct failure, any time
        } else {
            // success pending -> failure, before or after the review window, never finalized
            vm.warp(_earliest(fId) + bound(t1, 0, 3000));
            _propose(fId);
            vm.warp(block.timestamp + bound(t2, 0, 2 * uint256(WINDOW)));
        }
        _fStep("pre-admit");
        assertEq(uint8(cover.outcomeOf(fId)), uint8(MicroCover.Outcome.NONE));
        _admit(fId);
        _fStep("admitted");
    }

    /// forge-config: default.fuzz.runs = 120
    function testFuzz_RandomPath_ConservationAndIdentities(
        uint256 maxSeed,
        uint256 nSeed,
        uint256 compSeed,
        uint256 escSeed,
        uint256 pathSeed,
        uint256 t1,
        uint256 t2,
        uint256 batchSeed
    ) public {
        fMax = uint32(bound(maxSeed, 1, 100));
        fN = uint32(bound(nSeed, 0, fMax));
        fComp = uint128(bound(compSeed, 1, 1e9));
        fEsc = uint128(bound(escSeed, 1, 1e9));
        _fCreateAndEnroll();
        assertEq(usdc.balanceOf(address(cover)), uint256(fComp) * fMax + uint256(fEsc) * fN);
        _fStep("created");

        uint256 path = pathSeed % 5;
        if (path == 0) {
            _fSuccess(t1, t2);
        } else {
            _fFailurePath(path, t1, t2);
            _fSettleAndWithdraw(batchSeed);
        }
    }

    /// forge-config: default.fuzz.runs = 200
    function testFuzz_ProposalBoundary_AroundEarliestTimestamp(uint256 gapSeed, uint256 kSeed) public {
        uint64 gap = uint64(bound(gapSeed, 0, 4));
        uint64 k = uint64(bound(kSeed, 0, 8));
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, ESC, MAXC, joinDeadline, joinDeadline + gap, TERMS);
        uint256 earliest = uint256(joinDeadline) + 1;
        if (joinDeadline + gap > earliest) earliest = joinDeadline + gap;
        uint256 t = uint256(joinDeadline) + k;
        vm.warp(t);
        if (t >= earliest) {
            _propose(id);
            assertEq(_ready(id), t + WINDOW);
            assertEq(cover.getLifecycle(id).successProposedAt, t);
        } else {
            _xPropose(operator, id, abi.encodeWithSelector(MicroCover.ProposalTooEarly.selector, id, earliest));
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
        }
        // Enrollment is inclusive of the deadline and closed right after, independent of the proposal.
        if (t <= joinDeadline) {
            _join(id, alice);
        } else if (t >= earliest) {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, id));
            cover.joinCohort(id);
        } else {
            vm.prank(alice);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.JoinDeadlinePassed.selector, id));
            cover.joinCohort(id);
        }
    }

    /// forge-config: default.fuzz.runs = 200
    function testFuzz_FinalizeAndDisputeBoundary_AroundReadyAt(uint256 lateSeed, uint256 dSeed) public {
        uint256 a = _create();
        uint256 b = _create();
        _join(a, alice);
        _join(b, alice);
        vm.warp(_earliest(a) + bound(lateSeed, 0, 5000));
        _propose(a);
        _propose(b);
        uint64 ready = _ready(a);
        assertEq(ready, block.timestamp + WINDOW);
        uint256 t = uint256(ready) - 3 + bound(dSeed, 0, 6);
        vm.warp(t);
        bytes memory disputeErr = abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, a, ready);
        bytes memory finalizeErr = abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, b, ready);
        if (t <= ready) _dispute(a, alice);
        else _xDispute(alice, a, disputeErr);
        if (t > ready) _finalize(b);
        else _xFinalize(stranger, b, finalizeErr);
        assertEq(
            uint8(cover.statusOf(a)),
            uint8(t <= ready ? MicroCover.Status.UNCERTAIN : MicroCover.Status.SUCCESS_PENDING)
        );
        assertEq(
            uint8(cover.statusOf(b)),
            uint8(t > ready ? MicroCover.Status.SUCCEEDED : MicroCover.Status.SUCCESS_PENDING)
        );
        // Exactly one of {dispute accepted, finalize accepted} is possible at any instant.
        assertTrue((t <= ready) != (t > ready));
    }

    /// forge-config: default.fuzz.runs = 150
    function testFuzz_OpenDisputeBoundary_AroundClaimEndsAt(uint256 dSeed) public {
        uint256 id = _create();
        _join(id, alice);
        uint64 ce = _claimEnds(id);
        uint256 t = uint256(ce) - 3 + bound(dSeed, 0, 6);
        vm.warp(t);
        if (t <= ce) {
            _dispute(id, alice);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.UNCERTAIN));
        } else {
            _xDispute(alice, id, abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, id, ce));
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
        }
    }
}
