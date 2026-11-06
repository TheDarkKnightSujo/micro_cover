// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// Drives bounded Phase 1 + Phase 2 actions (create/join/propose/dispute/uncertain/finalize/release/
/// admit/settle/withdraw/warp/donate) from synthetic actors. Expected reverts are tolerated, but every
/// outcome is checked against a model of when each call must (not) succeed and with which revert
/// reason; contradictions are recorded in `violations`.
contract MicroCoverHandler is Test {
    MicroCover public cover;
    MockUSDC public usdc;
    address public operator;
    address[] public actors;

    uint256 internal constant POOL = 60;
    uint256 internal constant MAX_IDS = 12;
    mapping(address => bool) internal poolReady;

    struct Pre {
        MicroCover.GuaranteeState s;
        MicroCover.LifecycleView l;
        MicroCover.Guarantee g;
        bytes32 ledger;
        uint256 bal;
    }

    // ---- ghost state ----
    uint256 public ghostDonations;
    mapping(uint256 id => uint256) public ghostWithdrawn;
    mapping(uint256 id => uint8) public lastStatus;
    mapping(uint256 id => uint8) public lastOutcome;
    mapping(uint256 id => uint32) internal lastPaid;
    mapping(uint256 id => uint32) internal lastCohort;
    mapping(uint256 id => uint64) internal lastAdmittedAt;
    uint256 public violations;
    string public firstViolation;
    uint256 public illegalTransitions;
    string public firstIllegal;
    uint256 public outcomeChanges;

    // ---- coverage counters ----
    uint256 public nCreate;
    uint256 public nJoin;
    uint256 public nAdmit;
    uint256 public nSettle;
    uint256 public nSettledBeneficiaries;
    uint256 public nWithdraw;
    uint256 public nClosed;
    uint256 public nPropose;
    uint256 public nDispute;
    uint256 public nUncertain;
    uint256 public nFinalize;
    uint256 public nRelease;
    uint256 public nSuccessClosed;
    uint256 public nFailureClosed;
    uint256 public nPendingToFailure;
    uint256 public nUncertainToFailure;
    uint256 public nOpenToFailure;

    constructor(MicroCover cover_, MockUSDC usdc_) {
        cover = cover_;
        usdc = usdc_;
        operator = cover_.demoOperator();
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

    function _sel(bytes memory ret) internal pure returns (bytes4) {
        return bytes4(ret);
    }

    function _ledger(uint256 id) internal view returns (bytes32) {
        return keccak256(
            abi.encode(cover.bondOf(id), cover.escrowedOf(id), cover.reservedOf(id), usdc.balanceOf(address(cover)))
        );
    }

    function _pre(uint256 id) internal view returns (Pre memory p) {
        p.s = cover.getState(id);
        p.l = cover.getLifecycle(id);
        p.g = cover.getGuarantee(id);
        p.ledger = _ledger(id);
        p.bal = usdc.balanceOf(address(cover));
    }

    function _earliest(MicroCover.Guarantee memory g) internal pure returns (uint256 e) {
        e = uint256(g.joinDeadline) + 1;
        if (g.settlementTime > e) e = g.settlementTime;
    }

    /// The explicit legal-transition table for Status values (0 OPEN, 1 FAILED, 2 CLOSED,
    /// 3 SUCCESS_PENDING, 4 SUCCEEDED, 5 UNCERTAIN).
    function legal(uint8 from, uint8 to) public pure returns (bool) {
        if (from == 0) return to == 3 || to == 5 || to == 1;
        if (from == 3) return to == 5 || to == 1 || to == 4;
        if (from == 5) return to == 1;
        if (from == 1) return to == 2;
        if (from == 4) return to == 2;
        return false; // CLOSED -> nothing
    }

    function outcomeMatchesStatus(uint8 status, uint8 outcome) public pure returns (bool) {
        if (status == 0 || status == 3 || status == 5) return outcome == 0;
        if (status == 1) return outcome == 1;
        if (status == 4) return outcome == 2;
        return outcome == 1 || outcome == 2; // CLOSED keeps its verdict
    }

    /// Records transition / monotonicity violations after every action.
    function _track() internal {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.GuaranteeState memory s = cover.getState(id);
            uint8 st = uint8(s.status);
            uint8 prev = lastStatus[id];
            if (st != prev && !legal(prev, st)) {
                illegalTransitions++;
                if (illegalTransitions == 1) {
                    firstIllegal = string.concat(
                        "illegal transition ", vm.toString(uint256(prev)), "->", vm.toString(uint256(st))
                    );
                }
            }
            if (prev != 0 && s.enrolled != lastCohort[id]) _violate("cohort changed after enrollment closed");
            if (s.paidCount < lastPaid[id]) _violate("paidCount went backwards");
            if (s.enrolled < lastCohort[id]) _violate("cohort shrank");
            if (lastAdmittedAt[id] != 0 && s.failureAdmittedAt != lastAdmittedAt[id]) {
                _violate("failure admission changed");
            }
            uint8 o = uint8(s.outcome);
            if (lastOutcome[id] != 0 && o != lastOutcome[id]) outcomeChanges++;
            if (!outcomeMatchesStatus(st, o)) _violate("outcome does not match status");
            lastStatus[id] = st;
            lastOutcome[id] = o;
            lastPaid[id] = s.paidCount;
            lastCohort[id] = s.enrolled;
            lastAdmittedAt[id] = s.failureAdmittedAt;
        }
    }

    // ------------------------------------------------------------ Phase 1 actions

    function create(uint256 actorSeed, uint256 comp, uint256 escrow, uint256 maxC, uint256 deadline) external {
        // Cap the number of guarantees so the per-call invariant loops stay cheap.
        if (cover.nextGuaranteeId() > MAX_IDS) return;
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        uint64 dl = uint64(block.timestamp + bound(deadline, 1 hours, 3 days));
        // The settlement gap is derived from the raw seed: 0, 1s, 1h or 1 day after the deadline.
        uint256 sel = deadline % 4;
        uint64 gap = sel == 0 ? 0 : sel == 1 ? 1 : sel == 2 ? 1 hours : 1 days;
        vm.prank(who);
        cover.createGuarantee(
            uint128(bound(comp, 1, 1e9)), uint128(bound(escrow, 1, 1e9)), uint32(bound(maxC, 1, 100)),
            dl, dl + gap, bytes32(0)
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
            if (pre.status != MicroCover.Status.OPEN) _violate("join succeeded after enrollment closed");
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
        _tryAdmit(id, caller);
        _track();
    }

    function _tryAdmit(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool terminalFail = p.s.status == MicroCover.Status.FAILED
            || (p.s.status == MicroCover.Status.CLOSED && p.s.outcome == MicroCover.Outcome.FAILURE);
        bool terminalSuccess = p.s.status == MicroCover.Status.SUCCEEDED
            || (p.s.status == MicroCover.Status.CLOSED && p.s.outcome == MicroCover.Outcome.SUCCESS);
        bool shouldWork = caller == p.g.provider && !terminalFail && !terminalSuccess;
        vm.prank(caller);
        try cover.admitFailure(id) {
            nAdmit++;
            if (!shouldWork) _violate("admit succeeded illegitimately");
            if (p.s.status == MicroCover.Status.OPEN) nOpenToFailure++;
            if (p.s.status == MicroCover.Status.SUCCESS_PENDING) nPendingToFailure++;
            if (p.s.status == MicroCover.Status.UNCERTAIN) nUncertainToFailure++;
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            if (l.status != MicroCover.Status.FAILED || l.outcome != MicroCover.Outcome.FAILURE) {
                _violate("admit did not record FAILED/FAILURE");
            }
            if (l.successReadyAt != 0) _violate("admit left successReadyAt set");
            if (_ledger(id) != p.ledger) _violate("admit moved funds or ledgers");
        } catch (bytes memory ret) {
            if (shouldWork) _violate("admit reverted unexpectedly");
            bytes4 want = caller != p.g.provider
                ? MicroCover.NotProvider.selector
                : terminalFail ? MicroCover.AlreadyAdmitted.selector : MicroCover.SuccessAlreadyFinalized.selector;
            if (_sel(ret) != want) _violate("admit wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted admit moved funds");
        }
    }

    function settle(uint256 callerSeed, uint256 idSeed, uint256 batchSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        uint32 batch = uint32(bound(batchSeed, 0, 24)); // 0 and 21..24 are invalid
        _trySettle(id, batch, _anyCaller(callerSeed));
        _track();
    }

    function _trySettle(uint256 id, uint32 batch, address caller) internal {
        MicroCover.GuaranteeState memory pre = cover.getState(id);
        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        uint256 balBefore = usdc.balanceOf(address(cover));
        // Only a failure verdict opens settlement: never OPEN / pending / uncertain / success.
        bool shouldWork = batch >= 1 && batch <= 20 && pre.outcome == MicroCover.Outcome.FAILURE
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
            if (cover.statusOf(id) == MicroCover.Status.CLOSED && pre.status != MicroCover.Status.CLOSED) {
                nClosed++;
                nFailureClosed++;
            }
        } catch {
            if (shouldWork) _violate("settle reverted unexpectedly");
            if (usdc.balanceOf(address(cover)) != balBefore) _violate("reverted settle moved funds");
        }
    }

    function withdraw(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        address prov = cover.getGuarantee(id).provider;
        _tryWithdraw(id, callerSeed % 3 != 0 ? prov : actors[(callerSeed / 3) % actors.length]);
        _track();
    }

    function _withdrawWant(Pre memory p, address caller) internal pure returns (bool works, bytes4 want) {
        MicroCover.Status st = p.s.status;
        if (caller != p.g.provider) return (false, MicroCover.NotProvider.selector);
        if (st == MicroCover.Status.OPEN) return (false, MicroCover.NotFailed.selector);
        if (st == MicroCover.Status.CLOSED) return (false, MicroCover.NothingToWithdraw.selector);
        if (st == MicroCover.Status.SUCCEEDED) {
            if (!p.l.successEscrowReleased) return (false, MicroCover.SuccessEscrowNotReleased.selector);
            return (true, bytes4(0));
        }
        if (st == MicroCover.Status.FAILED) {
            if (p.s.paidCount < p.s.enrolled) return (false, MicroCover.LiabilitiesUnpaid.selector);
            return (true, bytes4(0));
        }
        return (false, MicroCover.InvalidStatus.selector); // SUCCESS_PENDING, UNCERTAIN
    }

    function _tryWithdraw(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        uint256 provBal = usdc.balanceOf(p.g.provider);
        (bool shouldWork, bytes4 want) = _withdrawWant(p, caller);
        vm.prank(caller);
        try cover.withdrawRemainingBond(id) returns (uint256 amount) {
            nWithdraw++;
            nClosed++;
            ghostWithdrawn[id] += amount;
            if (!shouldWork) _violate("withdraw succeeded illegitimately");
            bool success = p.s.status == MicroCover.Status.SUCCEEDED;
            uint256 comp = p.g.compensation;
            if (success) {
                nSuccessClosed++;
                if (amount != comp * p.g.maxCohort) _violate("success withdraw is not the whole original bond");
            } else {
                nFailureClosed++;
                if (amount != comp * (p.g.maxCohort - p.g.cohortSize)) _violate("leftover wrong");
            }
            if (amount != p.s.bondHeld) _violate("withdraw != bondOf");
            if (p.bal - usdc.balanceOf(address(cover)) != amount) _violate("withdraw debit mismatch");
            if (usdc.balanceOf(p.g.provider) - provBal != amount) _violate("provider credit mismatch");
            if (cover.statusOf(id) != MicroCover.Status.CLOSED) _violate("withdraw did not close");
            if (cover.getLifecycle(id).withdrawnBond != amount) _violate("withdrawnBond mismatch");
        } catch (bytes memory ret) {
            if (shouldWork) _violate("withdraw reverted unexpectedly");
            if (_sel(ret) != want) _violate("withdraw wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted withdraw moved funds");
        }
    }

    // ------------------------------------------------------------ Phase 2 actions

    function propose(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        _tryPropose(id, callerSeed % 3 != 0 ? operator : _anyCaller(callerSeed / 3));
        _track();
    }

    function _tryPropose(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool shouldWork = caller == operator && p.s.status == MicroCover.Status.OPEN
            && block.timestamp >= _earliest(p.g);
        vm.prank(caller);
        try cover.proposeSuccess(id) {
            nPropose++;
            if (!shouldWork) _violate("propose succeeded illegitimately");
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            uint256 ready = block.timestamp + cover.reviewWindow();
            if (l.claimEndsAt > ready) ready = l.claimEndsAt;
            if (l.status != MicroCover.Status.SUCCESS_PENDING || l.outcome != MicroCover.Outcome.NONE) {
                _violate("propose did not set SUCCESS_PENDING with no verdict");
            }
            if (l.successReadyAt != ready || l.successProposedAt != block.timestamp) _violate("propose timing wrong");
            if (_ledger(id) != p.ledger) _violate("propose moved funds or ledgers");
        } catch (bytes memory ret) {
            if (shouldWork) _violate("propose reverted unexpectedly");
            bytes4 want = caller != operator
                ? MicroCover.NotDemoOperator.selector
                : p.s.status != MicroCover.Status.OPEN ? MicroCover.InvalidStatus.selector : MicroCover.ProposalTooEarly.selector;
            if (_sel(ret) != want) _violate("propose wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted propose moved funds");
        }
    }

    function dispute(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        _tryDispute(id, _disputer(id, callerSeed));
        _track();
    }

    function _disputer(uint256 id, uint256 callerSeed) internal returns (address) {
        uint256 n = cover.beneficiaryCount(id);
        if (n > 0 && callerSeed % 4 != 0) return cover.beneficiaryAt(id, (callerSeed / 4) % n);
        return _anyCaller(callerSeed / 4);
    }

    function _tryDispute(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool member = cover.isMember(id, caller);
        MicroCover.Status st = p.s.status;
        bool open = st == MicroCover.Status.OPEN;
        bool pending = st == MicroCover.Status.SUCCESS_PENDING;
        bool inWindow = (open && block.timestamp <= p.l.claimEndsAt)
            || (pending && block.timestamp <= p.l.successReadyAt);
        bool shouldWork = member && inWindow;
        vm.prank(caller);
        try cover.raiseDispute(id) {
            nDispute++;
            if (!shouldWork) _violate("dispute succeeded illegitimately");
            _checkFrozen(id, p, caller);
        } catch (bytes memory ret) {
            if (shouldWork) _violate("dispute reverted unexpectedly");
            bytes4 want = !member
                ? MicroCover.NotBeneficiary.selector
                : (open || pending) ? MicroCover.DisputeWindowClosed.selector : MicroCover.InvalidStatus.selector;
            if (_sel(ret) != want) _violate("dispute wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted dispute moved funds");
        }
    }

    function markUncertain(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        _tryUncertain(id, callerSeed % 2 == 0 ? operator : _anyCaller(callerSeed / 2));
        _track();
    }

    function _tryUncertain(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool live = p.s.status == MicroCover.Status.OPEN || p.s.status == MicroCover.Status.SUCCESS_PENDING;
        bool shouldWork = caller == operator && live;
        vm.prank(caller);
        try cover.markUncertain(id) {
            nUncertain++;
            if (!shouldWork) _violate("markUncertain succeeded illegitimately");
            _checkFrozen(id, p, caller);
        } catch (bytes memory ret) {
            if (shouldWork) _violate("markUncertain reverted unexpectedly");
            bytes4 want = caller != operator ? MicroCover.NotDemoOperator.selector : MicroCover.InvalidStatus.selector;
            if (_sel(ret) != want) _violate("markUncertain wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted markUncertain moved funds");
        }
    }

    function _checkFrozen(uint256 id, Pre memory p, address by) internal {
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        if (l.status != MicroCover.Status.UNCERTAIN || l.outcome != MicroCover.Outcome.NONE) {
            _violate("freeze did not set UNCERTAIN with no verdict");
        }
        if (l.successReadyAt != 0 || l.uncertainBy != by || l.uncertainAt != block.timestamp) {
            _violate("freeze lifecycle fields wrong");
        }
        if (l.successProposedAt != p.l.successProposedAt) _violate("freeze rewrote proposal history");
        if (_ledger(id) != p.ledger) _violate("freeze moved funds or ledgers");
    }

    function finalize(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        _tryFinalize(id, _anyCaller(callerSeed));
        _track();
    }

    function _tryFinalize(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool pending = p.s.status == MicroCover.Status.SUCCESS_PENDING;
        bool shouldWork = pending && block.timestamp > p.l.successReadyAt;
        vm.prank(caller);
        try cover.finalizeSuccess(id) {
            nFinalize++;
            if (!shouldWork) _violate("finalize succeeded illegitimately");
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            if (l.status != MicroCover.Status.SUCCEEDED || l.outcome != MicroCover.Outcome.SUCCESS) {
                _violate("finalize did not record SUCCEEDED/SUCCESS");
            }
            if (cover.reservedOf(id) != 0 || l.releasedSuccessReservation != p.s.reservedCompensation) {
                _violate("finalize reservation release wrong");
            }
            if (l.successFinalizedAt != block.timestamp) _violate("finalize timestamp wrong");
            if (usdc.balanceOf(address(cover)) != p.bal) _violate("finalize moved tokens");
            if (cover.bondOf(id) != p.s.bondHeld || cover.escrowedOf(id) != p.s.escrowHeld) {
                _violate("finalize touched bond/escrow");
            }
        } catch (bytes memory ret) {
            if (shouldWork) _violate("finalize reverted unexpectedly");
            bytes4 want = !pending ? MicroCover.InvalidStatus.selector : MicroCover.ReviewWindowOpen.selector;
            if (_sel(ret) != want) _violate("finalize wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted finalize moved funds");
        }
    }

    function release(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        _tryRelease(id, _anyCaller(callerSeed));
        _track();
    }

    function _tryRelease(uint256 id, address caller) internal {
        Pre memory p = _pre(id);
        bool succeeded = p.s.status == MicroCover.Status.SUCCEEDED;
        bool shouldWork = succeeded && !p.l.successEscrowReleased;
        uint256 provBal = usdc.balanceOf(p.g.provider);
        vm.prank(caller);
        try cover.releaseSuccessEscrow(id) returns (uint256 amount) {
            nRelease++;
            if (!shouldWork) _violate("release succeeded illegitimately");
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            if (amount != p.s.escrowHeld || l.releasedSuccessEscrow != amount || !l.successEscrowReleased) {
                _violate("release amount/record wrong");
            }
            if (amount != uint256(p.g.escrowAmount) * p.g.cohortSize) _violate("release != escrow * cohort");
            if (cover.escrowedOf(id) != 0) _violate("release left escrow behind");
            if (p.bal - usdc.balanceOf(address(cover)) != amount) _violate("release debit mismatch");
            if (usdc.balanceOf(p.g.provider) - provBal != amount) _violate("release did not go to the provider");
            if (cover.bondOf(id) != p.s.bondHeld) _violate("release touched bond");
        } catch (bytes memory ret) {
            if (shouldWork) _violate("release reverted unexpectedly");
            bytes4 want =
                !succeeded ? MicroCover.InvalidStatus.selector : MicroCover.SuccessEscrowAlreadyReleased.selector;
            if (_sel(ret) != want) _violate("release wrong revert reason");
            if (_ledger(id) != p.ledger) _violate("reverted release moved funds");
        }
    }

    // ------------------------------------------------------------ guided macros (one protocol step each)

    /// Performs the next legitimate success-path step for the chosen guarantee, warping just far enough.
    function advanceSuccess(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        MicroCover.GuaranteeState memory s = cover.getState(id);
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        if (s.status == MicroCover.Status.OPEN) {
            uint256 e = _earliest(cover.getGuarantee(id));
            if (block.timestamp < e) vm.warp(e);
            _tryPropose(id, operator);
        } else if (s.status == MicroCover.Status.SUCCESS_PENDING) {
            if (block.timestamp <= l.successReadyAt) vm.warp(uint256(l.successReadyAt) + 1);
            _tryFinalize(id, _anyCaller(callerSeed));
        } else if (s.status == MicroCover.Status.SUCCEEDED) {
            if (!l.successEscrowReleased) {
                _tryRelease(id, _anyCaller(callerSeed));
            } else {
                _tryWithdraw(id, cover.getGuarantee(id).provider);
            }
        }
        _track();
    }

    /// Performs the next step towards a failure verdict: freeze (dispute / operator) or admit, then settle.
    function advanceFailure(uint256 callerSeed, uint256 idSeed) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        MicroCover.GuaranteeState memory s = cover.getState(id);
        address prov = cover.getGuarantee(id).provider;
        if (s.status == MicroCover.Status.OPEN || s.status == MicroCover.Status.SUCCESS_PENDING) {
            if (callerSeed % 3 == 1) {
                _tryDispute(id, _disputer(id, callerSeed));
                if (cover.statusOf(id) != MicroCover.Status.UNCERTAIN) _tryUncertain(id, operator);
            } else if (callerSeed % 3 == 2) {
                _tryUncertain(id, operator);
            } else {
                _tryAdmit(id, prov);
            }
        } else if (s.status == MicroCover.Status.UNCERTAIN) {
            _tryAdmit(id, prov);
        } else if (s.status == MicroCover.Status.FAILED) {
            if (s.paidCount < s.enrolled) {
                _trySettle(id, uint32(1 + callerSeed % 20), _anyCaller(callerSeed));
            } else {
                _tryWithdraw(id, prov);
            }
        }
        _track();
    }

    // ------------------------------------------------------------ time and donations

    function warp(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 0, 2 days));
        _track();
    }

    /// Small forward steps so successive calls land on both sides of a boundary.
    function warpSmall(uint256 secs) external {
        vm.warp(block.timestamp + bound(secs, 0, 300));
        _track();
    }

    /// Warps to within [-1, +2] seconds of joinDeadline / settlementTime / claimEndsAt / successReadyAt.
    function warpToBoundary(uint256 idSeed, uint256 which, uint256 delta) external {
        (uint256 id, bool ok) = _pickId(idSeed);
        if (!ok) return;
        MicroCover.LifecycleView memory l = cover.getLifecycle(id);
        uint256 w = which % 4;
        uint256 target = w == 0 ? l.joinDeadline : w == 1 ? l.settlementTime : w == 2 ? l.claimEndsAt : l.successReadyAt;
        if (target == 0) return;
        target = target + bound(delta, 0, 3) - 1;
        if (target > block.timestamp) vm.warp(target);
        _track();
    }

    function donate(uint256 actorSeed, uint256 amount) external {
        address who = actors[bound(actorSeed, 0, actors.length - 1)];
        uint256 amt = bound(amount, 1, 1e9);
        vm.prank(who);
        usdc.transfer(address(cover), amt);
        ghostDonations += amt;
    }
}

