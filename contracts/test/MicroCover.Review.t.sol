// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MicroCover} from "../MicroCover.sol";
import {MockUSDC, RecipientFeeUSDC} from "./MockUSDC.sol";
import {Phase1Base} from "./MicroCover.Phase1.t.sol";

/// Regression tests for the Phase 1 draft review: the failure verdict must be recorded
/// explicitly (never inferred from a nonzero timestamp).
contract ReviewOutcomeTest is Phase1Base {
    function _createAtZero(uint32 maxC) internal returns (uint256 id) {
        vm.prank(provider);
        id = cover.createGuarantee(COMP, ESC, maxC, 100, 200, bytes32(0));
    }

    function test_OutcomeIsFailureAtTimestampZero() public {
        vm.warp(0);
        uint256 id = _createAtZero(1);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE), "no verdict before admission");
        _admit(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE), "verdict recorded at t=0");
        MicroCover.GuaranteeState memory s = cover.getState(id);
        assertEq(uint8(s.outcome), uint8(MicroCover.Outcome.FAILURE));
        assertEq(s.failureAdmittedAt, 0, "timestamp is informational and may be zero");
    }

    function test_OutcomeStaysFailureAfterPayoutAndClosureAtTimestampZero() public {
        vm.warp(0);
        uint256 id = _createAtZero(1);
        _join(id, alice);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE));
        _admit(id);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(_settle(id, 1), 1);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE), "after closure");
        assertEq(uint8(cover.getState(id).outcome), uint8(MicroCover.Outcome.FAILURE));
    }

    function test_OutcomeAfterPartialPayoutAndLeftoverWithdrawal() public {
        vm.warp(0);
        uint256 id = _createAtZero(3);
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        assertEq(_settle(id, 1), 1);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE), "mid payout");
        assertEq(_settle(id, 20), 1);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE), "all paid, leftover pending");
        assertEq(_withdraw(id), COMP);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE), "after withdrawal");
    }

    function test_OutcomeFailureWithZeroEnrollmentAtTimestampZero() public {
        vm.warp(0);
        uint256 id = _createAtZero(2);
        _admit(id);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        _withdraw(id);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
    }

    function test_OpenGuaranteeKeepsNoVerdictAtAnyTimestamp() public {
        vm.warp(0);
        uint256 a = _createAtZero(1);
        vm.warp(50);
        uint256 b = _createAtZero(1);
        assertEq(uint8(cover.outcomeOf(a)), uint8(MicroCover.Outcome.NONE));
        assertEq(uint8(cover.outcomeOf(b)), uint8(MicroCover.Outcome.NONE));
        _admit(a);
        assertEq(uint8(cover.outcomeOf(a)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(uint8(cover.outcomeOf(b)), uint8(MicroCover.Outcome.NONE), "isolated");
    }

    function testFuzz_OutcomeIndependentOfTimestamp(uint64 ts) public {
        ts = uint64(bound(ts, 0, 1e12));
        vm.warp(ts);
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, ESC, 1, ts + 100, ts + 200, bytes32(0));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE));
        _admit(id);
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(cover.getState(id).failureAdmittedAt, ts);
    }
}

