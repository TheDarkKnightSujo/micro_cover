// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC, FeeOnTransferUSDC} from "./MockUSDC.sol";

abstract contract MicroCoverBase is Test {
    MicroCover internal cover;
    MockUSDC internal usdc;

    address internal provider = makeAddr("provider");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal dave = makeAddr("dave");

    uint128 internal constant COMP = 100e6;
    uint128 internal constant ESCROW = 10e6;
    uint32 internal constant MAXC = 3;
    uint256 internal constant BOND = uint256(COMP) * MAXC;
    bytes32 internal constant TERMS = keccak256("generic-terms");

    uint64 internal joinDeadline;
    uint64 internal settlementTime;

    function setUp() public virtual {
        usdc = new MockUSDC();
        cover = new MicroCover(IERC20(address(usdc)));
        joinDeadline = uint64(block.timestamp + 1 days);
        settlementTime = uint64(block.timestamp + 7 days);

        usdc.mint(provider, 10_000e6);
        address[4] memory bens = [alice, bob, carol, dave];
        for (uint256 i; i < bens.length; i++) {
            usdc.mint(bens[i], 1_000e6);
            vm.prank(bens[i]);
            usdc.approve(address(cover), type(uint256).max);
        }
        vm.prank(provider);
        usdc.approve(address(cover), type(uint256).max);
    }

    function _create() internal returns (uint256 id) {
        vm.prank(provider);
        id = cover.createGuarantee(COMP, ESCROW, MAXC, joinDeadline, settlementTime, TERMS);
    }

    function _join(uint256 id, address who) internal {
        vm.prank(who);
        cover.joinCohort(id);
    }
}

