// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Test.sol";
import {MicroCover} from "../MicroCover.sol";
import {Phase3Base} from "./MicroCover.Phase3.t.sol";

/// Scenario D: evidence FAILURE establishes failure without any provider action.
contract Phase3EvidenceFailureTest is Phase3Base {
    uint256 internal id;
    uint64 internal S;

    function setUp() public override {
        super.setUp();
        id = _bound3();
        S = cover.getGuarantee(id).settlementTime;
    }

    function _failureChecks(uint256 gid, uint32 enrolled) internal view {
        MicroCover.EvidenceState memory e = _ev(gid);
        MicroCover.GuaranteeState memory s = cover.getState(gid);
        assertEq(uint8(s.status), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.FAILURE));
        assertEq(e.failureOrigin, 2, "origin EVIDENCE");
        assertEq(s.failureAdmittedAt, 0, "no provider admission timestamp");
        assertEq(cover.getLifecycle(gid).successReadyAt, 0);
        assertEq(s.enrolled, enrolled);
        assertEq(s.paidCount, 0);
        assertEq(e.refundedCount, 0);
        assertEq(e.lastReportOutcome, 1);
    }

    function _fail(uint256 gid) internal returns (Vm.Log[] memory logs) {
        _anchorNext(gid);
        MicroCover.EvidenceReport memory r = _repNow(gid, 1);
        vm.recordLogs();
        _submit(r);
        logs = vm.getRecordedLogs();
    }

    function _paysOut3() internal {
        uint256 a = usdc.balanceOf(alice);
        uint256 b = usdc.balanceOf(bob);
        uint256 c = usdc.balanceOf(carol);
        uint256 p = usdc.balanceOf(provider);
        assertEq(_settle(id, 20), 3);
        assertEq(usdc.balanceOf(alice), a + 7e6);
        assertEq(usdc.balanceOf(bob), b + 7e6);
        assertEq(usdc.balanceOf(carol), c + 7e6);
        assertEq(usdc.balanceOf(provider), p, "bond fully consumed; provider unchanged");
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertTrue(cover.isPaid(id, alice) && cover.isPaid(id, bob) && cover.isPaid(id, carol));
        assertEq(cover.getState(id).paidCount, 3);
        assertFalse(cover.isRefunded(id, alice));
        assertEq(_ev(id).refundedCount, 0);
        _id3(id);
    }

    function test_D_FromOpen_ExactlyAtSettlementTime() public {
        vm.warp(S);
        bytes32 root = _anchorNext(id);
        MicroCover.EvidenceReport memory r = _repNow(id, 1);
        uint256 bal = usdc.balanceOf(address(cover));
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.EvidenceFailureEstablished(id, root, 1, S, 3, 21e6);
        _submit(r);
        _failureChecks(id, 3);
        assertEq(usdc.balanceOf(address(cover)), bal, "establishing failure moves no tokens");
        assertEq(cover.reservedOf(id), 15e6);
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(_ev(id).verdictNonce, 1);
        _paysOut3();
    }

    function test_D_FromOpen_LongAfterSettlement_NoFailureAdmittedEvent() public {
        vm.warp(uint256(S) + 1 days);
        Vm.Log[] memory logs = _fail(id);
        assertEq(_hasTopic(logs, MicroCover.FailureAdmitted.selector), 0, "FailureAdmitted must not fire");
        assertEq(_hasTopic(logs, MicroCover.EvidenceFailureEstablished.selector), 1);
        assertEq(_hasTopic(logs, MicroCover.SuccessProposed.selector), 0);
        _failureChecks(id, 3);
        _paysOut3();
    }

    function test_D_FromSuccessPending() public {
        vm.warp(S);
        _verdict(id, 2);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        uint64 proposedAt = cover.getLifecycle(id).successProposedAt;
        vm.warp(block.timestamp + 30);
        Vm.Log[] memory logs = _fail(id);
        assertEq(_hasTopic(logs, MicroCover.FailureAdmitted.selector), 0);
        _failureChecks(id, 3);
        assertEq(cover.getLifecycle(id).successProposedAt, proposedAt, "proposal history preserved");
        assertEq(_ev(id).verdictNonce, 2);
        _paysOut3();
    }

    function test_D_FromSuccessPending_AfterReviewDeadlinePassedButNotFinalized() public {
        vm.warp(S);
        _verdict(id, 2);
        vm.warp(uint256(_ready(id)) + 500);
        _fail(id);
        _failureChecks(id, 3);
        _paysOut3();
    }

    function test_D_FromUncertain_BeforeTimeout_PreservesUncertaintyHistory() public {
        _dispute(id, bob);
        uint64 since = _ev(id).uncertainSince;
        uint64 ready = _readyU(id);
        vm.warp(ready - 1);
        Vm.Log[] memory logs = _fail(id);
        assertEq(_hasTopic(logs, MicroCover.FailureAdmitted.selector), 0);
        _failureChecks(id, 3);
        assertEq(_ev(id).uncertainSince, since);
        assertEq(_readyU(id), ready);
        assertEq(cover.getLifecycle(id).uncertainBy, bob);
        _paysOut3();
    }

    function test_D_EmptyCohort_FailureThenFullBondWithdrawal() public {
        uint256 e = _createB();
        vm.warp(S);
        _fail(e);
        _failureChecks(e, 0);
        assertEq(cover.getState(e).remainingOwed, 0);
        uint256 p = usdc.balanceOf(provider);
        vm.prank(provider);
        assertEq(cover.withdrawRemainingBond(e), BOND_);
        assertEq(usdc.balanceOf(provider), p + BOND_);
        assertEq(uint8(cover.statusOf(e)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(e)), uint8(MicroCover.Outcome.FAILURE));
        _id3(e);
    }

    uint256 internal constant BOND_ = uint256(COMP) * MAXC;

    function test_D_PartialCohort_SettleThenLeftoverBond() public {
        uint256 pc = _createB();
        _join(pc, alice);
        _join(pc, bob);
        vm.warp(S);
        _fail(pc);
        _failureChecks(pc, 2);
        uint256 a = usdc.balanceOf(alice);
        uint256 b = usdc.balanceOf(bob);
        vm.prank(stranger);
        assertEq(cover.settleFailure(pc, 1), 1);
        assertEq(usdc.balanceOf(alice), a + 7e6);
        assertEq(usdc.balanceOf(bob), b);
        assertTrue(cover.isPaid(pc, alice));
        assertFalse(cover.isPaid(pc, bob));
        vm.prank(stranger);
        assertEq(cover.settleFailure(pc, 20), 1);
        assertEq(usdc.balanceOf(bob), b + 7e6);
        assertEq(cover.getState(pc).paidCount, 2);
        assertEq(_ev(pc).refundedCount, 0);
        _id3(pc);
        uint256 p = usdc.balanceOf(provider);
        vm.prank(provider);
        assertEq(cover.withdrawRemainingBond(pc), COMP, "unreserved third slot returned");
        assertEq(usdc.balanceOf(provider), p + COMP);
        assertEq(uint8(cover.statusOf(pc)), uint8(MicroCover.Status.CLOSED));
        _id3(pc);
    }

    function test_D_ProviderAdmitAfterEvidenceFailure_AlreadyAdmitted_EvenAfterClose() public {
        vm.warp(S);
        _fail(id);
        _xAdmit(provider, id, _eId(MicroCover.AlreadyAdmitted.selector, id));
        _paysOut3();
        _xAdmit(provider, id, _eId(MicroCover.AlreadyAdmitted.selector, id));
        assertEq(_ev(id).failureOrigin, 2, "origin never rewritten");
    }

    function test_D_EvidenceVerdictAfterProviderAdmission_Rejected_ProviderOriginRecorded() public {
        vm.warp(S + 5);
        _anchorNext(id);
        MicroCover.EvidenceReport memory r = _repNow(id, 1);
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.FailureAdmitted(id, provider, 3, 21e6);
        _admit(id);
        MicroCover.EvidenceState memory e = _ev(id);
        assertEq(e.failureOrigin, 1, "origin PROVIDER");
        assertEq(cover.getState(id).failureAdmittedAt, block.timestamp);
        assertGt(cover.getState(id).failureAdmittedAt, 0);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.InvalidStatus.selector, id, MicroCover.Status.FAILED));
        assertEq(_ev(id).failureOrigin, 1);
        assertEq(_ev(id).verdictNonce, 0);
    }

    function test_D_ProviderAdmission_RecordsOriginFromOpenPendingUncertain_AndManual() public {
        uint256 m = _create();
        _admit(m);
        assertEq(_ev(m).failureOrigin, 1);
        assertEq(cover.getState(m).failureAdmittedAt, block.timestamp);

        uint256 u = _bound3();
        _dispute(u, alice);
        vm.warp(block.timestamp + 10);
        _admit(u);
        assertEq(_ev(u).failureOrigin, 1);
        assertEq(cover.getState(u).failureAdmittedAt, block.timestamp);

        uint256 pend = _bound3();
        _toPending(pend);
        _admit(pend);
        assertEq(_ev(pend).failureOrigin, 1);
        assertEq(_ev(pend).lastReportOutcome, 2, "prior success evidence remains historical; admission adds no evidence verdict");
        assertEq(_ev(pend).verdictNonce, 1);
        assertEq(_ev(id).failureOrigin, 0, "untouched guarantee still NONE");
        _id3(m);
        _id3(u);
        _id3(pend);
    }

    function test_D_EvidenceFailureCannotBeDoubleEstablished_NorFollowedByDispute() public {
        vm.warp(S);
        _fail(id);
        _anchorNotAllowed();
        _xDispute(alice, id, _eInvalid(id, MicroCover.Status.FAILED));
        _xUncertain(operator, id, _eInvalid(id, MicroCover.Status.FAILED));
        vm.prank(stranger);
        vm.expectRevert(_eInvalid(id, MicroCover.Status.FAILED));
        cover.finalizeUnresolved(id);
        _xFinalize(stranger, id, _eInvalid(id, MicroCover.Status.FAILED));
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.FAILED));
        _xRefund(id, 20, _eInvalid(id, MicroCover.Status.FAILED));
    }

    function _anchorNotAllowed() internal {
        MicroCover.EvidenceState memory ev = _ev(id);
        _xAnchor(operator, id, ROOT2, ev.policyHash, ev.cohortId, ev.nextAnchorNonce, _eInvalid(id, MicroCover.Status.FAILED));
    }
}

