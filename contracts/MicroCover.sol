// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MicroCover
/// @notice Phase 2 prototype only: provider-admitted failure and reviewed success lifecycle.
/// @dev Not upgradeable; no owner/admin/role rotation. demoOperator is a trusted, immutable,
/// human-controlled demo authority: it cannot decide failure, move funds, or shorten a review
/// window. It can only propose success or mark uncertain (trusted blocking power, without a
/// time bound). Any enrolled beneficiary can freeze an OPEN or SUCCESS_PENDING guarantee
/// into UNCERTAIN within its dispute window: this creates a griefing risk. Only provider
/// admitFailure resolves UNCERTAIN; provider nonresponse can lock funds indefinitely.
/// There is no reviewer/evidence policy and no route from UNCERTAIN back to success.
/// The provider can still admit failure until finalizeSuccess is actually called, even after
/// the review window elapsed. reviewWindow is a short synthetic test value, not a production
/// safety claim. An OPEN guarantee without a verdict can also keep its funds locked.
/// A beneficiary the token refuses to pay (e.g. a blocklisted address) makes failure settlement
/// revert atomically for that guarantee; there is no skip or alternate recipient path.
/// Direct token donations are unaccounted, cannot be withdrawn, and never create capacity.
/// Every outgoing transfer requires the contract to be debited exactly the amount AND the
/// recipient to gain exactly that amount, else the whole call reverts. Official USDC is the
/// supported asset; this does not claim safety for arbitrary rebasing, fee-charging or
/// malicious ERC-20s. All success accounting and releases are guarantee-local.
/// Verdict (Outcome), lifecycle (Status), and payout progress (counters) are distinct.
/// Outcome is explicitly stored, never inferred from time, and survives terminal CLOSED.
/// paidCompensation, paidEscrow, isPaid and paidCount track FAILURE payouts only;
/// releasedSuccessReservation and releasedSuccessEscrow are separate success counters.
/// Per-guarantee invariants (amounts in USDC base units):
/// bondOf + paidCompensation + withdrawnBond == compensation * maxCohort;
/// escrowedOf + paidEscrow + releasedSuccessEscrow == escrowAmount * cohortSize;
/// reservedOf + paidCompensation + releasedSuccessReservation == compensation * cohortSize;
/// reservedOf <= bondOf; paidCount <= cohortSize <= maxCohort <= 100;
/// _beneficiaries.length == cohortSize. The sum over guarantees of bondOf + escrowedOf
/// equals usdc.balanceOf(address(this)) minus unaccounted donations. Reserved compensation
/// is a subset of bondOf and is never added separately to the accounted token balance.
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
    /// UNCERTAIN (5): frozen; only provider failure admission can resolve it in Phase 2.
    enum Status { OPEN, FAILED, CLOSED, SUCCESS_PENDING, SUCCEEDED, UNCERTAIN }

    /// @notice Explicit verdict: NONE (0) means no final verdict; FAILURE (1) means provider
    /// admitted failure; SUCCESS (2) means reviewed success finalized. Survives closure.
    enum Outcome { NONE, FAILURE, SUCCESS }

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
    /// @notice Trusted immutable demo authority; may only propose success or block it.
    address public immutable demoOperator;
    /// @notice Synthetic review duration in seconds; not a production safety claim.
    uint64 public immutable reviewWindow;

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

    /// @param usdc_ USDC address supplied by the deployer; not hardcoded.
    /// @param demoOperator_ Trusted immutable human-controlled demo authority.
    /// @param reviewWindow_ Positive synthetic review duration in seconds.
    constructor(IERC20 usdc_, address demoOperator_, uint64 reviewWindow_) {
        if (address(usdc_) == address(0)) revert ZeroUsdcAddress();
        if (demoOperator_ == address(0)) revert ZeroOperatorAddress();
        if (reviewWindow_ == 0) revert ZeroReviewWindow();
        usdc = usdc_;
        demoOperator = demoOperator_;
        reviewWindow = reviewWindow_;
    }

    /// @notice Return the contract lifecycle protocol version.
    function protocolVersion() external pure returns (uint256) {
        return 2;
    }

    /// @notice Create a guarantee and lock compensation times maxCohort as its bond.
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

        _pullUsdc(msg.sender, bond);

        emit GuaranteeCreated(
            id, msg.sender, compensation, escrowAmount, maxCohort,
            joinDeadline, settlementTime, termsHash, bond
        );
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
        uint256 earliest = uint256(guarantee.joinDeadline) + 1;
        if (guarantee.settlementTime > earliest) earliest = guarantee.settlementTime;
        if (block.timestamp < earliest) revert ProposalTooEarly(id, earliest);
        Lifecycle storage lifecycle = _lifecycle[id];
        uint256 readyAt = block.timestamp + uint256(reviewWindow);
        if (lifecycle.claimEndsAt > readyAt) readyAt = lifecycle.claimEndsAt;
        uint64 ready = _timestamp64(readyAt);
        progress.status = Status.SUCCESS_PENDING;
        lifecycle.successProposedAt = _timestamp64(block.timestamp);
        lifecycle.successReadyAt = ready;
        emit SuccessProposed(id, msg.sender, ready);
    }

    /// @notice Freeze an OPEN or pending guarantee within its inclusive dispute window.
    /// @dev Only enrolled beneficiaries; no payout is selected and no tokens move.
    /// UNCERTAIN has no path back to success; only provider failure admission resolves it.
    function raiseDispute(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (!_members[id][msg.sender]) revert NotBeneficiary(id, msg.sender);
        Status status = _progress[id].status;
        uint64 deadline;
        if (status == Status.OPEN) deadline = _lifecycle[id].claimEndsAt;
        else if (status == Status.SUCCESS_PENDING) deadline = _lifecycle[id].successReadyAt;
        else revert InvalidStatus(id, status);
        if (block.timestamp > deadline) revert DisputeWindowClosed(id, deadline);
        _markUncertain(id);
        emit DisputeRaised(id, msg.sender);
    }

    /// @notice Exercise trusted operator blocking power on an OPEN or pending guarantee.
    /// @dev No time bound, token movement or payout selection. Only provider failure
    /// admission resolves UNCERTAIN; no route from UNCERTAIN to success exists in Phase 2.
    function markUncertain(uint256 id) external nonReentrant {
        if (_guarantees[id].provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != demoOperator) revert NotDemoOperator(msg.sender);
        Status status = _progress[id].status;
        if (status != Status.OPEN && status != Status.SUCCESS_PENDING) revert InvalidStatus(id, status);
        _markUncertain(id);
        emit UncertaintyMarked(id, msg.sender);
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
        if (progress.status != Status.OPEN && progress.status != Status.SUCCESS_PENDING
            && progress.status != Status.UNCERTAIN) revert InvalidStatus(id, progress.status);

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
    /// @dev Requires failure admission and all beneficiaries paid, or finalized success
    /// with success escrow already released. The amount is derived from bondOf, never
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
            || (progress.status == Status.SUCCEEDED && _lifecycle[id].successEscrowReleased)) {
            state.withdrawableBond = state.bondHeld;
        }
        if (progress.outcome != Outcome.SUCCESS) {
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

    /// @dev Cancel pending eligibility while preserving proposal history; never moves funds.
    function _markUncertain(uint256 id) private {
        _progress[id].status = Status.UNCERTAIN;
        Lifecycle storage lifecycle = _lifecycle[id];
        lifecycle.uncertainAt = _timestamp64(block.timestamp);
        lifecycle.uncertainBy = msg.sender;
        lifecycle.successReadyAt = 0;
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
