# Phase 3 checkpoint — IN_PROGRESS

Latest verified state, 6 November 2026: the human deployed via the separate local Vite/MetaMask page. Transaction `0x725bcd4e06c26ec5a5e0762d79a66ef1424ec0d8c8d21cb832843b630c70bd18` created `0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0` at block71037359. The read-only verifier passed exact creation input/four arguments, prior empty code, full21620-byte runtime, version3, official USDC, Account1 operator and separate120/120 windows at deployment and latest. See `evidence/phase3-deployment-725bcd4e06c2.json`. Only then the ignored local configuration was updated and Vite restarted; HTTP200 and served contract module confirmed the new address. Evidence service is healthy at8787, bound to that contract, zero activations, policy `0x390c151a55ce5c1e9861f5781528a38864fdc389edaee853de2fdb6f4d8e9d3d`, same-team sources/weights1+1, collection10s/freshness60s. New runtime store `C:\MicroCover-Evidence-Local` is outside Git. No guarantee or financial action was performed by the agent. Required live scenarios and Studio reconciliation remain pending; older no-address/environment-preserved notes below are historical and superseded for local configuration only.

Latest follow-up: the user explicitly authorized HUMAN local deployment/testing before Studio quota returns. The previous Studio-first next-action text below is superseded for that deployment only. [Local deployment guide](phase3-local-deployment.md) and scripts prepare an unsigned preflight, then a separately human-invoked browser/keystore broadcast. Preflight passed on actual Arc Testnet; no signer opened and no transaction sent. After the human supplies the actual hash, independent verification must pass before ignored environment/service changes. Foundry294 tests passed again; service/ABI/verifier suite now25/25 (476 expectations). Studio reconciliation remains pending even if local financial flows later pass. See evidence/phase3-local-preflight.json; this is not deployment evidence.

## Current checkpoint result — local implementation complete; external/human gate pending

This section supersedes historical pending-policy/startup notes below. The user explicitly approved the synthetic policy and timeout. D09/D10/interfaces were reconciled before dependent implementation. No Phase4/CRE, Arkiv, AI, public checkout action, commit, push, deployment or wallet signature was performed.

All four local slices are implemented: persistent authenticated collector/hash-linked receipts; deterministic cutoff evaluator and evidence commitment; restricted evidence verdict plus non-resetting timeout/refund lifecycle; evidence/status UI and tests. Both feeds are our fixtures, not independent sources. Runtime signing keys and raw envelopes are generated/stored outside Git; none are committed or displayed. Existing reference amounts remain5 compensation/2 escrow/3 beneficiaries, bond15 USDC.

Checks on the local Phase3 source:

| Command / observation | Actual result |
|---|---|
| WSL `~/.foundry/bin/forge test` from this checkout | 294 passed,0 failed,0 skipped,41 suites; includes unit/fuzz and both legacy/new stateful invariants |
| WSL `~/.foundry/bin/forge build --sizes` | Exit0; MicroCover runtime21,620 bytes, initcode22,239, within EVM limits; test-file lint warnings remain |
| `bun run evidence:check` | Exit0 |
| `bun run evidence:test` | 24 passed,0 failed,470 expectations across4 files; includes real local HTTP fixture transport, restart/auth/tamper/replay/stale/conflict, UI policy/domain/report guards and compiled ABI comparison |
| `bun run check` | Exit0: existing lint and app TypeScript checks |
| `bunx vite build` | Exit0; existing third-party PURE-annotation/chunk-size warnings, no new toolchain replacement |
| `bun install --frozen-lockfile --ignore-scripts` | Exit0,957 installs/933 packages checked, no changes; lock retains existing resolutions and adds only Bun development types |
| `scripts/reconcile-phase3-studio.ps1 -WhatIf` | Exit0,63 reviewed source mappings validated, no upload/run performed |
| `git diff --check` | Exit0; line-ending conversion notices are not whitespace errors |
| Local browser127.0.0.1:5173 with preserved Phase2 address | Actual read: version2; app requires3, displays deployment-required gate and no approval/create/enroll writes. Policy/timeout disclosure visible. No wallet connected or transaction sent |
| Phase2 evidence/public checkout | Historical Phase2 JSON files have no diff; public checkout remains clean main tracking origin/main |

Studio state is **not reconciled**: initial contracts-only CLI run ended exit4, `budget_exceeded`, daily usage limit, before completing its test work. The partial draft was pulled into a temporary review directory and imported for local review. Local corrections explicitly block manual success on evidence-bound guarantees, preserve the inclusive join cutoff for success from UNCERTAIN, and add the missing timeout/refund/race/stateful tests and UI. The Studio draft must not be deployed as if it were this source. Use [manual steps](phase3-manual.md), source manifest and the human-run reconciliation script when quota returns.

