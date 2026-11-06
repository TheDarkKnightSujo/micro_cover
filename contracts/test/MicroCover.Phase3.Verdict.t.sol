// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MicroCover} from "../MicroCover.sol";
import {Phase3Base} from "./MicroCover.Phase3.t.sol";

/// Scenario C: submitEvidenceVerdict authorization, domain, nonce, timing and status rules.
contract Phase3VerdictTest is Phase3Base {
    uint256 internal id;
    uint256 internal other; // second bound guarantee, never anchored
    uint256 internal manual; // manual-demo guarantee
    uint64 internal S; // settlementTime

    function setUp() public override {
        super.setUp();
        id = _bound3();
        other = _createB();
        manual = _create();
        S = cover.getGuarantee(id).settlementTime;
        vm.warp(S);
        _anchor(id, ROOT1, 1);
    }

    function _ok(uint8 outcome) internal view returns (MicroCover.EvidenceReport memory) {
        return _repNow(id, outcome);
    }

    function _eStatus(MicroCover.Status s) internal view returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.InvalidStatus.selector, id, s);
    }

    function _eNonce(uint256 expected, uint256 got) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.InvalidNonce.selector, expected, got);
    }

    function _unchanged() internal view returns (bytes32) {
        return _esnap(id);
    }

    // ------------------------------------------------------------ authorization
    function test_C_OnlyOperator_ProviderBeneficiaryStrangerRejected() public {
        MicroCover.EvidenceReport memory r = _ok(1);
        address[5] memory who = [provider, alice, bob, stranger, address(this)];
        bytes32 h = _unchanged();
        for (uint256 i; i < who.length; i++) {
            vm.prank(who[i]);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
            cover.submitEvidenceVerdict(r);
        }
        assertEq(_unchanged(), h);
        _submit(r); // the very same report from the operator is accepted
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
    }

    function test_C_UnknownGuarantee_ChecksIdBeforeOperator() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        r.guaranteeId = 99;
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.submitEvidenceVerdict(r); // a stranger, still UnknownGuarantee first
        _xSubmit(r, abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
    }

    // ------------------------------------------------------------ domain
    function test_C_WrongChain_WrongConsumer() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        r.chainId = block.chainid + 1;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.WrongChain.selector, block.chainid, block.chainid + 1));
        r.chainId = 0;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.WrongChain.selector, block.chainid, 0));
        r = _ok(2);
        r.consumer = address(0);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.WrongConsumer.selector, address(0)));
        r.consumer = address(usdc);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.WrongConsumer.selector, address(usdc)));
        // Chain is checked before consumer.
        r.chainId = 1234;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.WrongChain.selector, block.chainid, 1234));
    }

    function test_C_WrongGuaranteeCohortPolicy_BindingMismatch() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        bytes memory err = abi.encodeWithSelector(MicroCover.EvidenceBindingMismatch.selector, id);
        r.cohortId = keccak256("other-cohort");
        _xSubmit(r, err);
        r = _ok(2);
        r.policyHash = keccak256("other-policy");
        _xSubmit(r, err);
        r = _ok(2);
        r.cohortId = bytes32(0);
        _xSubmit(r, err);
        r = _ok(2);
        r.policyHash = bytes32(0);
        _xSubmit(r, err);
        // Report for guarantee A pointed at guarantee B's id: B's cohort differs.
        r = _ok(2);
        r.guaranteeId = other;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceBindingMismatch.selector, other));
        // Same policy but B's cohort and A's id: A's cohort differs.
        r = _ok(2);
        r.cohortId = _ev(other).cohortId;
        _xSubmit(r, err);
        // Binding is checked before the root.
        r = _ok(2);
        r.cohortId = keccak256("other-cohort");
        r.evidenceRoot = ROOT2;
        _xSubmit(r, err);
    }

    function test_C_RootMustBeTheLatestNonzeroAnchor() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evidenceRoot = bytes32(0);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceRootMismatch.selector, id, ROOT1, bytes32(0)));
        r.evidenceRoot = ROOT2;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceRootMismatch.selector, id, ROOT1, ROOT2));
        _anchor(id, ROOT2, 2);
        r.evidenceRoot = ROOT1; // superseded anchor
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceRootMismatch.selector, id, ROOT2, ROOT1));
        r.evidenceRoot = ROOT2;
        _submit(r);
        assertEq(_ev(id).verdictNonce, 1);
    }

    function test_C_NoAnchorAtAll_RootMismatchEvenForZeroRoot() public {
        MicroCover.EvidenceReport memory r = _rep(other, 2, ROOT1, 1, uint64(block.timestamp), uint64(block.timestamp));
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceRootMismatch.selector, other, bytes32(0), ROOT1));
        r.evidenceRoot = bytes32(0);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceRootMismatch.selector, other, bytes32(0), bytes32(0)));
    }

    function test_C_InvalidEvidenceOutcome_ZeroThreeAndAbove() public {
        uint8[5] memory bad = [0, 3, 4, 100, 255];
        for (uint256 i; i < bad.length; i++) {
            MicroCover.EvidenceReport memory r = _ok(bad[i]);
            _xSubmit(r, abi.encodeWithSelector(MicroCover.InvalidEvidenceOutcome.selector, bad[i]));
        }
        assertEq(_ev(id).verdictNonce, 0);
    }

    // ------------------------------------------------------------ nonce
    function test_C_VerdictNonce_StrictFromOne_ConsumedOnlyOnSuccess() public {
        vm.warp(S + 40);
        MicroCover.EvidenceReport memory r = _ok(2);
        r.nonce = 0;
        _xSubmit(r, _eNonce(1, 0));
        r.nonce = 2;
        _xSubmit(r, _eNonce(1, 2));
        r.nonce = type(uint256).max;
        _xSubmit(r, _eNonce(1, type(uint256).max));
        // A report that reverts for another reason (expired) does not consume nonce 1.
        r = _ok(2);
        r.evaluatedAt = uint64(block.timestamp - 30);
        r.validUntil = uint64(block.timestamp - 1);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceExpired.selector, r.validUntil, block.timestamp));
        assertEq(_ev(id).verdictNonce, 0, "reverted submission consumed nothing");
        assertEq(_ev(id).nextVerdictNonce, 1);
        _submit(_ok(2));
        assertEq(_ev(id).verdictNonce, 1);
        assertEq(_ev(id).nextVerdictNonce, 2);
    }

    function test_C_ReplayAndSkipRejected_AfterAcceptedReport() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        _submit(r);
        _xSubmit(r, _eNonce(2, 1)); // exact replay
        _anchor(id, ROOT2, 2);
        r = _ok(2);
        r.nonce = 3; // skip
        _xSubmit(r, _eNonce(2, 3));
        r.nonce = 1; // replay with a fresh root
        _xSubmit(r, _eNonce(2, 1));
        assertEq(_ev(id).verdictNonce, 1);
    }

    function test_C_NonceChecked_BeforeTimingAndStatus() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        r.nonce = 5;
        r.evaluatedAt = uint64(block.timestamp + 1); // would be EvidenceFromFuture
        _xSubmit(r, _eNonce(1, 5));
    }

    // ------------------------------------------------------------ timing
    function test_C_EvidenceTooEarly_Boundary() public {
        vm.warp(S + 10);
        _anchor(id, ROOT2, 2);
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evaluatedAt = S - 1;
        r.validUntil = S - 1 + 60;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceTooEarly.selector, S - 1, S));
        r.evaluatedAt = S; // exactly settlementTime is accepted
        r.validUntil = S + 60;
        _submit(r);
        assertEq(_ev(id).lastReportEvaluatedAt, S);
        assertEq(_ev(id).lastReportValidUntil, S + 60);
        assertEq(_ev(id).lastReportOutcome, 2);
    }

    function test_C_EvidenceFromFuture_Boundary() public {
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evaluatedAt = uint64(block.timestamp + 1);
        r.validUntil = uint64(block.timestamp + 30);
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceFromFuture.selector, block.timestamp + 1, block.timestamp));
        r.evaluatedAt = uint64(block.timestamp); // evaluatedAt == now is accepted
        _submit(r);
        assertEq(_ev(id).lastReportEvaluatedAt, block.timestamp);
    }

    function test_C_EvidenceExpired_Boundary_ValidUntilEqualNowAccepted() public {
        vm.warp(S + 100);
        _anchor(id, ROOT2, 2);
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evaluatedAt = S + 90;
        r.validUntil = S + 99; // now - 1
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceExpired.selector, S + 99, S + 100));
        r.validUntil = S + 100; // validUntil == now
        _submit(r);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        assertEq(_ev(id).lastReportValidUntil, S + 100);
    }

    function test_C_ValidityWindow_Exactly60Ok_61Rejected() public {
        vm.warp(S + 30);
        _anchor(id, ROOT2, 2);
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evaluatedAt = S; // 30s ago
        r.validUntil = S + 61; // evaluatedAt + 61
        _xSubmit(r, abi.encodeWithSelector(MicroCover.InvalidValidity.selector, S, S + 61));
        r.validUntil = S + 1000;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.InvalidValidity.selector, S, S + 1000));
        r.validUntil = S + 60; // evaluatedAt + 60 == now + 30
        _submit(r);
        assertEq(_ev(id).lastReportValidUntil, S + 60);
    }

    function test_C_ValidUntilBeforeEvaluatedAt_IsAlwaysExpiredFirst() public {
        // evaluatedAt <= now <= validUntil is enforced first, so validUntil < evaluatedAt can only surface
        // as EvidenceExpired (the InvalidValidity lower-bound arm is unreachable by construction).
        vm.warp(S + 20);
        _anchor(id, ROOT2, 2);
        MicroCover.EvidenceReport memory r = _ok(2);
        r.evaluatedAt = S + 10;
        r.validUntil = S + 5;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceExpired.selector, S + 5, S + 20));
        r.evaluatedAt = S + 20;
        r.validUntil = S + 19;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.EvidenceExpired.selector, S + 19, S + 20));
    }

    // ------------------------------------------------------------ guarantee kind / status
    function test_C_ManualGuaranteeRejected() public {
        uint256 m = manual;
        MicroCover.EvidenceReport memory r = _ok(2);
        r.guaranteeId = m;
        _xSubmit(r, abi.encodeWithSelector(MicroCover.NotEvidenceBound.selector, m));
    }

    function test_C_FinalStatesRejected_Failed() public {
        _admit(id);
        _xSubmit(_ok(1), _eStatus(MicroCover.Status.FAILED));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.FAILED));
        assertEq(_ev(id).verdictNonce, 0);
    }

    function test_C_FinalStatesRejected_Succeeded_ClosedSuccess() public {
        _toSucceeded(id); // proposes manually, then finalizes
        _xSubmit(_ok(1), _eStatus(MicroCover.Status.SUCCEEDED));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.SUCCEEDED));
        _release(id);
        _withdraw(id);
        _xSubmit(_ok(1), _eStatus(MicroCover.Status.CLOSED));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.CLOSED));
    }

    function test_C_FinalStatesRejected_ClosedFailure() public {
        _admit(id);
        assertEq(_settle(id, 20), 3);
        _xSubmit(_ok(1), _eStatus(MicroCover.Status.CLOSED));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.CLOSED));
    }

    function test_C_FinalStatesRejected_RefundingAndClosedUnresolved() public {
        _dispute(id, alice);
        vm.warp(_readyU(id));
        _finU(id);
        MicroCover.EvidenceReport memory r = _ok(1);
        _xSubmit(r, _eStatus(MicroCover.Status.REFUNDING));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.REFUNDING));
        _refund(id, 20);
        _withdraw(id);
        _xSubmit(_ok(1), _eStatus(MicroCover.Status.CLOSED));
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.CLOSED));
    }

    function test_C_SuccessFromPending_Rejected_ReviewCannotBeReProposedOrExtended() public {
        _submit(_ok(2));
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        assertEq(uint8(l.status), uint8(MicroCover.Status.SUCCESS_PENDING));
        vm.warp(block.timestamp + 50);
        _anchor(id, ROOT2, 2);
        MicroCover.EvidenceReport memory r = _ok(2);
        bytes32 h = _unchanged();
        _xSubmit(r, _eStatus(MicroCover.Status.SUCCESS_PENDING));
        assertEq(_unchanged(), h, "no state change from the rejected re-proposal");
        assertEq(cover.getLifecycle(id).successReadyAt, l.successReadyAt, "review deadline not extended");
        assertEq(cover.getLifecycle(id).successProposedAt, l.successProposedAt);
        assertEq(_ev(id).verdictNonce, 1, "nonce not consumed by the rejected SUCCESS");
    }

    function test_C_FailureFromPending_IsAccepted() public {
        _submit(_ok(2));
        vm.warp(block.timestamp + 10);
        _anchor(id, ROOT2, 2);
        _submit(_ok(1));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(_ev(id).verdictNonce, 2);
    }

    function test_C_LastReportFieldsDescribeOnlyTheLatestAcceptedVerdict() public {
        _submit(_ok(2));
        MicroCover.EvidenceState memory e = _ev(id);
        assertEq(e.lastReportOutcome, 2);
        assertEq(e.lastReportEvaluatedAt, block.timestamp);
        assertEq(e.lastReportValidUntil, block.timestamp + 60);
        // A rejected SUCCESS-from-pending leaves them untouched.
        _anchor(id, ROOT2, 2);
        _xSubmit(_ok(2), _eStatus(MicroCover.Status.SUCCESS_PENDING));
        assertEq(_ev(id).lastReportOutcome, 2);
        assertEq(_ev(id).lastReportEvaluatedAt, e.lastReportEvaluatedAt);
    }
}