/// Scenario E: evidence SUCCESS starts a full review; it never finalizes by itself.
contract Phase3EvidenceSuccessTest is Phase3Base {
    uint256 internal id;
    uint64 internal S;

    function setUp() public override {
        super.setUp();
        id = _bound3();
        S = cover.getGuarantee(id).settlementTime;
    }

    function test_E_FromOpen_AtSettlementTime_FullReview_ExactValues_Events() public {
        vm.warp(S);
        bytes32 root = _anchorNext(id);
        MicroCover.EvidenceReport memory r = _repNow(id, 2);
        uint256 bal = usdc.balanceOf(address(cover));
        uint64 ready = S + 120; // max(claimEndsAt = S + 120, now + 120)
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.SuccessProposed(id, operator, ready);
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.EvidenceSuccessReported(id, root, 1, S, ready);
        _submit(r);

        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(uint8(l.outcome), uint8(MicroCover.Outcome.NONE), "no final outcome yet");
        assertEq(l.successProposedAt, S);
        assertEq(l.successReadyAt, ready);
        assertEq(l.claimEndsAt, ready);
        assertEq(l.successFinalizedAt, 0);
        assertEq(usdc.balanceOf(address(cover)), bal, "no money moves");
        assertEq(cover.reservedOf(id), 15e6, "reservations unchanged");
        assertEq(cover.bondOf(id), 15e6);
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(l.releasedSuccessReservation, 0);
        assertEq(_ev(id).failureOrigin, 0);
        assertEq(_ev(id).lastReportOutcome, 2);
        _id3(id);
    }

    function test_E_FromOpen_LateReport_ReviewStartsFromNow_NotClaimEnd() public {
        vm.warp(uint256(S) + 5000);
        _verdict(id, 2);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(l.successReadyAt, S + 5000 + 120, "a late report still gets a full review window");
        assertEq(l.claimEndsAt, S + 120);
        assertEq(l.successProposedAt, S + 5000);
    }

    function test_E_FromOpen_NeverBeforeSettlement() public {
        vm.warp(S - 1);
        _anchorNext(id);
        MicroCover.EvidenceReport memory r = _repNow(id, 2);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceTooEarly.selector, S - 1, S));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
    }

    function test_E_JoinDeadlineInclusiveCutoff_SettlementEqualsJoinDeadline() public {
        uint64 jd = uint64(block.timestamp + 1 days);
        vm.prank(provider);
        uint256 g = cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, jd, jd, TERMS, POLICY, keccak256("eq"));
        _join(g, alice);
        vm.warp(jd);
        _anchorNext(g);
        MicroCover.EvidenceReport memory r = _repNow(g, 2);
        // At joinDeadline joins are still allowed, so success may not close enrollment yet.
        _xSubmit(r, abi.encodeWithSelector(MicroCover.ProposalTooEarly.selector, g, uint256(jd) + 1));
        assertEq(_ev(g).verdictNonce, 0);
        _join(g, bob);
        vm.warp(uint256(jd) + 1);
        _anchorNext(g);
        r = _repNow(g, 2);
        _submit(r);
        assertEq(uint8(cover.statusOf(g)), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(cover.getLifecycle(g).successReadyAt, jd + 1 + 120);
        assertEq(cover.getLifecycle(g).claimEndsAt, jd + 120);
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, g));
        cover.joinCohort(g);
    }

    function test_E_FailureAtJoinDeadlineIsNotSubjectToCutoff() public {
        uint64 jd = uint64(block.timestamp + 1 days);
        vm.prank(provider);
        uint256 g = cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, jd, jd, TERMS, POLICY, keccak256("eq2"));
        _join(g, alice);
        vm.warp(jd);
        _verdict(g, 1);
        assertEq(uint8(cover.statusOf(g)), uint8(MicroCover.Status.FAILED));
    }

    function test_E_FromUncertain_BeforeTimeout_ResolvesToFullReview_KeepsFirstTimer() public {
        _dispute(id, alice);
        uint64 since = _ev(id).uncertainSince;
        uint64 uready = _readyU(id);
        vm.warp(uint256(S) + 77);
        _verdict(id, 2);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(uint8(l.outcome), uint8(MicroCover.Outcome.NONE));
        assertEq(l.successReadyAt, S + 77 + 120);
        assertEq(l.uncertainAt, since);
        assertEq(l.uncertainBy, alice);
        assertEq(_ev(id).uncertainSince, since);
        assertEq(_readyU(id), uready, "first uncertainty deadline preserved");
        assertTrue(_ev(id).uncertaintyStarted);
        _id3(id);
    }

    function test_E_DisputePossibleExactlyAtReadyAt_NotAfter() public {
        uint256 g = _bound3(); // create before advancing past the join deadline
        vm.warp(S);
        _verdict(id, 2);
        uint64 ready = _ready(id);
        vm.warp(ready);
        uint256 other = id;
        _dispute(other, bob); // exactly at readyAt is still inside the window
        assertEq(uint8(cover.statusOf(other)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(cover.getLifecycle(other).successReadyAt, 0);

        // A second guarantee: one second later the window is closed.
        vm.warp(S + 1000);
        // g has the same settlement time, so reuse the same clock.
        _verdict(g, 2);
        uint64 gReady = _ready(g);
        vm.warp(uint256(gReady) + 1);
        _xDispute(bob, g, abi.encodeWithSelector(MicroCover.DisputeWindowClosed.selector, g, gReady));
    }

    function test_E_FinalizeStrictlyAfterReadyAt_ThenReleaseAndBondWithdraw() public {
        vm.warp(S);
        _verdict(id, 2);
        uint64 ready = _ready(id);
        vm.warp(ready);
        _xFinalize(stranger, id, abi.encodeWithSelector(MicroCover.ReviewWindowOpen.selector, id, ready));
        vm.warp(uint256(ready) + 1);
        uint256 bal = usdc.balanceOf(address(cover));
        _finalize(id);
        assertEq(usdc.balanceOf(address(cover)), bal, "finalize moves no tokens");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(cover.reservedOf(id), 0);
        assertEq(cover.getLifecycle(id).releasedSuccessReservation, 15e6);
        _id3(id);
        uint256 p = usdc.balanceOf(provider);
        assertEq(_release(id), 6e6);
        assertEq(usdc.balanceOf(provider), p + 6e6);
        assertEq(_withdraw(id), 15e6);
        assertEq(usdc.balanceOf(provider), p + 21e6);
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(cover.getState(id).paidCount, 0);
        assertEq(_ev(id).refundedCount, 0);
        _id3(id);
    }

    function test_E_RepeatedAnchorsAndVerdicts_NeverResetOrExtendTheReview() public {
        vm.warp(S);
        _verdict(id, 2);
        uint64 ready = _ready(id);
        uint64 proposedAt = cover.getLifecycle(id).successProposedAt;
        for (uint256 i; i < 3; i++) {
            vm.warp(block.timestamp + 20);
            _anchorNext(id);
            assertEq(_ready(id), ready);
            MicroCover.EvidenceReport memory r = _repNow(id, 2);
            _xSubmit(r, abi.encodeWithSelector(MicroCover.InvalidStatus.selector, id, MicroCover.Status.SUCCESS_PENDING));
            assertEq(_ready(id), ready, "no extension");
            assertEq(cover.getLifecycle(id).successProposedAt, proposedAt);
        }
        _xPropose(operator, id, _eInvalid(id, MicroCover.Status.SUCCESS_PENDING));
        vm.warp(uint256(ready) + 1);
        _finalize(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCEEDED));
    }

    function test_E_BoundGuaranteeCannotBypassEvidenceWithManualProposal() public {
        vm.warp(S);
        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EvidenceReportRequired.selector, id));
        cover.proposeSuccess(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
    }

    function test_E_SuccessThenDisputeThenSuccessAgain_StartsAnotherFullReview() public {
        vm.warp(S);
        _verdict(id, 2);
        vm.warp(block.timestamp + 10);
        _dispute(id, carol);
        uint64 uready = _readyU(id);
        vm.warp(block.timestamp + 10);
        _verdict(id, 2);
        assertEq(cover.getLifecycle(id).successReadyAt, block.timestamp + 120);
        assertEq(_readyU(id), uready);
        assertEq(_ev(id).verdictNonce, 2);
    }
}
