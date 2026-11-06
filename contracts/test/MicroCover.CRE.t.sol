// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {MicroCover} from "../MicroCover.sol";
import {MicroCoverCREReceiver} from "../MicroCoverCREReceiver.sol";
import {Phase3Base} from "./MicroCover.Phase3.t.sol";

contract MicroCoverCRETest is Phase3Base {
    MicroCoverCREReceiver internal receiver;
    address internal forwarder=address(0xf012);
    bytes32 internal constant WORKFLOW=keccak256("test-workflow");
    bytes10 internal constant NAME=bytes10("microcover");
    uint256 internal id;
    function setUp() public override {
        super.setUp();
        receiver=new MicroCoverCREReceiver(forwarder,WORKFLOW,NAME,address(this));
        // Test fixture replaces only the test's operator. No deployed contract is modified.
        cover=new MicroCover(usdc,address(receiver),120,120);
        vm.prank(provider);usdc.approve(address(cover),type(uint256).max);
        vm.prank(alice);usdc.approve(address(cover),type(uint256).max);
        id=_createB();_join(id,alice);vm.warp(settlementTime);
    }
    function reportFor(uint8 outcome) internal view returns(MicroCover.EvidenceReport memory){return _rep(id,outcome,ROOT1,1,uint64(block.timestamp),uint64(block.timestamp+60));}
    function metadata() internal view returns(bytes memory){return abi.encodePacked(WORKFLOW,NAME,address(this),bytes2(0));}
    function deliver(MicroCover.EvidenceReport memory r) internal {vm.prank(forwarder);receiver.onReport(metadata(),abi.encode(r));}
    function test_EvidenceFailureWithoutProviderAndReplay() public {
        MicroCover.EvidenceReport memory r=reportFor(1);deliver(r);
        assertEq(uint8(cover.statusOf(id)),uint8(MicroCover.Status.FAILED));
        assertEq(cover.getEvidenceState(id).failureOrigin,2);
        vm.expectRevert(MicroCoverCREReceiver.Replay.selector);deliver(r);
    }
    function testUnauthorizedAndWrongWorkflow() public {
        bytes memory payload=abi.encode(reportFor(1));
        vm.expectRevert(MicroCoverCREReceiver.UnauthorizedForwarder.selector);receiver.onReport(metadata(),payload);
        vm.prank(forwarder);vm.expectRevert(MicroCoverCREReceiver.WrongWorkflow.selector);receiver.onReport(abi.encodePacked(bytes32(0),NAME,address(this)),payload);
    }
    function testWrongDomainRollsBackAnchorAndConsumed() public {
        MicroCover.EvidenceReport memory r=reportFor(1);r.cohortId=bytes32(uint256(42));
        vm.expectRevert();deliver(r);
        assertFalse(receiver.consumed(keccak256(abi.encode(r))));
        assertEq(cover.getEvidenceState(id).anchorNonce,0);
        r=reportFor(1);r.chainId=block.chainid+1;
        vm.expectRevert(MicroCoverCREReceiver.WrongDomain.selector);deliver(r);
    }
    function testSuccessPreservesFullReview() public {
        deliver(reportFor(2));
        vm.expectRevert();cover.finalizeSuccess(id);
        vm.warp(block.timestamp+121);cover.finalizeSuccess(id);
        assertEq(uint8(cover.statusOf(id)),uint8(MicroCover.Status.SUCCEEDED));
    }
    function testExpiredAndTimeoutCannotBeOverridden() public {
        MicroCover.EvidenceReport memory r=reportFor(1);
        vm.warp(block.timestamp+61);vm.expectRevert();deliver(r);
        vm.prank(alice);cover.raiseDispute(id);
        vm.warp(block.timestamp+120);cover.finalizeUnresolved(id);
        r=reportFor(1);vm.expectRevert();deliver(r);
    }
}
