# Phase 5 checkpoint — live feature verified; inherited deferrals remain

6 November 2026. Started from private main `9d98930b05679dca5a1ddb2f6d9c980a08e93a6f`. User explicitly authorized Phase5 with Studio reconciliation and Phase4 human reproduction/review deferred. Those are not PASSED. Phase6 has not started. No contract change or new deployment is needed.

## Current next action

Live publication and all functional browser checks are complete:19entities for G2, matching snapshot/Arc anchor, reload and InPrivate/no-wallet reads, outage warning and recovery. See evidence/phase5-publication.json, phase5-retry.json and phase5-browser-checks.json. Do not republish. Remaining formal deferrals are Studio reconciliation/judge access and earlier review; Phase6 local verification is now underway. Older entries below are chronological evidence, not current next actions.

## Current result

- Public outbox uses existing verified cutoff receipts and actual logs read from the Phase3 Arc deployment. It never exports private payload envelopes, wallet keys or access keys.
- Evidence pages hold at most30 public receipts, a manifest links the pages and frozen activation, and Arc event entities link real transaction hashes/log indices/block timestamps. Stable IDs and durable SQLite preparation survive restart and skip identical retries.
- The app's **Public history on Arkiv** card reads `arkiv_query` through a read-only loopback proxy. It recomputes the exported receipt prefix/root and deterministic outcome, checks the selected Arc domain, and separately compares the root with the current Arc anchor. Missing pages, tampering and unavailable history cannot authorize funds.
- A separate expandable writer section proposes Account1 `0x1d39fc0e5293ab949d63217ffb375357adf3933f`, Rabdi7794095, seven-day retention, read-only attributes and permissionless expiry extension. The human approves these by choosing to publish. No signing key enters the service.
- The MetaMask SDK batch writes at most20 new entities. It queries existing IDs first, locks concurrent tabs using Web Locks, saves an ambiguous attempt before requesting a signature, and saves a returned transaction hash immediately before SDK receipt waiting. Pending/unknown outcomes cannot be blindly retried. Browser-profile locks are not global onchain uniqueness; use one writer session/device.
- SDK salt is a deterministic128-bit fragment of the record ID, but Arkiv keys also include the owner's counter. Salt is not an onchain deduplication constraint. Concurrent writers outside this browser can create duplicate IDs; the read model checks identical content and the application deduplicates it.

## Exact checks run

- `bun add --exact @arkiv-network/sdk@1.0.1`: exit0. Inspected installed schema/createEntity/executeBatch/salt/flags/expiration APIs. Kept existing dependency resolutions in bun.lock; `bun install --frozen-lockfile`: exit0, no changes.
- `bun run check`: initially failed on typed transport arguments and an ES2020 browser import of `.at`; corrected and reran exit0. The shared evaluator's final-element access changed to equivalent array indexing, with no policy/hash/contract change.
- `bun run evidence:check`: initially failed on decode/mocked-fetch casts; corrected and reran exit0.
- `bun run evidence:test`:42 passed,0 failed,549 assertions across9 files (seven new Arkiv tests). Includes queue restart/dedup, privacy, wrong domain, tampering, missing pages, fake outcome, outage and ambiguous-wallet retry guard.
- `bun run --cwd workflows/cre check`: exit0 after the browser-safe evaluator import.
- `bun run vite build`: exit0; existing third-party PURE annotation and large-chunk warnings remain.
- `bun run arkiv queue 1 71037359`, `... queue 2 ...`, `... queue 3 ...`: successful read-only preparations reported14/19/15 public records. Subsequent intermediate scans encountered Arc network failures; those attempts remain failed. No transaction was sent. Earlier incomplete local event drafts are excluded from the publishable queue; timestamp-complete preparation succeeded subsequently.
- Verified local snapshot integrity independently: G1 failure120 receipts, G2 success238, G3 uncertainty114. This is local preparation, not an Arkiv read/write proof.
- Rabdi `eth_chainId`:7794095. Anonymous `arkiv_query`:HTTP429 `ANON_COST_LIMITED`. `bun run arkiv query 2`:exit1; live query remains blocked until the saved access key is configured.
- Restarted the identified evidence service on127.0.0.1:8787 with the same external store and Phase3 consumer. Queue GET returned200/19 records forG2; history GET returned503 with explicit Arkiv-unavailable status. No fallback to local successful history. Arc discovery also reported a transient RPC failure; its deployment guard remains enabled.
- Automated local browser access was refused by Work settings. No new browser rendering or wallet check is claimed.

No Solidity test rerun is needed for unchanged contracts; previous299-test evidence is preserved, not claimed rerun.

## Do this next — configure the saved access key

In the ignored `C:\GitHub\MicroCover-Private\.env`, add `ARKIV_ACCESS_KEY=<your saved key>`. Do not paste the value into chat, commit it, put it in a VITE_ variable, or add it to a wallet network URL. Confirm only that it is saved. The running service must then be restarted to read the new server-only value.

Read-only terminal query (before any wallet write):

```powershell
cd C:\GitHub\MicroCover-Private
$env:MICROCOVER_EVIDENCE_CONTRACT='0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0'
bun run arkiv query 2
```

