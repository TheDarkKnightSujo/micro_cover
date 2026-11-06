// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MicroCover} from "../MicroCover.sol";
import {MockUSDC} from "./MockUSDC.sol";

/// Three live, isolated liabilities travel through evidence failure, reviewed success and refunds.
contract Phase3Handler is Test {
    MockUSDC public token;
    MicroCover public cover;
    address public operator = address(0xA001);
    address public provider = address(0xA002);
    mapping(uint256 => uint64) public firstReady;
    uint256 public evidenceFailures;
    uint256 public successes;
    uint256 public refunds;
    constructor() {
        token = new MockUSDC();
        cover = new MicroCover(IERC20(address(token)), operator, 73, 120);
        token.mint(provider, 1000e6);
        vm.prank(provider); token.approve(address(cover), type(uint256).max);
        for (uint256 i = 1; i <= 3; i++) {
            vm.prank(provider);
            cover.createGuaranteeWithPolicy(5e6, 2e6, 25, uint64(block.timestamp + 30), uint64(block.timestamp + 30), keccak256("terms"), keccak256("policy"), bytes32(i));
            for (uint256 j; j < 25; j++) {
                address member = address(uint160(10000 + i * 100 + j));
                token.mint(member, 20e6);
                vm.startPrank(member); token.approve(address(cover), 2e6); cover.joinCohort(i); vm.stopPrank();
            }
        }
    }
    function elapse(uint256 seed) external { vm.warp(block.timestamp + seed % 151); }
    function advance(uint256 seed) external {
        uint256 id = 1 + seed % 3;
        MicroCover.Status st = cover.statusOf(id);
        if (st == MicroCover.Status.OPEN) {
            if (id == 3) {
                vm.prank(operator); cover.markUncertain(id);
                firstReady[id] = cover.getEvidenceState(id).uncertainReadyAt;
            } else if (block.timestamp > cover.getGuarantee(id).settlementTime) {
                MicroCover.EvidenceState memory e = cover.getEvidenceState(id);
                bytes32 root = keccak256(abi.encode(id, seed));
                vm.prank(operator); cover.anchorEvidence(id, root, e.policyHash, e.cohortId, e.nextAnchorNonce);
                MicroCover.EvidenceReport memory r = MicroCover.EvidenceReport(block.chainid, address(cover), id, e.cohortId, e.policyHash, root, id == 1 ? 1 : 2, uint64(block.timestamp), uint64(block.timestamp + 60), e.nextVerdictNonce);
                vm.prank(operator); cover.submitEvidenceVerdict(r);
                if (id == 1) evidenceFailures++;
            }
        } else if (st == MicroCover.Status.UNCERTAIN) {
            assertEq(cover.getEvidenceState(id).uncertainReadyAt, firstReady[id]);
            if (block.timestamp >= firstReady[id]) cover.finalizeUnresolved(id);
            else { vm.expectRevert(); cover.finalizeUnresolved(id); }
        } else if (st == MicroCover.Status.REFUNDING) {
            if (cover.getEvidenceState(id).refundedCount < 25) refunds += cover.refundUnresolved(id, uint32(1 + seed % 20));
            else { vm.prank(provider); cover.withdrawRemainingBond(id); }
        } else if (st == MicroCover.Status.FAILED) {
            cover.settleFailure(id, uint32(1 + seed % 20));
        } else if (st == MicroCover.Status.SUCCESS_PENDING) {
            if (block.timestamp > cover.getLifecycle(id).successReadyAt) { cover.finalizeSuccess(id); successes++; }
        } else if (st == MicroCover.Status.SUCCEEDED) {
            if (!cover.getLifecycle(id).successEscrowReleased) cover.releaseSuccessEscrow(id);
            else { vm.prank(provider); cover.withdrawRemainingBond(id); }
        } else {
            vm.expectRevert(); cover.finalizeUnresolved(id);
            vm.expectRevert(); cover.refundUnresolved(id, 1);
        }
    }
    function checkAccounting() external view {
        uint256 held;
        for (uint256 id = 1; id <= 3; id++) {
            MicroCover.GuaranteeState memory s = cover.getState(id);
            MicroCover.EvidenceState memory e = cover.getEvidenceState(id);
            MicroCover.LifecycleView memory l = cover.getLifecycle(id);
            assertEq(s.bondHeld + s.paidCompensation + l.withdrawnBond, 125e6);
            assertEq(s.escrowHeld + s.paidEscrow + l.releasedSuccessEscrow + e.refundedEscrow, 50e6);
            assertEq(s.reservedCompensation + s.paidCompensation + l.releasedSuccessReservation + e.releasedUnresolvedReservation, 125e6);
            assertLe(s.paidCount + e.refundedCount, 25);
            if (e.uncertaintyStarted) assertEq(e.uncertainReadyAt, firstReady[id]);
            if (s.outcome == MicroCover.Outcome.UNRESOLVED_REFUNDED) {
                assertEq(s.paidCompensation, 0);
                assertEq(s.remainingOwed, (25 - e.refundedCount) * 2e6);
                if (e.refundedCount < 25) assertEq(s.withdrawableBond, 0);
            }
            held += s.bondHeld + s.escrowHeld;
        }
        assertEq(token.balanceOf(address(cover)), held);
    }
}

/// forge-config: default.invariant.runs = 48
/// forge-config: default.invariant.depth = 120
contract Phase3InvariantTest is Test {
    Phase3Handler internal handler;
    function setUp() public {
        handler = new Phase3Handler();
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = handler.advance.selector; selectors[1] = handler.elapse.selector;
        targetSelector(FuzzSelector(address(handler), selectors));
    }
    function invariant_ConservationAndFirstTimeoutAcrossAllOutcomes() public view { handler.checkAccounting(); }
    function test_DriverActuallyReachesAllThreeClosedOutcomes() public {
        for (uint256 turn; turn < 90; turn++) {
            handler.elapse(151 + 30);
            handler.advance(turn);
            handler.checkAccounting();
        }
        assertEq(handler.evidenceFailures(), 1);
        assertEq(handler.successes(), 1);
        assertEq(handler.refunds(), 25);
        for (uint256 id = 1; id <= 3; id++) assertEq(uint8(handler.cover().statusOf(id)), 2);
    }
}
