# MicroCover — Final Implementation Plan

Updated 6 November 2026, IST. This replaces the earlier implementation plan.

**Goal:** deliver a small working pipeline first, then add the selected sponsor integrations one at a time. The core product remains programmable guarantees backed by provider bonds and buyer escrow. Target partner prizes and ETHGlobal finalist judging.

## 1. Decisions to freeze

| Decision | Final direction |
|---|---|
| Primary bounty | Arc: Best Smart Contracts with Advanced Stablecoin Logic, In Arc Studio — $3,000 |
| Second bounty | Chainlink: Best workflow with CRE — $1,500 |
| Third bounty | Arkiv: Build on Arkiv (from scratch) — $4,000 pool; $3,000 first / $1,000 second |
| Settlement | Arc Testnet, official testnet USDC |
| First template | Objective promise with a deadline, evidence policy and shared trigger; rides and concerts are examples, not separate core protocols |
| First decision path | Provider admission, then deterministic deadline evaluation |
| Subsequent integration | Queryable evidence receipts and public history on Arkiv |
| Deferred | AI evidence review, complex concert evidence collection, reviewer panels, ENS, Swarm, bridging, trading and yield |
| Public submission | https://github.com/TheDarkKnightSujo/MicroCover |
| Private development | https://github.com/TheDarkKnightSujo/MicroCover-Private |

Arc's broader DeFi/onchain-finance track is a secondary match to the same implementation. Do not assume multiple awards stack. Prize amounts are advertised allocations, not expected earnings.

**Arc Studio is mandatory as the starting point.** Start the contract/app there, retain its project URL and show it in the demo. The advanced-contract track asks for contract writing, testing, deployment and app connection in Studio. Before relying on external edits, confirm Studio's supported export/import/sync workflow and whether the intended workflow satisfies that requirement. Using Codex or Antigravity does not replace Studio usage. If Studio is blocked, get a concrete answer from the Arc team early; deploying elsewhere alone does not qualify for the Arc bounty.

Chainlink documents Arc Testnet CRE simulation support. Begin with simulation; a live CRE network deployment is not required by this track. Prove the actual workflow and report path before describing settlement as CRE-driven. Do not substitute Functions or add CCIP just for a prize.

Arkiv should supply an actual user-visible evidence/history query. It is not sufficient to install its SDK or write an unread log. Keep contract balances authoritative on Arc.

### Domain-neutral product model

MicroCover is a reusable guarantee protocol for organizations and their customers. Use generic contract/API names such as `provider`, `beneficiary`, `guarantee`, `cohort`, `condition`, `deadline`, `evidencePolicy`, `bond` and `escrow`. Avoid building the protocol around `driver` or `rider` fields.

| Example | Provider | Beneficiaries | Promise/evidence | Cohort |
|---|---|---|---|---|
| Pickup | Ride organization | Rider | Pickup confirmed by agreed deadline, with scoped customer/provider signatures | One booking |
| Concert | Event organizer | Ticket holders | Event held under agreed terms, or cancellation verified against specified sources | All tickets sharing that event trigger |

Both reuse creation, funding, purchase, evidence, verdict and settlement. Evidence adapters differ: an attendee check-in cannot prove a concert happened, and one attendee's assertion cannot cancel an event for everyone. Fix event-specific evidence rules before allowing automated resolution. A provider admission works for either example.

Build a small generic deadline/condition template first, demonstrated with a synthetic concert cohort of three attendees and a provider-admitted cancellation; add verified evidence evaluation afterward. The same interfaces accept a ride adapter later. Do not require both full ride and concert applications to finish the first pipeline.

## 2. Repository workflow: two repositories, one truthful history

The proposed private-to-public arrangement can work. A teammate may publish commits you made, but Git must retain the original authorship and history. Pushing a commit does not make the pusher its author. Each member should add real implementation, tests, fixes, documentation or review work; there is no cited rule requiring equal commit counts.

Do not copy completed files into a new repository and recommit them under other members' names to manufacture participation. Do not backdate commits, reset authors, or recreate an artificial sequence. ETHGlobal asks for development history and disclosure of reused work and AI assistance.

