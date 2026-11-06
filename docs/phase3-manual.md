# Phase 3 manual scenarios and Studio reconciliation

Current local state: human deployment `0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0` is independently verified in `evidence/phase3-deployment-725bcd4e06c2.json`. Ignored local configuration points there, Vite5173 and evidence8787 are running, policy initialized once at `C:\MicroCover-Evidence-Local`. Begin section4 with a fresh guarantee; do not redeploy or reinitialize/rotate keys. Studio reconciliation remains pending. Earlier no-address/setup instructions below are retained as history/reference.

Current user authorization supersedes the earlier Studio-first deployment gate: human local Arc Testnet deployment may proceed using [the local Foundry route](phase3-local-deployment.md), with independent verification before environment changes. Studio reconciliation remains pending and is not bypassed or claimed complete. The original Studio route below is still an alternative when quota returns; sections4–6 remain the scenario guide.

Local implementation is ready for reconciliation; Phase 3 is not PASSED. No new address or transaction is claimed. Keep the verified Phase 2 deployment/evidence unchanged. No public repo update, commit or push is part of these steps.

## 1. Reconcile the existing Studio project when quota is available

The Studio contract turn ended with CLI exit4 / `budget_exceeded` and a daily-usage-limit message. Its partial draft is not the final local source. Local review added the missing refund/race/stateful tests, fixed the evidence-bound manual-success bypass and the UNCERTAIN success cutoff, and implemented the evidence UI. These changes must go back to the same project.

In PowerShell:

```powershell
cd C:\GitHub\MicroCover-Private
Get-Content docs/phase3-studio-files.txt
.\scripts\reconcile-phase3-studio.ps1 -WhatIf
# After reviewing the manifest and when Studio quota is restored:
.\scripts\reconcile-phase3-studio.ps1
arc-studio pull --app c47658be-4463-462f-89b8-a0a418962a3d --paths 'contracts/**' 'src/microcover/**' 'services/evidence/**' 'package.json' 'bun.lock' 'tsconfig.services.json' --dry-run
```

The script uploads only named source files via supported CLI in-place mappings and asks Studio to run checks. It never sends `.env`, private storage or keys. If Studio changes source, first pull to a separate temporary review directory, inspect the diff, then selectively reconcile and rerun checks. Do not overwrite local work blindly. Confirm exact source equality and Preview's version2 deployment-required gate before proceeding. A successful run alone is not proof of judge access; the historical sharing issue is separate.

## 2. Human deployment of the reviewed Phase 3 source

Only after reconciliation/checks, give Studio this explicit human request:

```text
Deploy only the reviewed Phase 3 MicroCover source to Arc Testnet5042002.
Constructor arguments in order:
USDC = 0x3600000000000000000000000000000000000000
demoOperator = 0x1d39fc0e5293ab949d63217ffb375357adf3933f
success reviewWindow = 120 seconds
separate uncertaintyTimeout = 120 seconds
Do not change source or overwrite historical Phase2 evidence. Return the actual
address/transaction and verify protocolVersion3, USDC, operator, reviewWindow120,
uncertaintyTimeout120. Do not create guarantees, approve, move funds or publish.
```

Independent receipt/runtime/config verification is still required. Do not reuse the Phase2 address as if it were upgraded. Only after verification, set the **public** `VITE_MICROCOVER_ADDRESS` to the actual new address and restart the local dev server. Preserve Phase2 deployment/evidence files. No private wallet key belongs in any browser variable or chat.

## 3. Initialize private synthetic-feed storage once

Use a persistent directory outside all Git checkouts. This laptop has a home-directory Git marker, so use a path outside `C:\Users\abhir` too. Do not rotate keys after creating evidence-bound guarantees: the frozen policy includes their public identities.

```powershell
cd C:\GitHub\MicroCover-Private
$env:MICROCOVER_EVIDENCE_HOME='C:\MicroCover-Evidence-Local'
bun run evidence init-demo
$env:MICROCOVER_EVIDENCE_CONTRACT='<ACTUAL_VERIFIED_PHASE3_ADDRESS>'
bun run evidence serve
```

`init-demo` creates two demo Ed25519 signing keys outside Git; it prints only the public policy hash/disclosure and refuses overwrite. Those keys authenticate fixtures; they are not wallet keys. Keep that terminal running. No wallet signing/broadcast code exists in the service. Run `bun run dev --host 127.0.0.1 --port 5173 --strictPort` in another terminal, after setting the verified public contract address in its local environment. The existing dev server must be stopped first if it already occupies5173. The API defaults to loopback8787; `.env.example` documents the actual config names. Hosted Studio cannot reach this local service; it must honestly show unavailable until a separately reviewed hosting configuration exists. No hosting is performed in Phase3.

## 4. Human evidence-driven failure reference

Use the existing reference amounts: compensation5, escrow2, max cohort3, bond15 USDC. Give enough join time to enroll three accounts and inspect collection (default10 minutes; outcome delay0). The create screen must show the exact public policy hash, cohort ID, review120 and separate uncertainty120 **before purchase**.

