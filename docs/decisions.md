# Decisions and open items

Accepted direction comes from the user's plans; technical choices below stay pending until observed/implemented. Add dated entries with owner, rationale and evidence when changing a choice.

| ID | Decision | Status / required action |
|---|---|---|
| D01 | Generic protocol for providers/beneficiaries/cohorts | Accepted direction |
| D02 | Three-attendee synthetic concert demo; provider admission first | Accepted planning scenario |
| D03 | Arc + CRE + Arkiv bounty focus | Accepted direction; usage not implemented |
| D04 | Arc Studio required build origin and supported source sync | Existing app targeted via authenticated `--app`; remote tooling edits pulled and local EOF fixes uploaded with `--file`, then targeted dry run confirmed parity. Both source directions verified; judge sharing remains unverified. |
| D05 | Reuse Studio-generated language/framework/package manager | Retained React/Vite/TypeScript + Bun 1.3.14 and Foundry 1.7.1; local checks recorded in runbook.md. |
| D06 | One isolated bond per guarantee; full escrow in first demo | Selected 6 November 2026 under user delegation: preserve Studio's 2 USDC escrow / 5 compensation / 15 bond / 21 total example. Prior 20/10 notes reconciled. Generic contract remains configurable. |
| D07 | Three demo accounts, one enrollment/account | Selected demo configuration; foundation enforces one enrollment per account/guarantee and rejects provider enrollment. |
| D08 | Success release and unlock after configured finality conditions | Phase 2 implementation design frozen in interfaces.md / phase2-lifecycle prompt: immutable review window, no success proposal before settlement/cutoff, full window after late proposal, claims inclusive at boundary and finalize strictly after. Pending source/tests review, not deployed. |
| D09 | Evidence source groups, freshness and threshold | User frozen for Phase3: synthetic-status-a and synthetic-status-b, each weight1, same team-controlled group; both fresh explicit matching statuses required; interval10s/freshness60s; all missing/stale/invalid/conflict cases UNCERTAIN. Domain/policy binding and no independence claim. |
| D10 | Bounded uncertainty and refund-only fallback | User frozen: separate immutable demo uncertaintyTimeout120s before purchase; first onchain UNCERTAIN entry starts once; eligible permissionless finalization refunds full escrow in batches<=20, compensation0, bond only after refunds, distinct UNRESOLVED_REFUNDED. Repeated calls never reset; established failure/finalized success excluded. Offchain uncertainty does not open a dispute automatically. |
| D11 | Restricted early operator replaced/connected to actual CRE path | Pending supported receiver/report design |
| D12 | Arkiv receipt schema/owner/expiry | Pending current SDK/network verification |
| D13 | Separate private/public clones; manual snapshot publication | User selected file snapshots on 6 November 2026. Preserve genuine private history and record source SHA/authors/publisher/public SHA; public snapshots do not preserve the private commit graph. No publication performed. |
| D14 | Open-source licence and third-party attribution | Human selection pending |
| D15 | Hosting and persistent collector storage | Phase3 local demo: existing Bun with SQLite WAL outside all Git checkouts; two local authenticated fixture HTTP routes; loopback8787, local browser origins only. Laptop availability/clock and operator-owned storage limit integrity/completeness. Hosted evidence service remains unconfigured; no hosting/deployment claim. |
| D16 | Single implementation operator and rotating publishers | User handles all implementation roles on one laptop; the four supplied GitHub accounts publish complete phase snapshots per contributions.md. Publication is not implementation attribution. |
| D17 | Continue Phase 1 while Studio judge-sharing is unresolved | User authorized progression after discussion. Phase 0 technical evidence retained; final sponsor access requirement remains open, with no eligibility or Phase 0 pass asserted. |
| D18 | Phase 1 financial/lifecycle slice | Implemented and locally verified in Studio/private source: full escrow/full-capacity bond; provider-only failure; enrollment-order payouts, batch 1–20; remaining bond only after all failed-cohort payouts. Explicit outcome survives closure and timestamp zero. No OPEN withdrawal or success release. Historical Phase 1 local suite 115 tests passed; human Arc flows later passed, with final receipts in docs/evidence/phase1-final.json. Phase 2 expands the suite to 210 tests. |
| D19 | Phase 2 restricted prototype authority / uncertainty | Immutable human-specified demo operator may propose success or mark uncertainty, never arbitrary payouts. Beneficiary dispute requests review and freezes success; provider concession remains possible. No operator override of UNCERTAIN to success in Phase 2, no evaluator/CRE proof implied. Constructor/public ABI change requires new deployment; testnet-only suggested review window 120 seconds. |

