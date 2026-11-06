# MicroCover — Phase-by-Phase Execution Runbook

Companion to `MicroCover_Implementation_Plan.md`. Prepared 6 November 2026.

This is the execution order for the plan already in your private folder. It does not assume any product code has been implemented. Keep both documents in the private project root. The full plan defines scope and bounty requirements; this document defines the next task, who does it and what proves it works.

## How to use this runbook

1. Open **only your local private project folder** in the coding agent. Keep the public folder for reviewed publication.
2. Give the agent the shared instruction below, then the prompt for the current phase. Do not paste every phase as a request to implement everything.
3. Let the agent finish its bounded task and run its checks. Perform your manual checks independently.
4. If a checkpoint fails, use the repair prompt; do not proceed to the next feature.
5. Review the diff and create small meaningful commits under the actual author's identity. Publish the validated phase using the two-folder instructions in the full plan.
6. Update `docs/progress.md`: phase, status, actual commands/results, human reviewer, private commit, public commit/PR, blockers and next action. Status is `NOT_STARTED`, `IN_PROGRESS`, `BLOCKED` or `PASSED`.

The instructions about manual commits below are your chosen local workflow for the coding agents. They do not require asking for approval after every read, local edit or test. Humans handle credentials, wallet signatures, accepting terms, repository publication and final submission.

### Shared instruction — give once at the start of an agent session

```text
Work in the current private MicroCover checkout. Read AGENTS.md if present,
MicroCover_Implementation_Plan.md, MicroCover_Phase_By_Phase_Runbook.md,
docs/progress.md and docs/interfaces.md if they exist. Inspect current code,
Git status and existing scripts before making changes. Preserve unrelated work.

Implement only the phase I name. Reuse the working Studio-generated toolchain;
do not rebuild the project or add unrelated sponsors/features. Use generic
provider/beneficiary/guarantee/cohort names. Concerts and rides are examples.

For sponsor SDKs/config, consult current official docs and verify actual APIs.
Do local edits and checks autonomously. Stop for genuine missing credentials,
unsupported integrations or decisions that change the agreed product.
Do not invent command results, contract addresses, source independence or proofs.

Use environment placeholders; never commit or display private keys. Do not
commit, push, merge, publish, sign wallet transactions or deploy automatically.
Prepare the exact commands for us to run. Keep required Arc work in its supported
Studio workflow; local agent changes must be reconciled there.

Finish with changed files, exact checks and results, manual steps remaining,
checkpoint status, proposed commit groups, and the next action. Update progress
and AI-use notes accurately. Stop at the phase boundary.
```

### Repair prompt — reuse whenever a checkpoint fails

```text
Phase [N] failed at [check]. Here is the exact error/output: [paste sanitized
output]. Diagnose the cause against the phase requirements. Fix the smallest
relevant change, run the failed check plus checks affected by the fix, and report
the actual result. Stay within this phase. Do not mask the error, replace live
data with a fake success, weaken authorization, or start later phases.
```

## Reference scenario to use throughout

Keep the engine generic, but use one consistent small scenario to reduce debugging:

| Parameter | Demo value |
|---|---|
| Provider | Synthetic concert organizer |
| Beneficiaries | Three distinct test attendee accounts |
| Guaranteed promise | Event occurs under the explicitly configured condition and time window |
| Price per attendee | 2 test USDC |
| Escrow share | Full 2 test USDC for this first demo |
| Compensation | 5 test USDC per attendee |
| Provider bond | 15 test USDC |
| Capacity | Three attendees; enrollment closes before evaluation |
| Failure total | Each gets 2 refund + 5 compensation; 21 USDC across three |
| Success total | 6 USDC escrow releases to provider; 15 USDC bond withdrawable after its window |
| Timing | Short, disclosed demo deadlines chosen when creating each guarantee |
| Evidence | First provider admission; later labeled event-status fixtures through the evidence adapter |

These are test amounts, not real ticket economics. Contract accounting uses integer token units. Keep extra USDC for account gas separate from amounts committed to the guarantee. Assess transfers and ledger balances; sender wallet deltas may also include gas.

Prepare separate guarantees for failure, success and uncertainty. Never reset a settled guarantee to reuse it. No one attendee's check-in or complaint proves whether the whole concert happened.

## Phase 0 — Prepare the workspace and prove access