Service startup, if stopped (only one instance):

```powershell
cd C:\GitHub\MicroCover-Private
$env:MICROCOVER_EVIDENCE_HOME='C:\MicroCover-Evidence-Local'
$env:MICROCOVER_EVIDENCE_CONTRACT='0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0'
bun run evidence serve
```

After successful read access, use the existing guarantee2 at `http://127.0.0.1:5173/?guarantee=2`, connect Account1, find **Public history on Arkiv**, expand **Publish queued public history (writer only)**, review writer/network/retention and choose **Switch to Rabdi and publish next batch**. Review and personally confirm MetaMask. This is a public-data write on Rabdi, not another guarantee or an Arc settlement. If Rabdi is missing, add it through the official Hub network page first. Keep the saved public transaction hash; do not retry if wallet status is ambiguous.

Then agent independently verifies receipt/entities, exact record bytes/flags/creator/expiry and reruns `bun run arkiv query 2`. Reload the page (also without a wallet); matching Arkiv entity keys/records and anchor check must appear. Retry publication: it should report0 new writes. Test unavailable history without changing Arc settlement, then restore service. Only after recording real results can Checkpoint5 pass. No additional beneficiary enrollment or payout repetition is required.

## Checkpoint and proposed commit groups

**IN_PROGRESS**. Real entity keys/transaction, live duplicate retry, fresh browser read and outage UI verification pending; no fabricated evidence. Studio parity, judge access and Phase4 human review remain explicit deferrals. SDK receiver/native CRE network delivery remains undeployed.

Proposed groups (no commit/push authorization for this phase):

1. `feat: queue public receipts and Arc event history for Arkiv` — schema, reader, outbox, CLI, SDK/lock, tests.
2. `feat: display and manually publish Arkiv-backed guarantee history` — client, UI and workspace integration.
3. `docs: record Arkiv schema checks and remaining checkpoint work` — notes, judging files, deferrals and supported Studio upload correction.

Stop at Phase5. Do not touch the separate public checkout or automatically publish, deploy, sign, commit or push.

SDK estimation and receipt reads use POST /api/arkiv/v1/rpc through a strict read-method allowlist. Signing/broadcast methods are refused; estimates/calls are restricted to the official Arkiv system contract, expected writer and zero value. This keeps the access key server-side even during SDK gas estimation; wallet network URLs remain keyless. No server signing or transaction submission is added.

## Changed files in this slice

- `.env.example`
- `arkiv/friction.md`
- `arkiv/how-you-use-arkiv.md`
- `arkiv/reach.md`
- `arkiv/schema.md`
- `arkiv/why-arkiv.md`
- `bun.lock`
- `docs/ai-usage.md`
- `docs/decisions.md`
- `docs/interfaces.md`
- `docs/phase3-studio-files.txt`
- `docs/phase4-manual.md`
- `docs/phase4-studio-files.txt`
- `docs/phase5-manual.md`
- `docs/progress.md`
- `docs/runbook.md`
- `docs/sponsor-checklist.md`
- `package.json`
- `scripts/reconcile-phase3-studio.ps1`
- `services/evidence/arkiv-cli.ts`
- `services/evidence/arkiv-outbox.ts`
- `services/evidence/arkiv-reader.ts`
- `services/evidence/arkiv.test.ts`
- `services/evidence/core.ts`
- `services/evidence/server.ts`
- `services/evidence/store.ts`
- `src/microcover/arkivClient.ts`
- `src/microcover/arkivRecords.ts`
- `src/microcover/components/ArkivHistoryCard.tsx`
- `src/microcover/components/Workspace.tsx`

Phase5 publication-size fix: human screenshot showed pre-wallet preparation failure. Unsigned SDK diagnostics reproduced HTTP413 for the uncompressed19-record eth_estimateGas request (483491 JSON bytes;241668 calldata bytes). Added explicit bodyEncoding=gzip-json-v1; only transport bytes are compressed, canonical JSON IDs/hashes/Arc anchors unchanged. Server bounded gunzip decoding(max60000bytes) rechecks the original canonical body hash. Exact browser CompressionStream path with all19records then passed actual Rabdi estimation:190883request bytes, estimate0x488048(4751432gas). Diagnostic was hard-stopped before every send method; no signature/broadcast. Latest/pending writer nonce both0x1. Proof docs/evidence/phase5-estimation.json. Evidence service restarted with updated decoder. App/service checks pass; full suite44passes/0failures/556assertions, including gzip roundtrip/hash preservation and live-reader wire decoding/spoof rejection. Human live publication/query/browser proof still pending; no checkpoint pass, Git push or Studio reconciliation claim.