The prior Phase2 deployment0xa1e621497040d845fe4dc952dc524b88231ade16, deployment evidence and environment address are preserved; no Phase3 address exists here. The new UI requires an actual version3 deployment and a verified matching local policy before enabling evidence-bound creation/enrollment. Local service availability does not establish onchain evidence or sponsor eligibility. Hosted Studio cannot reach this loopback service; it must display unavailable until a separately reviewed host is configured.

Required human checks remain unchecked:

- [ ] Same-project Studio reconciliation, source parity, checks and Preview observation.
- [x] Human fresh deployment with separate120/120 constructor fields; independent receipt/runtime/config verification (transaction725bcd4e06c2, evidence linked above).
- [ ] Real pre-claim collection and restart using the same persistent store, no fabricated backfill.
- [ ] Evidence-origin FAILURE without provider admission; actual anchor/root/verdict/payout receipts.
- [ ] Separate SUCCESS with full review and finality/release/bond receipts.
- [ ] Missing/stale/conflicting/invalid snapshot remains offchain UNCERTAIN without silently opening a dispute.
- [ ] Explicit first onchain uncertainty starts once; permissionless eligible finalization, bounded full escrow refunds, compensation0 and bond last; distinct UNRESOLVED_REFUNDED.
- [ ] Real fresh-session, wrong-network/account, rejection, duplicate-action and timing observations; exact final liabilities recorded.

Proposed human commit groups after review (none executed): (1) reconciled D09/D10/interfaces; (2) collector/evaluator/shared canonical serialization and development types; (3) Phase3 contract/refund lifecycle and meaningful tests, including constructor fixture/model adaptations; (4) evidence UI/ABI and capability guards; (5) verified checkpoint/manual/source-sync/AI records. Keep the user's updated plan/runbook contents and genuine author identity. No public snapshot in this task.

Next action: restore Studio availability, review63-file manifest and run the manual reconciliation command. Do not deploy until the reviewed local source is reconciled and checks pass there. Phase3 remains IN_PROGRESS, not PASSED. Stop at this phase boundary.

## Historical startup and slice notes (superseded by the current checkpoint above)

Authorized 6 November 2026 after Phase2 PASSED. Phase2 private task commits6cbbed48d3778677b771aa30cba557f61d0a0895 (contracts/tests),2af1a3a0569d7f34da0b4093a46b949550c14479 (UI),45405c0bc37673c25b262eda02f8551454e30510 (docs/evidence) were pushed to existing private origin main; remote SHA matches local source. Public checkout/repo deferred and untouched. Phase3 starts on codex/phase3-evidence from clean45405c0. Existing tests/build evidence reused because only a test EOF blank line and documentation changed during release; the failed initial staged-whitespace check and corrected rerun are recorded.

## Bounded work

Generic evidence receipt model, canonical serialization/hash chain, authenticated source identity, append-only private persistence/idempotent cursor, pre-claim interval collection, deterministic evaluator and safe API, policy/domain-bound evidence anchor through supported Studio contract changes, UI evidence view, meaningful tamper/replay/stale/conflict/restart tests. No CRE, Arkiv, AI evaluator, other chain or sponsor feature. No automatic wallet/deploy/public publication. Preserve the Phase2 deployment as historical; any incompatible contract source requires a fresh human deployment later.

## Required human decision before dependent code

Runbook Phase3 section explicitly says "You decide manually before coding": freeze promise/success/cancellation, approved source groups/window, freshness/coverage/weights/threshold. D09 is still pending. An asynchronous concrete policy question was presented; no response/approval is assumed from elapsed time or generic phase authorization.

Proposed synthetic-only policy for review:

