// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MicroCover} from "../MicroCover.sol";
import {Phase3Base} from "./MicroCover.Phase3.t.sol";

/// Scenario B: anchorEvidence.
contract Phase3AnchorTest is Phase3Base {
    uint256 internal id;
    bytes32 internal coh;

    function setUp() public override {
        super.setUp();
        id = _bound3();
        coh = _ev(id).cohortId;
    }

    function _eStatus(MicroCover.Status s) internal view returns (bytes memory) {
        return abi.encodeWithSelector(MicroCover.InvalidStatus.selector, id, s);
    }

    /// Digest of every evidence-state field a mere anchor must not touch.
    function _unrelated(uint256 gid) internal view returns (bytes32) {
        MicroCover.EvidenceState memory e = _ev(gid);
        e.latestEvidenceRoot = bytes32(0);
        e.anchorNonce = 0;
        e.nextAnchorNonce = 0;
        return keccak256(abi.encode(e, cover.getLifecycle(gid), cover.getState(gid), usdc.balanceOf(address(cover))));
    }

    function test_B_OperatorOnly() public {
        address[5] memory who = [provider, alice, bob, stranger, address(this)];
        for (uint256 i; i < who.length; i++) {
            _xAnchor(who[i], id, ROOT1, POLICY, coh, 1, abi.encodeWithSelector(MicroCover.NotDemoOperator.selector, who[i]));
        }
        assertEq(_ev(id).anchorNonce, 0);
        _anchor(id, ROOT1, 1);
        assertEq(_ev(id).anchorNonce, 1);
    }

    function test_B_UnknownGuaranteeAndZeroRoot() public {
        _xAnchor(operator, 99, ROOT1, POLICY, coh, 1, abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        _xAnchor(operator, 0, ROOT1, POLICY, coh, 1, abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 0));
        _xAnchor(operator, id, bytes32(0), POLICY, coh, 1, abi.encodeWithSelector(MicroCover.ZeroEvidenceRoot.selector));
        assertEq(_ev(id).anchorNonce, 0);
        assertEq(_ev(id).latestEvidenceRoot, bytes32(0));
    }

    function test_B_BindingMismatch_PolicyCohortOrBoth_AndPrecedence() public {
        bytes memory err = abi.encodeWithSelector(MicroCover.EvidenceBindingMismatch.selector, id);
        _xAnchor(operator, id, ROOT1, keccak256("wrong-policy"), coh, 1, err);
        _xAnchor(operator, id, ROOT1, POLICY, keccak256("wrong-cohort"), 1, err);
        _xAnchor(operator, id, ROOT1, bytes32(0), bytes32(0), 1, err);
        _xAnchor(operator, id, ROOT1, keccak256("wrong-policy"), keccak256("wrong-cohort"), 1, err);
        // Another guarantee's own cohortId is not this guarantee's.
        uint256 other = _createB();
        _xAnchor(operator, id, ROOT1, POLICY, _ev(other).cohortId, 1, err);
        // Precedence: zero root, then binding, then nonce.
        _xAnchor(operator, id, bytes32(0), keccak256("wrong-policy"), coh, 9, abi.encodeWithSelector(MicroCover.ZeroEvidenceRoot.selector));
        _xAnchor(operator, id, ROOT1, keccak256("wrong-policy"), coh, 9, err);
        _xAnchor(operator, id, ROOT1, POLICY, coh, 9, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 1, 9));
        assertEq(_ev(id).anchorNonce, 0);
    }

    function test_B_StrictNonceFromOne_ReplayAndSkipRejected() public {
        _xAnchor(operator, id, ROOT1, POLICY, coh, 0, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 1, 0));
        _xAnchor(operator, id, ROOT1, POLICY, coh, 2, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 1, 2));
        _xAnchor(operator, id, ROOT1, POLICY, coh, type(uint256).max, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 1, type(uint256).max));
        _anchor(id, ROOT1, 1);
        _xAnchor(operator, id, ROOT1, POLICY, coh, 1, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 2, 1));
        _xAnchor(operator, id, ROOT2, POLICY, coh, 1, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 2, 1));
        _xAnchor(operator, id, ROOT2, POLICY, coh, 3, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 2, 3));
        _anchor(id, ROOT2, 2);
        _xAnchor(operator, id, ROOT2, POLICY, coh, 2, abi.encodeWithSelector(MicroCover.InvalidNonce.selector, 3, 2));
        MicroCover.EvidenceState memory e = _ev(id);
        assertEq(e.anchorNonce, 2);
        assertEq(e.nextAnchorNonce, 3);
        assertEq(e.latestEvidenceRoot, ROOT2);
    }

    function test_B_LatestRootStored_EventEmitted_SameRootAllowedWithNextNonce() public {
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.EvidenceAnchored(id, ROOT1, 1);
        _anchor(id, ROOT1, 1);
        assertEq(_ev(id).latestEvidenceRoot, ROOT1);
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.EvidenceAnchored(id, ROOT2, 2);
        _anchor(id, ROOT2, 2);
        assertEq(_ev(id).latestEvidenceRoot, ROOT2, "only the latest root is kept");
        _anchor(id, ROOT2, 3);
        assertEq(_ev(id).latestEvidenceRoot, ROOT2);
        assertEq(_ev(id).anchorNonce, 3);
        assertEq(_ev(id).verdictNonce, 0, "independent nonce streams");
        assertEq(_ev(id).nextVerdictNonce, 1);
    }

    function test_B_TerminalStatesRejected_Failed() public {
        _admit(id);
        _xAnchor(operator, id, ROOT1, POLICY, coh, 1, _eStatus(MicroCover.Status.FAILED));
        assertEq(_ev(id).anchorNonce, 0, "nonce not consumed by a rejected anchor");
    }

    function test_B_TerminalStatesRejected_Succeeded() public {
        _toSucceeded(id);
        _xAnchor(operator, id, ROOT1, POLICY, coh, _ev(id).nextAnchorNonce, _eStatus(MicroCover.Status.SUCCEEDED));
    }

    function test_B_TerminalStatesRejected_ClosedAfterFailureAndAfterSuccess() public {
        _admit(id);
        assertEq(_settle(id, 20), 3);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        _xAnchor(operator, id, ROOT1, POLICY, coh, 1, _eStatus(MicroCover.Status.CLOSED));
        uint256 s = _bound3();
        _toClosedSuccess(s);
        assertEq(uint8(cover.statusOf(s)), uint8(MicroCover.Status.CLOSED));
        _xAnchor(operator, s, ROOT1, POLICY, _ev(s).cohortId, _ev(s).nextAnchorNonce, abi.encodeWithSelector(MicroCover.InvalidStatus.selector, s, MicroCover.Status.CLOSED));
    }

    function test_B_TerminalStatesRejected_RefundingAndClosedAfterRefund() public {
        _toRefunding(id);
        _xAnchor(operator, id, ROOT1, POLICY, coh, 1, _eStatus(MicroCover.Status.REFUNDING));
        assertEq(_refund(id, 20), 3);
        _withdraw(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        _xAnchor(operator, id, ROOT1, POLICY, coh, 1, _eStatus(MicroCover.Status.CLOSED));
    }

    function test_B_AllowedInOpenPendingUncertain_NeverChangesStatusOrTimers() public {
        // OPEN
        bytes32 h = _unrelated(id);
        _anchor(id, ROOT1, 1);
        assertEq(_unrelated(id), h, "OPEN: nothing but root/nonce changed");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
        assertFalse(_ev(id).uncertaintyStarted);

        // SUCCESS_PENDING
        _toPending(id);
        uint64 ready = _ready(id);
        h = _unrelated(id);
        _anchor(id, ROOT2, _ev(id).nextAnchorNonce);
        assertEq(_unrelated(id), h, "PENDING: nothing but root/nonce changed");
        assertEq(_ready(id), ready, "successReadyAt unchanged");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));

        // UNCERTAIN, before and after the timeout.
        _dispute(id, alice);
        uint64 uready = _readyU(id);
        uint64 since = _ev(id).uncertainSince;
        h = _unrelated(id);
        _anchor(id, ROOT1, _ev(id).nextAnchorNonce);
        assertEq(_unrelated(id), h, "UNCERTAIN: nothing but root/nonce changed");
        assertEq(_readyU(id), uready);
        assertEq(_ev(id).uncertainSince, since);
        vm.warp(uint256(uready) + 5);
        h = _unrelated(id);
        _anchor(id, ROOT2, _ev(id).nextAnchorNonce);
        assertEq(_unrelated(id), h, "anchoring stays allowed after the timeout");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.UNCERTAIN), "anchoring never finalizes");
        assertEq(_ev(id).anchorNonce, 5);
        _id3(id);
    }

    function test_B_AnchorMovesNoTokens() public {
        uint256 bal = usdc.balanceOf(address(cover));
        uint256 prov = usdc.balanceOf(provider);
        uint256 op = usdc.balanceOf(operator);
        _anchor(id, ROOT1, 1);
        assertEq(usdc.balanceOf(address(cover)), bal);
        assertEq(usdc.balanceOf(provider), prov);
        assertEq(usdc.balanceOf(operator), op);
        _id3(id);
    }

    function test_B_AnchorsAreIndependentPerGuarantee() public {
        uint256 other = _createB();
        _anchor(id, ROOT1, 1);
        _anchor(id, ROOT2, 2);
        assertEq(_ev(other).anchorNonce, 0);
        assertEq(_ev(other).latestEvidenceRoot, bytes32(0));
        _anchor(other, ROOT1, 1); // same root and nonce on a different id are independent
        assertEq(_ev(other).anchorNonce, 1);
        assertEq(_ev(id).anchorNonce, 2);
        assertEq(_ev(id).latestEvidenceRoot, ROOT2);
    }
}
