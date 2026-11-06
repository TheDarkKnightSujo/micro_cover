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
    ReentrantUSDC,
    IRecipientHook
} from "./MockUSDC.sol";

/// Shared fixtures/helpers for all Phase 1 suites. Token type is swappable via _deployToken.
abstract contract Phase1Base is Test {
    MicroCover internal cover;
    MockUSDC internal usdc;

    address internal provider = makeAddr("provider");
    address internal provider2 = makeAddr("provider2");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");
    address internal stranger = makeAddr("stranger");

    uint128 internal constant COMP = 5e6;
    uint128 internal constant ESC = 2e6;
    uint32 internal constant MAXC = 3;
    uint256 internal constant START = 100e6;
    bytes32 internal constant TERMS = keccak256("phase1-terms");

    uint64 internal joinDeadline;
    uint64 internal settlementTime;
    mapping(address => bool) internal funded;

    function _deployToken() internal virtual returns (MockUSDC) {
        return new MockUSDC();
    }

    function setUp() public virtual {
        usdc = _deployToken();
        cover = new MicroCover(IERC20(address(usdc)));
        joinDeadline = uint64(block.timestamp + 1 days);
        settlementTime = uint64(block.timestamp + 7 days);
        _fundProvider(provider);
        _fundProvider(provider2);
        _fundUser(alice);
        _fundUser(bob);
        _fundUser(carol);
        _fundUser(dave);
        _fundUser(stranger);
    }

    // ------------------------------------------------------------ helpers

    function _fundProvider(address p) internal {
        usdc.mint(p, 10_000e6);
        vm.prank(p);
        usdc.approve(address(cover), type(uint256).max);
    }

    function _fundUser(address u) internal {
        if (funded[u]) return;
        funded[u] = true;
        usdc.mint(u, START);
        vm.prank(u);
        usdc.approve(address(cover), type(uint256).max);
    }

    function _user(uint256 i) internal pure returns (address) {
        return address(uint160(0x10000 + i));
    }

    function _create(address p, uint128 comp, uint128 esc, uint32 maxC) internal returns (uint256 id) {
        vm.prank(p);
        id = cover.createGuarantee(comp, esc, maxC, joinDeadline, settlementTime, TERMS);
    }

    function _create() internal returns (uint256) {
        return _create(provider, COMP, ESC, MAXC);
    }

    function _join(uint256 id, address who) internal {
        _fundUser(who);
        vm.prank(who);
        cover.joinCohort(id);
    }

    /// Enrolls _user(0.._n-1) in order.
    function _enroll(uint256 id, uint256 n) internal {
        for (uint256 i; i < n; i++) {
            _join(id, _user(i));
        }
    }

    function _providerOf(uint256 id) internal view returns (address) {
        return cover.getGuarantee(id).provider;
    }

    function _admit(uint256 id) internal {
        address p = _providerOf(id);
        vm.prank(p);
        cover.admitFailure(id);
    }

    function _settle(uint256 id, uint32 n) internal returns (uint32 settled) {
        vm.prank(stranger);
        settled = cover.settleFailure(id, n);
    }

    function _withdraw(uint256 id) internal returns (uint256 amount) {
        address p = _providerOf(id);
        vm.prank(p);
        amount = cover.withdrawRemainingBond(id);
    }

    function _check(uint256 id, MicroCover.GuaranteeState memory e, string memory tag) internal view {
        MicroCover.GuaranteeState memory s = cover.getState(id);
        assertEq(uint8(s.status), uint8(e.status), string.concat(tag, ": status"));
        assertEq(uint8(s.outcome), uint8(e.outcome), string.concat(tag, ": outcome"));
        assertEq(s.enrolled, e.enrolled, string.concat(tag, ": enrolled"));
        assertEq(s.paidCount, e.paidCount, string.concat(tag, ": paidCount"));
        assertEq(s.openSlots, e.openSlots, string.concat(tag, ": openSlots"));
        assertEq(s.failureAdmittedAt, e.failureAdmittedAt, string.concat(tag, ": failureAdmittedAt"));
        assertEq(s.bondHeld, e.bondHeld, string.concat(tag, ": bondHeld"));
        assertEq(s.reservedCompensation, e.reservedCompensation, string.concat(tag, ": reserved"));
        assertEq(s.escrowHeld, e.escrowHeld, string.concat(tag, ": escrowHeld"));
        assertEq(s.paidCompensation, e.paidCompensation, string.concat(tag, ": paidCompensation"));
        assertEq(s.paidEscrow, e.paidEscrow, string.concat(tag, ": paidEscrow"));
        assertEq(s.withdrawableBond, e.withdrawableBond, string.concat(tag, ": withdrawableBond"));
        assertEq(s.remainingOwed, e.remainingOwed, string.concat(tag, ": remainingOwed"));
        // The standalone ledger getters must agree with getState.
        assertEq(cover.bondOf(id), e.bondHeld, string.concat(tag, ": bondOf"));
        assertEq(cover.escrowedOf(id), e.escrowHeld, string.concat(tag, ": escrowedOf"));
        assertEq(cover.reservedOf(id), e.reservedCompensation, string.concat(tag, ": reservedOf"));
        assertEq(uint8(cover.statusOf(id)), uint8(e.status), string.concat(tag, ": statusOf"));
        assertEq(uint8(cover.outcomeOf(id)), uint8(e.outcome), string.concat(tag, ": outcomeOf"));
    }

    /// Opaque digest of every ledger/flag/balance relevant to guarantee `id` for rollback checks.
    function _snap(uint256 id) internal view returns (bytes32) {
        address[] memory bens = cover.getBeneficiaries(id);
        bytes memory acc = abi.encode(
            cover.getState(id), cover.bondOf(id), cover.escrowedOf(id), cover.reservedOf(id),
            usdc.balanceOf(address(cover)), usdc.balanceOf(_providerOf(id)), cover.nextGuaranteeId()
        );
        for (uint256 i; i < bens.length; i++) {
            acc = abi.encode(acc, bens[i], cover.isPaid(id, bens[i]), usdc.balanceOf(bens[i]));
        }
        return keccak256(acc);
    }
}