contract MicroCoverTest is MicroCoverBase {
    // ---------------- constructor ----------------

    function test_Constructor_StoresUsdcAndStartsAtOne() public view {
        assertEq(address(cover.usdc()), address(usdc));
        assertEq(cover.nextGuaranteeId(), 1);
        assertEq(cover.MAX_COHORT(), 100);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(MicroCover.ZeroUsdcAddress.selector);
        new MicroCover(IERC20(address(0)));
    }

    // ---------------- createGuarantee happy path ----------------

    function test_CreateGuarantee_LocksBondAndStoresTerms() public {
        uint256 provBefore = usdc.balanceOf(provider);
        uint256 id = _create();

        assertEq(id, 1);
        assertEq(cover.nextGuaranteeId(), 2);
        assertEq(cover.bondOf(id), BOND);
        assertEq(cover.escrowedOf(id), 0);
        assertEq(usdc.balanceOf(address(cover)), BOND);
        assertEq(usdc.balanceOf(provider), provBefore - BOND);

        MicroCover.Guarantee memory g = cover.getGuarantee(id);
        assertEq(g.provider, provider);
        assertEq(g.compensation, COMP);
        assertEq(g.escrowAmount, ESCROW);
        assertEq(g.maxCohort, MAXC);
        assertEq(g.cohortSize, 0);
        assertEq(g.joinDeadline, joinDeadline);
        assertEq(g.settlementTime, settlementTime);
        assertEq(g.termsHash, TERMS);
    }

    function test_CreateGuarantee_EmitsEvent() public {
        vm.expectEmit(true, true, false, true, address(cover));
        emit MicroCover.GuaranteeCreated(1, provider, COMP, ESCROW, MAXC, joinDeadline, settlementTime, TERMS, BOND);
        _create();
    }

    function test_CreateGuarantee_IdsIncrementAndAreIndependent() public {
        uint256 a = _create();
        uint256 b = _create();
        assertEq(a, 1);
        assertEq(b, 2);
        assertEq(cover.nextGuaranteeId(), 3);
        assertEq(cover.bondOf(a), BOND);
        assertEq(cover.bondOf(b), BOND);
        assertEq(usdc.balanceOf(address(cover)), 2 * BOND);
    }

    function test_CreateGuarantee_SettlementEqualToDeadlineAllowed() public {
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, ESCROW, MAXC, joinDeadline, joinDeadline, TERMS);
        assertEq(cover.getGuarantee(id).settlementTime, joinDeadline);
    }

    function test_CreateGuarantee_MaxCohortBoundsAllowed() public {
        usdc.mint(provider, 100_000e6);
        vm.startPrank(provider);
        uint256 one = cover.createGuarantee(COMP, ESCROW, 1, joinDeadline, settlementTime, TERMS);
        uint256 hundred = cover.createGuarantee(COMP, ESCROW, 100, joinDeadline, settlementTime, TERMS);
        vm.stopPrank();
        assertEq(cover.bondOf(one), COMP);
        assertEq(cover.bondOf(hundred), uint256(COMP) * 100);
    }

    // ---------------- createGuarantee reverts ----------------

    function test_CreateGuarantee_RevertsZeroCompensation() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidCompensation.selector);
        cover.createGuarantee(0, ESCROW, MAXC, joinDeadline, settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsZeroEscrow() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidEscrowAmount.selector);
        cover.createGuarantee(COMP, 0, MAXC, joinDeadline, settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsZeroMaxCohort() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidMaxCohort.selector);
        cover.createGuarantee(COMP, ESCROW, 0, joinDeadline, settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsMaxCohortAboveMax() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidMaxCohort.selector);
        cover.createGuarantee(COMP, ESCROW, 101, joinDeadline, settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsJoinDeadlineInPast() public {
        vm.warp(1_000_000);
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidJoinDeadline.selector);
        cover.createGuarantee(COMP, ESCROW, MAXC, uint64(block.timestamp - 1), settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsJoinDeadlineEqualsNow() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidJoinDeadline.selector);
        cover.createGuarantee(COMP, ESCROW, MAXC, uint64(block.timestamp), uint64(block.timestamp + 1), TERMS);
    }

    function test_CreateGuarantee_RevertsSettlementBeforeDeadline() public {
        vm.prank(provider);
        vm.expectRevert(MicroCover.InvalidSettlementTime.selector);
        cover.createGuarantee(COMP, ESCROW, MAXC, joinDeadline, joinDeadline - 1, TERMS);
    }

    function test_CreateGuarantee_RevertsMissingAllowance() public {
        address stranger = makeAddr("stranger");
        usdc.mint(stranger, BOND);
        vm.prank(stranger);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(cover), 0, BOND)
        );
        cover.createGuarantee(COMP, ESCROW, MAXC, joinDeadline, settlementTime, TERMS);
    }

    function test_CreateGuarantee_RevertsInsufficientBalance() public {
        address poor = makeAddr("poor");
        vm.startPrank(poor);
        usdc.approve(address(cover), type(uint256).max);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, poor, 0, BOND));
        cover.createGuarantee(COMP, ESCROW, MAXC, joinDeadline, settlementTime, TERMS);
        vm.stopPrank();
    }

    // ---------------- joinCohort happy path ----------------

    function test_Join_ThreeBeneficiariesExactAccounting() public {
        uint256 id = _create();
        address[3] memory bens = [alice, bob, carol];

        for (uint256 i; i < bens.length; i++) {
            uint256 benBefore = usdc.balanceOf(bens[i]);
            assertTrue(cover.isJoinable(id));
            assertFalse(cover.isMember(id, bens[i]));

            vm.expectEmit(true, true, false, true, address(cover));
            emit MicroCover.CohortJoined(id, bens[i], uint32(i + 1));
            _join(id, bens[i]);

            assertTrue(cover.isMember(id, bens[i]));
            assertEq(usdc.balanceOf(bens[i]), benBefore - ESCROW);
            assertEq(cover.escrowedOf(id), ESCROW * (i + 1));
            assertEq(cover.getGuarantee(id).cohortSize, i + 1);
            assertEq(cover.bondOf(id), BOND);
            assertEq(usdc.balanceOf(address(cover)), BOND + ESCROW * (i + 1));
        }
        assertFalse(cover.isJoinable(id), "full cohort not joinable");
        assertEq(cover.escrowedOf(id), 3 * uint256(ESCROW));
        assertFalse(cover.isMember(id, dave));
        assertFalse(cover.isMember(id, provider));
    }

    function test_Join_AtExactDeadlineAllowed() public {
        uint256 id = _create();
        vm.warp(joinDeadline);
        assertTrue(cover.isJoinable(id));
        _join(id, alice);
        assertTrue(cover.isMember(id, alice));
    }

    function test_Join_SameBeneficiaryCanJoinDifferentGuarantees() public {
        uint256 a = _create();
        uint256 b = _create();
        _join(a, alice);
        _join(b, alice);
        assertEq(cover.escrowedOf(a), ESCROW);
        assertEq(cover.escrowedOf(b), ESCROW);
    }

    // ---------------- joinCohort reverts ----------------

    function test_Join_RevertsUnknownId() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 42));
        cover.joinCohort(42);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 0));
        vm.prank(alice);
        cover.joinCohort(0);
    }

    function test_Join_RevertsAfterDeadline() public {
        uint256 id = _create();
        vm.warp(uint256(joinDeadline) + 1);
        assertFalse(cover.isJoinable(id));
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.JoinDeadlinePassed.selector, id));
        cover.joinCohort(id);
    }

    function test_Join_RevertsCohortFullOnFourthJoiner() public {
        uint256 id = _create();
        _join(id, alice);
        _join(id, bob);
        _join(id, carol);
        vm.prank(dave);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.CohortFull.selector, id));
        cover.joinCohort(id);
        assertEq(cover.escrowedOf(id), 3 * uint256(ESCROW));
    }

    function test_Join_RevertsDuplicate() public {
        uint256 id = _create();
        _join(id, alice);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.AlreadyMember.selector, id, alice));
        cover.joinCohort(id);
        assertEq(cover.escrowedOf(id), ESCROW);
    }

    function test_Join_RevertsProviderJoining() public {
        uint256 id = _create();
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.ProviderCannotJoin.selector, id));
        cover.joinCohort(id);
    }

    function test_Join_RevertsMissingAllowance() public {
        uint256 id = _create();
        address erin = makeAddr("erin");
        usdc.mint(erin, ESCROW);
        vm.prank(erin);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(cover), 0, ESCROW)
        );
        cover.joinCohort(id);
        assertFalse(cover.isMember(id, erin));
        assertEq(cover.escrowedOf(id), 0);
    }

    // ---------------- getters on unknown ids ----------------

    function test_GetGuarantee_RevertsUnknownId() public {
        vm.expectRevert(abi.encodeWithSelector(MicroCover.UnknownGuarantee.selector, 7));
        cover.getGuarantee(7);
    }

    function test_UnknownIdGettersAreZeroOrFalse() public view {
        assertFalse(cover.isJoinable(99));
        assertFalse(cover.isMember(99, alice));
        assertEq(cover.bondOf(99), 0);
        assertEq(cover.escrowedOf(99), 0);
    }

    // ---------------- fuzz ----------------

    function testFuzz_BondEqualsCompensationTimesMaxCohort(uint128 comp, uint32 maxC, uint128 escrow) public {
        comp = uint128(bound(comp, 1, 1e12));
        maxC = uint32(bound(maxC, 1, 100));
        escrow = uint128(bound(escrow, 1, 1e12));
        uint256 expected = uint256(comp) * maxC;
        usdc.mint(provider, expected);
        uint256 provBefore = usdc.balanceOf(provider);

        vm.prank(provider);
        uint256 id = cover.createGuarantee(comp, escrow, maxC, joinDeadline, settlementTime, TERMS);

        assertEq(cover.bondOf(id), expected);
        assertEq(usdc.balanceOf(address(cover)), expected);
        assertEq(usdc.balanceOf(provider), provBefore - expected);
        assertEq(cover.escrowedOf(id), 0);
    }

    function testFuzz_EscrowEqualsEscrowAmountTimesCohortSize(uint128 escrow, uint8 joiners) public {
        escrow = uint128(bound(escrow, 1, 1e6));
        uint256 n = bound(joiners, 0, 10);
        vm.prank(provider);
        uint256 id = cover.createGuarantee(COMP, escrow, 10, joinDeadline, settlementTime, TERMS);
        for (uint256 i; i < n; i++) {
            address b = address(uint160(0x1000 + i));
            usdc.mint(b, escrow);
            vm.startPrank(b);
            usdc.approve(address(cover), escrow);
            cover.joinCohort(id);
            vm.stopPrank();
        }
        assertEq(cover.escrowedOf(id), uint256(escrow) * n);
        assertEq(cover.getGuarantee(id).cohortSize, n);
        assertEq(usdc.balanceOf(address(cover)), cover.bondOf(id) + uint256(escrow) * n);
    }
}

