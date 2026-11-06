// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vm} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MicroCover} from "../MicroCover.sol";
import {Phase2Base} from "./MicroCover.Phase2.t.sol";

/// Shared Phase 3 fixtures: evidence-bound creation, anchors, reports, timeout/refund stepping and the
/// extended (refund-aware) accounting identities. Default config: review 120s, uncertainty 30 days.
abstract contract Phase3Base is Phase2Base {
    function _propose(uint256 id) internal override {
        if (cover.getEvidenceState(id).evidenceBound) _verdict(id, 2);
        else super._propose(id);
    }
    bytes32 internal constant POLICY = keccak256("phase3-policy");
    bytes32 internal constant COHORT0 = keccak256("phase3-cohort");
    bytes32 internal constant ROOT1 = keccak256("phase3-root-1");
    bytes32 internal constant ROOT2 = keccak256("phase3-root-2");

    // ------------------------------------------------------------ creation
    function _createB(address p, uint128 comp, uint128 esc, uint32 maxC, bytes32 policy, bytes32 cohort)
        internal
        returns (uint256 id)
    {
        vm.prank(p);
        id = cover.createGuaranteeWithPolicy(comp, esc, maxC, joinDeadline, settlementTime, TERMS, policy, cohort);
    }

    function _createB(uint32 maxC) internal returns (uint256) {
        return _createB(provider, COMP, ESC, maxC, POLICY, keccak256(abi.encode("cohort", cover.nextGuaranteeId())));
    }

    function _createB() internal returns (uint256) {
        return _createB(MAXC);
    }

    /// Bound guarantee with alice, bob, carol enrolled (cohort 3 of 3).
    function _bound3() internal returns (uint256 id) {
        id = _createB();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
    }

    // ------------------------------------------------------------ evidence helpers
    function _ev(uint256 id) internal view returns (MicroCover.EvidenceState memory) {
        return cover.getEvidenceState(id);
    }

    function _anchor(uint256 id, bytes32 root, uint256 nonce) internal {
        MicroCover.EvidenceState memory ev = _ev(id);
        vm.prank(operator);
        cover.anchorEvidence(id, root, ev.policyHash, ev.cohortId, nonce);
    }

    function _anchorNext(uint256 id) internal returns (bytes32 root) {
        uint256 n = _ev(id).nextAnchorNonce;
        root = keccak256(abi.encode("root", id, n));
        _anchor(id, root, n);
    }

    function _xAnchor(address who, uint256 id, bytes32 root, bytes32 pol, bytes32 coh, uint256 nonce, bytes memory err)
        internal
    {
        vm.prank(who);
        vm.expectRevert(err);
        cover.anchorEvidence(id, root, pol, coh, nonce);
    }

    function _rep(uint256 id, uint8 outcome, bytes32 root, uint256 nonce, uint64 evalAt, uint64 validUntil)
        internal
        view
        returns (MicroCover.EvidenceReport memory r)
    {
        MicroCover.EvidenceState memory ev = _ev(id);
        r = MicroCover.EvidenceReport({
            chainId: block.chainid,
            consumer: address(cover),
            guaranteeId: id,
            cohortId: ev.cohortId,
            policyHash: ev.policyHash,
            evidenceRoot: root,
            outcome: outcome,
            evaluatedAt: evalAt,
            validUntil: validUntil,
            nonce: nonce
        });
    }

    /// Well-formed report for the latest anchor, evaluated now and valid 60s.
    function _repNow(uint256 id, uint8 outcome) internal view returns (MicroCover.EvidenceReport memory) {
        MicroCover.EvidenceState memory ev = _ev(id);
        return _rep(
            id, outcome, ev.latestEvidenceRoot, ev.nextVerdictNonce, uint64(block.timestamp), uint64(block.timestamp + 60)
        );
    }

    function _submit(MicroCover.EvidenceReport memory r) internal {
        vm.prank(operator);
        cover.submitEvidenceVerdict(r);
    }

    function _xSubmit(MicroCover.EvidenceReport memory r, bytes memory err) internal {
        vm.prank(operator);
        vm.expectRevert(err);
        cover.submitEvidenceVerdict(r);
    }

    /// Anchor a fresh root, then submit a well-formed report now. Caller must be at/after settlementTime.
    function _verdict(uint256 id, uint8 outcome) internal returns (MicroCover.EvidenceReport memory r) {
        _anchorNext(id);
        r = _repNow(id, outcome);
        _submit(r);
    }

    function _atSettle(uint256 id) internal {
        _warpTo(cover.getGuarantee(id).settlementTime);
    }

    // ------------------------------------------------------------ timeout / refund helpers
    function _readyU(uint256 id) internal view returns (uint64) {
        return _ev(id).uncertainReadyAt;
    }

    function _finU(uint256 id) internal {
        vm.prank(stranger);
        cover.finalizeUnresolved(id);
    }

    function _refund(uint256 id, uint32 n) internal returns (uint32 r) {
        vm.prank(stranger);
        r = cover.refundUnresolved(id, n);
    }

    function _xRefund(uint256 id, uint32 n, bytes memory err) internal {
        vm.prank(stranger);
        vm.expectRevert(err);
        cover.refundUnresolved(id, n);
    }

    function _xFinU(uint256 id, bytes memory err) internal {
        vm.prank(stranger);
        vm.expectRevert(err);
        cover.finalizeUnresolved(id);
    }

    /// OPEN guarantee with alice enrolled -> first dispute -> warp to the exact timeout -> finalize.
    function _toRefunding(uint256 id) internal {
        _dispute(id, alice);
        vm.warp(_readyU(id));
        _finU(id);
    }

    function _eNotReached(uint256 id, uint64 readyAt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.UncertaintyTimeoutNotReached.selector, id, readyAt);
    }

    function _eReached(uint256 id, uint64 readyAt) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.UncertaintyTimeoutReached.selector, id, readyAt);
    }

    // ------------------------------------------------------------ checks
    /// The three accounting identities extended with refundedEscrow and releasedUnresolvedReservation.
    function _id3(uint256 id) internal view {
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        MicroCover.GuaranteeState memory s = cover.getState(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        MicroCover.EvidenceState memory e = cover.getEvidenceState(id);
        assertEq(
            cover.bondOf(id) + s.paidCompensation + l.withdrawnBond, uint256(g.compensation) * g.maxCohort, "id3: bond"
        );
        assertEq(
            cover.escrowedOf(id) + s.paidEscrow + l.releasedSuccessEscrow + e.refundedEscrow,
            uint256(g.escrowAmount) * g.cohortSize,
            "id3: escrow"
        );
        assertEq(
            cover.reservedOf(id) + s.paidCompensation + l.releasedSuccessReservation + e.releasedUnresolvedReservation,
            uint256(g.compensation) * g.cohortSize,
            "id3: reserve"
        );
        assertLe(cover.reservedOf(id), cover.bondOf(id), "id3: reserved <= bond");
        assertLe(s.paidCount, g.cohortSize);
        assertLe(e.refundedCount, g.cohortSize);
    }

    /// Global solvency: token balance covers every guarantee's bond + escrow (donations are extra).
    function _solvent() internal view {
        assertGe(usdc.balanceOf(address(cover)), _accounted(), "global solvency");
    }

    /// Per-guarantee digest including lifecycle, evidence state, refund flags (no global balances).
    function _edigest(uint256 id) internal view returns (bytes32) {
        address[] memory bens = cover.getBeneficiaries(id);
        bytes memory acc = abi.encode(_gdigest(id), cover.getEvidenceState(id));
        for (uint256 i; i < bens.length; i++) {
            acc = abi.encode(acc, bens[i], cover.isRefunded(id, bens[i]), usdc.balanceOf(bens[i]));
        }
        return keccak256(acc);
    }

    /// _edigest plus the global ledger balances and the provider balance.
    function _esnap(uint256 id) internal view returns (bytes32) {
        return keccak256(abi.encode(_edigest(id), usdc.balanceOf(address(cover)), usdc.balanceOf(_providerOf(id))));
    }

    function _hasTopic(Vm.Log[] memory logs, bytes32 topic0) internal pure returns (uint256 n) {
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics.length > 0 && logs[i].topics[0] == topic0) n++;
        }
    }
}