/// Scenarios 1 and 2: reference demo, partial and zero enrollment.
contract Phase1ReferenceAndPartialTest is Phase1Base {
    function test_ReferenceDemo_ExactBalances() public {
        uint256 provStart = usdc.balanceOf(provider);
        address[3] memory bens = [alice, bob, carol];
        uint256[3] memory start;
        for (uint256 i; i < 3; i++) {
            start[i] = usdc.balanceOf(bens[i]);
        }

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.GuaranteeCreated(1, provider, 5e6, 2e6, 3, joinDeadline, settlementTime, TERMS, 15e6);
        uint256 id = _create(provider, 5e6, 2e6, 3);
        assertEq(usdc.balanceOf(provider), provStart - 15e6, "provider funded 15e6 upfront");
        assertEq(usdc.balanceOf(address(cover)), 15e6);

        MicroCover.GuaranteeState memory e;
        e.openSlots = 3;
        e.bondHeld = 15e6;
        _check(id, e, "created");

        for (uint256 i; i < 3; i++) {
            vm.expectEmit(true, true, false, true, address(cover));
            emit MicroCover.CohortJoined(id, bens[i], uint32(i + 1));
            _join(id, bens[i]);
            e.enrolled = uint32(i + 1);
            e.openSlots = uint32(2 - i);
            e.reservedCompensation = 5e6 * (i + 1);
            e.escrowHeld = 2e6 * (i + 1);
            e.remainingOwed = 7e6 * (i + 1); // prospective obligation: (escrow + compensation) per enrollee
            _check(id, e, "joined");
            assertEq(usdc.balanceOf(bens[i]), start[i] - 2e6);
        }
        assertEq(usdc.balanceOf(address(cover)), 21e6, "15 bond + 6 escrow");
        assertEq(cover.reservedOf(id), 15e6, "reserved 15 after full");
        assertFalse(cover.isJoinable(id));

        // Admit failure: no tokens move.
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.FailureAdmitted(id, provider, 3, 21e6);
        vm.prank(provider);
        cover.admitFailure(id);
        e.status = MicroCover.Status.FAILED;
        e.outcome = MicroCover.Outcome.FAILURE;
        e.failureAdmittedAt = uint64(block.timestamp);
        e.openSlots = 0;
        e.remainingOwed = 21e6;
        _check(id, e, "admitted");
        assertEq(usdc.balanceOf(address(cover)), 21e6, "admit moves nothing");

        // Settle everything in one permissionless call.
        for (uint256 i; i < 3; i++) {
            vm.expectEmit(true, true, false, true, address(cover));
            emit MicroCover.BeneficiaryPaid(id, bens[i], 2e6, 5e6);
        }
        vm.expectEmit(true, false, false, false, address(cover));
        emit MicroCover.GuaranteeClosed(id);
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.SettlementBatchProcessed(id, stranger, 3, 3, 3);
        assertEq(_settle(id, 20), 3);

        for (uint256 i; i < 3; i++) {
            assertEq(usdc.balanceOf(bens[i]), start[i] + 5e6, "beneficiary nets +5e6 (7e6 gross)");
            assertTrue(cover.isPaid(id, bens[i]));
        }
        assertEq(usdc.balanceOf(provider), provStart - 15e6, "provider out exactly 15e6");
        assertEq(usdc.balanceOf(address(cover)), 0, "contract drained");
        assertEq(usdc.balanceOf(stranger), START, "caller receives nothing");

        e.status = MicroCover.Status.CLOSED;
        e.paidCount = 3;
        e.reservedCompensation = 0;
        e.escrowHeld = 0;
        e.bondHeld = 0;
        e.paidCompensation = 15e6;
        e.paidEscrow = 6e6;
        e.remainingOwed = 0;
        _check(id, e, "closed");

        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToWithdraw.selector, id));
        cover.withdrawRemainingBond(id);
    }

    function test_PartialEnrollment_TwoOfThree_LeftoverWithdrawnThenClosed() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 aStart = usdc.balanceOf(alice);
        uint256 bStart = usdc.balanceOf(bob);
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _admit(id);

        MicroCover.GuaranteeState memory e;
        e.status = MicroCover.Status.FAILED;
        e.outcome = MicroCover.Outcome.FAILURE;
        e.enrolled = 2;
        e.failureAdmittedAt = uint64(block.timestamp);
        e.bondHeld = 15e6;
        e.reservedCompensation = 10e6;
        e.escrowHeld = 4e6;
        e.remainingOwed = 14e6;
        _check(id, e, "admitted-partial");

        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.LiabilitiesUnpaid.selector, id, 2));
        cover.withdrawRemainingBond(id);

        assertEq(_settle(id, 20), 2);
        e.paidCount = 2;
        e.bondHeld = 5e6;
        e.reservedCompensation = 0;
        e.escrowHeld = 0;
        e.paidCompensation = 10e6;
        e.paidEscrow = 4e6;
        e.withdrawableBond = 5e6;
        e.remainingOwed = 0;
        _check(id, e, "paid-partial");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED), "not CLOSED until provider withdraws");
        assertEq(usdc.balanceOf(address(cover)), 5e6, "only the unreserved compensation remains");
        assertEq(usdc.balanceOf(alice), aStart + 5e6);
        assertEq(usdc.balanceOf(bob), bStart + 5e6);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 20);

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.RemainingBondWithdrawn(id, provider, 5e6);
        vm.expectEmit(true, false, false, false, address(cover));
        emit MicroCover.GuaranteeClosed(id);
        assertEq(_withdraw(id), 5e6);

        e.status = MicroCover.Status.CLOSED;
        e.bondHeld = 0;
        e.withdrawableBond = 0;
        _check(id, e, "closed-partial");
        assertEq(usdc.balanceOf(address(cover)), 0, "no orphaned bond");
        assertEq(usdc.balanceOf(provider), provStart - 10e6, "provider net -2 * compensation");
    }

    function test_ZeroEnrollment_WholeBondWithdrawn() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 id = _create();

        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.FailureAdmitted(id, provider, 0, 0);
        _admit(id);

        MicroCover.GuaranteeState memory e;
        e.status = MicroCover.Status.FAILED;
        e.outcome = MicroCover.Outcome.FAILURE;
        e.failureAdmittedAt = uint64(block.timestamp);
        e.bondHeld = 15e6;
        e.withdrawableBond = 15e6;
        _check(id, e, "admitted-zero");

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 20);

        assertEq(_withdraw(id), 15e6);
        e.status = MicroCover.Status.CLOSED;
        e.bondHeld = 0;
        e.withdrawableBond = 0;
        _check(id, e, "closed-zero");
        assertEq(usdc.balanceOf(provider), provStart, "provider fully refunded");
        assertEq(usdc.balanceOf(address(cover)), 0);

        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToWithdraw.selector, id));
        cover.withdrawRemainingBond(id);
    }

    function test_ProviderWithdrawFlowDoesNotTouchBeneficiaryEscrowOfPartialCohort() public {
        // Leftover is strictly bondOf; escrow of unpaid members is never part of a withdrawal.
        uint256 id = _create();
        _join(id, alice);
        _admit(id);
        assertEq(_settle(id, 1), 1);
        assertEq(_withdraw(id), 10e6, "two unreserved compensations only");
        assertEq(usdc.balanceOf(address(cover)), 0);
    }
}

/// Scenario 3: guarantees are fully isolated from each other.
contract Phase1IsolationTest is Phase1Base {
    function _isolation(uint32 aEnrolled) internal {
        uint256 a = _create();
        uint256 b = _create();
        uint256 c = _create(provider2, COMP, ESC, MAXC);
        address[3] memory aBens = [alice, bob, carol];
        for (uint256 i; i < aEnrolled; i++) {
            _join(a, aBens[i]);
        }
        _join(b, alice);
        _join(b, bob);
        _join(c, carol);
        _join(c, dave);
        assertEq(usdc.balanceOf(address(cover)), (15e6 + 2e6 * aEnrolled) + 19e6 + 19e6);

        bytes32 bBefore = keccak256(abi.encode(cover.getState(b)));
        bytes32 cBefore = keccak256(abi.encode(cover.getState(c)));

        // A fails, settles and (if partial) the provider withdraws the leftover.
        _admit(a);
        assertEq(_settle(a, 20), aEnrolled);
        if (aEnrolled < MAXC) {
            assertEq(_withdraw(a), 5e6 * (MAXC - aEnrolled));
        }
        assertEq(uint8(cover.statusOf(a)), uint8(MicroCover.Status.CLOSED));
        assertEq(cover.bondOf(a) + cover.escrowedOf(a) + cover.reservedOf(a), 0);

        // B and C are untouched, and the contract holds exactly B's and C's money.
        assertEq(keccak256(abi.encode(cover.getState(b))), bBefore, "B state unchanged");
        assertEq(keccak256(abi.encode(cover.getState(c))), cBefore, "C state unchanged");
        assertEq(cover.bondOf(b), 15e6);
        assertEq(cover.escrowedOf(b), 4e6);
        assertEq(cover.reservedOf(b), 10e6);
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.OPEN));
        assertEq(uint8(cover.outcomeOf(b)), uint8(MicroCover.Outcome.NONE));
        assertEq(usdc.balanceOf(address(cover)), 38e6, "exactly B + C");

        // B cannot be settled or withdrawn while OPEN, by anyone.
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotFailed.selector, b));
        cover.settleFailure(b, 20);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotFailed.selector, b));
        cover.withdrawRemainingBond(b);

        // Cross-provider authority: A's/B's provider is not C's provider, and vice versa.
        vm.prank(provider2);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, b, provider2));
        cover.admitFailure(b);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, c, provider));
        cover.admitFailure(c);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, c, provider));
        cover.withdrawRemainingBond(c);
        vm.prank(provider2);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, a, provider2));
        cover.withdrawRemainingBond(a);

        // A is closed for enrollment; B still enrolls normally.
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, a));
        cover.joinCohort(a);
        _join(b, dave);
        assertEq(cover.reservedOf(b), 15e6);
        assertEq(cover.escrowedOf(b), 6e6);
        assertEq(usdc.balanceOf(address(cover)), 40e6);

        // Failing C afterwards does not disturb B.
        vm.prank(provider2);
        cover.admitFailure(c);
        assertEq(_settle(c, 20), 2);
        assertEq(_withdraw(c), 5e6);
        assertEq(usdc.balanceOf(address(cover)), 21e6, "only B remains: 15 bond + 6 escrow");
        assertEq(cover.bondOf(b), 15e6);
        assertEq(uint8(cover.statusOf(b)), uint8(MicroCover.Status.OPEN));
    }

    function test_Isolation_PartialAFailsWhileBAndCStayOpen() public {
        _isolation(2);
    }

    function test_Isolation_FullAFailsWhileBAndCStayOpen() public {
        _isolation(3);
    }
}