**Corresponds to full-plan Stage 0. Agent:** Codex for inspection/configuration; Arc Studio for initialization. **Suggested budget:** 30–45 minutes, with access blockers addressed immediately.

### You do manually first

1. Confirm you are in the cloned private folder containing the full plan. Do not initialize another Git repository inside it.
2. Assign five owners: contracts/Studio, frontend, evidence, CRE and Arkiv/release. One person coordinates merges and deploys.
3. Verify teammates can access the private repo and the submission repo. Check the dashboard deadline and create the submission draft early.
4. Open Arc Studio, sign in and create the project there. Use the first Studio prompt below. Save the project URL and initial prompt.
5. Ask the Arc team how local source edits can be synced back while meeting the contract/app Studio requirements. Record the actual answer, not an assumption.
6. Prepare test accounts for provider, three beneficiaries and the demo settlement operator. Keep keys in wallet/local secret settings, not chat or docs. Request official Arc testnet USDC.

### First Arc Studio prompt

```text
Create the foundation of MicroCover on Arc Testnet using official USDC.
It is a generic programmable-guarantee protocol: provider bond, beneficiary
escrow, fixed compensation, bounded cohort and deterministic settlement.
Use a synthetic concert example with three attendees, but no concert-specific
contract fields. Retain generic provider/beneficiary/cohort terminology.

For this first pass, produce the smallest runnable app/contract foundation,
network configuration and test/deploy commands. Do not build all lifecycle
features yet. Do not add AI, bridges, ENS, swaps or new sponsors.
Explain how to preserve this shareable Studio project while reviewing/editing
source with external coding tools and connecting the final app inside Studio.
```

### Codex prompt for this phase

```text
Execute Phase 0 only. Inspect the repository, full plan and Studio-generated
source. Do not overwrite existing code or create a second scaffold.
Inventory the stack, package manager, lockfile, run/test/build commands and Git
history. Prepare .gitignore and .env.example before any product commits.
Create concise docs/interfaces.md, docs/progress.md, docs/ai-usage.md and
docs/contributions.md. Record the frozen reference scenario and exact local
commands in docs/runbook.md. Mark unverified addresses/capabilities as unverified.
Prepare minimal Arc connectivity, CRE simulation and Arkiv write/query smoke
checks using current docs. Run only checks with available nonsecret config;
report missing credentials rather than fabricating results. No full integration.
```

### You check manually

- Start the app with the generated documented command; open the actual local URL.
- Check the network name and account on your wallet. Inspect an actual small test transaction in the explorer.
- Confirm Studio project URL is accessible to the intended judges; check sharing settings.
- Supply CRE/Arkiv account setup and environment values privately when needed. Run sign-in steps yourself.
- Inspect `git status`, `git remote -v` and history. Ensure `.env` and dependencies are ignored. In an empty repo there may not yet be a commit; record that honestly.

### Checkpoint 0

- [ ] Studio origin and supported source-sync route recorded.
- [ ] App starts; test/build commands are known, with real output or an explicit blocker.
- [ ] Arc token/network connectivity works; no invented addresses.
- [ ] CRE and Arkiv feasibility checks are attempted; failures have an owner and next action.
- [ ] Local private/public folders are distinct and credentials are excluded.

**Commit groups:** `chore: initialize Studio application and safe configuration`; `docs: freeze interfaces and execution checkpoints`.

**Stop if:** Studio workflow is unresolved or account/network access fails. Resolve access before building features that assume it works.

## Phase 1 — Prove the bond/escrow/refund pipeline

**Full-plan Stage 1. Agent:** Studio implements the contract/app slice; Codex reviews accounting/tests. **Suggested budget:** 90–120 minutes.

### Agent tasks, in order

1. Define an immutable guarantee policy once sales begin: provider, condition, times, price, escrow share, compensation, cohort cap and bond.
2. Implement deposit/create and enrollment with the official ERC-20 interface. Derive capacity from reserved compensation, not total contract token balance.
3. Bind membership and refund entitlement to enrolled accounts. For this demo, one purchase per account is sufficient; reject duplicates explicitly.
4. Send only the non-guaranteed payment share to provider; the reference scenario uses full escrow, so this share is zero.
5. Implement provider-admitted failure and a tested bounded batch payout. Prevent sales after closure and repeat settlement. Keep guarantees financially isolated.
6. Produce tests for balances and invalid transitions, plus a simple runnable UI or script. No evidence engine, CRE or Arkiv integration yet.