/// Regression tests for the Phase 1 draft review: a payout is complete only when the recipient
/// actually gained the full amount. Fees are toggled only AFTER enrolling.
contract ReviewRecipientFeeTest is Phase1Base {
    RecipientFeeUSDC internal rf;

    function _deployToken() internal override returns (MockUSDC) {
        rf = new RecipientFeeUSDC();
        return rf;
    }

    function _threeAdmitted() internal returns (uint256 id) {
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
    }

    function test_RecipientFeeCannotDischargeLiability() public {
        uint256 id = _threeAdmitted();
        uint256 aliceBefore = usdc.balanceOf(alice);
        bytes32 before_ = _snap(id);

        rf.configure(address(cover), address(0), true);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, alice, 7e6, aliceBefore, aliceBefore + 6.3e6)
        );
        cover.settleFailure(id, 1);

        assertEq(_snap(id), before_, "every ledger, flag and balance rolled back");
        assertFalse(cover.isPaid(id, alice));
        assertEq(cover.getState(id).paidCount, 0);
        assertEq(cover.reservedOf(id), 15e6);
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(usdc.balanceOf(address(cover)), 21e6);

        // The obligation is preserved: once the fee is gone the exact 7 USDC is paid.
        rf.configure(address(cover), address(0), false);
        assertEq(_settle(id, 1), 1);
        assertEq(usdc.balanceOf(alice), aliceBefore + 7e6);
        assertTrue(cover.isPaid(id, alice));
    }

    function test_RecipientFeeOnLastRecipientRollsBackEarlierTransfersInBatch() public {
        uint256 id = _threeAdmitted();
        uint256 aliceBal = usdc.balanceOf(alice);
        uint256 bobBal = usdc.balanceOf(bob);
        uint256 carolBal = usdc.balanceOf(carol);
        bytes32 before_ = _snap(id);

        // Only carol (the third payout of the batch) is charged a recipient fee.
        rf.configure(address(cover), carol, true);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, carol, 7e6, carolBal, carolBal + 6.3e6)
        );
        cover.settleFailure(id, 3);

        assertEq(_snap(id), before_);
        assertEq(usdc.balanceOf(alice), aliceBal, "earlier transfer in the failing batch rolled back");
        assertEq(usdc.balanceOf(bob), bobBal, "earlier transfer in the failing batch rolled back");
        assertEq(usdc.balanceOf(carol), carolBal);
        assertFalse(cover.isPaid(id, alice));
        assertFalse(cover.isPaid(id, bob));
        assertFalse(cover.isPaid(id, carol));
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));

        rf.configure(address(cover), address(0), false);
        assertEq(_settle(id, 20), 3);
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
    }

    function test_RecipientFeeMidSettlementKeepsEarlierBatchAndRollsBackLaterOne() public {
        uint256 id = _threeAdmitted();
        assertEq(_settle(id, 1), 1); // alice paid before any fee exists
        uint256 bobBefore = usdc.balanceOf(bob);
        bytes32 before_ = _snap(id);

        rf.configure(address(cover), address(0), true);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, bob, 7e6, bobBefore, bobBefore + 6.3e6)
        );
        cover.settleFailure(id, 2);

        assertEq(_snap(id), before_);
        assertTrue(cover.isPaid(id, alice), "the earlier confirmed batch stays paid");
        assertFalse(cover.isPaid(id, bob));
        assertEq(cover.getState(id).paidCount, 1);
        assertEq(cover.getState(id).remainingOwed, 14e6);
    }

    function test_RecipientFeeOnProviderLeftoverWithdrawalRollsBack() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        assertEq(_settle(id, 20), 2);
        uint256 providerBefore = usdc.balanceOf(provider);
        bytes32 before_ = _snap(id);

        rf.configure(address(cover), address(0), true);
        vm.prank(provider);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectRecipientReceipt.selector, provider, 5e6, providerBefore, providerBefore + 4.5e6)
        );
        cover.withdrawRemainingBond(id);

        assertEq(_snap(id), before_);
        assertEq(cover.bondOf(id), COMP, "leftover bond still owed to the provider");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(cover.getState(id).withdrawableBond, COMP);

        rf.configure(address(cover), address(0), false);
        assertEq(_withdraw(id), COMP);
        assertEq(usdc.balanceOf(provider), providerBefore + COMP);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_ExactRecipientReceiptStillSucceedsWithFeeConfiguredForOtherAddress() public {
        uint256 id = _threeAdmitted();
        // Fee targets an address that is not owed anything: payouts are unaffected.
        rf.configure(address(cover), dave, true);
        assertEq(_settle(id, 20), 3);
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
    }
}