/// Scenario 4: donations and capacity.
contract Phase1DonationTest is Phase1Base {
    uint256 internal constant DONATION = 777e6;

    function test_Donation_DoesNotExtendCohortCapacity() public {
        uint256 id = _create();
        usdc.mint(address(cover), DONATION); // donation to the cover address
        MicroCover.GuaranteeState memory e = cover.getState(id);
        assertEq(e.openSlots, 3, "openSlots unchanged by donation");
        assertEq(e.bondHeld, 15e6);

        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        assertFalse(cover.isJoinable(id), "isJoinable not extended");
        assertEq(cover.getState(id).openSlots, 0);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, id));
        cover.joinCohort(id);
        assertEq(cover.getGuarantee(id).cohortSize, 3);
        assertEq(cover.escrowedOf(id), 6e6);
    }

    function test_Donation_ByTransferAfterFullCohortStillCohortFull() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        vm.prank(dave);
        usdc.transfer(address(cover), 50e6); // donation via a normal transfer
        assertFalse(cover.isJoinable(id));
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, id));
        cover.joinCohort(id);
    }

    function test_Donation_FullCohortPayoutsExactAndDonationRemains() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 aStart = usdc.balanceOf(alice);
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        usdc.mint(address(cover), DONATION);
        _admit(id);
        assertEq(_settle(id, 20), 3);
        assertEq(usdc.balanceOf(alice), aStart + 5e6, "payout amount unchanged by donation");
        assertEq(usdc.balanceOf(provider), provStart - 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), DONATION, "only the donation remains");
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToWithdraw.selector, id));
        cover.withdrawRemainingBond(id);
        assertEq(usdc.balanceOf(address(cover)), DONATION, "donation cannot be extracted");
    }

    function test_Donation_ProviderWithdrawsOnlyBondLeftover() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        usdc.mint(address(cover), DONATION);
        _admit(id);
        assertEq(_settle(id, 20), 2);
        assertEq(cover.getState(id).withdrawableBond, 5e6, "withdrawable ignores donation");
        assertEq(_withdraw(id), 5e6, "exactly the 1 unreserved compensation");
        assertEq(usdc.balanceOf(provider), provStart - 10e6);
        assertEq(usdc.balanceOf(address(cover)), DONATION);
    }

    function test_Donation_ZeroEnrollmentWithdrawsOnlyBond() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 id = _create();
        usdc.mint(address(cover), DONATION);
        _admit(id);
        assertEq(_withdraw(id), 15e6);
        assertEq(usdc.balanceOf(provider), provStart);
        assertEq(usdc.balanceOf(address(cover)), DONATION);
    }

    function test_Capacity_ComesFromOwnBondNotTokenBalance() public {
        // A big guarantee makes the contract hold 5000e6 of other guarantees' tokens.
        uint256 big = _create(provider, 50e6, 2e6, 100);
        assertEq(usdc.balanceOf(address(cover)), 5_000e6);
        // Tiny guarantee: compensation 1, escrow 1, maxCohort 2.
        uint256 tiny = _create(provider2, 1, 1, 2);
        assertEq(cover.bondOf(tiny), 2);
        _join(tiny, alice);
        _join(tiny, bob);
        assertFalse(cover.isJoinable(tiny));
        vm.prank(carol);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, tiny));
        cover.joinCohort(tiny);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, tiny));
        cover.joinCohort(tiny);
        assertEq(cover.getGuarantee(tiny).cohortSize, 2);
        assertEq(cover.getState(tiny).openSlots, 0);
        // The big guarantee is unaffected.
        assertEq(cover.bondOf(big), 5_000e6);
        assertEq(cover.reservedOf(big), 0);
        assertEq(usdc.balanceOf(address(cover)), 5_000e6 + 2 + 2);
    }
}

/// Scenario 5: unauthorized callers and state gating.
contract Phase1AuthTest is Phase1Base {
    function test_NonProviderCannotAdmit() public {
        uint256 id = _create();
        _join(id, alice);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, id, stranger));
        cover.admitFailure(id);
        vm.prank(provider2); // another provider with its own guarantees
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, id, provider2));
        cover.admitFailure(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.NONE));
    }

    function test_BeneficiaryCannotAdmit() public {
        uint256 id = _create();
        _join(id, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, id, alice));
        cover.admitFailure(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.OPEN));
    }

    function test_ProviderCanAdmitAndOnlyProviderMovesToFailed() public {
        uint256 id = _create();
        _admit(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(uint8(cover.outcomeOf(id)), uint8(MicroCover.Outcome.FAILURE));
    }

    function test_NonProviderCannotWithdraw() public {
        uint256 id = _create();
        _join(id, alice);
        _admit(id);
        _settle(id, 20);
        address[3] memory callers = [stranger, alice, provider2];
        for (uint256 i; i < 3; i++) {
            vm.prank(callers[i]);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.NotProvider.selector, id, callers[i]));
            cover.withdrawRemainingBond(id);
        }
        assertEq(cover.bondOf(id), 10e6, "leftover untouched");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
    }

    function test_ProviderWithdrawWhileOpenRevertsNotFailed() public {
        uint256 id = _create();
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotFailed.selector, id));
        cover.withdrawRemainingBond(id);
        assertEq(cover.bondOf(id), 15e6);
    }

    function test_WithdrawWithUnpaidLiabilitiesRevertsWithRemainingCount() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.LiabilitiesUnpaid.selector, id, 3));
        cover.withdrawRemainingBond(id);
        assertEq(_settle(id, 1), 1);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.LiabilitiesUnpaid.selector, id, 2));
        cover.withdrawRemainingBond(id);
        assertEq(_settle(id, 1), 1);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.LiabilitiesUnpaid.selector, id, 1));
        cover.withdrawRemainingBond(id);
        assertEq(usdc.balanceOf(address(cover)), 15e6 + 6e6 - 14e6, "no leakage by failed withdrawals");
    }

    function test_UnknownIdRejectedByAdminActions() public {
        _create();
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.admitFailure(99);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 0));
        cover.admitFailure(0);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.withdrawRemainingBond(99);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.statusOf(99);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.outcomeOf(99);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 99));
        cover.getState(99);
    }
}

