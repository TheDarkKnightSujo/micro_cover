// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MicroCover
/// @notice Phase 3 prototype: provider admission, trusted evidence reports and reviewed success.
/// @dev Not upgradeable; no owner/admin/role rotation. Immutable demoOperator is a trusted
/// demo authority: it can establish evidence-origin FAILURE or start a success review without
/// provider cooperation. Onchain code verifies neither offchain signatures nor evidence truth.
/// An anchor proves a matching submitted commitment, not truth or completeness. Legacy
/// createGuarantee is explicitly manual demo with no evidence policy. reviewWindow and
/// uncertaintyTimeout are separate synthetic test durations, not production safety claims.
/// Phase 2's indefinite-lock rule is superseded only by the bounded uncertaintyTimeout refund
/// fallback. OPEN without a verdict can still lock funds. Only explicit onchain disputes/marks
/// start uncertainty; temporary offchain uncertainty never starts it automatically. A later
/// dispute reuses the FIRST uncertainty deadline and may be immediately timeout-eligible.
/// Beneficiary disputes retain griefing risk. While UNCERTAIN, resolution must precede the
/// timeout; at equality only refund finalization is eligible. Otherwise provider admission
/// remains possible until success is actually finalized, even after its review deadline.
/// A blocklisted recipient still blocks a failure or refund batch for that guarantee atomically;
/// there is no skip, alternate recipient or arbitrary withdrawal. Donations are unaccounted,
/// never withdrawable and never create capacity. Every outgoing transfer requires exact
/// contract debit AND exact recipient credit. Official USDC is supported, not arbitrary
/// rebasing, fee-charging or malicious tokens. All releases affect only their own guarantee.
/// Outcome, Status and payout progress are distinct; explicit outcomes survive CLOSED.
/// paidCount/isPaid/paidCompensation/paidEscrow are FAILURE-only; refunds and success releases
/// have separate counters. Per-guarantee invariants (USDC base units):
/// bondOf + paidCompensation + withdrawnBond == compensation * maxCohort;
/// escrowedOf + paidEscrow + releasedSuccessEscrow + refundedEscrow == escrowAmount * cohortSize;
/// reservedOf + paidCompensation + releasedSuccessReservation + releasedUnresolvedReservation
/// == compensation * cohortSize; reservedOf <= bondOf;
/// paidCount <= cohortSize <= maxCohort <= 100; _beneficiaries.length == cohortSize.
/// Sum over guarantees of (bondOf + escrowedOf) <= usdc.balanceOf(address(this)); reserved
/// compensation is a subset of bondOf, never an additional token liability.
contract MicroCover is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Guarantee terms; compensation and escrowAmount are USDC base units.
    /// @dev Terms are immutable after creation, except cohortSize increments on joining.
    struct Guarantee {
        address provider;
        uint128 compensation;
        uint128 escrowAmount;
        uint32 maxCohort;
        uint32 cohortSize;
        uint64 joinDeadline;
        uint64 settlementTime;
        bytes32 termsHash;
    }

    /// @notice Append-only lifecycle values, independent of the explicitly stored verdict.
    /// @dev OPEN (0): enrollment/awaiting verdict. FAILED (1): failure admitted, settlement
    /// available. CLOSED (2): terminal for either outcome, with no remaining obligation.
    /// SUCCESS_PENDING (3): enrollment closed, success under review, no verdict yet.
    /// SUCCEEDED (4): finalized success, escrow release and bond withdrawal remain.
    /// UNCERTAIN (5): frozen until timely resolution or timeout refund finalization.
    /// REFUNDING (6): unresolved escrow refunds; bond locked until every refund is paid.
    enum Status { OPEN, FAILED, CLOSED, SUCCESS_PENDING, SUCCEEDED, UNCERTAIN, REFUNDING }

    /// @notice Explicit verdict, preserved on closure: NONE (0), FAILURE (1), SUCCESS (2),
    /// UNRESOLVED_REFUNDED (3). The last selects escrow-only refunds, not compensation.
    enum Outcome { NONE, FAILURE, SUCCESS, UNRESOLVED_REFUNDED }

    /// @notice Failure authority: NONE (0), provider admission (1), trusted evidence (2).
    enum FailureOrigin { NONE, PROVIDER, EVIDENCE }

    /// @notice Submitted report commitment; field order is the stable evidence domain ABI.
    /// @dev No offchain signatures or truth are verified by this contract.
    struct EvidenceReport {
        uint256 chainId;
        address consumer;
        uint256 guaranteeId;
        bytes32 cohortId;
        bytes32 policyHash;
        bytes32 evidenceRoot;
        uint8 outcome;
        uint64 evaluatedAt;
        uint64 validUntil;
        uint256 nonce;
    }

    /// @notice Fixed-order evidence/timeout snapshot; separate from legacy tuples.
    /// @dev evidenceBound means policyHash != 0; policyHash/cohortId/createdAt are frozen.
    /// uncertaintyStarted distinguishes timestamp zero from no timer. Since/readyAt keep the
    /// FIRST uncertainty. Refund counters and released reservation are unresolved-only.
    /// Root/anchorNonce describe the latest submitted commitment, not verified evidence.
    /// Next nonces are current + 1; failureOrigin uses FailureOrigin's numeric values.
    /// Last report fields describe only the latest accepted verdict, not a final success.
    struct EvidenceState {
        bool evidenceBound;
        bytes32 policyHash;
        bytes32 cohortId;
        uint64 createdAt;
        uint64 uncertaintyTimeout;
        bool uncertaintyStarted;
        uint64 uncertainSince;
        uint64 uncertainReadyAt;
        uint32 refundedCount;
        uint256 refundedEscrow;
        uint256 releasedUnresolvedReservation;
        bytes32 latestEvidenceRoot;
        uint256 anchorNonce;
        uint256 nextAnchorNonce;
        uint256 verdictNonce;
        uint256 nextVerdictNonce;
        uint8 failureOrigin;
        uint8 lastReportOutcome;
        uint64 lastReportEvaluatedAt;
        uint64 lastReportValidUntil;
    }

    /// @dev Only actual per-guarantee fields; derived evidence view fields are not stored.
    struct Evidence {
        bytes32 policyHash;
        bytes32 cohortId;
        uint64 createdAt;
        bool uncertaintyStarted;
        uint64 uncertainSince;
        uint64 uncertainReadyAt;
        uint32 refundedCount;
        uint256 refundedEscrow;
        uint256 releasedUnresolvedReservation;
        bytes32 latestEvidenceRoot;
        uint256 anchorNonce;
        uint256 verdictNonce;
        FailureOrigin failureOrigin;
        uint8 lastReportOutcome;
        uint64 lastReportEvaluatedAt;
        uint64 lastReportValidUntil;
    }

    /// @notice Separate lifecycle history and success release accounting.
    struct Lifecycle {
        uint64 claimEndsAt;
        uint64 successProposedAt;
        uint64 successReadyAt;
        uint64 successFinalizedAt;
        uint64 uncertainAt;
        address uncertainBy;
        bool successEscrowReleased;
        uint256 releasedSuccessReservation;
        uint256 releasedSuccessEscrow;
    }

    /// @notice Fixed-order lifecycle snapshot, separate from the Phase 1 state tuple.
    struct LifecycleView {
        Status status;
        Outcome outcome;
        uint64 joinDeadline;
        uint64 settlementTime;
        uint64 claimEndsAt;
        uint64 successProposedAt;
        uint64 successReadyAt;
        uint64 successFinalizedAt;
        uint64 uncertainAt;
        address uncertainBy;
        bool successEscrowReleased;
        uint256 releasedSuccessReservation;
        uint256 releasedSuccessEscrow;
        uint256 withdrawnBond;
        address demoOperator;
        uint64 reviewWindow;
    }

    /// @notice Lifecycle and payout counters, separate from immutable guarantee terms.
    struct Progress {
        Status status;
        Outcome outcome;
        uint32 paidCount;
        uint64 failureAdmittedAt;
        uint256 paidCompensation;
        uint256 paidEscrow;
        uint256 withdrawnBond;
    }

    /// @notice Snapshot separating lifecycle, verdict, payout progress, and held funds.
    struct GuaranteeState {
        Status status;
        Outcome outcome;
        uint32 enrolled;
        uint32 paidCount;
        uint32 openSlots;
        uint64 failureAdmittedAt;
        uint256 bondHeld;
        uint256 reservedCompensation;
        uint256 escrowHeld;
        uint256 paidCompensation;
        uint256 paidEscrow;
        uint256 withdrawableBond;
        uint256 remainingOwed;
    }

    /// @notice Maximum number of beneficiaries per guarantee.
    uint32 public constant MAX_COHORT = 100;
    /// @notice Maximum number of beneficiaries paid in one settlement call.
    uint32 public constant MAX_SETTLEMENT_BATCH = 20;

    /// @notice USDC used for all bonds and escrow; amounts use its 6-decimal ERC-20 view.
    IERC20 public immutable usdc;
    /// @notice Trusted immutable demo authority for proposals, uncertainty and bound evidence.
    address public immutable demoOperator;
    /// @notice Synthetic review duration in seconds; not a production safety claim.
    uint64 public immutable reviewWindow;
    /// @notice Separate positive synthetic timeout measured from FIRST onchain uncertainty.
    uint64 public immutable uncertaintyTimeout;
    /// @notice Maximum report validity span in seconds, not a proof of evidence freshness.
    uint64 public constant EVIDENCE_FRESHNESS = 60;

    mapping(uint256 id => Evidence) private _evidence;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _refunded;

    /// @notice The identifier assigned to the next guarantee, starting at 1.
    uint256 public nextGuaranteeId = 1;

    mapping(uint256 id => Guarantee) private _guarantees;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _members;
    mapping(uint256 id => Progress) private _progress;
    mapping(uint256 id => Lifecycle) private _lifecycle;
    mapping(uint256 id => address[]) private _beneficiaries;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _paid;

    /// @notice Bond USDC currently held; starts at compensation * maxCohort and
    /// decreases on compensation payouts and leftover withdrawal. Unknown ids return zero.
    mapping(uint256 id => uint256) public bondOf;

    /// @notice Escrow USDC held; increases on join, decreases on failure payout or success release.
    /// @dev Unknown identifiers return zero.
    mapping(uint256 id => uint256) public escrowedOf;

    /// @notice Compensation reserved for unresolved beneficiaries; a subset of bondOf.
    /// @dev Increases per join, decreases per failure payout, cleared on finalized success.
    /// Unknown identifiers return zero.
    mapping(uint256 id => uint256) public reservedOf;

    /// @notice The USDC address cannot be zero.
    error ZeroUsdcAddress();
    /// @notice Compensation must be positive.
    error InvalidCompensation();
    /// @notice Escrow must be positive.
    error InvalidEscrowAmount();
    /// @notice The cohort bound must be between 1 and MAX_COHORT.
    error InvalidMaxCohort();
    /// @notice The join deadline must be in the future.
    error InvalidJoinDeadline();
    /// @notice Settlement cannot precede the join deadline.
    error InvalidSettlementTime();
    /// @notice No guarantee exists for this identifier.
    error UnknownGuarantee(uint256 id);
    /// @notice The guarantee no longer accepts beneficiaries.
    error JoinDeadlinePassed(uint256 id);
    /// @notice The cohort has reached its bound.
    error CohortFull(uint256 id);
    /// @notice The beneficiary already belongs to the cohort.
    error AlreadyMember(uint256 id, address beneficiary);
    /// @notice A provider cannot join their own guarantee.
    error ProviderCannotJoin(uint256 id);
    /// @notice The USDC balance increase did not equal the required bond or escrow.
    error IncorrectUsdcReceived(uint256 expected, uint256 balanceBefore, uint256 balanceAfter);
    error EnrollmentClosed(uint256 id);
    error InsufficientBondCapacity(uint256 id, uint256 available, uint256 required);
    error NotProvider(uint256 id, address caller);
    error AlreadyAdmitted(uint256 id);
    error NotFailed(uint256 id);
    error NothingToSettle(uint256 id);
    error NothingToWithdraw(uint256 id);
    error LiabilitiesUnpaid(uint256 id, uint32 remaining);
    error InvalidBatchSize(uint32 requested, uint32 max);
    error IncorrectUsdcSent(uint256 expected, uint256 balanceBefore, uint256 balanceAfter);
    /// @notice A payout recipient's balance did not rise by exactly the amount owed
    /// (for example a token that deducts a fee from the recipient).
    error IncorrectRecipientReceipt(address recipient, uint256 expected, uint256 balanceBefore, uint256 balanceAfter);
    error IndexOutOfRange(uint256 id, uint256 index);
    /// @notice Defensive rejection of a duplicate payout in the settlement cursor.
    error AlreadyPaid(uint256 id, address beneficiary);
    /// @notice Defensive rejection of withdrawal while compensation remains reserved.
    error ReservedCompensationRemaining(uint256 id, uint256 reserved);

    /// @notice A provider created a guarantee and locked its bond.
    event GuaranteeCreated(
        uint256 indexed id,
        address indexed provider,
        uint128 compensation,
        uint128 escrowAmount,
        uint32 maxCohort,
        uint64 joinDeadline,
        uint64 settlementTime,
        bytes32 termsHash,
        uint256 bond
    );

    /// @notice A beneficiary locked escrow and joined the cohort.
    event CohortJoined(uint256 indexed id, address indexed beneficiary, uint32 cohortSize);
    event FailureAdmitted(uint256 indexed id, address indexed provider, uint32 enrolled, uint256 totalOwed);
    event BeneficiaryPaid(
        uint256 indexed id, address indexed beneficiary, uint256 escrowReturned, uint256 compensationPaid
    );
    event SettlementBatchProcessed(
        uint256 indexed id, address indexed caller, uint32 settled, uint32 paidCount, uint32 enrolled
    );
    event GuaranteeClosed(uint256 indexed id);
    event RemainingBondWithdrawn(uint256 indexed id, address indexed provider, uint256 amount);

    /// @notice The immutable demo operator cannot be zero.
    error ZeroOperatorAddress();
    /// @notice The review duration must be positive.
    error ZeroReviewWindow();
    /// @notice A computed timestamp cannot fit the stored uint64 representation.
    error TimestampOverflow(uint256 value);
    /// @notice The caller is not the immutable demo operator.
    error NotDemoOperator(address caller);
    /// @notice This operation is unavailable in the guarantee's current status.
    error InvalidStatus(uint256 id, Status status);
    /// @notice Success cannot be proposed before enrollment ends and settlement is due.
    error ProposalTooEarly(uint256 id, uint256 earliestTimestamp);
    /// @notice Only an enrolled beneficiary may raise a dispute.
    error NotBeneficiary(uint256 id, address caller);
    /// @notice The inclusive beneficiary dispute deadline has passed.
    error DisputeWindowClosed(uint256 id, uint64 deadline);
    /// @notice Failure cannot be admitted after success has finalized.
    error SuccessAlreadyFinalized(uint256 id);
    /// @notice Success finalization requires strictly passing the review deadline.
    error ReviewWindowOpen(uint256 id, uint64 successReadyAt);
    /// @notice Success escrow has already been released, including a zero release.
    error SuccessEscrowAlreadyReleased(uint256 id);
    /// @notice Success escrow must be released before withdrawing the bond.
    error SuccessEscrowNotReleased(uint256 id);

    /// @notice The operator proposed success without recording a final verdict.
    event SuccessProposed(uint256 indexed id, address indexed operator, uint64 readyAt);
    /// @notice An enrolled beneficiary froze the guarantee without selecting a payout.
    event DisputeRaised(uint256 indexed id, address indexed beneficiary);
    /// @notice The operator exercised trusted blocking power without selecting a payout.
    event UncertaintyMarked(uint256 indexed id, address indexed operator);
    /// @notice Success finalized and this guarantee's compensation reservation was released.
    event SuccessFinalized(uint256 indexed id, uint256 releasedReservation);
    /// @notice This guarantee's success escrow was released once to its provider.
    event SuccessEscrowReleased(uint256 indexed id, address indexed provider, uint256 amount);

    /// @notice The independent uncertainty duration must be positive.
    error ZeroUncertaintyTimeout();
    error EvidenceReportRequired(uint256 id);
    /// @notice Evidence-bound creation requires a nonzero policy commitment.
    error ZeroPolicyHash();
    /// @notice Evidence-bound creation requires a nonzero cohort domain.
    error ZeroCohortId();
    /// @notice Manual-demo guarantees cannot accept evidence operations.
    error NotEvidenceBound(uint256 id);
    /// @notice An anchor commitment cannot be zero.
    error ZeroEvidenceRoot();
    /// @notice Report/anchor policy or cohort differs from frozen creation terms.
    error EvidenceBindingMismatch(uint256 id);
    /// @notice Each independent nonce stream must advance exactly once.
    error InvalidNonce(uint256 expected, uint256 got);
    /// @notice The report targets a different chain.
    error WrongChain(uint256 expected, uint256 got);
    /// @notice The report targets a different consumer contract.
    error WrongConsumer(address got);
    /// @notice The report must match the latest nonzero submitted commitment.
    error EvidenceRootMismatch(uint256 id, bytes32 expected, bytes32 got);
    /// @notice Only FAILURE (1) or SUCCESS (2) reports are accepted.
    error InvalidEvidenceOutcome(uint8 outcome);
    /// @notice Evaluation precedes the guarantee's settlement time.
    error EvidenceTooEarly(uint64 evaluatedAt, uint64 settlementTime);
    /// @notice Evaluation cannot be in the future.
    error EvidenceFromFuture(uint64 evaluatedAt, uint256 currentTime);
    /// @notice Report validity has already expired.
    error EvidenceExpired(uint64 validUntil, uint256 currentTime);
    /// @notice Validity must span evaluation through at most EVIDENCE_FRESHNESS seconds.
    error InvalidValidity(uint64 evaluatedAt, uint64 validUntil);
    /// @notice UNCERTAIN resolution is forbidden at or after the first timeout.
    error UncertaintyTimeoutReached(uint256 id, uint64 readyAt);
    /// @notice Unresolved finalization requires reaching the first timeout.
    error UncertaintyTimeoutNotReached(uint256 id, uint64 readyAt);
    /// @notice Unresolved refund outcome cannot be replaced with provider failure.
    error UnresolvedAlreadyFinalized(uint256 id);
    /// @notice No unresolved escrow refunds remain.
    error NothingToRefund(uint256 id);
    /// @notice Defensive rejection of a duplicate refund in the enrollment cursor.
    error AlreadyRefunded(uint256 id, address beneficiary);
    /// @notice Bond stays locked until all unresolved escrow refunds are paid.
    error RefundsPending(uint256 id, uint32 remaining);

    /// @notice Creation froze the evidence policy and cohort domain.
    event EvidencePolicyBound(uint256 indexed id, bytes32 policyHash, bytes32 cohortId);
    /// @notice First explicit onchain uncertainty started the nonextendable timeout.
    event UncertaintyStarted(uint256 indexed id, address indexed by, uint64 since, uint64 readyAt);
    /// @notice Operator submitted a commitment; this does not prove evidence truth/completeness.
    event EvidenceAnchored(uint256 indexed id, bytes32 indexed root, uint256 nonce);
    /// @notice An accepted trusted report started a full review, not a final success outcome.
    event EvidenceSuccessReported(
        uint256 indexed id, bytes32 indexed root, uint256 nonce, uint64 evaluatedAt, uint64 readyAt
    );
    /// @notice Operator established evidence-origin failure without provider admission.
    event EvidenceFailureEstablished(
        uint256 indexed id, bytes32 indexed root, uint256 nonce, uint64 evaluatedAt,
        uint32 enrolled, uint256 totalOwed
    );
    /// @notice An enrolled member requested evaluation only; no outcome or dispute is chosen.
    event EvaluationRequested(uint256 indexed id, address indexed requester);
    /// @notice Timeout selected escrow-only refunds and released compensation reservation.
    event UnresolvedFinalized(uint256 indexed id, uint256 releasedReservation, uint32 enrolled);
    /// @notice An enrolled beneficiary's full escrow was accounted for refund.
    event BeneficiaryRefunded(uint256 indexed id, address indexed beneficiary, uint256 escrow);
    /// @notice A bounded enrollment-order escrow refund batch was processed atomically.
    event RefundBatchProcessed(
        uint256 indexed id, address indexed caller, uint32 refunded, uint32 refundedCount, uint32 enrolled
    );

    /// @param usdc_ USDC address supplied by the deployer; not hardcoded.
    /// @param demoOperator_ Trusted immutable human-controlled demo authority.
    /// @param reviewWindow_ Positive synthetic review duration in seconds.
    /// @param uncertaintyTimeout_ Independent positive synthetic uncertainty duration.
    constructor(IERC20 usdc_, address demoOperator_, uint64 reviewWindow_, uint64 uncertaintyTimeout_) {
        if (address(usdc_) == address(0)) revert ZeroUsdcAddress();
        if (demoOperator_ == address(0)) revert ZeroOperatorAddress();
        if (reviewWindow_ == 0) revert ZeroReviewWindow();
        if (uncertaintyTimeout_ == 0) revert ZeroUncertaintyTimeout();
        usdc = usdc_;
        demoOperator = demoOperator_;
        reviewWindow = reviewWindow_;
        uncertaintyTimeout = uncertaintyTimeout_;
    }

    /// @notice Return the contract lifecycle protocol version.
    function protocolVersion() external pure returns (uint256) {
        return 3;
    }

    /// @notice Create an explicitly manual-demo guarantee with no evidence policy and lock its bond.
    /// @param compensation USDC base units of compensation per beneficiary on failure.
    /// @param escrowAmount USDC base units each beneficiary must lock.
    /// @param maxCohort Maximum beneficiary count, between 1 and MAX_COHORT.
    /// @param joinDeadline Last timestamp at which beneficiaries may join.
    /// @param settlementTime Settlement timestamp, no earlier than joinDeadline.
    /// @param termsHash Opaque hash of off-chain terms.
    /// @return id The newly created guarantee identifier.
    /// @dev settlementTime gates success proposals; provider failure admission is not time-gated.
    function createGuarantee(
        uint128 compensation,
        uint128 escrowAmount,
        uint32 maxCohort,
        uint64 joinDeadline,
        uint64 settlementTime,
        bytes32 termsHash
    ) external nonReentrant returns (uint256 id) {
        return _create(compensation, escrowAmount, maxCohort, joinDeadline, settlementTime, termsHash, 0, 0);
    }

    /// @notice Atomically create/fund a guarantee with frozen nonzero evidence policy/cohort.
    /// @dev Same terms/bond rules as manual creation; no policy mutation or external self-call.
    function createGuaranteeWithPolicy(
        uint128 compensation, uint128 escrowAmount, uint32 maxCohort,
        uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash,
        bytes32 policyHash, bytes32 cohortId
    ) external nonReentrant returns (uint256 id) {
        if (policyHash == 0) revert ZeroPolicyHash();
        if (cohortId == 0) revert ZeroCohortId();
        return _create(compensation, escrowAmount, maxCohort, joinDeadline, settlementTime, termsHash,
            policyHash, cohortId);
    }

    /// @dev Shared atomic creation for manual-demo and evidence-bound guarantees.
    function _create(
        uint128 compensation, uint128 escrowAmount, uint32 maxCohort,
        uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash,
        bytes32 policyHash, bytes32 cohortId
    ) private returns (uint256 id) {
        if (compensation == 0) revert InvalidCompensation();
        if (escrowAmount == 0) revert InvalidEscrowAmount();
        if (maxCohort == 0 || maxCohort > MAX_COHORT) revert InvalidMaxCohort();
        if (joinDeadline <= block.timestamp) revert InvalidJoinDeadline();
        if (settlementTime < joinDeadline) revert InvalidSettlementTime();
        uint64 claimEndsAt = _timestamp64(uint256(settlementTime) + reviewWindow);

        uint256 bond = uint256(compensation) * uint256(maxCohort);
        id = nextGuaranteeId;
        nextGuaranteeId = id + 1;
        _guarantees[id] = Guarantee({
            provider: msg.sender,
            compensation: compensation,
            escrowAmount: escrowAmount,
            maxCohort: maxCohort,
            cohortSize: 0,
            joinDeadline: joinDeadline,
            settlementTime: settlementTime,
            termsHash: termsHash
        });
        bondOf[id] = bond;
        escrowedOf[id] = 0;
        _lifecycle[id].claimEndsAt = claimEndsAt;
        {
            Evidence storage evidence = _evidence[id];
            evidence.policyHash = policyHash;
            evidence.cohortId = cohortId;
            evidence.createdAt = _timestamp64(block.timestamp);
        }

        _pullUsdc(msg.sender, bond);

        emit GuaranteeCreated(
            id, msg.sender, compensation, escrowAmount, maxCohort,
            joinDeadline, settlementTime, termsHash, bond
        );
        if (policyHash != 0) emit EvidencePolicyBound(id, policyHash, cohortId);
    }

    /// @notice Join a guarantee's cohort by locking its required escrow.
    /// @param id An existing guarantee identifier.
    /// @dev Joining is allowed through joinDeadline inclusive, only while OPEN.
    /// Capacity uses this guarantee's unreserved bond, never the token balance.
    function joinCohort(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (_progress[id].status != Status.OPEN) revert EnrollmentClosed(id);
        if (block.timestamp > guarantee.joinDeadline) revert JoinDeadlinePassed(id);
        if (guarantee.cohortSize >= guarantee.maxCohort) revert CohortFull(id);
        if (_members[id][msg.sender]) revert AlreadyMember(id, msg.sender);
        if (msg.sender == guarantee.provider) revert ProviderCannotJoin(id);

        uint256 compensation = uint256(guarantee.compensation);
        uint256 reserved = reservedOf[id];
        uint256 bond = bondOf[id];
        if (reserved + compensation > bond) {
            revert InsufficientBondCapacity(id, bond > reserved ? bond - reserved : 0, compensation);
        }

        _beneficiaries[id].push(msg.sender);
        _members[id][msg.sender] = true;
        guarantee.cohortSize += 1;
        reservedOf[id] = reserved + compensation;
        escrowedOf[id] += uint256(guarantee.escrowAmount);

        _pullUsdc(msg.sender, uint256(guarantee.escrowAmount));

        emit CohortJoined(id, msg.sender, guarantee.cohortSize);
    }

    /// @notice Propose success once, closing enrollment without a verdict or token movement.
    /// @dev Only demoOperator; a late proposal still receives a full reviewWindow.
    /// No reservation is released until permissionless finalization strictly after readyAt.
    function proposeSuccess(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != demoOperator) revert NotDemoOperator(msg.sender);
        Progress storage progress = _progress[id];
        if (progress.status != Status.OPEN) revert InvalidStatus(id, progress.status);
        _requireProposalTime(id, guarantee);
        if (_evidence[id].policyHash != 0) revert EvidenceReportRequired(id);
        _proposeSuccess(id);
    }

    /// @notice Freeze an OPEN or pending guarantee within its inclusive dispute window.
    /// @dev Only enrolled beneficiaries; no payout is selected and no tokens move.
    /// Starts the FIRST timeout only once; subsequent disputes preserve its original deadline.
    function raiseDispute(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (!_members[id][msg.sender]) revert NotBeneficiary(id, msg.sender);
        Status status = _progress[id].status;
        uint64 deadline;
        if (status == Status.OPEN) deadline = _lifecycle[id].claimEndsAt;
        else if (status == Status.SUCCESS_PENDING) deadline = _lifecycle[id].successReadyAt;
        else revert InvalidStatus(id, status);
        if (block.timestamp > deadline) revert DisputeWindowClosed(id, deadline);
        _startUncertainty(id);
        emit DisputeRaised(id, msg.sender);
    }

    /// @notice Exercise trusted operator blocking power on an OPEN or pending guarantee.
    /// @dev No marking-window limit, token movement or payout selection. Starts the FIRST
    /// uncertainty timeout once; timely bound evidence can resolve back to a full success review.
    function markUncertain(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != demoOperator) revert NotDemoOperator(msg.sender);
        Status status = _progress[id].status;
        if (status != Status.OPEN && status != Status.SUCCESS_PENDING) revert InvalidStatus(id, status);
        _startUncertainty(id);
        emit UncertaintyMarked(id, msg.sender);
    }

    /// @notice Submit a latest evidence commitment for a policy-bound guarantee.
    /// @dev Operator only; validates binding/strict anchor nonce, not signatures or truth.
    /// No uncertainty timer, lifecycle or report clock is changed.
    function anchorEvidence(uint256 id, bytes32 root, bytes32 policyHash, bytes32 cohortId, uint256 nonce)
        external nonReentrant
    {
        Evidence storage evidence = _requireBound(id, true);
        if (root == 0) revert ZeroEvidenceRoot();
        if (policyHash != evidence.policyHash || cohortId != evidence.cohortId) {
            revert EvidenceBindingMismatch(id);
        }
        uint256 expected = evidence.anchorNonce + 1;
        if (nonce != expected) revert InvalidNonce(expected, nonce);
        _requireEvidenceStatus(id);
        evidence.latestEvidenceRoot = root;
        evidence.anchorNonce = nonce;
        emit EvidenceAnchored(id, root, nonce);
    }

    /// @notice Accept an operator's bound submitted commitment as a FAILURE or success review.
    /// @dev Trusted demo authority, NOT offchain signature/truth verification. The operator can
    /// establish evidence-origin failure without provider cooperation; it never calls admitFailure
    /// or emits FailureAdmitted. Only a matching latest submitted anchor is accepted.
    function submitEvidenceVerdict(EvidenceReport calldata r) external nonReentrant {
        uint256 id = r.guaranteeId;
        Evidence storage evidence = _requireBound(id, true);
        if (r.chainId != block.chainid) revert WrongChain(block.chainid, r.chainId);
        if (r.consumer != address(this)) revert WrongConsumer(r.consumer);
        if (r.cohortId != evidence.cohortId || r.policyHash != evidence.policyHash) {
            revert EvidenceBindingMismatch(id);
        }
        if (r.evidenceRoot == 0 || r.evidenceRoot != evidence.latestEvidenceRoot) {
            revert EvidenceRootMismatch(id, evidence.latestEvidenceRoot, r.evidenceRoot);
        }
        if (r.outcome != 1 && r.outcome != 2) revert InvalidEvidenceOutcome(r.outcome);
        uint256 expected = evidence.verdictNonce + 1;
        if (r.nonce != expected) revert InvalidNonce(expected, r.nonce);
        Guarantee storage guarantee = _guarantees[id];
        if (r.evaluatedAt < guarantee.settlementTime) {
            revert EvidenceTooEarly(r.evaluatedAt, guarantee.settlementTime);
        }
        if (r.evaluatedAt > block.timestamp) revert EvidenceFromFuture(r.evaluatedAt, block.timestamp);
        if (r.validUntil < block.timestamp) revert EvidenceExpired(r.validUntil, block.timestamp);
        uint64 latest = _timestamp64(uint256(r.evaluatedAt) + EVIDENCE_FRESHNESS);
        if (r.validUntil < r.evaluatedAt || r.validUntil > latest) {
            revert InvalidValidity(r.evaluatedAt, r.validUntil);
        }
        Status status = _requireEvidenceStatus(id);
        if (status == Status.UNCERTAIN) _requireBeforeTimeout(id);
        evidence.verdictNonce = r.nonce;
        evidence.lastReportOutcome = r.outcome;
        evidence.lastReportEvaluatedAt = r.evaluatedAt;
        evidence.lastReportValidUntil = r.validUntil;
        if (r.outcome == 2) {
            if (status == Status.SUCCESS_PENDING) revert InvalidStatus(id, status);
            _requireProposalTime(id, guarantee);
            uint64 ready = _proposeSuccess(id);
            emit EvidenceSuccessReported(id, r.evidenceRoot, r.nonce, r.evaluatedAt, ready);
        } else {
            _progress[id].status = Status.FAILED;
            _progress[id].outcome = Outcome.FAILURE;
            evidence.failureOrigin = FailureOrigin.EVIDENCE;
            _lifecycle[id].successReadyAt = 0;
            emit EvidenceFailureEstablished(id, r.evidenceRoot, r.nonce, r.evaluatedAt,
                guarantee.cohortSize,
                (uint256(guarantee.escrowAmount) + guarantee.compensation) * guarantee.cohortSize);
        }
    }

    /// @notice Request evaluation only; no dispute, state mutation, chosen outcome or fund move.
    /// @dev Enrolled members only, for a bound OPEN, SUCCESS_PENDING or UNCERTAIN guarantee.
    function requestEvaluation(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (!_members[id][msg.sender]) revert NotBeneficiary(id, msg.sender);
        _requireBound(id, false);
        _requireEvidenceStatus(id);
        emit EvaluationRequested(id, msg.sender);
    }

    /// @notice Permissionlessly select escrow-only refunds after the FIRST uncertainty timeout.
    /// @dev No token movement or compensation payout; bond remains locked and escrow owed.
    function finalizeUnresolved(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        if (progress.status != Status.UNCERTAIN) revert InvalidStatus(id, progress.status);
        Evidence storage evidence = _evidence[id];
        if (block.timestamp < evidence.uncertainReadyAt) {
            revert UncertaintyTimeoutNotReached(id, evidence.uncertainReadyAt);
        }
        progress.outcome = Outcome.UNRESOLVED_REFUNDED;
        progress.status = Status.REFUNDING;
        uint256 released = reservedOf[id];
        evidence.releasedUnresolvedReservation = released;
        reservedOf[id] = 0;
        _lifecycle[id].successReadyAt = 0;
        emit UnresolvedFinalized(id, released, guarantee.cohortSize);
    }

    /// @notice Permissionlessly refund the next bounded enrollment-order batch of full escrows.
    /// @dev Refund-only counters; all effects precede exact-debit/exact-credit transfers.
    /// A rejected recipient rolls back the whole batch; no skipping or alternate wallet.
    function refundUnresolved(uint256 id, uint32 maxBeneficiaries)
        external nonReentrant returns (uint32 refunded)
    {
        if (maxBeneficiaries == 0 || maxBeneficiaries > MAX_SETTLEMENT_BATCH) {
            revert InvalidBatchSize(maxBeneficiaries, MAX_SETTLEMENT_BATCH);
        }
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        if (progress.status == Status.CLOSED && progress.outcome == Outcome.UNRESOLVED_REFUNDED) {
            revert NothingToRefund(id);
        }
        if (progress.status != Status.REFUNDING) revert InvalidStatus(id, progress.status);
        Evidence storage evidence = _evidence[id];
        uint32 start = evidence.refundedCount;
        if (start == guarantee.cohortSize) revert NothingToRefund(id);
        refunded = guarantee.cohortSize - start;
        if (refunded > maxBeneficiaries) refunded = maxBeneficiaries;
        uint256 escrow = guarantee.escrowAmount;
        for (uint32 i = 0; i < refunded; ++i) {
            address beneficiary = _beneficiaries[id][start + i];
            if (_refunded[id][beneficiary]) revert AlreadyRefunded(id, beneficiary);
            _refunded[id][beneficiary] = true;
            emit BeneficiaryRefunded(id, beneficiary, escrow);
        }
        escrowedOf[id] -= escrow * refunded;
        evidence.refundedEscrow += escrow * refunded;
        evidence.refundedCount = start + refunded;
        emit RefundBatchProcessed(id, msg.sender, refunded, evidence.refundedCount, guarantee.cohortSize);
        _transferBatch(id, start, refunded, escrow);
    }

    /// @notice Finalize reviewed success permissionlessly, releasing only its reservation.
    /// @dev Strictly after successReadyAt. Records SUCCESS explicitly, moves no tokens,
    /// and leaves bond and escrow held for separate release and withdrawal calls.
    function finalizeSuccess(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        if (progress.status != Status.SUCCESS_PENDING) revert InvalidStatus(id, progress.status);
        Lifecycle storage lifecycle = _lifecycle[id];
        if (block.timestamp <= lifecycle.successReadyAt) revert ReviewWindowOpen(id, lifecycle.successReadyAt);
        progress.outcome = Outcome.SUCCESS;
        progress.status = Status.SUCCEEDED;
        lifecycle.successFinalizedAt = _timestamp64(block.timestamp);
        uint256 released = reservedOf[id];
        lifecycle.releasedSuccessReservation = released;
        reservedOf[id] = 0;
        emit SuccessFinalized(id, released);
    }

    /// @notice Release this guarantee's entire success escrow once to its provider.
    /// @dev Permissionless; effects precede exact sender-debit and recipient-credit checks.
    /// An empty cohort records a zero release and emits the event without a token transfer.
    /// @return amount The escrow released; never supplied by the caller.
    function releaseSuccessEscrow(uint256 id) external nonReentrant returns (uint256 amount) {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Status status = _progress[id].status;
        if (status != Status.SUCCEEDED) revert InvalidStatus(id, status);
        Lifecycle storage lifecycle = _lifecycle[id];
        if (lifecycle.successEscrowReleased) revert SuccessEscrowAlreadyReleased(id);
        amount = escrowedOf[id];
        escrowedOf[id] = 0;
        lifecycle.releasedSuccessEscrow = amount;
        lifecycle.successEscrowReleased = true;
        if (amount > 0) _sendUsdc(guarantee.provider, amount);
        emit SuccessEscrowReleased(id, guarantee.provider, amount);
    }

    /// @notice Admit failure once, closing enrollment without moving any tokens.
    /// @dev Only this guarantee's provider, while OPEN, SUCCESS_PENDING or UNCERTAIN,
    /// even after a review deadline until success is actually finalized.
    /// Zero enrollment remains FAILED until the provider withdraws the whole bond.
    function admitFailure(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != guarantee.provider) revert NotProvider(id, msg.sender);
        Progress storage progress = _progress[id];
        if (progress.status == Status.FAILED
            || (progress.status == Status.CLOSED && progress.outcome == Outcome.FAILURE)) {
            revert AlreadyAdmitted(id);
        }
        if (progress.status == Status.SUCCEEDED
            || (progress.status == Status.CLOSED && progress.outcome == Outcome.SUCCESS)) {
            revert SuccessAlreadyFinalized(id);
        }
        if (progress.status == Status.REFUNDING
            || (progress.status == Status.CLOSED && progress.outcome == Outcome.UNRESOLVED_REFUNDED)) {
            revert UnresolvedAlreadyFinalized(id);
        }
        if (progress.status != Status.OPEN && progress.status != Status.SUCCESS_PENDING
            && progress.status != Status.UNCERTAIN) revert InvalidStatus(id, progress.status);
        if (progress.status == Status.UNCERTAIN) _requireBeforeTimeout(id);
        _evidence[id].failureOrigin = FailureOrigin.PROVIDER;

        _lifecycle[id].successReadyAt = 0;
        progress.status = Status.FAILED;
        progress.outcome = Outcome.FAILURE;
        progress.failureAdmittedAt = uint64(block.timestamp);
        emit FailureAdmitted(
            id, guarantee.provider, guarantee.cohortSize,
            (uint256(guarantee.escrowAmount) + uint256(guarantee.compensation)) * guarantee.cohortSize
        );
    }

    /// @notice Pay the next bounded batch of beneficiaries after failure admission.
    /// @dev Permissionless; enrollment order and frozen terms fix recipients and amounts.
    /// All batch effects precede transfers. Any failure rolls back the entire batch.
    /// @return settled Number of beneficiaries paid by this call.
    function settleFailure(uint256 id, uint32 maxBeneficiaries)
        external nonReentrant returns (uint32 settled)
    {
        if (maxBeneficiaries == 0 || maxBeneficiaries > MAX_SETTLEMENT_BATCH) {
            revert InvalidBatchSize(maxBeneficiaries, MAX_SETTLEMENT_BATCH);
        }
        Guarantee memory guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        if (progress.status == Status.OPEN) revert NotFailed(id);
        if (progress.status != Status.FAILED
            && !(progress.status == Status.CLOSED && progress.outcome == Outcome.FAILURE)) {
            revert InvalidStatus(id, progress.status);
        }
        uint32 start = progress.paidCount;
        if (start == guarantee.cohortSize) revert NothingToSettle(id);
        settled = guarantee.cohortSize - start;
        if (settled > maxBeneficiaries) settled = maxBeneficiaries;

        uint256 compensation = uint256(guarantee.compensation);
        uint256 escrow = uint256(guarantee.escrowAmount);
        for (uint32 i = 0; i < settled; ++i) {
            address beneficiary = _beneficiaries[id][start + i];
            if (_paid[id][beneficiary]) revert AlreadyPaid(id, beneficiary);
            _paid[id][beneficiary] = true;
            emit BeneficiaryPaid(id, beneficiary, escrow, compensation);
        }

        progress.paidCount = start + settled;
        reservedOf[id] -= compensation * settled;
        bondOf[id] -= compensation * settled;
        escrowedOf[id] -= escrow * settled;
        progress.paidCompensation += compensation * settled;
        progress.paidEscrow += escrow * settled;
        if (progress.paidCount == guarantee.cohortSize && bondOf[id] == 0) {
            progress.status = Status.CLOSED;
            emit GuaranteeClosed(id);
        }
        emit SettlementBatchProcessed(id, msg.sender, settled, progress.paidCount, guarantee.cohortSize);

        _transferBatch(id, start, settled, escrow + compensation);
    }

    /// @notice Withdraw only this guarantee's leftover bond to its own provider.
    /// @dev Requires established failure and all beneficiaries paid, finalized success with
    /// escrow released, or unresolved finalization with all escrows refunded. Amount is bondOf, never
    /// supplied by the caller. A fully paid full failure cohort is already CLOSED.
    /// @return amount Leftover bond withdrawn.
    function withdrawRemainingBond(uint256 id) external nonReentrant returns (uint256 amount) {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != guarantee.provider) revert NotProvider(id, msg.sender);
        Progress storage progress = _progress[id];
        if (progress.status == Status.OPEN) revert NotFailed(id);
        if (progress.status == Status.CLOSED) revert NothingToWithdraw(id);
        if (progress.status == Status.SUCCEEDED) {
            if (!_lifecycle[id].successEscrowReleased) revert SuccessEscrowNotReleased(id);
        } else if (progress.status == Status.REFUNDING) {
            uint32 remaining = guarantee.cohortSize - _evidence[id].refundedCount;
            if (remaining != 0) revert RefundsPending(id, remaining);
        } else {
            if (progress.status != Status.FAILED) revert InvalidStatus(id, progress.status);
            if (progress.paidCount < guarantee.cohortSize) {
                revert LiabilitiesUnpaid(id, guarantee.cohortSize - progress.paidCount);
            }
        }
        if (reservedOf[id] != 0) revert ReservedCompensationRemaining(id, reservedOf[id]);
        amount = bondOf[id];
        bondOf[id] = 0;
        progress.withdrawnBond += amount;
        progress.status = Status.CLOSED;
        emit RemainingBondWithdrawn(id, guarantee.provider, amount);
        emit GuaranteeClosed(id);

        _sendUsdc(guarantee.provider, amount);
    }

    /// @notice Return the terms and current cohort size of an existing guarantee.
    /// @param id An existing guarantee identifier; unknown identifiers revert.
    /// @return guarantee The stored guarantee.
    function getGuarantee(uint256 id) external view returns (Guarantee memory guarantee) {
        guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
    }

    /// @notice Return whether account belongs to the guarantee's cohort.
    /// @dev Unknown identifiers return false.
    function isMember(uint256 id, address account) external view returns (bool) {
        return _members[id][account];
    }

    /// @notice Return whether a guarantee is OPEN, within its deadline, and has capacity.
    /// @dev Does not check any particular beneficiary's eligibility or USDC allowance.
    /// Unknown identifiers return false; direct donations never affect capacity.
    function isJoinable(uint256 id) external view returns (bool) {
        Guarantee storage guarantee = _guarantees[id];
        return guarantee.provider != address(0)
            && _progress[id].status == Status.OPEN
            && block.timestamp <= guarantee.joinDeadline
            && guarantee.cohortSize < guarantee.maxCohort
            && reservedOf[id] + uint256(guarantee.compensation) <= bondOf[id];
    }

    /// @notice Return lifecycle status; unknown identifiers revert.
    function statusOf(uint256 id) external view returns (Status) {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        return _progress[id].status;
    }

    /// @notice Return the stored verdict, independent of lifecycle and payout counters.
    /// @dev Explicitly recorded on failure admission or success finalization; unknown ids revert.
    function outcomeOf(uint256 id) external view returns (Outcome) {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        return _progress[id].outcome;
    }

    /// @notice Return lifecycle, verdict, progress, and per-guarantee accounting together.
    /// @dev Unknown identifiers revert. openSlots is ledger capacity while OPEN (not a
    /// deadline check). withdrawableBond excludes reserves until every liability is paid.
    function getState(uint256 id) external view returns (GuaranteeState memory state) {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        state.status = progress.status;
        state.outcome = progress.outcome;
        state.enrolled = guarantee.cohortSize;
        state.paidCount = progress.paidCount;
        state.failureAdmittedAt = progress.failureAdmittedAt;
        state.bondHeld = bondOf[id];
        state.reservedCompensation = reservedOf[id];
        state.escrowHeld = escrowedOf[id];
        state.paidCompensation = progress.paidCompensation;
        state.paidEscrow = progress.paidEscrow;
        if (progress.status == Status.OPEN) {
            uint256 available = state.bondHeld > state.reservedCompensation
                ? state.bondHeld - state.reservedCompensation : 0;
            uint256 capacity = available / uint256(guarantee.compensation);
            uint32 slots = guarantee.maxCohort - guarantee.cohortSize;
            state.openSlots = capacity < slots ? uint32(capacity) : slots;
        }
        if ((progress.status == Status.FAILED && progress.paidCount == guarantee.cohortSize)
            || (progress.status == Status.SUCCEEDED && _lifecycle[id].successEscrowReleased)
            || (progress.status == Status.REFUNDING && _evidence[id].refundedCount == guarantee.cohortSize)) {
            state.withdrawableBond = state.bondHeld;
        }
        if (progress.outcome == Outcome.UNRESOLVED_REFUNDED) {
            state.remainingOwed = uint256(guarantee.escrowAmount)
                * (guarantee.cohortSize - _evidence[id].refundedCount);
        } else if (progress.outcome != Outcome.SUCCESS) {
            state.remainingOwed = (uint256(guarantee.escrowAmount) + uint256(guarantee.compensation))
                * (guarantee.cohortSize - progress.paidCount);
        }
    }

    /// @notice Return the fixed-order lifecycle history and immutable review configuration.
    /// @dev Unknown guarantees revert; this does not alter the Phase 1 getState tuple.
    function getLifecycle(uint256 id) external view returns (LifecycleView memory state) {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        Progress storage progress = _progress[id];
        Lifecycle storage lifecycle = _lifecycle[id];
        state.status = progress.status;
        state.outcome = progress.outcome;
        state.joinDeadline = guarantee.joinDeadline;
        state.settlementTime = guarantee.settlementTime;
        state.claimEndsAt = lifecycle.claimEndsAt;
        state.successProposedAt = lifecycle.successProposedAt;
        state.successReadyAt = lifecycle.successReadyAt;
        state.successFinalizedAt = lifecycle.successFinalizedAt;
        state.uncertainAt = lifecycle.uncertainAt;
        state.uncertainBy = lifecycle.uncertainBy;
        state.successEscrowReleased = lifecycle.successEscrowReleased;
        state.releasedSuccessReservation = lifecycle.releasedSuccessReservation;
        state.releasedSuccessEscrow = lifecycle.releasedSuccessEscrow;
        state.withdrawnBond = progress.withdrawnBond;
        state.demoOperator = demoOperator;
        state.reviewWindow = reviewWindow;
    }

    /// @notice Return the documented fixed-order evidence, FIRST timeout and refund snapshot.
    /// @dev Unknown identifiers revert; this view leaves all legacy tuples unchanged.
    function getEvidenceState(uint256 id) external view returns (EvidenceState memory state) {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        Evidence storage evidence = _evidence[id];
        state.evidenceBound = evidence.policyHash != 0;
        state.policyHash = evidence.policyHash;
        state.cohortId = evidence.cohortId;
        state.createdAt = evidence.createdAt;
        state.uncertaintyTimeout = uncertaintyTimeout;
        state.uncertaintyStarted = evidence.uncertaintyStarted;
        state.uncertainSince = evidence.uncertainSince;
        state.uncertainReadyAt = evidence.uncertainReadyAt;
        state.refundedCount = evidence.refundedCount;
        state.refundedEscrow = evidence.refundedEscrow;
        state.releasedUnresolvedReservation = evidence.releasedUnresolvedReservation;
        state.latestEvidenceRoot = evidence.latestEvidenceRoot;
        state.anchorNonce = evidence.anchorNonce;
        state.nextAnchorNonce = evidence.anchorNonce + 1;
        state.verdictNonce = evidence.verdictNonce;
        state.nextVerdictNonce = evidence.verdictNonce + 1;
        state.failureOrigin = uint8(evidence.failureOrigin);
        state.lastReportOutcome = evidence.lastReportOutcome;
        state.lastReportEvaluatedAt = evidence.lastReportEvaluatedAt;
        state.lastReportValidUntil = evidence.lastReportValidUntil;
    }

    /// @notice Return unresolved-only refund progress; unknown ids/accounts return false.
    function isRefunded(uint256 id, address account) external view returns (bool) {
        return _refunded[id][account];
    }

    /// @notice Return enrolled beneficiary count; unknown identifiers return zero.
    function beneficiaryCount(uint256 id) external view returns (uint256) {
        return _beneficiaries[id].length;
    }

    /// @notice Return the beneficiary at an enrollment-order index.
    /// @dev Out-of-bounds indices, including all indices for unknown ids, revert.
    function beneficiaryAt(uint256 id, uint256 index) external view returns (address) {
        if (index >= _beneficiaries[id].length) revert IndexOutOfRange(id, index);
        return _beneficiaries[id][index];
    }

    /// @notice Return beneficiaries in enrollment order, bounded by MAX_COHORT.
    /// @dev Unknown identifiers return an empty array.
    function getBeneficiaries(uint256 id) external view returns (address[] memory) {
        return _beneficiaries[id];
    }

    /// @notice Return whether account has been paid; unknown ids/accounts return false.
    function isPaid(uint256 id, address account) external view returns (bool) {
        return _paid[id][account];
    }

    /// @dev Checked timestamp narrowing for new lifecycle fields.
    function _timestamp64(uint256 value) private pure returns (uint64) {
        if (value > type(uint64).max) revert TimestampOverflow(value);
        return uint64(value);
    }

    /// @dev Cancel pending eligibility; initialize the FIRST timer/history only once.
    function _startUncertainty(uint256 id) private {
        _progress[id].status = Status.UNCERTAIN;
        Lifecycle storage lifecycle = _lifecycle[id];
        lifecycle.successReadyAt = 0;
        Evidence storage evidence = _evidence[id];
        if (!evidence.uncertaintyStarted) {
            uint64 since = _timestamp64(block.timestamp);
            uint64 ready = _timestamp64(block.timestamp + uint256(uncertaintyTimeout));
            evidence.uncertaintyStarted = true;
            evidence.uncertainSince = since;
            evidence.uncertainReadyAt = ready;
            lifecycle.uncertainAt = since;
            lifecycle.uncertainBy = msg.sender;
            emit UncertaintyStarted(id, msg.sender, since, ready);
        }
    }

    /// @dev Used only for resolutions while UNCERTAIN; equality belongs to timeout.
    function _requireBeforeTimeout(uint256 id) private view {
        uint64 ready = _evidence[id].uncertainReadyAt;
        if (block.timestamp >= ready) revert UncertaintyTimeoutReached(id, ready);
    }

    /// @dev Shared manual/evidence proposal cutoff, preserving Phase 2 precedence.
    function _requireProposalTime(uint256 id, Guarantee storage guarantee) private view {
        uint256 earliest = uint256(guarantee.joinDeadline) + 1;
        if (guarantee.settlementTime > earliest) earliest = guarantee.settlementTime;
        if (block.timestamp < earliest) revert ProposalTooEarly(id, earliest);
    }

    /// @dev Full success review without changing uncertainty history or final outcome.
    function _proposeSuccess(uint256 id) private returns (uint64 ready) {
        Lifecycle storage lifecycle = _lifecycle[id];
        uint256 readyAt = block.timestamp + uint256(reviewWindow);
        if (lifecycle.claimEndsAt > readyAt) readyAt = lifecycle.claimEndsAt;
        ready = _timestamp64(readyAt);
        _progress[id].status = Status.SUCCESS_PENDING;
        lifecycle.successProposedAt = _timestamp64(block.timestamp);
        lifecycle.successReadyAt = ready;
        emit SuccessProposed(id, msg.sender, ready);
    }

    /// @dev Unknown, operator and evidence binding precedence shared by evidence writes.
    function _requireBound(uint256 id, bool operatorOnly) private view returns (Evidence storage evidence) {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (operatorOnly && msg.sender != demoOperator) revert NotDemoOperator(msg.sender);
        evidence = _evidence[id];
        if (evidence.policyHash == 0) revert NotEvidenceBound(id);
    }

    /// @dev Evidence operations cannot overwrite any terminal verdict.
    function _requireEvidenceStatus(uint256 id) private view returns (Status status) {
        Progress storage progress = _progress[id];
        status = progress.status;
        if (progress.outcome != Outcome.NONE || (status != Status.OPEN
            && status != Status.SUCCESS_PENDING && status != Status.UNCERTAIN)) {
            revert InvalidStatus(id, status);
        }
    }

    /// @dev Every outgoing transfer checks both exact contract debit and recipient credit.
    function _sendUsdc(address to, uint256 amount) private {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        uint256 recipientBefore = usdc.balanceOf(to);
        usdc.safeTransfer(to, amount);
        _checkUsdcSent(amount, balanceBefore);
        _checkRecipientReceived(to, amount, recipientBefore);
    }

    /// @dev Transfer only an already-accounted batch, at most MAX_SETTLEMENT_BATCH entries.
    /// Requires the contract to be debited exactly the batch total AND every recipient to
    /// gain exactly the amount owed; otherwise the whole call reverts and nothing is marked paid.
    function _transferBatch(uint256 id, uint32 start, uint32 count, uint256 perBeneficiary) private {
        address[] memory recipients = new address[](count);
        uint256[] memory recipientBefore = new uint256[](count);
        for (uint32 i = 0; i < count; ++i) {
            recipients[i] = _beneficiaries[id][start + i];
            recipientBefore[i] = usdc.balanceOf(recipients[i]);
        }
        uint256 balanceBefore = usdc.balanceOf(address(this));
        for (uint32 i = 0; i < count; ++i) {
            usdc.safeTransfer(recipients[i], perBeneficiary);
        }
        _checkUsdcSent(perBeneficiary * count, balanceBefore);
        for (uint32 i = 0; i < count; ++i) {
            _checkRecipientReceived(recipients[i], perBeneficiary, recipientBefore[i]);
        }
    }

    /// @dev Reject a recipient balance increase that differs from the amount owed.
    function _checkRecipientReceived(address recipient, uint256 expected, uint256 balanceBefore) private view {
        uint256 balanceAfter = usdc.balanceOf(recipient);
        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != expected) {
            revert IncorrectRecipientReceipt(recipient, expected, balanceBefore, balanceAfter);
        }
    }

    /// @dev Reject any unequal balance decrease, including sender-side transfer fees.
    function _checkUsdcSent(uint256 expected, uint256 balanceBefore) private view {
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (balanceAfter > balanceBefore || balanceBefore - balanceAfter != expected) {
            revert IncorrectUsdcSent(expected, balanceBefore, balanceAfter);
        }
    }

    /// @dev Pull an exact bond or escrow amount; reject any unequal balance increase.
    function _pullUsdc(address from, uint256 amount) private {
        uint256 balanceBefore = usdc.balanceOf(address(this));
        usdc.safeTransferFrom(from, address(this), amount);
        uint256 balanceAfter = usdc.balanceOf(address(this));
        if (balanceAfter < balanceBefore || balanceAfter - balanceBefore != amount) {
            revert IncorrectUsdcReceived(amount, balanceBefore, balanceAfter);
        }
    }
}