1. Use Account2 as provider for this failure reference, keeping Account1 as the immutable operator. Account2 creates the evidence-bound guarantee and may then disconnect. This separates provider cooperation from the evidence-verdict authority. Record its actual new ID. The collector discovers its frozen policy/terms from Arc within10 seconds. Confirm receipt entries arrive before anyone requests evaluation or disputes.
2. In a separate PowerShell window, set the same `MICROCOVER_EVIDENCE_HOME` and actual contract environment values, then run `bun run evidence set-mode <ACTUAL_ID> failure`. Both named HTTP fixture feeds now explicitly sign CANCELLED for that domain. Do this before the outcome deadline and allow at least one final fresh collection period.
3. Enroll Accounts1,3,4 (approve2, then enroll, each wallet on Arc Testnet). Account1 is both trusted operator and a beneficiary in this synthetic demonstration; no impartiality claim is made. Confirm3/3 and policy disclosure. Request evaluation from one beneficiary if desired; it emits a request only and must not enter onchain UNCERTAIN.
4. Stop/restart the collector before the deadline, using the same storage/keys. Confirm sequence/nonces continue without duplicate polls; do not claim missed intervals were collected.
5. After the outcome deadline, inspect FAILURE, coverage2/2, group1, support100% (not probability), receipt clocks and commitment. **Do not click provider Admit failure or reconnect Account2 for settlement.** Connect Account1 as operator, prepare fresh verdict, anchor root, wait for confirmed receipt; prepare again and submit the fresh verdict. Reprepare if expired. Compare the evidence commitment with the actual EvidenceAnchored event.
6. Confirm evidence failure origin and no FailureAdmitted event, then permissionless bounded payouts7 each. Collect receipts and final accounting. The provider need not cooperate with evidence failure or beneficiary payout.

## 5. Separate success reference

Create a separate guarantee, enroll beneficiaries, and set its mode to `success` **before** its deadline. After the fixed snapshot establishes SUCCESS, anchor and submit through the same operator route. Verify full120-second review from the proposal (and original claim-end protection); no early release. After readiness, anyone finalizes success, releases actual escrow to provider, then provider returns its bond. Record receipt/state evidence. Never use manual proposeSuccess on an evidence-bound guarantee; the contract rejects it.

## 6. Unresolved fallback and negative cases

Use a separate small guarantee (e.g. compensation0.1, escrow0.1, cap2) with at least one enrolled beneficiary; existing reference defaults remain unchanged. Choose `conflict`, `unavailable`, `invalid`, `unknown`, or `stale` before the deadline. A legitimate stale fixture needs a window **longer than60 seconds**. Available modes are deterministic synthetic demonstrations, not external reports.

```powershell
bun run evidence set-mode <ACTUAL_ID> conflict
# Alternatives: success, failure, unknown, unavailable, invalid, stale
```

Confirm UNCERTAIN offchain does not change onchain status or start its timer. Only then explicitly raise a beneficiary dispute or operator mark-uncertain on this test guarantee. Record the first onchain timestamp/deadline. Repeated requests, retry/anchor submissions and service restarts must not reset it. Before120 seconds, unresolved finalization must be unavailable/reject; no chain-time manipulation. At/after the deadline, a nonprivileged account finalizes unresolved; confirm REFUNDING / UNRESOLVED_REFUNDED, zero compensation, full pending escrow liabilities. Refund in small batches; bond withdrawal stays blocked until all refunds. Finish refunds, provider returns unused bond, verify CLOSED/outcome3 and zero liabilities. Repeat refund/withdraw must reject. Established failure and finalized success must never take this fallback.

Local tests cover both transaction orderings around equality: resolution before the deadline wins; at equality every UNCERTAIN resolution is too late even if submitted before timeout finalization. A successful resolution gets full review; a later dispute reuses the first uncertainty deadline, possibly immediately eligible. Real testnet race ordering and wrong-wallet/network/cancel/fresh-session UI observations remain human checks, not results inferred from local tests.

The existing dispute timing is preserved: explicit uncertainty can be entered before the outcome deadline, so its first120-second timeout may become eligible before that service deadline. This consequence is disclosed before purchase/enrollment; no unapproved minimum-start-time redesign was added.

Tamper/replay tests run in disposable stores with ephemeral keys: `bun run evidence:test`. Do not corrupt the real demo store. Hash chains detect changed entries/payloads against retained links; a privileged owner can rewrite unanchored history or truncate its tail. Matching an Arc commitment checks integrity against that submitted fingerprint, not truth, source independence or complete collection. Blocklisted recipients may block a refund batch; no alternate-recipient/sweep path is invented.

## Checkpoint record

Supply actual new deployment/anchor/verdict/refund transaction links and observations. Only then update Phase3 checkpoint results. No Phase4, public release or Git action is authorized by completing these steps.