/// Scenario 6: duplicates and replay.
contract Phase1ReplayTest is Phase1Base {
    function test_SecondAdmitReverts_WhileFailedAndAfterClosed() public {
        uint256 id = _create();
        _join(id, alice);
        _admit(id);
        uint64 ts = cover.getState(id).failureAdmittedAt;
        vm.warp(block.timestamp + 5);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.AlreadyAdmitted.selector, id));
        cover.admitFailure(id);
        assertEq(cover.getState(id).failureAdmittedAt, ts, "admission time never rewritten");

        _settle(id, 20);
        _withdraw(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.AlreadyAdmitted.selector, id));
        cover.admitFailure(id);
    }

    function test_SettleAfterEverythingPaidReverts_FullCohort() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
        _settle(id, 20);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 20);
    }

    function test_RepeatedSettleCannotPayTwice() public {
        uint256 id = _create();
        uint256 aStart = usdc.balanceOf(alice);
        uint256 bStart = usdc.balanceOf(bob);
        uint256 cStart = usdc.balanceOf(carol);
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);

        assertEq(_settle(id, 2), 2);
        assertEq(_settle(id, 20), 1, "only the remaining beneficiary is paid");
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 20);
        assertEq(usdc.balanceOf(alice), aStart + 5e6);
        assertEq(usdc.balanceOf(bob), bStart + 5e6);
        assertEq(usdc.balanceOf(carol), cStart + 5e6);
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_IsPaidFlagsFollowEnrollmentOrder() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        assertFalse(cover.isPaid(id, alice));
        _admit(id);
        assertFalse(cover.isPaid(id, alice), "admission pays nobody");
        _settle(id, 1);
        assertTrue(cover.isPaid(id, alice));
        assertFalse(cover.isPaid(id, bob));
        assertFalse(cover.isPaid(id, carol));
        assertFalse(cover.isPaid(id, dave), "non-member never paid");
        assertFalse(cover.isPaid(id, provider));
        _settle(id, 1);
        assertTrue(cover.isPaid(id, bob));
        assertFalse(cover.isPaid(id, carol));
        _settle(id, 1);
        assertTrue(cover.isPaid(id, carol));
        assertFalse(cover.isPaid(999, alice), "unknown id");
    }

    function test_DuplicateJoinReverts() public {
        uint256 id = _create();
        _join(id, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.AlreadyMember.selector, id, alice));
        cover.joinCohort(id);
        assertEq(cover.getGuarantee(id).cohortSize, 1);
        assertEq(cover.escrowedOf(id), 2e6);
    }

    function test_JoinAfterFailureRevertsEnrollmentClosed() public {
        uint256 id = _create();
        _join(id, alice);
        _admit(id);
        address[4] memory who = [bob, alice, provider, stranger]; // new, existing, provider, outsider
        for (uint256 i; i < 4; i++) {
            _fundUser(who[i]);
            vm.prank(who[i]);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, id));
            cover.joinCohort(id);
        }
        // Still closed once the deadline passes and after CLOSED.
        vm.warp(uint256(joinDeadline) + 1);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, id));
        cover.joinCohort(id);
        _settle(id, 20);
        _withdraw(id);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.EnrollmentClosed.selector, id));
        cover.joinCohort(id);
        assertEq(cover.getGuarantee(id).cohortSize, 1);
        assertFalse(cover.isJoinable(id));
    }

    function test_JoinAfterDeadlineReverts() public {
        uint256 id = _create();
        vm.warp(uint256(joinDeadline) + 1);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.JoinDeadlinePassed.selector, id));
        cover.joinCohort(id);
        // Provider can still admit after the deadline (not time-gated), with zero enrollment.
        _admit(id);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
    }

    function test_ProviderCannotJoinOwnGuaranteeButMayJoinOthers() public {
        uint256 id = _create();
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.ProviderCannotJoin.selector, id));
        cover.joinCohort(id);
        uint256 other = _create(provider2, COMP, ESC, MAXC);
        _join(other, provider); // a provider is a normal beneficiary of someone else's guarantee
        assertTrue(cover.isMember(other, provider));
    }
}

/// Scenario 7: invalid inputs.
contract Phase1InputTest is Phase1Base {
    function test_SettleUnknownIdReverts() public {
        _create();
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 0));
        cover.settleFailure(0, 20);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 2));
        cover.settleFailure(2, 1);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, type(uint256).max));
        cover.settleFailure(type(uint256).max, 20);
    }

    function test_SettleInvalidBatchSizesRevertWithArgs() public {
        uint256 id = _create();
        _join(id, alice);
        _admit(id);
        uint32[4] memory bad = [uint32(0), 21, 1000, type(uint32).max];
        for (uint256 i; i < 4; i++) {
            vm.prank(stranger);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.InvalidBatchSize.selector, bad[i], 20));
            cover.settleFailure(id, bad[i]);
        }
        assertEq(cover.MAX_SETTLEMENT_BATCH(), 20);
        assertEq(cover.getState(id).paidCount, 0, "invalid sizes pay nobody");
        // Boundary values 1 and 20 are valid.
        assertEq(_settle(id, 20), 1);
    }

    function test_BatchSizeValidatedBeforeIdAndStatus() public {
        // Documents check ordering: size is validated first, even for unknown ids / OPEN guarantees.
        uint256 id = _create();
        vm.expectRevert(abi.encodeWithSelector(MicroCover.InvalidBatchSize.selector, 0, 20));
        cover.settleFailure(999, 0);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.InvalidBatchSize.selector, 21, 20));
        cover.settleFailure(id, 21);
    }

    function test_SettleOnOpenRevertsNotFailed() public {
        uint256 id = _create();
        _join(id, alice);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotFailed.selector, id));
        cover.settleFailure(id, 20);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NotFailed.selector, id));
        cover.settleFailure(id, 1);
        assertEq(usdc.balanceOf(address(cover)), 15e6 + 2e6);
    }

    function test_BeneficiaryViewsAndIndexOutOfRange() public {
        uint256 id = _create();
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IndexOutOfRange.selector, id, 0));
        cover.beneficiaryAt(id, 0);
        _join(id, carol);
        _join(id, alice);
        assertEq(cover.beneficiaryCount(id), 2);
        assertEq(cover.beneficiaryAt(id, 0), carol);
        assertEq(cover.beneficiaryAt(id, 1), alice);
        address[] memory all = cover.getBeneficiaries(id);
        assertEq(all.length, 2);
        assertEq(all[0], carol);
        assertEq(all[1], alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IndexOutOfRange.selector, id, 2));
        cover.beneficiaryAt(id, 2);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IndexOutOfRange.selector, id, type(uint256).max));
        cover.beneficiaryAt(id, type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IndexOutOfRange.selector, 99, 0));
        cover.beneficiaryAt(99, 0);
        assertEq(cover.beneficiaryCount(99), 0);
        assertEq(cover.getBeneficiaries(99).length, 0);
    }
}