### Prompt

```text
Implement Phase 1 only using the reference scenario. Follow the supported Studio
workflow for contract/app changes. Deliver create/fund, enroll/escrow, capacity
enforcement and provider-admitted failure for a bounded cohort of three.
Amounts and beneficiaries must come from recorded terms and membership, not a
caller-supplied payout list. Protect reserved obligations and repeat settlement.
Use official USDC on testnet; local mocks are for tests only. Provide a minimal
connected interface/script and meaningful accounting/authorization tests.
Do not add evidence collection or later sponsor integrations. Prepare deployment
steps for us; report checkpoint evidence and proposed small commit groups.
```

### You do manually

1. Review test output and deployment instructions. Deploy through the agreed Studio flow; sign test transactions yourself.
2. Create the reference guarantee and record its ID and bond transaction.
3. Enroll three attendees using three actual accounts. Check escrow total 6 and reserved compensation 15.
4. Try a fourth enrollment; it must fail. Try provider admission from an attendee; it must fail.
5. Admit cancellation using the provider account. Check each attendee's token transfer of 7 and total payout 21.
6. Try settling again and withdrawing a still-reserved bond from a different active guarantee. Both must be prevented.

### Checkpoint 1

- [ ] Bond, three enrollments and payouts are real testnet transactions.
- [ ] Refund comes from buyer escrow; compensation comes from provider bond.
- [ ] Unauthorized caller, excess capacity and repeat payout cases fail.
- [ ] Tests check cross-guarantee isolation, zero/invalid parameters and arithmetic.
- [ ] No unexplained operator button can send arbitrary money.

**Commits:** `feat: create bonded guarantees`; `feat: enroll beneficiaries into escrow`; `feat: settle provider-admitted failure`; `test: cover capacity and payout authorization`.

**Publish:** first validated phase, preserving its actual commits. This is the first complete small money pipeline.

## Phase 2 — Complete success/release and the core screens

**Full-plan Stage 2. Agents:** Studio/Codex for lifecycle, then Antigravity for UI. **Suggested budget:** 60–90 minutes. Run agents sequentially.

### Codex tasks and prompt

```text
Implement Phase 2 lifecycle only. Add the documented authorized success path,
enrollment cutoff, finalization timing, escrow release and time-gated bond
withdrawal. Define the claim/finality window precisely in docs/interfaces.md.
For the demo use a restricted, explicitly labeled operator until CRE is connected;
do not expose an unrestricted setOutcome function. Keep disputed/uncertain funds
locked. For the smallest version, release success funds only after the relevant
finality/claim window, so success cannot be clawed back after money is released.
Test premature release, wrong caller, double release and failure-to-success
transitions. Prepare the supported Studio deployment update and UI interface.
Stop before styling or evidence integration.
```

### Antigravity prompt after lifecycle checks pass

```text
Implement only Phase 2 UI using existing interfaces and the Studio-connected app.
Create provider setup/dashboard, public guarantee detail, beneficiary purchase
and status/history skeleton. Display the plain-language condition, deadline,
claim window, price/escrow split, compensation, locked bond and capacity.
Use real contract reads and transaction receipts. Include wallet connection,
wrong-network, pending, rejected, reverted and confirmed states. Add explorer
links and accessible mobile layout. Keep generic labels; concert is demo data.
Do not modify contracts or add future integrations. Run build and browser checks.
```

### You do manually

1. Create a fresh success guarantee, enroll buyers and close enrollment under its policy.
2. Attempt early release; confirm rejection.
3. Submit success through the restricted demo authority, wait for the declared short window and release funds when allowed.
4. Check escrow payout 6 and bond eligibility 15 for the reference scenario. Verify a failed guarantee cannot become successful.
5. Open a beneficiary flow in another browser profile. Reject a wallet transaction intentionally and switch to the wrong network once; confirm the UI explains both.

### Checkpoint 2

- [ ] Both failure and success are usable from the UI.
- [ ] Policy and funds are visible before purchase.
- [ ] Success finality and unlock timing are enforced by contracts.
- [ ] Operator powers are labeled; UI visibility is not the only access control.
- [ ] Fresh browser session loads actual chain data.

**Commits:** `feat: finalize successful guarantees safely`; `feat: connect provider and beneficiary screens`; `fix: handle wallet and transaction errors`.