/// Fee-on-transfer token must be rejected by the exact-receipt check.
contract MicroCoverFeeTokenTest is Test {
    MicroCover internal cover;
    FeeOnTransferUSDC internal fee;
    address internal provider = makeAddr("provider");
    address internal alice = makeAddr("alice");

    uint128 internal constant COMP = 100e6;
    uint128 internal constant ESCROW = 10e6;
    uint256 internal constant BOND = uint256(COMP) * 3;

    function setUp() public {
        fee = new FeeOnTransferUSDC();
        cover = new MicroCover(IERC20(address(fee)));
        fee.mint(provider, 1_000e6);
        fee.mint(alice, 1_000e6);
        vm.prank(provider);
        fee.approve(address(cover), type(uint256).max);
        vm.prank(alice);
        fee.approve(address(cover), type(uint256).max);
    }

    function test_CreateGuarantee_RevertsIncorrectUsdcReceived() public {
        uint256 received = BOND - BOND / 10;
        vm.prank(provider);
        vm.expectRevert(abi.encodeWithSelector(MicroCover.IncorrectUsdcReceived.selector, BOND, 0, received));
        cover.createGuarantee(COMP, ESCROW, 3, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), 0);
        assertEq(cover.nextGuaranteeId(), 1, "id counter rolled back");
    }

    function test_Join_RevertsIncorrectUsdcReceived() public {
        // A fee-on-all-transfers token cannot even create a guarantee, so use a token
        // that charges the fee only on transfers sent by alice to exercise the join path.
        FeeFromAliceUSDC t = new FeeFromAliceUSDC(alice);
        MicroCover c2 = new MicroCover(IERC20(address(t)));
        t.mint(provider, 1_000e6);
        t.mint(alice, 1_000e6);
        vm.prank(provider);
        t.approve(address(c2), type(uint256).max);
        vm.prank(alice);
        t.approve(address(c2), type(uint256).max);

        vm.prank(provider);
        uint256 id = c2.createGuarantee(COMP, ESCROW, 3, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), 0);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MicroCover.IncorrectUsdcReceived.selector, ESCROW, BOND, BOND + ESCROW - ESCROW / 10)
        );
        c2.joinCohort(id);
        assertFalse(c2.isMember(id, alice));
        assertEq(c2.escrowedOf(id), 0);
    }
}

/// @dev Charges a 10% fee only on transfers whose sender is `feePayer`.
contract FeeFromAliceUSDC is MockUSDC {
    address internal immutable feePayer;

    constructor(address feePayer_) {
        feePayer = feePayer_;
    }

    function _update(address from, address to, uint256 value) internal override {
        if (from == feePayer && to != address(0) && value > 0) {
            uint256 f = value / 10;
            super._update(from, address(0), f);
            super._update(from, to, value - f);
        } else {
            super._update(from, to, value);
        }
    }
}