/// Scenario 11: payouts depend only on enrollment and frozen terms, never on the caller.
contract Phase1DeterminismTest is Phase1Base {
    function test_AnyCallerProducesIdenticalPayoutsAndCallerReceivesNothingExtra() public {
        address[4] memory callers = [stranger, provider, alice, address(this)];
        address[6] memory watched = [carol, alice, bob, stranger, provider, address(this)];
        for (uint256 k; k < 4; k++) {
            uint256 id = _create();
            _join(id, carol); // enrollment order is carol, alice, bob
            _join(id, alice);
            _join(id, bob);
            _admit(id);

            uint256[6] memory before_;
            for (uint256 i; i < 6; i++) {
                before_[i] = usdc.balanceOf(watched[i]);
            }
            vm.expectEmit(true, true, false, true, address(cover));
            emit MicroCover.SettlementBatchProcessed(id, callers[k], 3, 3, 3);
            vm.prank(callers[k]);
            assertEq(cover.settleFailure(id, 20), 3);

            for (uint256 i; i < 6; i++) {
                uint256 expectedDelta = i < 3 ? 7e6 : 0; // carol/alice/bob gross 7e6; others nothing
                assertEq(usdc.balanceOf(watched[i]) - before_[i], expectedDelta, "identical payout, caller gets nothing");
            }
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        }
        // 4 guarantees x 15e6 bond + 6e6 escrow each were fully paid out.
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_RecipientsFollowEnrollmentOrderRegardlessOfCaller() public {
        uint256 id = _create();
        _join(id, carol);
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        vm.prank(bob); // a beneficiary who is last in line triggers the settlement
        assertEq(cover.settleFailure(id, 1), 1);
        assertTrue(cover.isPaid(id, carol), "first enrolled is paid first");
        assertFalse(cover.isPaid(id, alice));
        assertFalse(cover.isPaid(id, bob), "caller does not jump the queue");
        vm.prank(provider);
        assertEq(cover.settleFailure(id, 1), 1);
        assertTrue(cover.isPaid(id, alice));
        assertFalse(cover.isPaid(id, bob));
        vm.prank(carol);
        assertEq(cover.settleFailure(id, 1), 1);
        assertTrue(cover.isPaid(id, bob));
    }
}

/// Scenario 8: batching boundaries (COMP 5e6, ESC 2e6, users are _user(0..n-1)).
contract Phase1BatchingTest is Phase1Base {
    /// Expected state for a guarantee with `maxC` slots, `n` enrolled and `paid` paid.
    function _progressState(uint32 maxC, uint32 n, uint32 paid, uint64 admittedAt)
        internal
        pure
        returns (MicroCover.GuaranteeState memory e)
    {
        bool closed = paid == n && n == maxC;
        e.status = closed ? MicroCover.Status.CLOSED : MicroCover.Status.FAILED;
        e.outcome = MicroCover.Outcome.FAILURE;
        e.enrolled = n;
        e.paidCount = paid;
        e.failureAdmittedAt = admittedAt;
        e.bondHeld = uint256(COMP) * (maxC - paid);
        e.reservedCompensation = uint256(COMP) * (n - paid);
        e.escrowHeld = uint256(ESC) * (n - paid);
        e.paidCompensation = uint256(COMP) * paid;
        e.paidEscrow = uint256(ESC) * paid;
        e.withdrawableBond = (!closed && paid == n) ? e.bondHeld : 0;
        e.remainingOwed = uint256(COMP + ESC) * (n - paid);
    }

    function _assertProgress(uint256 id, uint32 maxC, uint32 n, uint32 paid, uint64 admittedAt) internal view {
        MicroCover.GuaranteeState memory e = _progressState(maxC, n, paid, admittedAt);
        _check(id, e, "progress");
        assertEq(usdc.balanceOf(address(cover)), e.bondHeld + e.escrowHeld, "solvent, nothing orphaned");
        for (uint256 i; i < n; i++) {
            bool isPaid_ = i < paid;
            assertEq(cover.isPaid(id, _user(i)), isPaid_, "paid flag order");
            assertEq(usdc.balanceOf(_user(i)), isPaid_ ? START + COMP : START - ESC, "beneficiary balance");
        }
    }

    function _checkBatchLogs(uint256 id, uint32 start, uint32 expectCount, bool expectClosed) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 paidEvents;
        uint256 closed;
        uint256 batches;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].emitter != address(cover)) continue;
            bytes32 t0 = logs[i].topics[0];
            if (t0 == MicroCover.BeneficiaryPaid.selector) {
                assertEq(logs[i].topics[1], bytes32(id));
                assertEq(address(uint160(uint256(logs[i].topics[2]))), _user(start + paidEvents), "recipient order");
                paidEvents++;
            } else if (t0 == MicroCover.GuaranteeClosed.selector) {
                closed++;
            } else if (t0 == MicroCover.SettlementBatchProcessed.selector) {
                batches++;
            }
        }
        assertEq(paidEvents, expectCount, "BeneficiaryPaid count");
        assertEq(closed, expectClosed ? 1 : 0, "GuaranteeClosed count");
        assertEq(batches, 1, "one batch event");
    }

    function _prepare(uint32 maxC, uint32 n) internal returns (uint256 id, uint64 admittedAt) {
        id = _create(provider, COMP, ESC, maxC);
        _enroll(id, n);
        _admit(id);
        admittedAt = uint64(block.timestamp);
    }

    function test_Batching_Full100_FiveBatchesOfExactlyTwenty() public {
        (uint256 id, uint64 at) = _prepare(100, 100);
        assertEq(usdc.balanceOf(address(cover)), 700e6);
        _assertProgress(id, 100, 100, 0, at);
        for (uint32 call; call < 5; call++) {
            vm.recordLogs();
            assertEq(_settle(id, 20), 20);
            _checkBatchLogs(id, call * 20, 20, call == 4);
            uint32 paid = (call + 1) * 20;
            assertEq(cover.getState(id).paidCount, paid, "paidCount grows 20 at a time");
            _assertProgress(id, 100, 100, paid, at);
            if (call < 4) {
                assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED), "FAILED until the last payout");
                assertEq(cover.getState(id).remainingOwed, uint256(7e6) * (100 - paid));
            }
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(usdc.balanceOf(provider), 10_000e6 - 500e6);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, id));
        cover.settleFailure(id, 20);
    }

    function test_Batching_MixedSizesIncludingOversizedRequestAtTheEnd() public {
        (uint256 id, uint64 at) = _prepare(100, 100);
        uint32[8] memory sizes = [uint32(7), 20, 1, 20, 20, 20, 20, 20];
        uint32 paid;
        for (uint256 i; i < sizes.length && paid < 100; i++) {
            uint32 remaining = 100 - paid;
            uint32 expected = sizes[i] < remaining ? sizes[i] : remaining;
            assertEq(_settle(id, sizes[i]), expected, "min(requested, remaining)");
            paid += expected;
            _assertProgress(id, 100, 100, paid, at);
        }
        assertEq(paid, 100);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_Batching_OneByOne() public {
        (uint256 id, uint64 at) = _prepare(5, 5);
        for (uint32 i; i < 5; i++) {
            vm.recordLogs();
            assertEq(_settle(id, 1), 1);
            _checkBatchLogs(id, i, 1, i == 4);
            _assertProgress(id, 5, 5, i + 1, at);
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
    }

    function test_Batching_LastShortBatch_45Enrolled_20_20_5_Closed() public {
        (uint256 id, uint64 at) = _prepare(45, 45);
        uint32[3] memory sizes = [uint32(20), 20, 20];
        uint32[3] memory expected = [uint32(20), 20, 5];
        uint32 paid;
        for (uint256 i; i < 3; i++) {
            vm.recordLogs();
            assertEq(_settle(id, sizes[i]), expected[i]);
            _checkBatchLogs(id, paid, expected[i], i == 2);
            paid += expected[i];
            _assertProgress(id, 45, 45, paid, at);
        }
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_Batching_45Of100_StaysFailedUntilProviderWithdrawsLeftover() public {
        (uint256 id, uint64 at) = _prepare(100, 45);
        assertEq(_settle(id, 20), 20);
        assertEq(_settle(id, 20), 20);
        assertEq(_settle(id, 20), 5);
        _assertProgress(id, 100, 45, 45, at);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(cover.getState(id).withdrawableBond, 275e6);
        assertEq(usdc.balanceOf(address(cover)), 275e6);
        assertEq(_withdraw(id), 275e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(usdc.balanceOf(provider), 10_000e6 - 225e6, "provider net -45 * compensation");
    }

    function test_Batching_RequestOf20WhenThreeRemainPaysThree() public {
        (uint256 id, uint64 at) = _prepare(23, 23);
        assertEq(_settle(id, 20), 20);
        _assertProgress(id, 23, 23, 20, at);
        vm.recordLogs();
        assertEq(_settle(id, 20), 3);
        _checkBatchLogs(id, 20, 3, true);
        _assertProgress(id, 23, 23, 23, at);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
    }

    function test_Batching_ProgressSurvivesAnInterleavedUnrelatedGuarantee() public {
        (uint256 id, uint64 at) = _prepare(30, 30);
        uint256 other = _create(provider2, 1e6, 1e6, 50);
        _join(other, alice);
        assertEq(_settle(id, 20), 20);
        assertEq(cover.getState(other).paidCount, 0);
        assertEq(_settle(id, 20), 10);
        _check(id, _progressState(30, 30, 30, at), "settled guarantee");
        assertEq(cover.bondOf(other), 50e6);
        assertEq(cover.escrowedOf(other), 1e6);
        assertEq(usdc.balanceOf(address(cover)), 50e6 + 1e6, "other guarantee still fully funded");
    }
}

/// Scenario 8 (gas): gas observations for settleFailure. The cohorts are built in setUp so the
/// measured calls start from a fresh transaction (cold storage), like a standalone settle tx.
contract Phase1GasTest is Phase1Base {
    uint256 internal full;
    uint256 internal one;
    uint256 internal constant LOOSE_BOUND = 15_000_000;

    function setUp() public override {
        super.setUp();
        full = _create(provider, COMP, ESC, 100);
        _enroll(full, 100);
        _admit(full);
        one = _create(provider2, COMP, ESC, 1);
        _join(one, alice);
        vm.prank(provider2);
        cover.admitFailure(one);
    }

    function test_Gas_Settle20_On100Cohort() public {
        vm.prank(stranger);
        uint256 g0 = gasleft();
        uint32 settled = cover.settleFailure(full, 20);
        uint256 used = g0 - gasleft();
        console2.log("gas settleFailure(id,20) first call on full 100 cohort:", used);
        assertEq(settled, 20);
        assertGt(used, 0);
        assertLt(used, LOOSE_BOUND, "sanity bound only");
    }

    function test_Gas_Settle1_On100Cohort() public {
        vm.prank(stranger);
        uint256 g0 = gasleft();
        uint32 settled = cover.settleFailure(full, 1);
        uint256 used = g0 - gasleft();
        console2.log("gas settleFailure(id,1) first call on full 100 cohort:", used);
        assertEq(settled, 1);
        assertLt(used, LOOSE_BOUND, "sanity bound only");
    }

    function test_Gas_Settle1_OnCohortOfOne_Closing() public {
        vm.prank(stranger);
        uint256 g0 = gasleft();
        uint32 settled = cover.settleFailure(one, 1);
        uint256 used = g0 - gasleft();
        console2.log("gas settleFailure(id,1) on cohort of 1 (closes guarantee):", used);
        assertEq(settled, 1);
        assertEq(uint8(cover.statusOf(one)), uint8(MicroCover.Status.CLOSED));
        assertLt(used, LOOSE_BOUND, "sanity bound only");
    }

    function test_Gas_AllFiveBatchesOf20() public {
        uint256[5] memory used;
        for (uint256 i; i < 5; i++) {
            vm.prank(stranger);
            uint256 g0 = gasleft();
            cover.settleFailure(full, 20);
            used[i] = g0 - gasleft();
            console2.log("gas batch-of-20 call #", i + 1, used[i]);
            assertLt(used[i], LOOSE_BOUND, "sanity bound only");
        }
        assertEq(uint8(cover.statusOf(full)), uint8(MicroCover.Status.CLOSED));
    }
}

/// Scenario 9a: a blocklisting token makes settlement revert atomically.
contract Phase1BlocklistTest is Phase1Base {
    BlocklistUSDC internal bl;

    function _deployToken() internal override returns (MockUSDC) {
        bl = new BlocklistUSDC();
        return bl;
    }

    function _blockedAt(uint256 pos) internal {
        address[3] memory bens = [alice, bob, carol];
        uint256[3] memory start;
        for (uint256 i; i < 3; i++) {
            start[i] = usdc.balanceOf(bens[i]);
        }
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
        bl.setBlocked(bens[pos], true);
        bytes32 before_ = _snap(id);

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, bens[pos]));
        cover.settleFailure(id, 20);

        assertEq(_snap(id), before_, "every ledger identical after the reverted batch");
        assertEq(cover.getState(id).paidCount, 0);
        assertEq(cover.bondOf(id), 15e6);
        assertEq(cover.escrowedOf(id), 6e6);
        assertEq(cover.reservedOf(id), 15e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        assertEq(usdc.balanceOf(address(cover)), 21e6);
        for (uint256 i; i < 3; i++) {
            assertFalse(cover.isPaid(id, bens[i]), "no paid flag survives the revert");
            assertEq(usdc.balanceOf(bens[i]), start[i] - 2e6);
        }
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.LiabilitiesUnpaid.selector, id, 3));
        cover.withdrawRemainingBond(id);

        bl.setBlocked(bens[pos], false);
        assertEq(_settle(id, 20), 3, "same batch succeeds once unblocked");
        for (uint256 i; i < 3; i++) {
            assertEq(usdc.balanceOf(bens[i]), start[i] + 5e6);
        }
        assertEq(usdc.balanceOf(address(cover)), 0);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
    }

    function test_BlockedFirstRecipientRollsBackWholeBatch() public {
        _blockedAt(0);
    }

    function test_BlockedMiddleRecipientRollsBackWholeBatch() public {
        _blockedAt(1);
    }

    function test_BlockedLastRecipientRollsBackWholeBatch() public {
        _blockedAt(2);
    }

    function test_BlockedRecipientHeadOfLineBlocksLaterBatchesButNotEarlierOnes() public {
        uint256 aStart = usdc.balanceOf(alice);
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
        bl.setBlocked(bob, true);
        assertEq(_settle(id, 1), 1, "batch excluding the blocked recipient succeeds");
        assertEq(usdc.balanceOf(alice), aStart + 5e6);

        bytes32 before_ = _snap(id);
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, bob));
        cover.settleFailure(id, 1); // bob is next in line: no way to skip him
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, bob));
        cover.settleFailure(id, 2);
        assertEq(_snap(id), before_);
        assertEq(cover.getState(id).paidCount, 1);
        assertFalse(cover.isPaid(id, carol), "carol cannot be paid out of order");

        bl.setBlocked(bob, false);
        assertEq(_settle(id, 20), 2);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_WithdrawRollsBackWhenProviderBlocked() public {
        uint256 provStart = usdc.balanceOf(provider);
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        assertEq(_settle(id, 20), 2);
        bl.setBlocked(provider, true);
        bytes32 before_ = _snap(id);

        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(BlocklistUSDC.Blocked.selector, provider));
        cover.withdrawRemainingBond(id);

        assertEq(_snap(id), before_);
        assertEq(cover.bondOf(id), 5e6, "bondOf unchanged");
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED), "status unchanged");
        assertEq(cover.getState(id).withdrawableBond, 5e6);
        assertEq(usdc.balanceOf(address(cover)), 5e6);

        bl.setBlocked(provider, false);
        assertEq(_withdraw(id), 5e6);
        assertEq(usdc.balanceOf(provider), provStart - 10e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0);
    }
}