### Two separate local folders (your chosen setup)

Keep two sibling folders: `MicroCover-Private/` for development and `MicroCover/` for publication. Each retains its own `.git` directory and GitHub `origin`. Use Git to transfer validated commits between them; a single folder with two GitHub remotes is not required.

Run from the parent directory only if the folders do not already exist:

```bash
git clone https://github.com/TheDarkKnightSujo/MicroCover-Private.git MicroCover-Private
git clone https://github.com/TheDarkKnightSujo/MicroCover.git MicroCover
cd MicroCover
git remote add private ../MicroCover-Private
git fetch private
git fetch origin
git log --all --graph --oneline --decorate -20
```

The `private` remote above is the separate local development folder. Its committed branches can be fetched without copying files. Uncommitted work will not transfer. Each teammate can use this same two-folder arrangement after cloning the private repository with their own authorized account.

The earlier repository check found public metadata reporting size 0/default branch `main`; private access returned 404 to the connected account. Check current branches before running publication commands. No remote branches were changed while preparing this plan.

### Development and clean commits

Work on small task branches in the private folder. Stage files or hunks selectively there, check the diff and commit after a meaningful slice works. For example, from `MicroCover-Private/`:

```bash
git status
git diff
git add contracts/Guarantee.sol
git diff --cached
git commit -m "feat: add bonded guarantee creation"
```

The example path is illustrative; use the actual Studio-generated path. Merge validated task branches into private `main` with reviewed changes, then push that history to private GitHub. Keep secrets out of all commits. Use each actual author's local identity, or accurate co-author attribution for pair work.

### Initial publication when public main does not exist

After private `main` contains a checked stage, run from `MicroCover/`:

```bash
git fetch private
git switch -c publish/stage-1 private/main
git push origin HEAD:main
```

This publishes the same commits, authors and timestamps through the public folder. If public `main` already exists, do not use the empty-repository path. Inspect ancestry first. Reconcile an independently initialized README/licence commit once with a reviewed merge; substantive divergent work needs explicit integration. Do not force-push or delete existing history.

### Subsequent stage publication

Assuming a shared lineage, from `MicroCover/`:

```bash
git fetch origin
git fetch private
git switch -c publish/stage-2 origin/main
git merge --ff-only private/main
git push -u origin publish/stage-2
```

Use a fresh stage branch name each time. Open a public PR to `main`, record validation and merge with **Create a merge commit** so original commits survive. If fast-forward fails, inspect and reconcile divergence on the publication branch with a reviewed merge; do not reset branches blindly.

After the public PR is merged, synchronize its merge commit back. From `MicroCover-Private/`, with a clean checkout:

```bash
git fetch https://github.com/TheDarkKnightSujo/MicroCover.git main
git switch main
git merge --ff-only FETCH_HEAD
git push origin main
```

If this fails, inspect divergence before merging. Start the next stage from the synchronized history. All teammates pull the updated private `main` before new work.

### If you manually copy files instead

Manual copying is technically possible, but it transfers a snapshot, not the original Git commits. `git add` stages content; adding files one by one does not reconstruct the development timeline or establish who wrote them. If all files are staged before one commit, Git still records only one commit. Files that depend on each other should be committed together as a working unit.

If you choose snapshots, keep both `.git` directories separate and never copy `.git`, `.env`, credentials, personal evidence, dependency folders or build outputs. Track deletions as well as additions; ordinary copy/paste can leave stale files. Maintain a release record mapping every public snapshot commit to its private source SHA, actual authors, what was copied, who published it and the original validation. Disclose the workflow in the public README and make the genuine original history available to judges as required. Snapshot metadata is not a substitute for event history requirements, so confirm acceptance with organizers before relying on this route.

A teammate who copies your work is its publisher, not its original author. Their new implementation, tests, fixes or documentation should be separate genuine contributions. Git transfer between your two folders is the recommended route because it preserves history without this reconstruction burden.

### Security and cleanliness