- Promise: provider delivers the described cohort service by the frozen outcome deadline. Only an explicit authenticated status FULFILLED or CANCELLED for that exact promise/domain can support a result; neither missing check-ins nor an unfulfilled inference is evidence of cancellation.
- Feeds: synthetic-status-a and synthetic-status-b, equal integer weight1, both in the same declared team-controlled source group. They are two fixtures, not independent reporting or oracle decentralization. Require both approved source identities (coverage2/2); no additional timestamps/duplicates add weight.
- Collection: every10 seconds beginning at recorded activation/creation, before a beneficiary evaluation request; retain source and receipt timestamps separately. Persist append-only entries and an idempotent per-source/domain cursor to survive restart. Private raw payloads/signing credentials outside Git and public responses; nonsecret placeholders only.
- Evaluation: no outcome before the configured deadline. Proposed freshness60 seconds, reject future timestamps/invalid signatures/wrong domains; both sources must have qualifying fresh observations within the documented activation/deadline evaluation window. Exact cutoff and late-receipt handling must be frozen with the policy, not chosen per request.
- Decision:2/2 explicit FULFILLED =>SUCCESS;2/2 explicit CANCELLED =>FAILURE; missing/stale/conflicting/insufficient/invalid evidence =>UNCERTAIN and locked funds. Coverage and support returned as integer numerator/denominator or basis points; no probabilistic confidence claim.
- Domain: chain5042002, actual contract address, guarantee/cohort, condition hash and policy version/hash. Every signed entry, linked root and verdict must reject cross-domain replay. Evidence root proves matching collected history integrity, not truth/completeness. New corrections append rather than overwrite.
- Authority: retain provider admission; an evaluation request cannot set verdict/payouts. Until CRE, the explicitly trusted operator submits the deterministic verdict/root via the restricted tested path. No autonomous signing; prepare exact human anchor commands. Terminal financial outcomes remain irreversible, and success must retain full review/finality timing.

This is a proposal, not an accepted production policy or implemented source. The timing/cutoff details and evidence-derived contract authority need to be written as one reviewable interface before Studio contract work. No evidence service, fixture, API, successful collection, report, source signature, anchor or new deployed address is claimed yet.

## Next

Record the user's policy choice, then implement/test local evidence mechanics using the existing Bun/TypeScript toolchain. Make required contract/app changes through the same Studio project and reconcile selective source; do not duplicate the app or rebuild tooling. Proposed commits after genuine checks: scoped receipts/collector; deterministic evaluator; restricted anchor/domain tests; evidence UI/docs. Phase3 stays IN_PROGRESS until local tests and required human collection/restart/verdict/anchor observations are recorded. Phase2 private push is complete; Phase3 has not been committed or pushed.


## User policy frozen — implementation authorized

Latest explicit request approves D09 and changes D10 with separate120-second uncertainty timeout, bounded escrow-only refunds, zero compensation, non-resetting first-entry timing and distinct unresolved closure. Initial proposal/pending paragraphs above are historical. Exact cutoff, trust, API/report interface and races reconciled in interfaces.md before code. Four slices: collector/authenticated log; evaluator/root; Studio restricted verdict/timeout contract; evidence/status UI. Preserve user-replaced plans and all uncommitted notes. No Git commit/push, deployment/signature, public repo edit, CRE/Arkiv/AI. Phase3 human checks remain outstanding.

## Phase3 slices1–2 local gate,6 November2026

D09/D10 and interfaces reconciled to explicit user policy before implementation. Added services/evidence model/auth/canonicalization, built-in SQLite append-only receipt/private-envelope store, persistent idempotent attempt/nonce cursors, collector, pure deadline-snapshot evaluator and domain-bound report preparation, two same-team authenticated HTTP fixture feeds and loopback read-only API/CLI. No transaction-signing code or private raw-payload endpoint. Private directories reject checkout paths/symlink paths. Added only @types/bun1.3.14 development types to match existing Bun1.3.14; npm view confirmed publishedversion and official Bun SQLite/Node crypto APIs were checked. No new framework/runtime.

Commands/results: bun run evidence:test initially8/8 collector tests, then16/16 with evaluator, now17/17 with HTTP privacy test; bun run evidence:check passed after each model/evaluator slice. During server wiring first typecheck failed on un-narrowed address and optional CORS-header union; added explicit validated address cast/typed header record; rerun typecheck and17 tests passed. Earlier failed typecheck is not reported as passed. No recorded product test failure. Pure evaluator produces a stable cutoff root/reasons and fixed denominator2; temporary outages never create onchain uncertainty automatically. Evidence report service uses a stable domain/nonce/root payload for later CRE adapter but no CRE integration claim.

Started Studio contracts-only Phase3 turn using docs/prompts/phase3-contract.txt and uploaded reconciled interfaces/decisions/user plans. Source/tests still in progress at this entry; not imported or claimed passing. User plan replacements and prior uncommitted docs preserved. No deployment, signature, commit/push or public checkout write.

Live failure reference update: Guarantee1 CLOSED/FAILURE after evidence verdict, one Account2 payout7USDC and unused provider bond return10USDC. All liabilities/actual contract token balance0; duplicate settlement/withdrawal rejected. See phase3-guarantee1-{anchor,failed,paid,closed}.json. Provider/operator were both Account1, so the separate-provider noncooperation human check is still outstanding; do not mark that stronger checkpoint complete. Next fresh scenario is reviewed success. Phase3 remains IN_PROGRESS.
