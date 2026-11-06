// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title MicroCover
/// @notice A foundation for provider bonds and beneficiary escrow in bounded guarantee cohorts.
/// @dev Testnet only. Settlement/release paths are intentionally NOT implemented in this
/// foundation, so funds are locked until a later version. This contract is not upgradeable.
contract MicroCover is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Guarantee terms; compensation and escrowAmount are USDC base units.
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

    /// @notice Maximum number of beneficiaries per guarantee.
    uint32 public constant MAX_COHORT = 100;

    /// @notice USDC used for all bonds and escrow; amounts use its 6-decimal ERC-20 view.
    IERC20 public immutable usdc;

    /// @notice The identifier assigned to the next guarantee, starting at 1.
    uint256 public nextGuaranteeId = 1;

    mapping(uint256 id => Guarantee) private _guarantees;
    mapping(uint256 id => mapping(address beneficiary => bool)) private _members;

    /// @notice Bond held for each guarantee; unknown identifiers return zero.
    mapping(uint256 id => uint256) public bondOf;

    /// @notice Total escrow held per guarantee: escrowAmount times cohortSize.
    /// @dev Unknown identifiers return zero.
    mapping(uint256 id => uint256) public escrowedOf;

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
    function joinCohort(uint256 id) external nonReentrant {
        Guarantee storage guarantee = _guarantees[id];
        if (guarantee.provider == address(0)) revert UnknownGuarantee(id);
        if (block.timestamp > guarantee.joinDeadline) revert JoinDeadlinePassed(id);
        if (guarantee.cohortSize >= guarantee.maxCohort) revert CohortFull(id);
        if (_members[id][msg.sender]) revert AlreadyMember(id, msg.sender);
        if (msg.sender == guarantee.provider) revert ProviderCannotJoin(id);

        _members[id][msg.sender] = true;
        guarantee.cohortSize += 1;
        escrowedOf[id] += uint256(guarantee.escrowAmount);

        _pullUsdc(msg.sender, uint256(guarantee.escrowAmount));

        emit CohortJoined(id, msg.sender, guarantee.cohortSize);
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

    /// @notice Return whether a guarantee exists, is within its deadline, and has capacity.
    /// @dev Does not check any particular beneficiary's eligibility or USDC allowance.
    function isJoinable(uint256 id) external view returns (bool) {
        Guarantee storage guarantee = _guarantees[id];
        return guarantee.provider != address(0)
            && block.timestamp <= guarantee.joinDeadline
            && guarantee.cohortSize < guarantee.maxCohort;
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