- Keep `.env`, wallet keys, RPC credentials, private evidence and deployment secrets outside Git from the first commit. Provide `.env.example` with placeholders.
- Private source commits become public when promoted, including reachable history. Review history for secrets before the first promotion; removing a file in a later commit does not remove its old contents. Rotate exposed credentials.
- Do not use `git push --mirror`; it can publish unrelated branches and delete refs.
- A clean history means clear task commits and a reproducible build, not a rewritten history with no mistakes. Fixes are normal.
- Describe the private-development/public-submission process in README. Include `docs/contributions.md` with actual member work and `docs/ai-usage.md` with tools, files and human validation.

## 3. Which tool to use where

These are workflow assignments, not claims about model superiority or subscription limits. Verify access in your own accounts; no paid API or deployment service is assumed to be included in ChatGPT Plus or Gemini Pro.

| Work | Primary tool | Human responsibility |
|---|---|---|
| Initial contract/app creation, contract testing and deployment, app connection | Arc Studio | Own prompts, verify output, retain shareable Studio project and usage evidence |
| Solidity/accounting review and meaningful failure tests | Codex | Check fund flows, access control, lifecycle and test results; feed required edits through the supported Studio workflow |
| Evidence schema, signatures, deterministic evaluator | Codex | Decide trust assumptions and deadline rules |
| CRE workflow, CLI simulation and contract reporting integration | Codex | Supply documented network config and verify simulation/transactions |
| Arkiv adapter, queries, integrity checks and integration | Codex | Verify live writes/reads and ownership/retention choices |
| UI hierarchy, responsive layouts, transaction states and browser verification | Antigravity with Gemini Pro | Review actual flows; keep contract/API interfaces unchanged |
| Integration debugging and final diff review | Codex | Run checks and approve the exact code being merged |
| Demo explanation, documentation and sponsor evidence | Either agent, one task at a time | Verify all claims and record real human contributions |

Arc Studio remains central to the bounty build. Antigravity UI changes must be reconciled into the Studio-connected app using the supported workflow, rather than becoming an unrelated replacement frontend.

Do not let two agents edit the same checkout or files simultaneously. Use sequential handoffs on the single laptop, or separate Git worktrees with disjoint file ownership. The easiest approach here is Codex finishes one scoped slice, a human checks and commits it, then Antigravity works from that commit. Neither agent should automatically commit, push, merge or deploy without the team's intended workflow.

## 4. Minimal architecture and interfaces

Retain the toolchain produced by Studio if it works; avoid rebuilding it merely to match a preferred stack. Suggested organization, adjusted to Studio's layout:

| Area | Responsibility |
|---|---|
| `contracts/` | Guarantee lifecycle, bond/escrow accounting, authorized verdict receiver, payouts |
| `apps/web/` | Provider, customer/attendee, confirmation and evidence/history views |
| `services/evidence/` | Signed event collection, private payload store, hash-linked receipts, evaluator |
| `workflows/cre/` | CRE source, config examples, simulation instructions and captured results |
| `packages/shared/` | IDs, types, canonical serialization and API schemas |
| `arkiv/` | Adapter/query scripts and required judging documentation |
| `docs/` | Interfaces, architecture, demo, contributions, AI use, sponsor checklist and limitations |
| `deployments/` | Nonsecret chain/token/contract addresses and deployment commit references |

Freeze `docs/interfaces.md` before parallel member work. Specify guarantee/cohort IDs; provider and buyer addresses; token amounts; deadline; compensation; escrow share; claim window; capacity; evidence fields; verdict fields; authorization; API errors and UI states.

Use explicit states such as `OPEN`, `EVALUATING`, `UNCERTAIN`, `FAILED`, `SUCCEEDED`, `CLOSED`. Define allowed transitions, enrollment cutoff, which funds may move, and unlock eligibility. Separate success confirmation from bond withdrawal so liabilities and challenge windows cannot be bypassed. Repeated claims may resume evaluation but never pay twice.

For the first version, a bond belongs to a single guarantee/cohort; do not build a global reusable cross-guarantee pool. With fixed compensation, available slots are `floor((bond - reservedCompensation) / compensationPerBuyer)`. Track buyer escrow separately. Reject zero compensation or specify a separate capacity rule; do not divide by zero. All bond withdrawals must preserve outstanding obligations.