/// Scenario A: creation with and without a frozen evidence policy.
contract Phase3CreationTest is Phase3Base {
    function test_A_ManualCreate_IsNotEvidenceBound_CreatedAtSet() public {
        vm.warp(5_000);
        joinDeadline = 6_000;
        settlementTime = 7_000;
        uint256 id = _create();
        MicroCover.EvidenceState memory e = _ev(id);
        assertFalse(e.evidenceBound);
        assertEq(e.policyHash, bytes32(0));
        assertEq(e.cohortId, bytes32(0));
        assertEq(e.createdAt, 5_000);
        assertEq(e.uncertaintyTimeout, UNCERTAINTY);
        assertFalse(e.uncertaintyStarted);
        assertEq(e.uncertainSince, 0);
        assertEq(e.uncertainReadyAt, 0);
        assertEq(e.refundedCount, 0);
        assertEq(e.refundedEscrow, 0);
        assertEq(e.releasedUnresolvedReservation, 0);
        assertEq(e.latestEvidenceRoot, bytes32(0));
        assertEq(e.anchorNonce, 0);
        assertEq(e.nextAnchorNonce, 1);
        assertEq(e.verdictNonce, 0);
        assertEq(e.nextVerdictNonce, 1);
        assertEq(e.failureOrigin, 0);
        assertEq(e.lastReportOutcome, 0);
        assertEq(e.lastReportEvaluatedAt, 0);
        assertEq(e.lastReportValidUntil, 0);
    }

    function test_A_BoundCreate_FreezesPolicyAndCohort_ExactFundingAndEvents() public {
        uint256 provBefore = usdc.balanceOf(provider);
        bytes32 coh = keccak256("cohort-A");
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.GuaranteeCreated(1, provider, COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, BOND_);
        vm.expectEmit(true, false, false, true, address(cover));
        emit MicroCover.EvidencePolicyBound(1, POLICY, coh);
        uint256 id = _createB(provider, COMP, ESC, MAXC, POLICY, coh);

        assertEq(id, 1);
        assertEq(cover.nextGuaranteeId(), 2);
        assertEq(cover.bondOf(id), BOND_);
        assertEq(usdc.balanceOf(provider), provBefore - BOND_, "atomic funding exact");
        assertEq(usdc.balanceOf(address(cover)), BOND_);
        MicroCover.EvidenceState memory e = _ev(id);
        assertTrue(e.evidenceBound);
        assertEq(e.policyHash, POLICY);
        assertEq(e.cohortId, coh);
        assertEq(e.createdAt, block.timestamp);
        assertEq(e.nextAnchorNonce, 1);
        assertEq(e.nextVerdictNonce, 1);
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        assertEq(g.provider, provider);
        assertEq(g.joinDeadline, joinDeadline);
        assertEq(g.settlementTime, settlementTime);
        assertEq(g.termsHash, TERMS);
        _id3(id);
    }

    uint256 internal constant BOND_ = uint256(COMP) * MAXC;

    function test_A_ManualCreateEmitsNoPolicyBoundEvent() public {
        vm.recordLogs();
        _create();
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(_hasTopic(logs, MicroCover.EvidencePolicyBound.selector), 0);
        assertEq(_hasTopic(logs, MicroCover.GuaranteeCreated.selector), 1);
        vm.recordLogs();
        _createB();
        logs = vm.getRecordedLogs();
        assertEq(_hasTopic(logs, MicroCover.EvidencePolicyBound.selector), 1);
        assertEq(_hasTopic(logs, MicroCover.GuaranteeCreated.selector), 1);
    }

    function test_A_ZeroPolicyAndZeroCohortRevert_NoStateChange() public {
        uint256 provBefore = usdc.balanceOf(provider);
        vm.prank(provider);
        vm.expectRevert(MicroCover.ZeroPolicyHash.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, bytes32(0), COHORT0);
        vm.prank(provider);
        vm.expectRevert(MicroCover.ZeroCohortId.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, POLICY, bytes32(0));
        // Both zero: the policy check comes first.
        vm.prank(provider);
        vm.expectRevert(MicroCover.ZeroPolicyHash.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, bytes32(0), bytes32(0));
        // The policy commitments are checked before term validation.
        vm.prank(provider);
        vm.expectRevert(MicroCover.ZeroPolicyHash.selector);
        cover.createGuaranteeWithPolicy(0, ESC, MAXC, joinDeadline, settlementTime, TERMS, bytes32(0), COHORT0);
        assertEq(cover.nextGuaranteeId(), 1);
        assertEq(usdc.balanceOf(provider), provBefore);
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_A_BoundCreate_SameTermValidationsAsLegacy() public {
        bytes32 c = COHORT0;
        vm.startPrank(provider);
        vm.expectRevert(MicroCover.InvalidCompensation.selector);
        cover.createGuaranteeWithPolicy(0, ESC, MAXC, joinDeadline, settlementTime, TERMS, POLICY, c);
        vm.expectRevert(MicroCover.InvalidEscrowAmount.selector);
        cover.createGuaranteeWithPolicy(COMP, 0, MAXC, joinDeadline, settlementTime, TERMS, POLICY, c);
        vm.expectRevert(MicroCover.InvalidMaxCohort.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, 0, joinDeadline, settlementTime, TERMS, POLICY, c);
        vm.expectRevert(MicroCover.InvalidMaxCohort.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, 101, joinDeadline, settlementTime, TERMS, POLICY, c);
        vm.expectRevert(MicroCover.InvalidJoinDeadline.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, uint64(block.timestamp), settlementTime, TERMS, POLICY, c);
        vm.expectRevert(MicroCover.InvalidSettlementTime.selector);
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, joinDeadline - 1, TERMS, POLICY, c);
        vm.stopPrank();
        assertEq(cover.nextGuaranteeId(), 1);
        assertEq(usdc.balanceOf(address(cover)), 0);
        // Boundary cases the legacy path accepts are accepted here too.
        vm.startPrank(provider);
        uint256 a = cover.createGuaranteeWithPolicy(COMP, ESC, 1, joinDeadline, joinDeadline, TERMS, POLICY, c);
        uint256 b = cover.createGuaranteeWithPolicy(COMP, ESC, 100, joinDeadline, settlementTime, TERMS, POLICY, c);
        vm.stopPrank();
        assertEq(cover.bondOf(a), COMP);
        assertEq(cover.bondOf(b), uint256(COMP) * 100);
    }

    function test_A_BoundCreate_FundingFailuresAreAtomic() public {
        address poor = makeAddr("poorProvider");
        vm.startPrank(poor);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(cover), 0, BOND_)
        );
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, POLICY, COHORT0);
        usdc.approve(address(cover), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, poor, 0, BOND_));
        cover.createGuaranteeWithPolicy(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS, POLICY, COHORT0);
        vm.stopPrank();
        assertEq(cover.nextGuaranteeId(), 1, "no id consumed, no record created");
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 1));
        cover.getEvidenceState(1);
    }

    function test_A_PolicyAndCohortAreFrozen_NoMutationSurface_AcrossAFullLifecycle() public {
        uint256 id = _bound3();
        MicroCover.EvidenceState memory before_ = _ev(id);
        string[6] memory sigs = [
            "setEvidencePolicy(uint256,bytes32,bytes32)",
            "bindPolicy(uint256,bytes32,bytes32)",
            "setPolicyHash(uint256,bytes32)",
            "setCohortId(uint256,bytes32)",
            "rebindEvidence(uint256,bytes32,bytes32)",
            "bindEvidence(uint256,bytes32,bytes32)"
        ];
        for (uint256 i; i < sigs.length; i++) {
            vm.prank(operator);
            (bool ok,) = address(cover).call(abi.encodeWithSignature(sigs[i], id, bytes32(uint256(1)), bytes32(uint256(2))));
            assertFalse(ok, sigs[i]);
        }
        // Operator and provider activity cannot rebind either.
        bytes32 root = _anchorNext(id);
        _xAnchor(operator, id, root, bytes32(uint256(9)), before_.cohortId, 2, abi.encodeWithSelector(MicroCover.EvidenceBindingMismatch.selector, id));
        _xAnchor(operator, id, root, before_.policyHash, bytes32(uint256(9)), 2, abi.encodeWithSelector(MicroCover.EvidenceBindingMismatch.selector, id));
        _dispute(id, alice);
        _atSettle(id);
        _verdict(id, 2);
        vm.warp(_ready(id) + 1);
        _finalize(id);
        MicroCover.EvidenceState memory after_ = _ev(id);
        assertEq(after_.policyHash, before_.policyHash);
        assertEq(after_.cohortId, before_.cohortId);
        assertEq(after_.createdAt, before_.createdAt);
        assertTrue(after_.evidenceBound);
        // A later creation can never touch an older guarantee's binding.
        joinDeadline = uint64(block.timestamp + 1 days);
        settlementTime = uint64(block.timestamp + 2 days);
        _createB(provider, COMP, ESC, MAXC, keccak256("other"), keccak256("other-cohort"));
        assertEq(_ev(id).policyHash, before_.policyHash);
        assertEq(_ev(id).cohortId, before_.cohortId);
    }

    function test_A_EvidenceFunctionsOnManualGuaranteeRevertNotEvidenceBound() public {
        uint256 id = _create();
        _join(id, alice);
        bytes memory err = abi.encodeWithSelector(MicroCover.NotEvidenceBound.selector, id);
        _xAnchor(operator, id, ROOT1, POLICY, COHORT0, 1, err);
        MicroCover.EvidenceReport memory r = _rep(id, 1, ROOT1, 1, uint64(block.timestamp), uint64(block.timestamp));
        r.policyHash = POLICY;
        r.cohortId = COHORT0;
        _xSubmit(r, err);
        vm.prank(alice);
        vm.expectRevert(err);
        cover.requestEvaluation(id);
        // Manual guarantees still follow the Phase 2 path and receive timeout protection.
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
    }

    function test_A_ManualGuaranteePrecedence_AuthBeforeBinding_UnknownFirst() public {
        uint256 id = _create();
        _join(id, alice);
        MicroCover.EvidenceReport memory r = _rep(id, 1, ROOT1, 1, uint64(block.timestamp), uint64(block.timestamp));
        // Non-operator on a manual guarantee: operator check precedes the binding check.
        _xAnchor(provider, id, ROOT1, POLICY, COHORT0, 1, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, provider));
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, provider));
        cover.submitEvidenceVerdict(r);
        // Non-member on a manual guarantee: membership check precedes the binding check.
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotBeneficiary.selector, id, bob));
        cover.requestEvaluation(id);
        // Unknown ids precede everything.
        _xAnchor(provider, 77, ROOT1, POLICY, COHORT0, 1, abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 77));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 77));
        cover.requestEvaluation(77);
        r.guaranteeId = 77;
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 77));
        cover.submitEvidenceVerdict(r);
    }
}
