// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Phase3Base} from "./MicroCover.Phase3.t.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC, BlocklistUSDC, OutgoingFeeUSDC, ReentrantUSDC} from "./MockUSDC.sol";

contract Phase3TimeoutTest is Phase3Base {
    function _uncertainty() internal pure override returns (uint64) { return 120; }
    function _window() internal pure override returns (uint64) { return 73; }

    function test_FirstTimerAndRequestsAnchorsRetriesCannotExtend() public {
        uint256 id = _bound3();
        vm.prank(alice); cover.requestEvaluation(id);
        assertFalse(_ev(id).uncertaintyStarted, "request is not an onchain dispute");
        _dispute(id, alice);
        uint64 since = _ev(id).uncertainSince;
        uint64 ready = _readyU(id);
        assertEq(ready, uint256(since) + 120);
        vm.warp(block.timestamp + 10);
        vm.prank(bob); cover.requestEvaluation(id);
        _anchorNext(id);
        vm.prank(operator); vm.expectRevert(); cover.markUncertain(id);
        vm.prank(bob); vm.expectRevert(); cover.raiseDispute(id);
        assertEq(_ev(id).uncertainSince, since);
        assertEq(_readyU(id), ready);
        vm.warp(ready - 1);
        _xFinU(id, _eNotReached(id, ready));
        vm.warp(ready);
        _finU(id);
        assertEq(uint8(cover.outcomeOf(id)), 3);
        assertEq(uint8(cover.statusOf(id)), 6);
        _id3(id);
    }

    function test_PartialBatchesEscrowOnlyBondLastAndIsolation() public {
        uint256 id = _bound3();
        uint256 other = _bound3();
        bytes32 protected = keccak256(abi.encode(_gdigest(other), _ev(other)));
        uint256 beforeAlice = usdc.balanceOf(alice);
        uint256 providerBefore = usdc.balanceOf(provider);
        _toRefunding(id);
        assertEq(cover.getState(id).remainingOwed, 6e6);
        assertEq(cover.reservedOf(id), 0);
        assertEq(_ev(id).releasedUnresolvedReservation, 15e6);
        assertEq(cover.bondOf(id), 15e6);
        vm.prank(provider); vm.expectRevert(); cover.withdrawRemainingBond(id);
        assertEq(_refund(id, 1), 1);
        assertEq(usdc.balanceOf(alice) - beforeAlice, 2e6);
        assertEq(_ev(id).refundedCount, 1);
        assertEq(cover.getState(id).remainingOwed, 4e6);
        assertEq(cover.getState(id).withdrawableBond, 0);
        assertFalse(cover.isPaid(id, alice));
        assertTrue(cover.isRefunded(id, alice));
        vm.prank(provider); vm.expectRevert(); cover.withdrawRemainingBond(id);
        _id3(id);
        _refund(id, 20);
        assertEq(cover.getState(id).paidCompensation, 0);
        assertEq(cover.getState(id).paidEscrow, 0);
        assertEq(_ev(id).refundedEscrow, 6e6);
        vm.expectRevert(); cover.refundUnresolved(id, 1);
        vm.expectRevert(); cover.settleFailure(id, 1);
        vm.prank(provider); cover.withdrawRemainingBond(id);
        assertEq(usdc.balanceOf(provider) - providerBefore, 15e6);
        assertEq(uint8(cover.statusOf(id)), 2);
        assertEq(uint8(cover.outcomeOf(id)), 3);
        assertEq(keccak256(abi.encode(_gdigest(other), _ev(other))), protected);
        _id3(id); _id3(other); _solvent();
    }

    function test_EmptyCohortPermissionlessFinalizeFullBondReturn() public {
        uint256 id = _createB();
        _uncertain(id);
        vm.warp(_readyU(id)); _finU(id);
        assertEq(cover.getState(id).remainingOwed, 0);
        vm.expectRevert(); cover.refundUnresolved(id, 1);
        vm.prank(provider); cover.withdrawRemainingBond(id);
        _id3(id); _solvent();
    }

    function testFuzz_MultipleRefundBatchesExactAndNoDuplicates(uint8 members, uint8 batchSeed) public {
        uint32 count = uint32(bound(members, 21, 55));
        uint32 batch = uint32(bound(batchSeed, 1, 20));
        uint256 id = _createB(count);
        for (uint32 i; i < count; i++) {
            address b = address(uint160(1000 + i));
            _fundUser(b); _join(id, b);
        }
        _uncertain(id); vm.warp(_readyU(id)); _finU(id);
        vm.expectRevert(); cover.refundUnresolved(id, 0);
        vm.expectRevert(); cover.refundUnresolved(id, 21);
        while (_ev(id).refundedCount < count) {
            uint32 beforeCount = _ev(id).refundedCount;
            _refund(id, batch);
            assertLe(_ev(id).refundedCount - beforeCount, 20);
            _id3(id); _solvent();
        }
        for (uint32 i; i < count; i++) {
            address b = address(uint160(1000 + i));
            assertTrue(cover.isRefunded(id, b));
            assertFalse(cover.isPaid(id, b));
        }
        assertEq(_ev(id).refundedEscrow, uint256(ESC) * count);
        vm.prank(provider); cover.withdrawRemainingBond(id);
        vm.expectRevert(); cover.refundUnresolved(id, 1);
        _id3(id);
    }

    function test_AtTimeoutAllResolutionPathsLoseRegardlessOfOrdering() public {
        uint256 id = _bound3();
        vm.warp(settlementTime); _uncertain(id); _anchorNext(id);
        uint64 ready = _readyU(id);
        vm.warp(ready);
        _xSubmit(_repNow(id, 1), _eReached(id, ready));
        _xSubmit(_repNow(id, 2), _eReached(id, ready));
        vm.prank(provider); vm.expectRevert(_eReached(id, ready)); cover.admitFailure(id);
        _finU(id);
        vm.prank(provider); vm.expectRevert(); cover.admitFailure(id);
        _xSubmit(_repNow(id, 1), _eInvalid(id, MicroCover.Status.REFUNDING));
        _refund(id, 20); _id3(id);
    }

    function test_ResolutionBeforeTimeoutWinsAndCannotBeOverridden() public {
        uint256 failureId = _bound3();
        uint256 successId = _bound3();
        vm.warp(settlementTime);
        _uncertain(failureId); _uncertain(successId);
        vm.warp(_readyU(failureId) - 1);
        _verdict(failureId, 1); _verdict(successId, 2);
        assertEq(cover.getLifecycle(successId).successReadyAt, block.timestamp + 73);
        vm.warp(block.timestamp + 2);
        vm.expectRevert(); cover.finalizeUnresolved(failureId);
        vm.expectRevert(); cover.finalizeUnresolved(successId);
        vm.warp(cover.getLifecycle(successId).successReadyAt + 1);
        _finalize(successId);
        vm.expectRevert(); cover.finalizeUnresolved(successId);
        _id3(failureId); _id3(successId);
    }

    function test_LaterDisputeReusesFirstDeadlineEvenAfterFullReviewRestarts() public {
        uint256 id = _bound3(); vm.warp(settlementTime);
        _uncertain(id); uint64 first = _readyU(id);
        vm.warp(first - 1); _verdict(id, 2);
        vm.warp(first + 1); _dispute(id, bob);
        assertEq(_readyU(id), first);
        _finU(id); assertEq(uint8(cover.outcomeOf(id)), 3);
    }

    function test_UncertainSuccessCannotBypassInclusiveJoinCutoff() public {
        settlementTime = joinDeadline;
        uint256 id = _bound3();
        vm.warp(joinDeadline); _uncertain(id); _anchorNext(id);
        _xSubmit(_repNow(id, 2), abi.encodeWithSelector(MicroCover.ProposalTooEarly.selector, id, uint256(joinDeadline) + 1));
        vm.warp(uint256(joinDeadline) + 1); _submit(_repNow(id, 2));
        assertEq(cover.getLifecycle(id).successReadyAt, block.timestamp + 73);
    }

    function test_ZeroTimestampIsNotAnUnstartedSentinel() public {
        vm.warp(0);
        uint256 id = _createB(); _uncertain(id);
        assertTrue(_ev(id).uncertaintyStarted);
        assertEq(_ev(id).uncertainSince, 0);
        assertEq(_readyU(id), 120);
    }
}