Use the official Arc USDC ERC-20 interface consistently: documented address `0x3600000000000000000000000000000000000000`, 6 decimals. Reverify against current Arc docs at setup. Native gas precision is different. Use integer token units, not floating-point money. Local mocks are allowed for tests, but the sponsor demo uses official testnet USDC.

Evidence fields: ID, guarantee/cohort ID, source ID, independence group, source/receipt timestamps, canonical payload hash, previous-entry hash, signature reference, schema version. A verdict binds chain ID, contract address, guarantee/cohort ID, outcome, reason, evidence root, policy version and expiry/nonce as appropriate.

Raw evidence stays private. Arkiv receives only public receipts and metadata. Create a new evidence entity for each entry; never overwrite earlier evidence. Pin the evidence root on Arc. Arkiv ownership and expiration do not by themselves prove immutability or completeness. Renew retention or preserve required evidence beyond all claim/appeal windows.

## 5. Stage-by-stage build

Do not begin the next feature stage until the current gate passes. Time estimates below are planning budgets; a failed gate means fixing or reducing scope, not calling it done.

### Stage 0 — Studio, access and repository foundation

**Budget:** 30–45 minutes. **Owner:** integration lead + contract owner. **Tool:** Arc Studio, then Codex for review.

- Open Studio and create MicroCover with only a deadline guarantee, USDC bond and escrow, provider admission and success settlement. Save the initial prompt and shareable project URL.
- Verify Studio deployment/test/app connection and the supported external-tool workflow. Confirm both repository remotes and contributor access.
- Obtain Arc testnet USDC; confirm token precision. Run one contract read and one small test transaction.
- Establish repository identity/history, ignore rules, environment example, run commands and frozen interfaces.
- Prove a minimal CRE CLI simulation can run; prove Arkiv credentials allow a tiny non-sensitive write/query. These are feasibility checks, not complete integrations.

**Gate:** runnable Studio project, real testnet connectivity, known repository lineage, no unresolved access blocker hidden in the plan.

**Example commits:** `chore: initialize Studio-generated application`; `docs: define MicroCover scope and shared interfaces`.

### Stage 1 — Bond and escrow with provider admission

**Budget:** 90–120 minutes. **Owner:** contract owner + buyer-flow owner. **Tools:** Studio; Codex review.

- Create and fund a guarantee; publish its terms and capacity from contract reads.
- Enroll buyer; hold guaranteed share in escrow and send only the non-guaranteed share to provider.
- Implement provider admission, reserved liabilities and refund-plus-compensation for a tiny bounded cohort.
- Use a minimal functional UI; visual polish waits.
- For the hackathon, explicitly cap batch size based on a tested bound. Larger cohorts are future work; do not loop over arbitrary thousands of recipients.

**Gate:** fresh local scenario and Arc testnet scenario prove creation, purchase and actual refund/compensation balances. Test over-capacity, unauthorized admission, duplicate enrollment where disallowed, repeated settlement, attempted early withdrawal and cross-guarantee accounting isolation.

**Commits:** `feat: add bonded guarantee creation`; `feat: escrow buyer payment and reserve compensation`; `feat: settle provider-admitted failure`; `test: protect liabilities and prevent duplicate payouts`.

**Publication:** promote this validated stage with original history. You now have the first working small-scale money pipeline.

### Stage 2 — Success lifecycle and usable core UI

**Budget:** 60–90 minutes. **Owner:** contract owner + frontend owner. **Tools:** Studio/Codex; Antigravity for UI.

- Implement the authorized success path, escrow release and time-gated bond unlock, consistent with the frozen policy.
- Add provider setup, buyer purchase/status and admission controls. Display pending, rejected, failed and confirmed transactions.
- Show bond, remaining capacity, payment/escrow split, deadlines, terms and explorer links before purchase.

**Gate:** both failure and success paths work from the app; ordinary users cannot issue verdicts or withdraw reserved funds; the success path cannot pay a failed guarantee later. Use short declared test deadlines on testnet, never pretend the chain clock was advanced.

