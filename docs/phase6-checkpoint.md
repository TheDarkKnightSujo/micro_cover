# Phase6 — final local verification and release preparation

**IN_PROGRESS**,6November2026. User authorized the next step after Phase5 functional checks. Phase5 uncommitted work is preserved. Base private commit9d98930b05679dca5a1ddb2f6d9c980a08e93a6f; dirty candidate is not a release SHA. Latest user request explicitly authorizes coherent private commits and a normal push. Deployment, public publication and signing remain human-only.

## Actual checks

| Command | Result |
|---|---|
| `bun run check` | exit0, lint/app types |
| `bun run evidence:check` | exit0 |
| `bun run evidence:test` | exit0,44pass/0fail/562assertions |
| `bun run --cwd workflows/cre check` | exit0 |
| `bun run contracts:test` in Windows | FAILED exit1, Forge absent from Windows PATH |
| `wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge test'` | exit0,299pass/0fail/0skipped,42suites; existing Foundry |
| `bun run vite build` | exit0; third-party PURE/chunk-size warnings remain |
| `bun run scripts/phase6-audit.ts` | exit0; exact artifact source/runtime/config and pinned ledger, all3examples closed, balance0/obligations0; captured CRE roots/outcomes agree;19live Arkiv entities match Arc success anchor |

Audit writes docs/evidence/phase6/live-audit.json with dirty-source fingerprint; no wallet/send method. Original proofs are preserved. CRE captures are compared, not claimed freshly simulated. No contract changes or redeployment.

## Blockers and deferrals

1. Hosting: app/API are laptop-local. A remote frontend cannot reach127.0.0.1. Select a persistent host and HTTPS routing before changing restrictions. Securely retain existing external SQLite/keys. No public reachability or sustained monitoring proof exists.
2. Studio: later source reconciliation and judge access incomplete. Existing Phase3/4 upload manifests omit Phase5 files; do not call that an entire final sync. Reconcile complete reviewed source through current supported Studio workflow, run checks and verify with another account. Local deployment alone does not establish Arc eligibility.
3. CRE: actual local simulations and human relay shown; native receiver undeployed. Teammate reproduction/review and mentor confirmation of the disclosed route remain pending. No production authentication claim.
4. Source/licence: original-code licence choice pending; recommendation MIT, retaining dependencies' licences. No licence added without selection. Phase5 private commits61cdd3c/14d4c30/7c648c0 are now pushed and remote verified. Phase6 final verification/docs form the next private commit; public promotion/tags remain pending. Preserve real private history/source-SHA mapping; do not manufacture authorship.
5. Human submission: clean-checkout teammate review, hosted/mobile QA, dashboard confirmation, public source promotion, human video and saved submission confirmation outstanding. Local InPrivate is not a public judge-access test.

## Exact local commands

Use README setup and ignored configuration, preserving existing external evidence home. Run checks above. Live read:

```powershell
bun run scripts/phase6-audit.ts
bun run arkiv query 2
```

Two terminals for local runtime:

```powershell
bun run evidence serve
```

```powershell
bun run dev --host 127.0.0.1 --port 5173 --strictPort
```

No deployment command is appropriate until host/config is chosen. Do not run a Phase2 three-argument deployment against the current four-argument contract. Preserve verified addresses. Do not rerun wallet transactions to read existing evidence.

## Human release sequence

1. Review diff/evidence; choose hosting/licence. Resolve Studio quota/reconciliation and judge access.
2. Prepare persistent host configuration and HTTPS routing with secrets only in server settings. Build frontend using verified v3 address/reachable API. Keep separate local deployment helper out of main build. Human deployment only.
3. Independently verify reachable host, restarts, public no-wallet history and origin/credential boundaries. Human runs any required fresh financial scenarios; no agent signing.
4. Teammate follows README from chosen candidate. Historical private collector reproduction requires secure external store; do not share secrets through Git.
5. Inspect stage contents/history for secrets, make coherent task commits under genuine identity, record exact tested/private/public SHAs and promote under separate explicit authorization. Never copy.env/keys/storage/.git/node_modules/out/dist blindly.
6. Verify public/Studio/explorer links as another user, record human demo, submit in dashboard and save confirmation. Tag actual tested submission commit only when authorized.

Official Mumbai guide https://ethglobal.com/events/mumbai/info/details currently lists7November2026 09:00IST, up to3partners and2–4minute video. Public-page verification is not signed-in dashboard verification or eligibility certification. Third-party terms remain separate under https://ethglobal.com/rules. MIT reference https://choosealicense.com/licenses/mit/.

## Proposed commit groups

- Phase5 receipt SDK/schema/outbox/read proxy/tests.
- Phase5 history UI/publication and actual proofs/docs.
- Phase6 audit, corrected README/architecture, demo/checkpoint guides and actual check records.

Private stage/commit/push explicitly authorized by the latest user; actual first3commit release recorded in private-phase5-phase6-release.md. Stop at Phase6 checkpoint until required external/human gates are recorded. Do not mark deferred earlier checkpoints passed based only on local checks.