## Change entry

6 November 2026 publication update: user explicitly takes the first public commit. First snapshot includes the foundation and completed Phase 1 together. Revised future rotation: Atharva7406 Phase 2, Vedanto28 Phase 3, NamanN-Creator Phase 4, current user Phase 5, Atharva7406 Phase 6. Default to whole verified phases; coherent independently reviewed task snapshots allowed if actually needed. This supersedes the earlier publisher assignments, does not grant the agent permission to publish, and does not reassign implementation authorship. Exact file manifest and human commands are in first-public-commit.md / public-release-files.txt. Public repo remains untouched.

Date / owner / ID:
What changed:
Why:
Affected files/interfaces:
Checks and evidence:
Unresolved consequences:

6 November 2026 Phase2 completion: D19 implemented in the verified three-argument deployment0xa1e621497040d845fe4dc952dc524b88231ade16 with Account1 operator/review120s. Both real financial flows and required human wallet/fresh-session UI observations passed; final evidence phase2-final.json. Freeze Phase2 at this checkpoint; Phase3 remains unstarted. No public eligibility/sharing claim or Git/publication authorization is inferred.


Phase3 policy accepted by explicit user instruction6 November2026; previous proposal/pending notes are historical. Numeric equality of success review120 and uncertainty timeout120 is coincidental: separate constructor fields/readbacks and tests use unequal durations. While onchain UNCERTAIN, resolution (provider admission or authorized evidence verdict) requires now < uncertainReadyAt; timeout finalization requires now >= uncertainReadyAt. First terminal operation wins; terminal financial outcomes cannot be changed. A success resolution starts a full new success-review window and preserves first uncertainty timestamp for any later dispute.

D10 consequence under preserved dispute timing: a beneficiary/operator can explicitly enter uncertainty before the outcome deadline;120 seconds from that entry may expire before the promised service deadline. This follows the approved first-entry rule rather than silently adding a different start/minimum deadline. Local test FirstTimerAndRequestsAnchorsRetriesCannotExtend exercises it. The UI discloses it before creation/enrollment and dispute. A production policy would need a separately agreed economic/dispute design; no such redesign is introduced here.

Local deployment workflow exception (latest explicit user request): permit HUMAN direct Foundry Arc Testnet deployment before Studio quota returns, using the exact4-argument reviewed source. User selected MetaMask browser wallet; encrypted-keystore route documented as an alternative. Agent must not sign/broadcast and must independently verify actual receipt/full code/config before any ignored frontend address update or runtime startup. No protocol/economic change, guard bypass or claim of Studio reconciliation/eligibility. Earlier Studio-first deployment wording is superseded only for this human local test route; Phase3 checkpoint remains pending.

D11 Phase4 local decision6November2026: retain existing EOA-operated Phase3 contract and demonstrate actual CRE read-only simulation plus explicitly labelled human demo relay preparation. Official Arc path currently lists a mock simulation forwarder; do not treat that as production DON authentication. Prepare a separate immutable identity-checked receiver for a future newly deployed consumer, but do not deploy, invent workflow identity, bypass metadata or change existing operator/version guards. Native writeReport wiring and live delivery remain pending. CRE consumes trusted collector-authenticated public receipts and reuses the exact pure evaluator; no source-independence or truth/completeness proof claim. Phase3 implementation frozen by user with human gates deferred, not PASSED. Phase4 remains IN_PROGRESS until actual write/relay and required review are recorded.