**Commits:** `feat: release successful guarantees after lifecycle checks`; `feat: connect provider and buyer flows`; `fix: handle wallet rejection and wrong network`.

### Stage 3 — Scoped evidence and deterministic evaluation

**Budget:** 90–120 minutes. **Owner:** evidence owner + confirmation-flow owner. **Tool:** Codex; Antigravity for confirmation screens.

- Implement the selected scenario's evidence adapter. Bind signed confirmations to guarantee ID, parties, condition, deadline, nonce and domain. Verify signatures and reject replay. A ride adapter may use a pickup code; a concert adapter uses the agreed event-status sources. Keep secrets and personal evidence private.
- Append canonical hash-linked evidence and anchor a root on Arc through an authorized path.
- Evaluate against the frozen condition and evidence policy. Concert cancellation needs the specified event-status evidence; check-in alone is insufficient. For a ride example, define its observation interval and required attestations. Do not count provider-controlled timestamps or syndicated announcements as independent sources.
- A buyer claim starts evaluation. It cannot select a verdict, recipients or payout amount.
- Distinguish a healthy observation interval with a missing required confirmation from unavailable collection. API outages, stale/incomplete records or invalid signatures result in `UNCERTAIN`, not automatic failure or success.
- Store uncertain outcomes without releasing disputed funds or unlocking reserved bond during their uncertainty period. Reviewer panels remain deferred; implement the timeout fallback below in Stage 3.
- Unresolved timeout (PS item 10 / D10): fix and disclose a separate `uncertaintyTimeout` duration before purchase; its numeric value must be selected before implementation. On first onchain entry into `UNCERTAIN`, record `uncertainSince` and derive `uncertainReadyAt`. Repeated claims, retries or submissions must not reset or extend it. This is separate from the success-review window.
- If still unresolved at timeout eligibility, anyone may call unresolved finalization; time passing alone does not execute a transaction. Refund each beneficiary's full escrow, pay no compensation, and return the provider bond only after all escrow refunds are settled. Use bounded refund batches, retain unpaid refund liabilities and prevent duplicate payments. Close with a distinct `UNRESOLVED_REFUNDED` outcome. Established failure and finalized success cannot use this fallback. Authorized resolution and timeout finalization must obey explicit, tested state/boundary rules; terminal outcomes cannot be changed afterward.
- A temporary offchain feed outage does not itself create an irreversible onchain dispute. Disclose the fallback tradeoff: a delivered service may be refunded if the case remains unresolved. Update the policy/interfaces and preserve historical Phase 2 evidence; documentation changes do not update its deployed contract.
- If a general source score is included, compute it deterministically from approved independent groups and fixed weights; require sufficient coverage as well as the threshold. Missing sources cannot inflate confidence by disappearing from the denominator. A 90% score is a policy measure, not a calibrated probability.

**Gate:** evidence satisfying the selected promise succeeds; verified cancellation/breach fails; outages/insufficient proof stay uncertain during the uncertainty period; tampered/replayed evidence is rejected. The evidence trail and root match. Clearly label synthetic provider systems and staged inputs. Test late disputes, separate review/uncertainty windows, timeout boundaries, non-resetting deadlines, permissionless finalization, partial refund batches, premature bond withdrawal, duplicate settlement and resolution-versus-timeout races. An unresolved timeout refunds escrow only, returns bond after refunds and records `UNRESOLVED_REFUNDED`; established failure/finalized success remain unaffected.

**Commits:** `feat: record scoped guarantee evidence`; `feat: append and anchor evidence receipts`; `feat: evaluate deadline outcomes with uncertain fallback`.

### Stage 4 — CRE orchestration connected to the product

**Budget:** 90–120 minutes. **Owner:** CRE/integration owner. **Tool:** Codex.