Phase5 browser publication follow-up,6November2026: repeated human screenshot showed pre-wallet preparation failure despite working GET history and successful unsigned CLI gas estimation. Reproduced browser JSON POST preflight OPTIONS /api/arkiv/v1/rpc returning405. Fixed services/evidence/server.ts to permit only POST/content-type preflight from the existing allowed loopback origins; foreign origins and extra headers remain rejected, broadcast/signing methods still forbidden. Extended server.test.ts for allowed and rejected preflights. Restarted only verified evidence-service bun process using the existing persistent home and contract. Actual live OPTIONS now204 with exact origin/POST header, followed by JSON POST eth_chainId result0x76edaf. bun run evidence:check exit0; bun run evidence:test44pass/0fail/562assertions; git diff --check exit0. This verifies HTTP preflight and read transport, not completed browser signing/publication. No wallet request/signature/broadcast, commit/push or contract change by agent. Phase5 remains IN_PROGRESS; next human reloads app and retries publication once, then supplies transaction hash. Proposed commit group: Phase5 RPC browser transport fix and regression checks, with accurate manual evidence.

Phase5 live publication verified,6November2026: human screenshots show19entities, SUCCESS238-receipt snapshot, matching Arc anchor and19written/0remaining. Independent read-only Bun diagnostic queried the running API and actual Rabdi block/transaction/receipt: tx0xe2852a9ef807a9145ee983f04327eb8c6cc43422810d248e36ba1166185784fc, expected Account1 writer to0x4400000000000000000000000000000000000044 on7794095, successful receipt with19creation logs whose entity keys match all19live records. All canonical record contents exactly match the prepared outbox. Recomputed complete receipt-prefix/root and deterministic outcome SUCCESS; root equals current Arc getEvidenceState.latestEvidenceRoot. Retention302400Rabdiblocks(nominal7days); live reader enforced configured creator/owner,readonly and gzip/body hashes. Public proof docs/evidence/phase5-publication.json. Two initial diagnostic runs failed because JSON property order was compared and then canonical() was called on bigint getter data; corrected diagnostics use canonical record comparison and named getter fields, final run exited0. No failed integrity result is attributed to the actual records. Zero missing IDs predicts retry skips but is not claimed as a performed browser duplicate-click test. Human reload without wallet, duplicate-click no-write and outage UI checks remain pending; Phase5 IN_PROGRESS and Studio/Phase4 deferrals unchanged. No agent signing/broadcast, commit/push or public checkout modification. Next human reloads the same guarantee page to confirm persistent history; no new guarantee or publication required for that check. Proposed commit groups remain receipt service/schema, visible UI/publication, and factual docs/proofs.

Phase5 persistence/retry follow-up,6November2026: user explicitly confirmed19entities and matching integrity message remain after Ctrl+R. Read-only diagnostic ran the actual publishHistory duplicate-filter path against live Rabdi history with a test-double wallet provider(no real wallet/network switch/signing): result written0/remaining0, transactionRequests0, no new-attempt storage created. Proof docs/evidence/phase5-retry.json. This is live-ID deduplication verification with a mock wallet, not a human second signed publication or independent-browser reproduction. No code changes or additional test rerun needed. Next required human check: open existing guarantee2 URL in InPrivate without connecting wallet and confirm public Arkiv history remains visible. Outage UI and Studio reconciliation remain unverified/deferred; Phase5 IN_PROGRESS. No commit/push or publication by agent.

Phase5 fresh-viewer human check,6November2026: user supplied Edge InPrivate screenshots at127.0.0.1:5173/?guarantee=2 showing Connect(no wallet connected), CLOSED/SUCCESS guarantee, live Arkiv source19entities, green recomputed receipt-chain/current Arc-anchor match, actual event references and SUCCESS238-receipt snapshot. This records a performed human fresh-browser/no-wallet read and visible-history check, not an agent-controlled browser run or public hosted URL. Publication, reload persistence, fresh-viewer read and live-ID duplicate filtering are verified. Remaining outage UI check and Studio reconciliation/judge-access deferrals stay explicit; Phase5 checkpoint remains IN_PROGRESS pending required outstanding checks. No source/contract change, test rerun, signing/broadcast, commit/push or Phase6 started. Proposed commit groups unchanged: receipt service/schema, visible UI/publication, factual docs/proofs. Next action is the remaining outage-state check, then Phase5 checkpoint review; no further publication or enrollment needed.

Phase5 functional verification complete,6November2026: human InPrivate outage screenshot shows explicit Arkiv-history-unavailable warning and cached-record staleness disclosure, with cached19records preserved. Restored evidence service using unchanged persistent home and contract; live API returnedHTTP200/sourceARKIV_RABDI_LIVE_RPC/19entities. Publication/read/integrity, reload persistence, fresh no-wallet browser and outage UI now demonstrated; live-ID retry filter returned0writes/0transaction requests using a test-double wallet. Proofs phase5-publication.json, phase5-retry.json, phase5-browser-checks.json. No further wallet steps required. Phase5 functional work is complete; formal checkpoint remains IN_PROGRESS with inherited Studio reconciliation/judge-access and Phase4 human reproduction/review deferrals explicit, not silently PASSED. No new source change/tests rerun for this runtime/documentation update; git diff --check passed. Proposed commits: receipt adapter/schema/service/tests; visible history/publication UI; actual proofs/docs/Studio-helper corrections. No commits/pushes, public checkout edit, signing or Phase6 work. Next: checkpoint/deferral review and separately authorize the next phase.