**Handoff:** record ABI/config/commit after contract review; Antigravity starts from that state and changes only its assigned UI files.

## Phase 3 — Make evidence produce a reproducible verdict

**Full-plan Stage 3. Agent:** Codex; Antigravity only for presenting existing evidence. **Suggested budget:** 90–120 minutes.

### You decide manually before coding

- Freeze exactly what the event promises and what constitutes cancellation or success. Do not let AI choose these at runtime.
- Choose the approved source groups and evidence window. For the first working adapter, use two or more clearly labeled synthetic event-status feeds, not a claim of real independent news coverage.
- Fix evidence freshness, minimum source coverage, weight and threshold. State that fixtures test the pipeline, not real-world oracle decentralization.
- Keep provider admission from Phase 1 available; it does not require invented evidence.

### Codex prompt

```text
Implement Phase 3 only. Add an evidence service with canonical serialized entries,
source identity/group, source and receipt timestamps, guarantee/cohort ID,
payload hash, previous-entry hash and verified authentication/signature where
configured. Retain private raw payloads outside Git; publish only safe receipts.

Implement a deterministic evaluator using the frozen template and source policy.
Return outcome, reason, coverage, weighted support, evidence root and policy
version. Two synthetic fixtures under our control must be labeled as synthetic,
not presented as independent production sources. Missing/stale sources must not
increase confidence. Event cancellation cannot be inferred from absent check-ins.

Collect on a documented interval starting at activation/enrollment, before a
claim. Use an idempotent cursor/store so restarting does not duplicate entries.
Append evidence; never overwrite history. Anchor a root through the restricted
contract path. Buyer claim starts evaluation but cannot dictate payout.
Return UNCERTAIN on unavailable/insufficient evidence and preserve locked funds.
Create failure/success/uncertain/tamper/replay fixtures and tests. Expose safe API
responses for the existing UI. Do not add CRE/Arkiv/AI yet.
```

### You do manually

1. Start collection before submitting a claim. Verify entries arrive with separate source/receipt timestamps.
2. Run cancellation fixture and check the computed score and root; trigger authorized settlement only from the documented evaluator/operator route.
3. Run success fixture on a separate guarantee.
4. Shut down one feed or make its result stale. The outcome must remain uncertain when coverage is inadequate, and funds stay locked.
5. Change a stored payload or replay a signed entry for another guarantee. Integrity/domain checks must detect/reject it.
6. Open evidence view and compare its root with the Arc anchor transaction.

### Checkpoint 3

- [ ] Collection starts before claims and survives a restart without duplicate records.
- [ ] Same evidence/policy yields the same verdict.
- [ ] Cancelled, successful and uncertain examples behave differently for explicit reasons.
- [ ] Missing collection is not proof of event failure.
- [ ] Privacy, replay checks and onchain fingerprint work.

**Commits:** `feat: collect scoped evidence receipts`; `feat: evaluate promise outcomes deterministically`; `feat: anchor evidence commitments`; `test: reject stale and tampered evidence`.

**Deferred:** rider pickup-code adapter, live complex web scraping and AI review. The generic interfaces support future adapters; they are not needed to prove this phase.

## Phase 4 — Connect Chainlink CRE to this exact pipeline

**Full-plan Stage 4. Agent:** Codex. **Suggested budget:** 90–120 minutes.

### You do manually first

1. Complete CRE account/CLI authentication if required and provide environment secrets privately.
2. Confirm supported Arc simulation configuration and the actual report/forwarder path using current docs. Ask Chainlink mentors promptly if the chosen write path is blocked.
3. Keep the evidence API reachable from the execution environment. Do not assume a hosted network can reach your laptop's localhost.

### Codex prompt

```text
Implement Phase 4 only. Use current official CRE docs and an actual working
template/SDK version. Read the deployed guarantee from Arc, fetch our evidence
API, apply the same deterministic policy and produce a report bound to chain,
contract, guarantee/cohort, evidence root, policy version and replay identifier.
Connect the report to the real MicroCover outcome flow using the supported
consumer/forwarder integration. Verify the required sender/workflow metadata.

Run CRE CLI simulations with the actual configured API and blockchain connection.
Preserve sanitized output and reproducible commands for success, failure and
uncertainty. Do not replace CRE with a standalone Node evaluator while claiming
the integration works. Explain simulation versus network deployment precisely.
If a supported write is unavailable, document the restriction and any explicit
demo relay authority; do not treat a locally forged report as verified CRE output.
Keep test adapters isolated and configured visibly. Add replay/wrong-domain tests.
Prepare wallet/deployment steps for us, then stop at Checkpoint 4.
```