- Build a workflow that reads the Arc guarantee, calls the evidence API and applies the same deterministic policy.
- Return an outcome bound to guarantee ID and evidence root. Connect it to the documented CRE report/receiver path and actual app status.
- Follow current official CRE consumer/forwarder instructions. Check authorized sender and workflow metadata supported by the chosen path, reject replay and wrong-domain reports. Do not invent a forwarder address.
- Run successful CLI simulations against the actual configured external API and chain, retaining reproducible commands, dependency versions and sanitized output.
- Demonstrate testnet settlement from the integrated workflow/report path if supported. A local simulation does not mean a decentralized CRE deployment is running continuously.
- If a demo operator relays a simulated result, use a clearly restricted demo adapter and disclose the operator's authority and report checks. Keep that result visibly separate from a deployed CRE network claim; confirm the meaningful integration with Chainlink mentors if the route is ambiguous.

**Gate:** a reproducible CRE simulation connects blockchain and external evidence, affects the actual MicroCover flow, and produces the same outcome as the evaluator. Preserve success/failure output and demonstrate uncertain handling. A disconnected sample workflow is not done.

**Commits:** `feat: orchestrate guarantee evaluation with CRE`; `feat: validate settlement reports`; `docs: reproduce CRE simulation and trust assumptions`.

### Stage 5 — Arkiv evidence/history read and write

**Budget:** 60–90 minutes. **Owner:** evidence-data owner + frontend owner. **Tools:** Codex; Antigravity for presentation.

- Write public evidence receipts, claim timeline records and linked Arc transaction references to Arkiv's current testnet using its SDK or JSON-RPC.
- Query by guarantee/cohort ID and receipt type. Expose writer, source, timestamp, integrity status and explorer links in the existing evidence/history screen.
- Keep payment state authoritative on Arc. Queue/retry indexing without duplicating receipts; an Arkiv outage must not turn into a payout verdict.
- Document entity ownership, queryable attributes and expiry. Ensure evidence retention covers the full configured lifecycle; expiry is not an excuse to lose appeal evidence.
- Compare returned receipt hashes with the anchored root; do not imply public records reveal private payloads.

**Gate:** a fresh app load displays evidence retrieved from Arkiv, with a real entity key and rerunnable query. It is more than a write-only log. Users gain publicly queryable receipts without dependence on MicroCover's database access permissions; do not promise every access dependency disappears.

**Commits:** `feat: publish public evidence receipts to Arkiv`; `feat: query guarantee history from Arkiv`; `docs: document Arkiv schema and integration feedback`.

### Stage 6 — Full integration and submission freeze

**Budget:** at least 2 hours reserved before submission. **Owner:** whole team; one integration lead. **Tools:** Codex for verification; Antigravity for browser walkthrough.

- Run the entire app from a clean session using documented setup and nonsecret configuration.
- Verify Arc Studio project opens for judges, website/backend are reachable, correct testnet addresses are deployed, and current code is publicly reproducible.
- Exercise failure, success and uncertain scenarios. Check payout balances, reserved liabilities, roots, CRE output and Arkiv history agree.
- Show the cohort rule with three test buyers sharing one explicitly labeled common-trigger fixture. An individual ride remains a cohort of one; do not group unrelated rides. The synthetic fixture tests existing cohort settlement without building a concert-data collection feature.
- Fix real browser/network/wallet errors; run contract checks and app build once more after material changes.
- Publish the validated commit history and a release tag such as `mvp-submission-v1`; record it in deployment documentation. Do not claim a tag exists until created.
- Record video, complete sponsor evidence and submit before the dashboard deadline. Do not wait until freeze time to create the submission draft.

**Gate:** an unfamiliar judge can run/try the app and inspect each claimed sponsor integration. List all mocked sources, operator powers, unresolved disputes and scalability limits.

**Commits:** `fix: resolve end-to-end integration failures`; `docs: finalize reproducible demo and sponsor evidence`.

## 6. Five-member ownership

Replace labels with real names; assignments are responsibilities, not claims that work has already been done.