/// Scenario 9b: tokens whose outgoing transfers move a different amount than requested.
contract Phase1OutgoingFeeTest is Phase1Base {
    OutgoingFeeUSDC internal ft;

    function _deployToken() internal override returns (MockUSDC) {
        ft = new OutgoingFeeUSDC();
        return ft;
    }

    function _threeAdmitted() internal returns (uint256 id) {
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
    }

    function test_ShortSendTokenTriggersIncorrectUsdcSentWithFullRollback() public {
        uint256 id = _threeAdmitted();
        ft.configure(address(cover), OutgoingFeeUSDC.Mode.SHORT);
        bytes32 before_ = _snap(id);
        // cover sends 3 x 6.3e6 instead of 3 x 7e6: balance 21e6 -> 2.1e6.
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 21e6, 21e6, 2.1e6));
        cover.settleFailure(id, 20);
        assertEq(_snap(id), before_);
        assertEq(cover.getState(id).paidCount, 0);
        assertFalse(cover.isPaid(id, alice));
        assertEq(usdc.balanceOf(address(cover)), 21e6);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        assertEq(_settle(id, 20), 3);
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_ExtraFeeTokenTriggersIncorrectUsdcSentWithFullRollback() public {
        uint256 id = _threeAdmitted();
        ft.configure(address(cover), OutgoingFeeUSDC.Mode.EXTRA);
        bytes32 before_ = _snap(id);
        // One 7e6 payout also burns 0.7e6 from the cover: balance 21e6 -> 13.3e6.
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 7e6, 21e6, 13.3e6));
        cover.settleFailure(id, 1);
        assertEq(_snap(id), before_);
        assertEq(cover.getState(id).paidCount, 0);
        assertEq(cover.reservedOf(id), 15e6);

        // A batch that cannot even afford the fee fails in the token; still fully atomic.
        vm.prank(stranger);
        vm.expectRevert();
        cover.settleFailure(id, 3);
        assertEq(_snap(id), before_);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        assertEq(_settle(id, 20), 3);
    }

    function test_WithdrawWithShortOrExtraFeeRollsBack() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        assertEq(_settle(id, 20), 2);
        usdc.mint(address(cover), 10e6); // donation so the EXTRA fee is affordable
        bytes32 before_ = _snap(id);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.SHORT);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 5e6, 15e6, 10.5e6));
        cover.withdrawRemainingBond(id);
        assertEq(_snap(id), before_);

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.EXTRA);
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcSent.selector, 5e6, 15e6, 9.5e6));
        cover.withdrawRemainingBond(id);
        assertEq(_snap(id), before_);
        assertEq(cover.bondOf(id), 5e6);
        assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));

        ft.configure(address(cover), OutgoingFeeUSDC.Mode.OFF);
        assertEq(_withdraw(id), 5e6);
        assertEq(usdc.balanceOf(address(cover)), 10e6, "only the donation remains");
    }
}

