# Shared interfaces — observed foundation and proposed extensions

The observed foundation below exists in the Studio-generated source and is not deployed. Subsequent sections describe proposed lifecycle/evidence extensions; they are not claims of implemented APIs. Record accepted changes in decisions.md and update consumers together.

## Observed Phase 0 foundation

- `createGuarantee(uint128 compensation, uint128 escrowAmount, uint32 maxCohort, uint64 joinDeadline, uint64 settlementTime, bytes32 termsHash) returns (uint256 id)` pulls `compensation * maxCohort` as the provider bond.
- `joinCohort(uint256 id)` pulls the fixed escrow amount from the joining beneficiary. One enrollment/account/guarantee, provider cannot enroll, contract maximum 100, guarantee-specific cap enforced. Enrollment at exactly `joinDeadline` is currently permitted; after it is rejected.
- Views: `getGuarantee`, `isMember`, `isJoinable`, `bondOf`, `escrowedOf`, `usdc`, `nextGuaranteeId`, `MAX_COHORT`.
- Terms: provider, compensation, escrowAmount, maxCohort, cohortSize, joinDeadline, settlementTime, termsHash. Amounts are integer ERC-20 USDC base units (6 decimals). Stored terms have no update function.
- Events: `GuaranteeCreated`, `CohortJoined`. Failures use Solidity custom errors, not a REST API error schema.
- UI is read-only apart from wallet connection/network switching. No deployed address, settlement, release, verdict, evidence API or lifecycle state enum exists. `settlementTime` currently validates creation terms; it authorizes no fund release.
- Selected synthetic demo: three beneficiaries, 2 USDC escrow each, 5 USDC compensation each, bond 15, total locked 21 if fully enrolled. The user delegated the choice on 6 November 2026; existing Studio amounts were retained and older notes reconciled. This is a demo configuration, not a protocol-wide fixed price.

## Core entities

| Entity | Required concepts |
|---|---|
| Guarantee | ID, provider, condition/template, policy version, token, price, escrow share, compensation, enrollment cutoff, outcome deadline, finality window, evidence policy, cohort cap, status |
| Cohort | Guarantee/common trigger, enrolled beneficiaries, outcome; no unrelated bookings grouped together |
| Enrollment | Guarantee ID, beneficiary, amount paid, escrow amount, reserved compensation, enrollment transaction, settled flag |
| Evidence receipt | Entry ID, guarantee/cohort, source/group, source timestamp, receipt timestamp, schema version, payload hash, previous hash, authentication reference |
| Verdict | Chain/domain, consumer contract, guarantee/cohort, outcome, reason, policy version, evidence root, coverage, fixed-policy support score, nonce/expiry as supported |

Use generic provider/beneficiary names. One beneficiary per account per guarantee is the proposed demo limit; multiple tickets/account is deferred. Terms cannot be changed retroactively after enrollment.

## Financial policy

- Official Arc testnet USDC, integer ERC-20 units; verify address/decimals against current docs during setup.
- One isolated bond per guarantee/cohort for MVP.
- slotsAvailable = floor((bond - reservedCompensation) / compensationPerBeneficiary), subject to the explicit demo cap. Reject compensation <= 0 in this version.
- Guaranteed portion stays in escrow; non-guaranteed portion goes to provider.
- Failure pays escrow refund + fixed compensation exactly once to each enrolled beneficiary.
- Success releases escrow only after the configured finality/claim condition; bond withdrawal also respects all active liabilities/windows.
- Contract token balance must cover the sum of all outstanding escrow, reserved compensation and other withdrawable obligations. Do not double-count ledger entries in the invariant.
- Bounded batch size must be tested. No unbounded cohort loop or claim of thousands of automatic transfers in the MVP.

## Proposed states

| State | Allowed behavior |
|---|---|
| OPEN | Enroll while before cutoff and within capacity; authorized admission can close/fail cohort |
| EVALUATING | No new enrollment; evaluate bound evidence |
| UNCERTAIN | No automatic compensation, release or bond unlock; documented restricted resolution path only |
| FAILED | Terminal adverse verdict; settle each membership once, with payout completion tracked |
| SUCCEEDED | Terminal favorable verdict; release/withdraw only when finality policy permits |
| CLOSED | All required fund obligations settled; repeated operations rejected |

Freeze exact transition timing and implementation enum names in Phase 0. Keep terminal verdict distinct from per-beneficiary payout completion. Reject FAILED-to-SUCCEEDED or reverse transitions.

## Evidence policy

A claim requests evaluation; it does not select outcome/amounts. Each template fixes approved sources, independence groups, freshness, coverage and threshold. Duplicated/syndicated sources do not create independence. An arbitrary AI confidence value does not authorize money movement. Outage/stale/insufficient evidence is UNCERTAIN. Missing attendance is not proof a concert was cancelled.

Use canonical payload encoding and a documented hashing rule. Raw private payloads stay private. Onchain commitments prove matching history integrity, not source truth/completeness. New evidence entries append; corrections link to old entries.

## Access and domains

Provider alone admits its own failure. Beneficiaries may request evaluation. Settlement authority must be restricted and bound to guarantee, chain, contract and replay controls. During early phases, label restricted demo operator authority. CRE must use its actual supported report/consumer verification path; never leave test authorization exposed on the final deployment.

## UI/API contracts to define after stack inspection

Proposed capabilities: get guarantee; create/fund; enroll; request evaluation; admit fault; fetch evidence/status/history; settle/release under policy. These are capabilities, not prescribed REST routes. Freeze actual signatures/paths, error shapes, pagination and auth in Phase 0. Never return secrets or raw personal evidence in public endpoints.

UI distinguishes pending transaction, confirmed outcome, payout completion, stale indexing, unavailable history and uncertain evidence. Arc is authoritative for money; Arkiv history is a read model.