| Member | Primary responsibility | Real contribution evidence |
|---|---|---|
| 1 — Integration lead | Studio setup, contracts, bond/escrow lifecycle | Contract changes, accounting tests, Studio/deployment evidence |
| 2 — Frontend owner | Provider/buyer UI and transaction states | UI changes, actual wallet/error fixes, browser QA |
| 3 — Evidence owner | Signatures, hash log, deterministic evaluator | API/evaluator implementation and adversarial cases |
| 4 — CRE owner | Workflow, receiver integration and reproducibility | CRE changes, simulation instructions and actual integration fixes |
| 5 — Arkiv/release owner | Arkiv queries, history integration, deployment and sponsor package | Adapter/query changes, schema/feedback and clean-start QA |

Members can pair at the single laptop or work on separate laptops after pulling the private history. Do not wait for a fixed time merely to add contributions: each person takes the next useful, bounded task. Keep documentation and QA contributions substantive and accurate.

## 7. Copy-paste instructions for agents

### First Arc Studio prompt

> Build the first stage of MicroCover, a testnet programmable guarantee app on Arc using official USDC. Use generic provider/beneficiary/cohort fields so rides and concerts share the protocol. Demonstrate a synthetic concert with three attendees first. Start only with provider guarantee creation and bond deposit, buyer purchase with a guaranteed share held in escrow, capacity enforced by reserved compensation, and provider-admitted failure paying escrow refund plus fixed compensation. Keep guarantees isolated, recipients and amounts derived from contract state, settlement idempotent and batch size explicitly bounded. Provide a minimal connected frontend, contract tests and deployment evidence. Do not implement AI, bridges, ENS, trading or a concert evidence collector. Preserve the shareable Studio project and explain how external source edits can be reconciled without leaving the required Studio workflow. Stop after this stage is demonstrable.

### Codex stage prompt

> Read MicroCover_Implementation_Plan.md, docs/interfaces.md and the current diff. Implement only Stage [N]. First state its scope, files and acceptance checks. Preserve existing contract/API schemas unless a necessary change is documented and coordinated. Use current official sponsor documentation; do not invent SDK APIs or network addresses. Write meaningful tests for fund accounting, authorization and evidence integrity where relevant. Run the checks, summarize actual results and limitations, and stop at the stage gate. Do not implement later stages, fabricate integration evidence, change Git authorship, commit, push, merge or deploy automatically. Keep Arc changes compatible with the supported Studio workflow. Record AI-assisted files and human review needs.

### Antigravity stage prompt

> Read MicroCover_Implementation_Plan.md and docs/interfaces.md. Work only on the UI tasks for Stage [N], starting from commit [SHA]. Use existing contract/API interfaces and Studio-connected app structure. Make provider terms, bond/capacity, buyer escrow, outcome and evidence status understandable. Include wallet/network/pending/rejection/error states and explorer links. Do not invent balances, fake transaction success or add product features. Verify the assigned flow in the browser and report the URL, actual checks, failures and changed files. Do not alter contracts, evaluator, CRE or Arkiv schemas, install paid services, commit, push, merge or deploy automatically. Stop after the assigned scope.

### Codex review/handoff prompt

> Review the diff for Stage [N] against its acceptance gate and frozen interfaces. Focus on accounting, authorization, replay/double payment, expiry, uncertainty and honest sponsor evidence. Report concrete blockers; fix only confirmed issues within this stage. Run applicable checks and give their exact results. Do not broaden scope or approve something merely because a previous agent says it passed. Update the contribution/AI-use notes with what actually happened. Leave a concise proposed commit message and next-stage handoff.

## 8. Sponsor evidence and submission checklist

### Arc

- Shareable Studio project URL and actual Studio usage shown in demo.
- Functional frontend/backend, architecture diagram, source repository and deployment evidence.
- Real USDC bond, escrow, compensation and release; identify the advanced-stablecoin-contract bounty explicitly.

### Chainlink

- Meaningful CRE workflow connecting a blockchain with an external API/system.
- Successful CLI simulation or CRE deployment, source/config and reproducible instructions.
- Explain exactly how the result enters MicroCover and the difference between simulation, demo relay and live network execution. A separate CCIP integration is not part of this selected track.

### Arkiv

