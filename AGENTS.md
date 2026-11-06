# MicroCover — instructions for coding agents

## Authority and scope

Follow the user's current instructions first. These instructions govern this repository and its subdirectories unless a more specific instruction applies. Read existing nested AGENTS.md files before modifying their area. This file records the team's intended workflow; it does not grant access to accounts or external services.

MicroCover is a generic programmable-guarantee protocol for organizations and their customers: provider bond + beneficiary escrow + fixed compensation + objective evidence + cohort settlement. Concerts and rides are examples. Use provider, beneficiary, guarantee, cohort, condition, evidencePolicy, bond and escrow in the core model. Do not build the core around driver/rider fields.

## Read before work

1. MicroCover_Implementation_Plan.md — product and sponsor boundaries.
2. MicroCover_Phase_By_Phase_Runbook.md — current phase execution.
3. docs/progress.md — actual verified state and next task.
4. docs/interfaces.md and docs/decisions.md — shared contract and pending choices.
5. docs/runbook.md and docs/sponsor-checklist.md — verified commands and integration evidence.

If a listed file is absent, report it and create only the minimum scaffold required for the current task. Never interpret a checkbox or example as evidence that implementation exists.

## First task in this repository

Inspect existing files, Git status/history, package manifests, lockfiles and Studio outputs. Preserve existing work. Reconcile this documentation with the actual repository. Identify the current phase and blockers. If no scaffold exists, do not create a competing app before Arc Studio initialization. Do not start Phase 1 merely because prerequisite documents are present.

## Incremental implementation

Implement only the phase requested. State the bounded scope, then edit and run local checks without repeated permission requests. Stop at the phase checkpoint. Fix failures within that phase before adding features. Reuse the working Studio-generated toolchain; choose dependencies only when required. Do not refactor unrelated code or change shared interfaces without recording the reason and coordinating consumers.

No AI review, ENS, bridges, swaps, investor pools, yield, token launches, Swarm or second chain in the core pipeline. Do not add features to chase extra bounties.

## Sponsor workflow

- Arc: initialize and keep the required contract/app work in the supported Arc Studio workflow. Record the shareable project URL and confirmed source-sync method. Local edits alone do not prove Studio eligibility.
- Chainlink: use CRE for the selected workflow bounty. Verify current docs, network support, report receiver and simulation commands. Do not invent SDK APIs, addresses or successful logs. Clearly distinguish CLI simulation, demo relay and deployed CRE network.
- Arkiv: write public receipts and query them in a visible app feature. Keep money authoritative on Arc. Document owner powers, expiry and integrity limits. A write-only log is insufficient.

## Financial and evidence rules

Use integer token units. Confirm official token address/decimals against current docs; never mix native gas precision and ERC-20 units. Reserve compensation for every accepted liability; isolate guarantees. Derive payout recipients/amounts from enrolled state and frozen terms. Prevent duplicate settlement, unauthorized verdicts, premature withdrawal and unbounded payout loops.

One complaint starts evaluation; it is not proof. Missing/unavailable evidence is uncertain unless a narrowly specified absence condition is positively established. Do not infer concert cancellation from missing check-ins. Provider-controlled observations are not independent merely because they have different timestamps. Keep uncertain/disputed funds locked under the documented prototype policy.

Keep raw/private evidence off public storage. Hash canonical payloads, append new receipts and anchor commitments. Hashing proves integrity against a commitment, not truth or complete collection. Reject replay/wrong-domain reports. Mark fixtures and simulated feeds clearly.

## Credentials and external actions

Do not request private keys in chat or print secrets. Use local/host environment settings; commit only placeholder examples after the actual config names are known. Never embed secrets in NEXT_PUBLIC_/VITE_ or similar browser-exposed variables.

The latest user-supplied repository instructions reserve deployment, commit and publication steps for humans. Do not automatically commit, push, merge, tag, publish, deploy or sign wallet transactions. Prepare the exact commands instead. This supersedes the earlier local-commit authorization recorded in historical notes. Local inspection, implementation and necessary tests are authorized within the requested phase. Do not modify the separate public checkout as a side effect. Preserve unrelated changes and inspect proposed commit contents.

Specific release authorization, 6 November 2026: the user explicitly requested that the agent execute all commits/pushes and the public snapshot export in docs/first-public-commit.md for the first completed Phase 1 release. This authorizes those private/public Git actions and the named public checkout update for that release only, using the existing genuine author identity. It does not authorize later releases, force pushes, history rewriting, deployment or wallet signing. Inspect staged contents, exclude secrets, verify remote SHAs and record actual release results.

## Git and contributions

Use coherent task commits proposed for the actual author. Preserve development history when transferring to the public repository. Do not reset authors, backdate, force-push or copy .git between folders. A publisher is not automatically an author. Record genuine human work and AI-assisted files. Do not manufacture participation or feedback.

## Validation and reporting

Use existing scripts; record exact commands and actual results in docs/runbook.md. Add meaningful tests for accounting, authorization, state transitions, evidence integrity and report replay. Do not add tests that merely repeat implementation or claim browser checks not performed. A failed command stays failed until rerun successfully; a missing credential is a blocker.

At completion update docs/progress.md, docs/ai-usage.md and relevant checklists. Report: changed files, checks/results, manual actions, limitations, checkpoint status, proposed commit groups and next action. No phase is PASSED until its required human verification is recorded.
