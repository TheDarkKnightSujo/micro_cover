// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MicroCover
/// @notice Phase 1: provider failure admission, bounded permissionless settlement, and
/// provider leftover bond withdrawal. No success release exists.
/// @dev Testnet only; not upgradeable and no owner, operator, or admin exists.
/// An OPEN guarantee whose provider never admits failure keeps its funds locked.
/// A beneficiary the token refuses to pay (e.g. a blocklisted address) makes settlement
/// revert atomically for that guarantee; there is no skip or alternate recipient path.
/// Direct token donations are unaccounted, cannot be withdrawn, and never create capacity.
/// Every payout (including the provider's leftover withdrawal) requires the contract to be
/// debited exactly the amount AND the recipient to gain exactly that amount, else the whole
/// call reverts. Official USDC is the supported asset; this does not claim safety for
/// arbitrary rebasing, fee-charging or malicious ERC-20s.
/// Verdict (Outcome), lifecycle (Status), and payout progress (counters) are distinct.
/// Per-guarantee invariants (amounts in USDC base units):
/// bondOf + paidCompensation + withdrawnBond == compensation * maxCohort;
/// escrowedOf + paidEscrow == escrowAmount * cohortSize;
/// reservedOf + paidCompensation == compensation * cohortSize;
/// reservedOf <= bondOf; paidCount <= cohortSize <= maxCohort <= 100;
/// _beneficiaries.length == cohortSize. Without donations, the sum over guarantees of
/// bondOf + escrowedOf equals usdc.balanceOf(address(this)). Reserved compensation is
/// a subset of bondOf and is never added separately to the accounted token balance.
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

    /// @notice Phase 1 lifecycle only; no success status exists.
    /// @dev OPEN: enrolling/awaiting provider verdict. FAILED: failure admitted,
    /// enrollment closed, obligations outstanding. CLOSED: no remaining obligation.
    enum Status { OPEN, FAILED, CLOSED }

    /// @notice Provider verdict, recorded explicitly when failure is admitted so it never
    /// depends on the block timestamp being nonzero.
    enum Outcome { NONE, FAILURE }

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

    /// @notice The identifier assigned to the next guarantee, starting at 1.
    uint256 public nextGuaranteeId = 1;

    mapping(uint256 id => Guarantee) private _guarantees;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _members;
    mapping(uint256 id => Progress) private _progress;
    mapping(uint256 id => address[]) private _beneficiaries;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _paid;

    /// @notice Bond USDC currently held; starts at compensation * maxCohort and
    /// decreases on compensation payouts and leftover withdrawal. Unknown ids return zero.
    mapping(uint256 id => uint256) public bondOf;

    /// @notice Escrow USDC currently held; increases on join and decreases on settlement.
    /// @dev Unknown identifiers return zero.
    mapping(uint256 id => uint256) public escrowedOf;

    /// @notice Compensation reserved for enrolled, unpaid beneficiaries; a subset of bondOf.
    /// @dev Increases by compensation per join and decreases per payout. Unknown ids return zero.
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

    /// @param usdc_ USDC address supplied by the deployer; not hardcoded.
    constructor(IERC20 usdc_) {
        if (address(usdc_) == address(0)) revert ZeroUsdcAddress();
        usdc = usdc_;
    }

    /// @notice Create a guarantee and lock compensation times maxCohort as its bond.
    /// @param compensation USDC base units of compensation per beneficiary on failure.
    /// @param escrowAmount USDC base units each beneficiary must lock.
    /// @param maxCohort Maximum beneficiary count, between 1 and MAX_COHORT.
    /// @param joinDeadline Last timestamp at which beneficiaries may join.
    /// @param settlementTime Settlement timestamp, no earlier than joinDeadline.
    /// @param termsHash Opaque hash of off-chain terms.
    /// @return id The newly created guarantee identifier.
    /// @dev settlementTime is stored metadata; Phase 1 failure admission is not time-gated.
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

    /// @notice Admit failure once, closing enrollment without moving any tokens.
    /// @dev Only this guarantee's provider may admit failure, at any time while OPEN.
    /// Zero enrollment remains FAILED until the provider withdraws the whole bond.
    function admitFailure(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != guarantee.provider) revert NotProvider(id, msg.sender);
        Progress storage progress = _progress[id];
        if (progress.status != Status.OPEN) revert AlreadyAdmitted(id);

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
    /// @dev Requires failure admission and all beneficiaries paid; the amount is derived
    /// from bondOf, never supplied by the caller. A fully paid full cohort is already CLOSED.
    /// @return amount Leftover bond withdrawn.
    function withdrawRemainingBond(uint256 id) external nonReentrant returns (uint256 amount) {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (msg.sender != guarantee.provider) revert NotProvider(id, msg.sender);
        Progress storage progress = _progress[id];
        if (progress.status == Status.OPEN) revert NotFailed(id);
        if (progress.status == Status.CLOSED) revert NothingToWithdraw(id);
        if (progress.paidCount < guarantee.cohortSize) {
            revert LiabilitiesUnpaid(id, guarantee.cohortSize - progress.paidCount);
        }
        if (reservedOf[id] != 0) revert ReservedCompensationRemaining(id, reservedOf[id]);
        amount = bondOf[id];
        bondOf[id] = 0;
        progress.withdrawnBond += amount;
        progress.status = Status.CLOSED;
        emit RemainingBondWithdrawn(id, guarantee.provider, amount);
        emit GuaranteeClosed(id);

        uint256 balanceBefore = usdc.balanceOf(address(this));
        uint256 providerBefore = usdc.balanceOf(guarantee.provider);
        usdc.safeTransfer(guarantee.provider, amount);
        _checkUsdcSent(amount, balanceBefore);
        _checkRecipientReceived(guarantee.provider, amount, providerBefore);
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

    /// @notice Return the provider verdict, independent of lifecycle and payout counters.
    /// @dev Stored explicitly when failure is admitted; unknown identifiers revert.
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
        if (progress.status == Status.FAILED && progress.paidCount == guarantee.cohortSize) {
            state.withdrawableBond = state.bondHeld;
        }
        state.remainingOwed = (uint256(guarantee.escrowAmount) + uint256(guarantee.compensation))
            * (guarantee.cohortSize - progress.paidCount);
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