/// Contract beneficiary whose token hook tries to re-enter MicroCover.
contract HookRecipient is IRecipientHook {
    MicroCover public immutable cover;
    uint256 public attackId;
    uint8 public attack; // 0 none, 1 settle, 2 withdraw, 3 admit, 4 join, 5 create, 6 plain revert
    bool public bubble;
    uint256 public hookCalls;
    bool public lastOk;
    bytes public lastRet;

    constructor(MicroCover cover_) {
        cover = cover_;
    }

    function joinTo(IERC20 token, uint256 id) external {
        token.approve(address(cover), type(uint256).max);
        cover.joinCohort(id);
    }

    function configure(uint8 attack_, uint256 attackId_, bool bubble_) external {
        attack = attack_;
        attackId = attackId_;
        bubble = bubble_;
    }

    function tokensReceived(address, uint256) external {
        hookCalls++;
        bytes memory data;
        if (attack == 1) data = abi.encodeCall(MicroCover.settleFailure, (attackId, 1));
        else if (attack == 2) data = abi.encodeCall(MicroCover.withdrawRemainingBond, (attackId));
        else if (attack == 3) data = abi.encodeCall(MicroCover.admitFailure, (attackId));
        else if (attack == 4) data = abi.encodeCall(MicroCover.joinCohort, (attackId));
        else if (attack == 5) {
            data = abi.encodeCall(
                MicroCover.createGuarantee, (uint128(1), uint128(1), uint32(1), uint64(block.timestamp + 1), uint64(block.timestamp + 1), bytes32(0))
            );
        } else if (attack == 6) {
            revert("hook-revert");
        } else {
            return;
        }
        (bool ok, bytes memory ret) = address(cover).call(data);
        lastOk = ok;
        lastRet = ret;
        if (!ok && bubble) {
            assembly {
                revert(add(ret, 32), mload(ret))
            }
        }
    }
}

/// Scenario 10: reentrant token callbacks and recipient hooks.
contract Phase1ReentrancyTest is Phase1Base {
    ReentrantUSDC internal rt;
    function _reentry() internal pure returns (bytes memory) {
        return abi.encodeWithSelector(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
    }

    function _deployToken() internal override returns (MockUSDC) {
        rt = new ReentrantUSDC();
        return rt;
    }

    function _payload(uint256 k, uint256 id) internal view returns (bytes memory) {
        if (k == 0) return abi.encodeCall(MicroCover.settleFailure, (id, 1));
        if (k == 1) return abi.encodeCall(MicroCover.admitFailure, (id));
        if (k == 2) return abi.encodeCall(MicroCover.withdrawRemainingBond, (id));
        if (k == 3) return abi.encodeCall(MicroCover.joinCohort, (id));
        return abi.encodeCall(
            MicroCover.createGuarantee, (COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS)
        );
    }

    function _threeAdmitted() internal returns (uint256 id) {
        id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        _admit(id);
    }

    function test_Control_CallbackReallyExecutesDuringPayout() public {
        uint256 id = _threeAdmitted();
        rt.arm(address(cover), abi.encodeCall(MicroCover.isJoinable, (id)), false);
        assertEq(_settle(id, 20), 3);
        assertEq(rt.reentries(), 3, "callback fired once per outgoing transfer");
        assertTrue(rt.lastOk(), "read-only callbacks are allowed");
    }

    function test_ReentryDuringPayout_BubbledRevertRollsEverythingBack() public {
        for (uint256 k; k < 5; k++) {
            uint256 id = _threeAdmitted();
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _snap(id);
            vm.prank(stranger);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.settleFailure(id, 20);
            assertEq(_snap(id), before_, "ledgers unchanged");
            assertEq(cover.getState(id).paidCount, 0);
            rt.disarm();
            assertEq(_settle(id, 20), 3, "guard is released after the revert");
        }
    }

    function test_ReentryDuringPayout_SwallowedRevertNeverDoublePays() public {
        for (uint256 k; k < 5; k++) {
            uint256 aStart = usdc.balanceOf(alice);
            uint256 provStart = usdc.balanceOf(provider);
            uint256 id = _threeAdmitted();
            uint256 coverBefore = usdc.balanceOf(address(cover));
            rt.arm(address(cover), _payload(k, id), false);
            assertEq(_settle(id, 20), 3);
            assertEq(rt.reentries(), 3);
            assertFalse(rt.lastOk(), "re-entry was rejected");
            assertEq(rt.lastRet(), _reentry());
            // Exactly one payout each; nothing extra left the contract.
            assertEq(usdc.balanceOf(alice) - aStart, 5e6, "net +compensation, not doubled");
            assertEq(coverBefore, 21e6);
            assertEq(usdc.balanceOf(address(cover)), 0, "exactly 21e6 left the contract");
            assertEq(cover.nextGuaranteeId(), id + 1, "no guarantee created by re-entry");
            assertFalse(cover.isMember(id, address(rt)), "token contract never joined");
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
            assertEq(usdc.balanceOf(provider), provStart - 15e6);
            rt.disarm();
        }
    }

    function test_ReentryDuringWithdraw_BubbledAndSwallowed() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _admit(id);
        _settle(id, 20);
        uint256 provBefore = usdc.balanceOf(provider);
        for (uint256 k; k < 5; k++) {
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _snap(id);
            vm.prank(provider);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.withdrawRemainingBond(id);
            assertEq(_snap(id), before_);
            assertEq(cover.bondOf(id), 5e6);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.FAILED));
        }
        rt.arm(address(cover), _payload(0, id), false);
        assertEq(_withdraw(id), 5e6);
        assertFalse(rt.lastOk());
        assertEq(rt.lastRet(), _reentry());
        assertEq(rt.reentries(), 1);
        assertEq(usdc.balanceOf(provider), provBefore + 5e6, "paid exactly once");
        assertEq(usdc.balanceOf(address(cover)), 0);
    }

    function test_ReentryDuringJoinPull() public {
        uint256 id = _create();
        for (uint256 k; k < 5; k++) {
            rt.arm(address(cover), _payload(k, id), true);
            bytes32 before_ = _snap(id);
            vm.prank(alice);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.joinCohort(id);
            assertEq(_snap(id), before_);
            assertFalse(cover.isMember(id, alice));
            assertEq(cover.escrowedOf(id), 0);
        }
        rt.arm(address(cover), _payload(3, id), false);
        _join(id, alice);
        assertFalse(rt.lastOk());
        assertEq(rt.lastRet(), _reentry());
        assertEq(cover.escrowedOf(id), 2e6, "charged exactly one escrow");
        assertEq(cover.reservedOf(id), 5e6);
        assertEq(cover.getGuarantee(id).cohortSize, 1);
    }

    function test_ReentryDuringCreatePull() public {
        for (uint256 k; k < 5; k++) {
            rt.arm(address(cover), _payload(k, 1), true);
            vm.prank(provider);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.createGuarantee(COMP, ESC, MAXC, joinDeadline, settlementTime, TERMS);
            assertEq(cover.nextGuaranteeId(), 1, "id counter rolled back");
            assertEq(usdc.balanceOf(address(cover)), 0);
        }
        rt.arm(address(cover), _payload(4, 1), false);
        uint256 id = _create();
        assertFalse(rt.lastOk());
        assertEq(rt.lastRet(), _reentry());
        assertEq(id, 1);
        assertEq(cover.nextGuaranteeId(), 2, "only the outer guarantee exists");
        assertEq(usdc.balanceOf(address(cover)), 15e6);
    }

    function _hookGuarantee(HookRecipient hr) internal returns (uint256 id) {
        usdc.mint(address(hr), START);
        id = _create();
        hr.joinTo(IERC20(address(usdc)), id); // enrollment order: hook recipient first
        _join(id, alice);
        _join(id, bob);
        rt.setHooks(address(cover), true);
        _admit(id);
    }

    function test_HookRecipientReentry_Swallowed_NoDoublePayAndNoExtra() public {
        for (uint8 attack = 1; attack <= 5; attack++) {
            HookRecipient hr = new HookRecipient(cover);
            uint256 id = _hookGuarantee(hr);
            hr.configure(attack, id, false);
            uint256 hrBefore = usdc.balanceOf(address(hr));
            uint256 aBefore = usdc.balanceOf(alice);
            assertEq(_settle(id, 20), 3);
            assertEq(hr.hookCalls(), 1, "hook ran exactly once");
            assertFalse(hr.lastOk(), "re-entry rejected");
            assertEq(hr.lastRet(), _reentry());
            assertEq(usdc.balanceOf(address(hr)) - hrBefore, 7e6, "hook recipient paid once, gross");
            assertEq(usdc.balanceOf(alice) - aBefore, 7e6);
            assertEq(usdc.balanceOf(address(cover)), 0);
            assertEq(uint8(cover.statusOf(id)), uint8(MicroCover.Status.CLOSED));
        }
    }

    function test_HookRecipientReentry_Bubbled_RollsBackBatch() public {
        for (uint8 attack = 1; attack <= 5; attack++) {
            HookRecipient hr = new HookRecipient(cover);
            uint256 id = _hookGuarantee(hr);
            hr.configure(attack, id, true);
            bytes32 before_ = _snap(id);
            vm.prank(stranger);
            vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
            cover.settleFailure(id, 20);
            assertEq(_snap(id), before_);
            assertFalse(cover.isPaid(id, address(hr)));
            assertFalse(cover.isPaid(id, alice));
        }
    }

    function test_HookRecipientCanReenterOtherGuaranteeToo_GuardIsContractWide() public {
        HookRecipient hr = new HookRecipient(cover);
        uint256 id = _hookGuarantee(hr);
        uint256 other = _create(provider2, COMP, ESC, MAXC);
        _join(other, alice);
        _admit(other);
        hr.configure(1, other, true);
        vm.prank(stranger);
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        cover.settleFailure(id, 20);
        assertEq(cover.getState(other).paidCount, 0, "other guarantee not settled via re-entry");
        assertEq(cover.getState(id).paidCount, 0);
    }

    function test_RevertingHookBlocksItsGuaranteeAtomically_OnlyWhenTokenCallsHooks() public {
        HookRecipient hr = new HookRecipient(cover);
        uint256 id = _hookGuarantee(hr);
        hr.configure(6, id, false);
        bytes32 before_ = _snap(id);
        vm.prank(stranger);
        vm.expectRevert(bytes("hook-revert"));
        cover.settleFailure(id, 20);
        assertEq(_snap(id), before_);

        // The same contract recipient is paid normally by a hook-less token (USDC-style).
        rt.setHooks(address(cover), false);
        assertEq(_settle(id, 20), 3);
        assertEq(hr.hookCalls(), 0, "no hook invoked");
        assertEq(usdc.balanceOf(address(hr)), START + 5e6);
    }
}