### You do manually

1. Run the documented simulation yourself from a clean terminal.
2. Compare CRE verdict/root with Phase 3's result.
3. Run the authorized write/relay procedure and inspect the actual Arc transaction and UI update.
4. Replay the same report and try a report for the wrong guarantee. Both must fail.
5. Take down evidence input; confirm CRE produces uncertainty/error rather than a fabricated outcome.

### Checkpoint 4

- [ ] CRE genuinely joins blockchain and external evidence in this app.
- [ ] Simulation is reproducible, and screenshots/logs match actual output.
- [ ] Settlement route is authenticated and its trust assumptions are explicit.
- [ ] Testnet write, simulated output and live network deployment are distinguished accurately.
- [ ] No unauthenticated general-purpose settlement endpoint remains.

**Commits:** `feat: orchestrate evidence evaluation with CRE`; `feat: authenticate guarantee settlement reports`; `docs: reproduce CRE simulation and settlement flow`.

**If blocked:** preserve the working core, disclose the boundary and resolve with the mentor. A disconnected sample workflow is not a completed integration.

## Phase 5 — Put the existing evidence/history view on Arkiv

**Full-plan Stage 5. Agents:** Codex for adapter/query; Antigravity for rendering. **Suggested budget:** 60–90 minutes.

### You do manually first

- Supply Arkiv testnet access/funding privately and confirm the current network from official docs.
- Choose the writer wallet and retention duration longer than the demo's full claim/finality window. Record its public address.

### Codex prompt

```text
Implement Phase 5 only using current Arkiv docs/SDK. Write public receipts and
claim/history metadata from the existing pipeline with stable IDs and deduplication.
Include guarantee/cohort ID, type, source group, receipt timestamp, payload hash,
previous hash and Arc references. Keep personal/raw evidence and secrets off Arkiv.

Provide queries by guarantee and record type. Make the existing evidence/history
screen obtain these records from Arkiv, directly or through a documented proxy.
Keep monetary state read from Arc. Queue/retry failed indexing safely; outage
must not decide the guarantee. New evidence is a new entity, not an overwrite.
Document integrity against the Arc anchor, owner powers and expiration/renewal.

Supply one real writer address, entity key, runnable query and UI proof.
Write arkiv/schema.md, friction.md, reach.md, why-arkiv.md and how-you-use-arkiv.md
with actual observations. Do not invent feedback or users. Run a live write/read,
duplicate retry and unavailable-service check. Stop at Checkpoint 5.
```

### Antigravity prompt after the query works

```text
Render the existing Arkiv-backed evidence/history response in the current app.
Show source, timestamp, outcome/reason, receipt hash and relevant explorer links.
Distinguish loading, empty, stale and unavailable history from an uncertain
guarantee outcome. Never fall back silently to hardcoded successful history.
Do not change schemas/contracts or add features. Verify a fresh browser load.
```

### You do manually

1. Create new evidence and record the resulting entity key.
2. Run the documented query outside the UI; verify the same records appear.
3. Refresh the browser and inspect the network request or server query logs to confirm Arkiv is the data source.
4. Re-run indexing; confirm no duplicate receipt.
5. Disconnect Arkiv briefly; the app explains history availability while Arc balances and settlement remain correct.

### Checkpoint 5

- [ ] Real Arkiv write, query and visible feature read are proven.
- [ ] Public entities contain no raw/private payloads.
- [ ] Retention, writer authority and integrity limits are documented.
- [ ] Required judging files contain genuine evidence and feedback.

**Commits:** `feat: index public guarantee receipts in Arkiv`; `feat: display Arkiv-backed evidence history`; `docs: add Arkiv schema queries and feedback`.

## Phase 6 — Verify, deploy and submit

**Full-plan Stage 6. Agents:** Codex for code/integration checks; Antigravity for browser QA. **Humans:** deploy, record and submit. **Reserve:** at least two hours before the verified deadline.

### Codex prompt

