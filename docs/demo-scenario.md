# Consistent small demo and evidence policy

## Reference amounts

Selected on 6 November 2026 under the user's delegated choice: retain the existing Studio example. Synthetic concert organizer, three test attendee accounts. Price 2 test USDC each, fully escrowed; compensation 5 each; provider bond 15; capacity 3. After all purchases: escrow 6 + bond 15 = 21 locked for the reference scenario. Future failure settlement pays 7 per attendee (2 refund + 5 compensation). Future success releases escrow 6 and makes bond 15 withdrawable only when its finality/window rules permit. These settlement paths do not exist in the Phase 0 contract. Keep account gas budgets separate.

Use generic provider/beneficiary/cohort contract fields. A concert and a ride reuse the financial engine but have different evidence adapters. Do not group unrelated rides into one trigger.

## Phase order

1. Provider admission proves money movement without claiming independent evidence.
2. Separate success fixture proves authorized release timing.
3. Labeled synthetic event-status feeds prove deterministic evaluation/integrity.
4. CRE orchestrates the same real pipeline.
5. Arkiv supplies the visible evidence/history query.

## Before auto-evaluation is implemented

Freeze condition, source groups, weights, freshness, minimum coverage, cutoff and threshold in decisions.md. Two feeds hosted by the team remain synthetic sources, not independent production reporting. Attendee check-in does not prove event occurrence; no check-in does not prove cancellation.

## Three fresh guarantees

- FAILURE: provider admission first, then evidence-based cancellation example when supported.
- SUCCESS: approved evidence and finality conditions met before release.
- UNCERTAIN: unavailable/stale/insufficient sources; locked funds remain locked.

Record guarantee IDs, public test addresses, transactions, evidence roots, CRE runs and Arkiv entity keys when created. Never reset an already settled guarantee or use an UI-only fake transfer. Use short disclosed demo windows, not a pretend testnet time advance.

## Synthetic/live labels

Each demo must state what is staged (concert, provider system, source fixtures) and what is real (deployed contract, testnet funds/transfers, anchored root, actual CRE simulation, Arkiv write/query). Until those integrations run, mark them not implemented.