/// Scenario 12: fuzzing the whole lifecycle.
contract Phase1FuzzTest is Phase1Base {
    // Fuzz-run parameters live in storage to keep stack usage low.
    uint32 internal fMax;
    uint32 internal fN;
    uint128 internal fComp;
    uint128 internal fEsc;
    address internal fProv;
    uint256 internal fId;
    uint32 internal fPaid;

    function _fuzzCreateAndEnroll() internal {
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

    function _assertStep() internal view {
        uint256 bond = uint256(fComp) * (fMax - fPaid);
        uint256 esc = uint256(fEsc) * (fN - fPaid);
        assertEq(cover.bondOf(fId), bond, "bondOf");
        assertEq(cover.escrowedOf(fId), esc, "escrowedOf");
        assertEq(cover.reservedOf(fId), uint256(fComp) * (fN - fPaid), "reservedOf");
        assertEq(usdc.balanceOf(address(cover)), bond + esc, "solvent: balance == bond + escrow");
        assertEq(cover.getState(fId).paidCount, fPaid);
        MicroCover.Status expected = (fPaid == fN && fN == fMax) ? MicroCover.Status.CLOSED : MicroCover.Status.FAILED;
        assertEq(uint8(cover.statusOf(fId)), uint8(expected), "status");
    }

    function _settleAll(uint256 batchSeed) internal {
        uint256 iter;
        while (fPaid < fN) {
            uint32 req = uint32(uint256(keccak256(abi.encode(batchSeed, iter))) % 20 + 1);
            uint32 remaining = fN - fPaid;
            uint32 got = _settle(fId, req);
            assertEq(got, req < remaining ? req : remaining, "min(requested, remaining)");
            fPaid += got;
            iter++;
            _assertStep();
        }
    }

    /// forge-config: default.fuzz.runs = 120
    function testFuzz_FullLifecycleConservation(
        uint256 maxSeed,
        uint256 nSeed,
        uint256 compSeed,
        uint256 escSeed,
        uint256 batchSeed,
        bool full
    ) public {
        fMax = uint32(bound(maxSeed, 1, 100));
        fN = full ? fMax : uint32(bound(nSeed, 0, fMax));
        fComp = uint128(bound(compSeed, 1, 1e9));
        fEsc = uint128(bound(escSeed, 1, 1e9));
        fPaid = 0;
        _fuzzCreateAndEnroll();
        uint256 provAfterCreate = usdc.balanceOf(fProv);
        assertEq(provAfterCreate, 0, "provider funded exactly the bond");
        assertEq(usdc.balanceOf(address(cover)), uint256(fComp) * fMax + uint256(fEsc) * fN);

        vm.prank(fProv);
        cover.admitFailure(fId);
        assertEq(usdc.balanceOf(address(cover)), uint256(fComp) * fMax + uint256(fEsc) * fN, "admit moves nothing");

        _settleAll(batchSeed);
        if (fN == 0) {
            _assertStep();
            vm.prank(stranger);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToSettle.selector, fId));
            cover.settleFailure(fId, 1);
        }
        if (fN < fMax) {
            assertEq(uint8(cover.statusOf(fId)), uint8(MicroCover.Status.FAILED), "partial cohort stays FAILED");
            assertEq(_withdraw(fId), uint256(fComp) * (fMax - fN), "leftover is exactly the unreserved bond");
        } else {
            vm.prank(fProv);
            vm.expectRevert(abi.encodeWithSelector(MicroCover.NothingToWithdraw.selector, fId));
            cover.withdrawRemainingBond(fId);
        }

        assertEq(uint8(cover.statusOf(fId)), uint8(MicroCover.Status.CLOSED));
        assertEq(usdc.balanceOf(address(cover)), 0, "contract balance back to zero");
        assertEq(usdc.balanceOf(fProv), uint256(fComp) * fMax - uint256(fComp) * fN, "provider got back only the unused bond");
        // provider net = -(compensation * enrolled)
        for (uint256 i; i < fN; i++) {
            assertEq(usdc.balanceOf(_user(i)), uint256(fEsc) + fComp, "beneficiary net +compensation");
            assertTrue(cover.isPaid(fId, _user(i)));
        }
    }

    /// forge-config: default.fuzz.runs = 120
    function testFuzz_JoinCountsBeforeAdmission(uint256 maxSeed, uint256 attemptSeed, uint256 warpSeed) public {
        uint32 maxC = uint32(bound(maxSeed, 1, 100));
        uint256 attempts = bound(attemptSeed, 0, uint256(maxC) + 5);
        uint256 id = _create(provider, COMP, ESC, maxC);
        vm.warp(block.timestamp + bound(warpSeed, 0, 1 days)); // at most exactly the deadline
        for (uint256 i; i < attempts; i++) {
            if (i < maxC) {
                _join(id, _user(i));
            } else {
                _fundUser(_user(i));
                vm.prank(_user(i));
                vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, id));
                cover.joinCohort(id);
            }
        }
        uint32 size = uint32(attempts < maxC ? attempts : maxC);
        MicroCover.GuaranteeState memory s = cover.getState(id);
        assertEq(cover.getGuarantee(id).cohortSize, size);
        assertEq(cover.beneficiaryCount(id), size);
        assertEq(s.enrolled, size);
        assertEq(s.openSlots, maxC - size);
        assertEq(cover.escrowedOf(id), uint256(ESC) * size);
        assertEq(cover.reservedOf(id), uint256(COMP) * size);
        assertEq(cover.bondOf(id), uint256(COMP) * maxC);
        assertEq(cover.isJoinable(id), size < maxC);
        assertEq(usdc.balanceOf(address(cover)), uint256(COMP) * maxC + uint256(ESC) * size);
        if (size > 0) {
            vm.prank(_user(0));
            if (size < maxC) {
                vm.expectRevert(abi.encodeWithSelector(MicroCover.AlreadyMember.selector, id, _user(0)));
            } else {
                vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, id));
            }
            cover.joinCohort(id);
        }
        // Admission freezes the cohort: obligations are exactly (escrow + compensation) per enrollee.
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.FailureAdmitted(id, provider, size, uint256(7e6) * size);
        _admit(id);
        s = cover.getState(id);
        assertEq(s.remainingOwed, uint256(7e6) * size);
        assertEq(s.openSlots, 0);
        assertFalse(cover.isJoinable(id));
        assertEq(usdc.balanceOf(address(cover)), uint256(COMP) * maxC + uint256(ESC) * size, "admit moves nothing");
    }
}