```text
Execute final verification only. Inspect code/config and create a reproducible
clean-start runbook for the tested commit. Run meaningful contract/evidence/report
checks and the app production build. Exercise failure, success and uncertainty;
check ledger totals, roots, CRE outcomes and Arkiv reads agree. Review auth,
duplicate settlement, secret exposure and runtime/deployment config.
Fix confirmed blockers without adding scope. Produce architecture, limitations,
sponsor evidence links, AI-use/contribution notes and a concise demo script.
Prepare exact deployment/release steps and outstanding manual actions.
Do not claim a deployment, transaction or submission exists until verified.
```

### Antigravity prompt

```text
Perform browser QA on the actual deployed candidate URL after we supply it.
Check provider setup, public terms, beneficiary purchase, transaction status,
evidence/history, failure, success and uncertain displays. Check mobile layout,
wrong network, rejected wallet action and unavailable backend/history states.
Report reproducible issues and fix presentation bugs only. Never simulate a
successful payment to hide a failure. Stop after the agreed checks.
```

### You do manually, in order

1. Freeze features. Review final changes and checks. Deploy contracts/app/service using the agreed Studio route and available hosts; configure secrets in host settings.
2. Ensure collector persistence/background execution works on that host. A browser tab or sleeping ephemeral process is not continuous monitoring.
3. Open deployed app from a clean session. Confirm chain/token/contract addresses, API URLs, CORS, writer permissions and restart behavior.
4. Run fresh failure and success scenarios and one uncertainty case. Prepare already-settled examples for the short video; disclose compressed demo timing and synthetic feeds.
5. Have a teammate follow README from a clean checkout. Fix missing commands/config without handing them your secrets.
6. Review reachable commit history for secrets and promote the exact tested code to the public folder/repo. Record deployed public SHA and actual contributions.
7. Verify public repo, live demo, Studio URL and explorer/query links open for judges. Add the chosen open-source licence.
8. Record the human-narrated demo according to the full plan's current rules checklist. Include Studio, real transfers, CRE usage and Arkiv query evidence. Keep backup recording/screenshots.
9. Select the three claimed partners and finalist judging in the dashboard. Complete all required fields, integration explanations and feedback. Submit before the verified deadline; save the confirmation.
10. Publish a release tag for the tested submission commit and record it. Keep fixes after submission traceable and within event rules.

### Checkpoint 6

- [ ] Judges can open the complete submission without private repo access.
- [ ] Each sponsor claim has real, reproducible evidence.
- [ ] Prototype limitations, synthetic data and operator powers are explicit.
- [ ] Deployed version matches a public commit and setup works for a teammate.
- [ ] Actual dashboard submission confirmation is saved.

**Commits:** small actual bug fixes, then `docs: finalize demo deployment and sponsor evidence`. Do not invent a large last-minute history.

## Routine at every checkpoint: your Git actions

From the private folder, inspect before staging:

```bash
git status
git diff --stat
git diff
```

Stage actual files or use `git add -p` for related hunks; inspect `git diff --cached`, then commit a coherent tested change. Avoid a blanket `git add .` before reviewing the working tree. Record actual check results in the commit/PR where useful.

Push reviewed private work, then follow the full plan's two-folder publication procedure. It includes separate paths for an empty public repository versus an existing public `main`. Do not run an empty-repo command against a populated branch, and do not copy either folder's `.git` directory.

If you choose file snapshots instead of transferring commits, follow the full plan's disclosure/source-SHA mapping instructions. `git add` cannot recover original commit history. Publication and original authorship remain distinct.

## Minimal checkpoint record to ask the agent to fill

```text
Phase:
Status: NOT_STARTED / IN_PROGRESS / BLOCKED / PASSED
Starting commit:
Implemented files/behavior:
Commands run and real results:
Manual checks still required:
Human reviewer and verification result:
Studio / deployment / transaction / CRE / Arkiv evidence:
Known limits and staged data:
Proposed commit groups:
Private commit / public commit or PR:
Next action:
```

## What you should do right now

1. Save this file next to `MicroCover_Implementation_Plan.md` in the private project root.
2. Open Arc Studio and complete the manual beginning of Phase 0.
3. Open that private folder in Codex. Paste the shared instruction, then the **Phase 0 prompt only**.
4. Run its manual checks and commit the foundation. Proceed to Phase 1 only when Checkpoint 0 is resolved.

For phases that touch sponsor integration, agents must verify current technical documentation. This runbook adds execution detail; it does not independently certify unbuilt code, subscription entitlements, sponsor acceptance or a signed-in submission form.
