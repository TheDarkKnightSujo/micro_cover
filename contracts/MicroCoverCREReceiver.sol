// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MicroCover} from "./MicroCover.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @notice Prepared CRE receiver for a NEW MicroCover configured with this as operator.
/// @dev Not connected to the existing EOA-operated Phase 3 deployment. Arc's documented
/// simulation forwarder is a MOCK: delivery through it is not production DON authentication.
contract MicroCoverCREReceiver is ReentrancyGuard {
    address public immutable forwarder;
    bytes32 public immutable workflowId;
    bytes10 public immutable workflowName;
    address public immutable workflowOwner;
    mapping(bytes32 => bool) public consumed;
    error InvalidConfiguration();
    error UnauthorizedForwarder();
    error WrongWorkflow();
    error WrongDomain();
    error Replay();
    event ReportApplied(address indexed consumer, uint256 indexed guaranteeId, bytes32 indexed digest);

    constructor(address f, bytes32 id, bytes10 name, address owner) {
        if(f==address(0)||id==0||name==0||owner==address(0))revert InvalidConfiguration();
        forwarder=f;workflowId=id;workflowName=name;workflowOwner=owner;
    }

    function supportsInterface(bytes4 id) external pure returns(bool) {
        return id==0x01ffc9a7 || id==this.onReport.selector;
    }

    /// Metadata: workflow ID32 + encoded name10 + owner20 + optional report ID2.
    function onReport(bytes calldata metadata, bytes calldata report) external nonReentrant {
        if(msg.sender!=forwarder)revert UnauthorizedForwarder();
        if(metadata.length!=62 && metadata.length!=64)revert WrongWorkflow();
        if(bytes32(metadata[0:32])!=workflowId || bytes10(metadata[32:42])!=workflowName ||
           address(bytes20(metadata[42:62]))!=workflowOwner)revert WrongWorkflow();
        MicroCover.EvidenceReport memory r=abi.decode(report,(MicroCover.EvidenceReport));
        if(r.chainId!=block.chainid || r.consumer.code.length==0)revert WrongDomain();
        MicroCover target=MicroCover(r.consumer);
        if(target.protocolVersion()!=3 || target.demoOperator()!=address(this))revert WrongDomain();
        bytes32 digest=keccak256(report);
        if(consumed[digest])revert Replay();
        consumed[digest]=true; // Reverts atomically with a rejected anchor or verdict.
        MicroCover.EvidenceState memory e=target.getEvidenceState(r.guaranteeId);
        target.anchorEvidence(r.guaranteeId,r.evidenceRoot,r.policyHash,r.cohortId,e.nextAnchorNonce);
        target.submitEvidenceVerdict(r); // Existing domain, nonce, expiry, review/timeout protections.
        emit ReportApplied(r.consumer,r.guaranteeId,digest);
    }
}