contract Phase3BlockedRefundTest is Phase3Base {
    function _deployToken() internal override returns (MockUSDC) { return new BlocklistUSDC(); }
    function test_BlockedSecondRecipientRollsBackWholeBatchAndFlags() public {
        uint256 id = _bound3(); _toRefunding(id);
        bytes32 beforeState = _esnap(id);
        BlocklistUSDC(address(usdc)).setBlocked(bob, true);
        vm.expectRevert(); cover.refundUnresolved(id, 3);
        assertEq(_esnap(id), beforeState);
        BlocklistUSDC(address(usdc)).setBlocked(bob, false);
        _refund(id, 3); _id3(id);
    }
}

contract Phase3FeeRefundTest is Phase3Base {
    function _deployToken() internal override returns (MockUSDC) { return new OutgoingFeeUSDC(); }
    function test_FeeRollbackProtectsRefundLiabilities() public {
        uint256 id = _bound3(); _toRefunding(id);
        bytes32 beforeState = _esnap(id);
        OutgoingFeeUSDC(address(usdc)).configure(address(cover), OutgoingFeeUSDC.Mode.SHORT);
        vm.expectRevert(); cover.refundUnresolved(id, 3);
        assertEq(_esnap(id), beforeState);
        OutgoingFeeUSDC(address(usdc)).configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        _refund(id, 3); _id3(id);
    }
}

contract Phase3ReentryRefundTest is Phase3Base {
    function _deployToken() internal override returns (MockUSDC) { return new ReentrantUSDC(); }
    function test_ReentrantRefundCannotDoublePay() public {
        uint256 id = _bound3(); _toRefunding(id);
        ReentrantUSDC token = ReentrantUSDC(address(usdc));
        token.arm(address(cover), abi.encodeCall(MicroCover.refundUnresolved, (id, 3)), false);
        _refund(id, 3);
        assertFalse(token.lastOk()); assertEq(_ev(id).refundedCount, 3);
        _id3(id); _solvent();
    }
}