- Current-testnet writes and a visible app feature reading Arkiv.
- README: writer wallet addresses, entity/query example, setup and actual AI use; public open-source licence.
- Files: `/arkiv/schema.md`, `/arkiv/friction.md`, `/arkiv/reach.md`, `/arkiv/why-arkiv.md`, `/arkiv/how-you-use-arkiv.md`.
- Each file should contain real observations, queries or evidence. Feedback, reach, why Arkiv and use each carry 25% in the listed judging rubric.

### ETHGlobal

- Official guide currently lists **7 November 2026, 09:00 IST**; verify dashboard/organizer updates immediately.
- Select **Finalist and Partner Prizes**; three partners maximum, multiple tracks per partner count once. Partner booths are optional for judging; submitted materials matter.
- Classic work begins during event. Preserve commits, disclose prior material and AI-assisted files; include specs/prompts when using spec-driven development. Human contributions must be meaningful.
- Prepare project description, public source, live demo, architecture, setup, limitations, sponsor explanations and feedback.
- Video: 2–4 minutes, at least 720p, human narration; no sped-up video, phone recording or AI voiceover. Finalist slot: four-minute demo plus three-minute Q&A.

Create the submission draft early and reconcile its exact dashboard fields; the plan is not a claim to have inspected the signed-in form.

## 9. Time control and fallback rules

The listed engineering budgets total roughly 10–14 hours including release preparation, before extended debugging. Recalculate against the live deadline and remaining team capacity. Preserve the final two hours for deploy/video/submission. Stop optional work at least three hours before the deadline.

If behind: simplify visual polish, keep one template, cap demo buyers and use disclosed deterministic input fixtures. Do not add 0G/ENS/Swarm or a second deployment chain. If Studio cannot meet its required flow, resolve with the sponsor rather than pretending a different workflow qualifies. If CRE or Arkiv cannot be meaningfully demonstrated, keep the core product working and remove the unsupported bounty claim; selecting fewer than three is allowed.

Never replace a failed source with invented evidence or a failed sponsor integration with a logo. Keep uncertain funds locked during the frozen uncertainty period; then, if still unresolved, use the Stage 3 refund-only timeout path. Clearly disclose prototype recovery limitations.

## 10. Demo sequence and final definition of done

1. Show Studio project, provider guarantee, terms, locked bond and capacity.
2. Buyer purchases; show real escrow transaction and balance change.
3. Show the selected promise's evidence, public receipts and Arc commitment; use generic provider/beneficiary terminology.
4. Run the CRE evaluation; explain whether simulated or deployed. Show a verified failure refund plus compensation and a small common-trigger cohort fixture.
5. Show pre-prepared success and uncertain examples. Success releases as permitted; uncertainty does not immediately pay or release. For an unresolved case whose separate timeout has expired, show transaction-triggered full escrow refunds, zero compensation and bond return after refunds, recorded as `UNRESOLVED_REFUNDED`.
6. Show Arkiv-backed history/query and public source/deployment links. State operator and evidence trust assumptions.

The build is done when the staged gates pass, both repositories retain truthful reachable history, every claimed sponsor has reproducible usage evidence, and the submission points to the exact tested code. This plan itself has not implemented, committed, deployed or submitted any product code.

## Official references

Requirements checked 6 November 2026. Recheck event announcements and technical setup at Stage 0.

- ETHGlobal rules/submission/judging: https://ethglobal.com/events/mumbai/info/details
- General rules: https://ethglobal.com/rules
- Arc prize requirements: https://ethglobal.com/events/mumbai/prizes/arc
- Chainlink prize requirements: https://ethglobal.com/events/mumbai/prizes/chainlink
- Arkiv prize requirements: https://ethglobal.com/events/mumbai/prizes/arkiv
- CRE Arc simulation support: https://docs.chain.link/changelog/cre-expands-testnet-support
- CRE network/forwarder documentation: https://docs.chain.link/cre/supported-networks
- Arc token addresses/precision: https://docs.arc.io/arc/references/contract-addresses
- Arkiv documentation/current network: https://docs.arkiv.network

Tool assignments, estimates, stages and accounting/verification choices above are implementation recommendations. Official links govern prize eligibility; successful integration must still be proven by the team.