/// forge-config: default.invariant.runs = 64
/// forge-config: default.invariant.depth = 150
contract MicroCoverInvariantTest is Test {
    MicroCover internal cover;
    MockUSDC internal usdc;
    MicroCoverHandler internal handler;
    address internal operator = makeAddr("demoOperator");
    uint64 internal constant WINDOW = 120;

    function setUp() public {
        usdc = new MockUSDC();
        cover = new MicroCover(IERC20(address(usdc)), operator, WINDOW);
        handler = new MicroCoverHandler(cover, usdc);
        targetContract(address(handler));
        bytes4[] memory sels = new bytes4[](17);
        sels[0] = handler.create.selector;
        sels[1] = handler.join.selector;
        sels[2] = handler.joinMany.selector;
        sels[3] = handler.admit.selector;
        sels[4] = handler.settle.selector;
        sels[5] = handler.withdraw.selector;
        sels[6] = handler.propose.selector;
        sels[7] = handler.dispute.selector;
        sels[8] = handler.markUncertain.selector;
        sels[9] = handler.finalize.selector;
        sels[10] = handler.release.selector;
        sels[11] = handler.advanceSuccess.selector;
        sels[12] = handler.advanceFailure.selector;
        sels[13] = handler.warp.selector;
        sels[14] = handler.warpSmall.selector;
        sels[15] = handler.warpToBoundary.selector;
        sels[16] = handler.donate.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: sels}));
    }

    // ------------------------------------------------------------ deterministic reachability smoke tests

    function _newPool(uint256 actor, uint256 comp, uint256 esc, uint256 maxC, uint256 joiners) internal returns (uint256 id) {
        handler.create(actor, comp, esc, maxC, 1 days);
        id = cover.nextGuaranteeId() - 1;
        handler.joinMany(id, joiners, 0);
    }

    function _toWindow() internal {
        vm.warp(block.timestamp + 1 days + 1); // past the 1-day join deadline; settlement == deadline (gap 0)
    }

    function test_HandlerReachesPartialCohortWithdrawal() public {
        uint256 id = _newPool(0, 5, 3, 50, 10);
        handler.admit(0, id);
        handler.settle(0, id, 20);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        handler.withdraw(1, id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(handler.nFailureClosed(), 1);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesFullCohortClosedByPayout() public {
        uint256 id = _newPool(1, 7, 4, 30, 30);
        assertEq(cover.getGuarantee(id).cohortSize, 30);
        handler.admit(0, id);
        handler.settle(0, id, 20);
        handler.settle(0, id, 20);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(handler.nClosed(), 1);
        assertEq(handler.nSettledBeneficiaries(), 30);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesSuccessClosure() public {
        uint256 id = _newPool(0, 5, 3, 50, 10);
        _toWindow();
        handler.propose(1, id); // callerSeed % 3 != 0 -> the operator
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        handler.finalize(0, id); // too early: tolerated and checked as an expected revert
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.SUCCESS_PENDING));
        vm.warp(block.timestamp + WINDOW + 1);
        handler.finalize(0, id);
        handler.withdraw(1, id); // before release: expected SuccessEscrowNotReleased
        handler.release(0, id);
        handler.withdraw(1, id);
        handler.settle(0, id, 5); // success never opens settlement
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.SUCCESS));
        assertEq(handler.nSuccessClosed(), 1);
        assertEq(handler.nFinalize(), 1);
        assertEq(handler.nRelease(), 1);
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesUncertain() public {
        uint256 a = _newPool(0, 5, 3, 50, 10);
        handler.dispute(1, a); // callerSeed % 4 != 0 -> an enrolled member
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(handler.nDispute(), 1);
        uint256 b = _newPool(2, 5, 3, 50, 10);
        handler.dispute(0, b); // callerSeed % 4 == 0 -> arbitrary caller: must be rejected unless a member
        handler.markUncertain(0, b); // callerSeed % 2 == 0 -> the operator
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(handler.nUncertain(), 1);
        _toWindow();
        handler.propose(1, a); // UNCERTAIN cannot be proposed
        handler.advanceSuccess(0, a); // nor advanced to success
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.UNCERTAIN));
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesPendingToFailure() public {
        uint256 id = _newPool(0, 5, 3, 50, 10);
        _toWindow();
        handler.propose(1, id);
        handler.admit(0, id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(handler.nPendingToFailure(), 1);
        handler.settle(0, id, 20);
        handler.withdraw(1, id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesDisputeToFailureClosure() public {
        uint256 id = _newPool(0, 5, 3, 50, 10);
        _toWindow();
        handler.propose(1, id);
        handler.dispute(1, id); // member disputes inside the review window
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.UNCERTAIN));
        handler.admit(0, id);
        assertEq(handler.nUncertainToFailure(), 1);
        handler.settle(0, id, 20);
        handler.withdraw(1, id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(handler.nFailureClosed(), 1);
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    function test_HandlerReachesOperatorUncertainToFailureClosure() public {
        uint256 id = _newPool(0, 5, 3, 50, 10);
        _toWindow();
        handler.propose(1, id);
        vm.warp(block.timestamp + WINDOW + 50); // review window over, not finalized yet
        handler.markUncertain(0, id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.UNCERTAIN));
        handler.advanceFailure(19, id); // admit (UNCERTAIN -> FAILED)
        handler.advanceFailure(19, id); // settle a full batch of 20 (cohort is 10)
        handler.advanceFailure(19, id); // withdraw the unreserved bond
        assertEq(handler.violations(), 0, handler.firstViolation());
        assertEq(uint256(cover.getState(id).paidCount), 10);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(handler.violations(), 0, handler.firstViolation());
    }

    /// A pseudo-random walk over the same action set the invariant fuzzer uses must reach every
    /// terminal kind, proving the invariants are not vacuous.
    function test_RandomDriver_ReachesEveryLifecycleKind() public {
        for (uint256 i; i < 1500; i++) {
            uint256 a = uint256(keccak256(abi.encode("a", i)));
            uint256 b = uint256(keccak256(abi.encode("b", i)));
            uint256 c = uint256(keccak256(abi.encode("c", i)));
            uint256 f = uint256(keccak256(abi.encode("f", i))) % 20;
            if (i % 120 == 0) handler.create(a, b, c, a >> 8, b >> 8);
            if (i % 120 == 0 && cover.nextGuaranteeId() > 1) {
                // Guided lifecycle on the newest guarantee so every terminal kind is always exercised.
                uint256 k = (i / 120) % 3;
                uint256 last = cover.nextGuaranteeId() - 1;
                handler.joinMany(last, 3, 0);
                if (k == 0) {
                    if ((i / 360) % 2 == 0) {
                        handler.dispute(1, last); // member dispute inside the claim window
                    } else {
                        handler.markUncertain(0, last); // operator freeze
                    }
                } else {
                    handler.warpToBoundary(last, 1, 2); // settlementTime + 1: proposable
                    handler.propose(1, last);
                    if (k == 1) {
                        handler.admit(0, last); // pending -> failure
                    } else {
                        handler.warpToBoundary(last, 3, 2); // readyAt + 1
                        handler.finalize(0, last);
                        handler.release(0, last);
                        handler.withdraw(1, last);
                    }
                }
            }
            if (f == 0 || f == 1) handler.join(a, b);
            else if (f == 2) handler.joinMany(a, b, c);
            else if (f == 3) handler.admit(a, b);
            else if (f == 4) handler.settle(a, b, c);
            else if (f == 5) handler.withdraw(a, b);
            else if (f == 6) handler.propose(a, b);
            else if (f == 7) handler.dispute(a, b);
            else if (f == 8) handler.markUncertain(a, b);
            else if (f == 9) handler.finalize(a, b);
            else if (f == 10) handler.release(a, b);
            else if (f == 11) handler.advanceSuccess(a, b);
            else if (f == 12) handler.admit(a, b);
            else if (f == 13) handler.advanceFailure(a, b);
            else if (f == 14) handler.warp(a);
            else if (f == 15 || f == 16) handler.warpSmall(a);
            else if (f == 17 || f == 18) handler.warpToBoundary(a, b, c);
            else handler.donate(a, b);
        }
        console2.log("driver: success closed", handler.nSuccessClosed());
        console2.log("driver: failure closed", handler.nFailureClosed());
        console2.log("driver: pending->failure", handler.nPendingToFailure());
        console2.log("driver: uncertain->failure", handler.nUncertainToFailure());
        console2.log("driver: disputes", handler.nDispute());
        console2.log("driver: operator uncertain", handler.nUncertain());
        assertEq(handler.violations(), 0, handler.firstViolation());
        assertGt(handler.nSuccessClosed(), 0, "success closure reached");
        assertGt(handler.nFailureClosed(), 0, "failure closure reached");
        assertGt(handler.nPendingToFailure(), 0, "pending -> failure reached");
        assertGt(handler.nUncertainToFailure(), 0, "uncertain -> failure reached");
        assertGt(handler.nDispute(), 0, "dispute reached");
        assertGt(handler.nUncertain(), 0, "operator uncertain reached");
        invariant_UsdcBalanceEqualsBondsPlusEscrowPlusDonations();
        invariant_PerGuaranteeLedgersConserve();
        invariant_StatusLifecycleConsistent();
        invariant_LifecycleFieldDiscipline();
    }

    // ------------------------------------------------------------ invariants

    function invariant_UsdcBalanceEqualsBondsPlusEscrowPlusDonations() public view {
        uint256 held;
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            held += cover.bondOf(id) + cover.escrowedOf(id);
        }
        assertEq(usdc.balanceOf(address(cover)), held + handler.ghostDonations(), "balance != bonds + escrow + donations");
    }

    function invariant_CohortBoundedAndEscrowConsistent() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            assertLe(g.cohortSize, g.maxCohort, "cohort exceeds max");
            assertEq(s.enrolled, g.cohortSize);
            assertEq(cover.beneficiaryCount(id), g.cohortSize);
            assertEq(
                cover.escrowedOf(id) + s.paidEscrow + l.releasedSuccessEscrow,
                uint256(g.escrowAmount) * g.cohortSize,
                "escrow identity"
            );
            assertLe(cover.reservedOf(id), cover.bondOf(id), "reserved exceeds bond");
        }
    }

    function invariant_PerGuaranteeLedgersConserve() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            uint256 comp = g.compensation;
            assertEq(s.paidCompensation, comp * s.paidCount);
            assertEq(s.paidEscrow, uint256(g.escrowAmount) * s.paidCount);
            // The three accounting identities hold at every moment of every guarantee.
            assertEq(cover.bondOf(id) + s.paidCompensation + l.withdrawnBond, comp * g.maxCohort, "bond identity");
            assertEq(l.withdrawnBond, handler.ghostWithdrawn(id), "withdrawn bond matches the handler ghost");
            assertEq(
                cover.reservedOf(id) + s.paidCompensation + l.releasedSuccessReservation,
                comp * g.cohortSize,
                "reservation identity"
            );
            uint256 owed = s.outcome == MicroCover.Outcome.SUCCESS
                ? 0
                : (comp + g.escrowAmount) * (g.cohortSize - s.paidCount);
            assertEq(s.remainingOwed, owed, "remainingOwed");
            bool closed = s.status == MicroCover.Status.CLOSED;
            uint256 wantWithdrawn;
            if (closed) {
                wantWithdrawn = s.outcome == MicroCover.Outcome.SUCCESS
                    ? comp * g.maxCohort
                    : comp * (g.maxCohort - g.cohortSize);
            }
            assertEq(l.withdrawnBond, wantWithdrawn, "withdrawn only on closure, exactly the unreserved/whole bond");
        }
    }

    function invariant_StatusLifecycleConsistent() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            MicroCover.Status st = s.status;
            uint256 comp = g.compensation;
            if (st == MicroCover.Status.OPEN) {
                assertTrue(s.outcome == MicroCover.Outcome.NONE, "OPEN has no verdict");
                assertEq(l.successReadyAt, 0);
                assertEq(l.successProposedAt, 0);
                assertEq(l.uncertainBy, address(0));
                assertEq(s.failureAdmittedAt, 0);
                assertEq(s.paidCount, 0);
            } else if (st == MicroCover.Status.SUCCESS_PENDING) {
                assertTrue(s.outcome == MicroCover.Outcome.NONE, "PENDING has no verdict");
                assertGt(l.successReadyAt, 0);
                assertGt(l.successProposedAt, 0);
                assertEq(l.uncertainBy, address(0));
                assertEq(s.paidCount, 0);
                assertEq(l.withdrawnBond, 0);
            } else if (st == MicroCover.Status.UNCERTAIN) {
                assertTrue(s.outcome == MicroCover.Outcome.NONE, "UNCERTAIN has no verdict");
                assertEq(l.successReadyAt, 0);
                assertTrue(l.uncertainBy != address(0));
                assertGt(l.uncertainAt, 0);
                assertEq(s.paidCount, 0);
                assertEq(l.withdrawnBond, 0);
            } else if (st == MicroCover.Status.FAILED) {
                assertTrue(s.outcome == MicroCover.Outcome.FAILURE, "FAILED carries FAILURE");
                assertGt(s.failureAdmittedAt, 0);
                assertEq(l.successReadyAt, 0);
                assertFalse(l.successEscrowReleased);
                assertLe(s.paidCount, s.enrolled);
            } else if (st == MicroCover.Status.SUCCEEDED) {
                assertTrue(s.outcome == MicroCover.Outcome.SUCCESS, "SUCCEEDED carries SUCCESS");
                assertGt(l.successFinalizedAt, 0);
                assertGt(l.successReadyAt, 0);
                assertEq(cover.reservedOf(id), 0);
                assertEq(l.releasedSuccessReservation, comp * g.cohortSize);
                assertEq(l.withdrawnBond, 0);
                assertEq(cover.bondOf(id), comp * g.maxCohort, "whole bond still held");
            } else if (s.outcome == MicroCover.Outcome.FAILURE) {
                // CLOSED after failure: everyone paid, nothing left.
                assertEq(s.paidCount, s.enrolled, "closed failure: all paid");
                assertEq(cover.bondOf(id), 0);
                assertEq(cover.escrowedOf(id), 0);
                assertEq(cover.reservedOf(id), 0);
                assertFalse(l.successEscrowReleased);
                assertEq(l.releasedSuccessEscrow, 0);
            } else {
                // CLOSED after success: nothing left, nobody paid, escrow went to the provider.
                assertTrue(s.outcome == MicroCover.Outcome.SUCCESS, "closed carries a verdict");
                assertEq(cover.bondOf(id), 0);
                assertEq(cover.escrowedOf(id), 0);
                assertEq(cover.reservedOf(id), 0);
                assertEq(s.paidCount, 0);
                assertTrue(l.successEscrowReleased);
                assertEq(l.releasedSuccessEscrow, uint256(g.escrowAmount) * g.cohortSize);
                assertEq(l.releasedSuccessReservation, comp * g.cohortSize);
            }
        }
    }

    function invariant_PaidFlagsAreAPrefixOfEnrollmentOrder() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.GuaranteeState memory s = cover.getState(id);
            uint256 n = cover.beneficiaryCount(id);
            for (uint256 i; i < n; i++) {
                assertEq(cover.isPaid(id, cover.beneficiaryAt(id, i)), i < s.paidCount, "paid flags are a prefix");
            }
        }
    }

    function invariant_SuccessVerdictNeverPaysCompensation() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.GuaranteeState memory s = cover.getState(id);
            if (s.outcome != MicroCover.Outcome.SUCCESS) continue;
            assertEq(s.paidCount, 0, "success pays nobody");
            assertEq(s.paidCompensation, 0);
            assertEq(s.paidEscrow, 0);
            assertEq(s.remainingOwed, 0);
            uint256 n = cover.beneficiaryCount(id);
            for (uint256 i; i < n; i++) {
                assertFalse(cover.isPaid(id, cover.beneficiaryAt(id, i)));
            }
        }
    }

    function invariant_LifecycleFieldDiscipline() public view {
        uint256 next = cover.nextGuaranteeId();
        for (uint256 id = 1; id < next; id++) {
            MicroCover.Guarantee memory g = cover.getGuarantee(id);
            MicroCover.GuaranteeState memory s = cover.getState(id);
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            bool success = s.outcome == MicroCover.Outcome.SUCCESS;
            bool live = s.status == MicroCover.Status.SUCCESS_PENDING;
            // successReadyAt is set only while pending or after success.
            if (l.successReadyAt != 0) assertTrue(live || success, "readyAt outside pending/success");
            // The escrow is released only after a success verdict, and then exactly in full.
            if (l.successEscrowReleased) {
                assertTrue(success, "escrow released without success");
                assertEq(l.releasedSuccessEscrow, uint256(g.escrowAmount) * g.cohortSize);
            } else {
                assertEq(l.releasedSuccessEscrow, 0);
            }
            // A success verdict was never uncertain, and a verdict is final.
            if (success) {
                assertEq(l.uncertainBy, address(0), "success after uncertainty");
                assertGt(l.successFinalizedAt, 0);
            } else {
                assertEq(l.successFinalizedAt, 0);
                assertEq(l.releasedSuccessReservation, 0);
            }
            assertLe(cover.reservedOf(id), cover.bondOf(id));
            assertLe(l.joinDeadline, l.settlementTime);
            assertEq(l.claimEndsAt, uint256(l.settlementTime) + cover.reviewWindow());
        }
    }

    function invariant_NoIllegalStatusTransitions() public view {
        assertEq(handler.illegalTransitions(), 0, handler.firstIllegal());
    }

    function invariant_OutcomeNeverChangesOnceSet() public view {
        assertEq(handler.outcomeChanges(), 0, "a terminal verdict was rewritten");
    }

    function invariant_NoHandlerViolations() public view {
        assertEq(handler.violations(), 0, handler.firstViolation());
    }
}
