# Concert demo handoff — 7 November 2026

Implementation is local in C:\GitHub\micro_cover. It has NOT been activated on the existing tunnel, committed, pushed or reconciled into Studio. C:\GitHub\MicroCover-Private remains unchanged. Do not confuse the isolated QA preview with the shared live demo.

## Supported promise and capability boundary

The contract, constructor, deployed address, ABI, evaluator, feed keys, fixed policy and historical guarantees are unchanged. The deployed v3 supports bond funding, exact USDC approval/enrollment, capacity, evidence failure without provider admission, reviewed success and unresolved escrow-only refunds. It does not evaluate a measured delay threshold or real concert cancellation. The only accepted terms hash still resolves to PRESET_CONDITION_TEXT. The concert UI says so explicitly; its fixed synthetic policy requires matching explicit FULFILLED/CANCELLED statuses from the existing two same-team feeds. No editable delay policy was added. A precise real start-time/delay policy remains unsupported and needs a separately reviewed future evaluator/policy change.

Name and venue are public presentation context. The chosen scheduled time equals the actual onchain join deadline and synthetic evidence cutoff. The organiser must choose at least two minutes ahead (within seven days), allowing enough time to fund and enroll customers. Use 15–20 minutes for a relaxed video capture. The actual contract fixes success review and uncertainty timeout at separate 120-second windows. The first onchain uncertainty deadline never resets. No missing poll automatically opens a dispute.

## Metadata commitment and persistence

The organiser creation transaction commits the canonical public presentation hash in cohortId. This binds schema, Arc chain, consumer, provider, name, venue, schedule, price in integer USDC units, compensation, capacity, original termsHash and frozen policyHash. The API associates that commitment with the confirmed guarantee ID by reading the deployed contract. The transaction's provider authorization binds the context; no additional signature, key or signing service is introduced. A previous generic random cohort ID cannot simply be renamed as a concert.

POST /api/evidence/v1/presentations accepts at most 8192 bytes, verifies onchain provider/terms/policy/cohort/price/capacity/deadline, and stores an immutable record in the existing external SQLite settings table. Anyone may republish identical already committed public context; they cannot substitute a different context. GET /api/evidence/v1/presentations/:id returns the record. GET /api/evidence/v1/presentations?provider=0x... returns up to 100 stored events for that provider. This is a store listing, not a claim to discover every guarantee globally. Browser independently checks the record against its current onchain reads before enabling purchase. Service outages and unknown terms fail closed, never becoming concert outcomes.

The local draft is crash/retry recovery only. Event details become cross-browser readable after a successful API save. If funding confirms but saving fails, retry saving, never repeat funding. If navigation/reload interrupts a wallet request, inspect MetaMask/activity before another attempt. The organiser view can recover a saved draft using its actual confirmed guarantee ID. This ID recovery tool is not part of customer checkout. If the creation was confirmed on a different device and its draft was not saved/shared, recover the original exact metadata rather than inventing it.

## Activate only when you are ready (human steps; not performed)

1. Review the local changes. Preserve/backup the existing external evidence directory and original policy/key files. Never initialize a new policy or run a second collector against the live database.
2. In C:\GitHub\micro_cover run `bun run check`, `bun run evidence:check`, and `bun test services/evidence services/hosting`.
3. When intentionally activating the frontend, run `$env:VITE_EVIDENCE_API_URL='/'; bun run vite build`. This writes the normal live dist, unlike the isolated candidate build used during implementation.
4. Stop the existing evidence process using Ctrl+C in its owning terminal. Run `bun run evidence serve` from the same checkout with the existing ignored environment. It must reuse C:\MicroCover-Evidence-Local and the existing contract, policy and keys.
5. Restart the owning gateway terminal with `bun run services/hosting/start-local.ts`. Keep the current Cloudflare origin file/tunnel; do not launch duplicate collector/gateway processes. If the tunnel ended, follow docs/laptop-tunnel.md for its new URL and exact origin.
6. Open the actual tunnel URL followed by `/#concert`. Confirm /readyz is healthy and the page clearly shows the synthetic policy. The old tunnel still serves the earlier UI until these activation steps are done.

## One fresh human demo / video walkthrough

Organiser: connect a test account on Arc Testnet, choose Organiser, enter a public synthetic concert name/venue/time, continue, set 2 USDC ticket / 5 USDC compensation / 3 tickets. Review 15 USDC money backing the promise. Approve exactly 15 USDC, then separately fund ticket protection in MetaMask. Wait for confirmation and shared-details save. Copy the customer link (`?concert=<confirmed id>#concert`). Do not reuse historical guarantees 1–3 as concerts.

Customer: open that exact link on another browser/phone, connect another test account, choose Customer, check the actual committed details/price/deadline. Protection is included, total 2 test USDC with no extra premium. Approve exactly 2 USDC, then buy the protected ticket. Confirm “You’re booked” only after onchain membership. Reload/reopen on another browser with that wallet and verify the same booking; no duplicate purchase is allowed. Provider cannot buy its own protection. A wallet rejection must not show a successful booking.

Presenter: use the separate presenter/settlement workspace for this exact guarantee. Keep the existing evidence collector running before the scheduled cutoff. Set fixture feeds only via the supported existing local evidence commands and record what you actually set. The normal organiser/customer view cannot make a concert fail. A SUCCESS evidence verdict starts the full review before finalization; release ticket escrow then return backing funds. A FAILURE verdict permits full ticket refund plus compensation via bounded settlement. UNCERTAIN requires an explicit onchain entry, the non-resetting timeout, finalization, bounded escrow refunds without compensation, then backing-fund return. These are alternative outcomes requiring distinct fresh guarantees; do not repeat completed scenarios unnecessarily or claim one run proved every branch.

Customer status distinguishes potential payout from eligibility and actual receipt. “Refund + compensation received” requires that customer's paid flag; unresolved receipt requires its enrollment index below refundedCount. Unavailable Arkiv history never changes the Arc outcome.

## Actual checks and remaining checks

- `bun run check`: passed, lint and application TypeScript clean.
- `bun run evidence:check`: passed.
- `bun test services/evidence services/hosting`: 49 passed, 0 failed, 621 assertions.
- Candidate production build: VITE_EVIDENCE_API_URL=/ with `bun run vite build --outDir .local-hosting/concert-dist`; passed, existing dependency PURE annotations and large-bundle warnings remain.
- Isolated headless Microsoft Edge at 127.0.0.1:10002: disconnected no-selection, exact cross-session shared metadata, 390px no horizontal overflow, generic platform and explicit historical runs, fixture wallet role selection, returning membership/duplicate prevention, failure-ready versus paid, success/no payout, unresolved escrow-only refund, account/network switching, empty organiser listing, rejected approval leaving purchase disabled, and unavailable metadata blocking purchase passed; zero uncaught page exceptions on the passing run.
- Browser RPC/event/wallet data were test doubles, never real MetaMask signing. Metadata persistence and tamper/domain/old-cohort rejection used a temporary external SQLite database in unit tests. No claim is made that a real new concert transaction or cross-device new concert purchase occurred.
- Initial checks caught a test cleanup naming mismatch, fixture typing/syntax errors and QA harness routing/locator problems. Corrected and rerun; those failed attempts are not counted as passes. QA launcher initially had an incorrect relative import, then started successfully.
- Contract tests were not rerun: contracts, ABI and evaluator are unchanged; existing service regression suite passed.

Checkpoint: implementation checked; NOT PASSED for release. Outstanding: intentional activation, fresh human funding/enrollment/rejection/reload on two devices, presenter outcome walkthrough, Studio reconciliation, and previously recorded Phase 6 review/licence/submission gates. No deployment, Git action or wallet signing occurred.

Proposed commits only: (1) generic committed presentation storage/API + integrity tests; (2) concert story UI and safe wallet/session handling; (3) handoff, interfaces, decisions and actual validation records. Existing unrelated tunnel/UI work must be reviewed separately before staging.


## Concert activation — 7 November 2026 (authorized)

Activated the already checked normal `dist` in C:\GitHub\micro_cover. Before stopping services, created a consistent SQLite online backup plus original policy/key copies at `C:\MicroCover-Backups\concert-activation-20261107-050219`; backup integrity_check passed. Original policy/key files and ignored `.env` fingerprints remained unchanged after restart; active SQLite integrity_check passed. No initialization, contract/address changes or additional collector were used.

Stopped only prior gateway PID 29552 and evidence PID 34840 with Ctrl+C in their owning terminals. Started `bun run evidence serve` (collector PID 5560 on 127.0.0.1:8787; command wrapper PID 1844) and `bun run services/hosting/start-local.ts` (PID 27916 on 127.0.0.1:10000). Kept existing cloudflared PID 22928 and exact origin settings unchanged. Local and public `/readyz` returned HTTP 200 `ready`.

Verified the actual public URL https://potatoes-parameter-mon-programmes.trycloudflare.com/#concert in headless Microsoft Edge: HTTP 200, concert entry, same-team synthetic-policy disclosure and MicroCover platform navigation to generic `/#home` present; zero uncaught page errors. Initial browser assertion used an incorrect link label (“generic platform”); corrected it to the actual “MicroCover platform” label and reran successfully. No wallet was connected, concert created, signature requested, commit or push performed. Existing live build was reused; checks/build were not unnecessarily repeated.

Activation is complete, but release checkpoint remains pending fresh human funding/purchase and Studio reconciliation plus previously recorded human release gates. Next action: one fresh organiser/customer demo following docs/concert-demo.md. Proposed commit groups remain storage/API, concert UI/guards, and documentation; none created.


## Authorized Git publication — 7 November 2026

User explicitly requested a clean push of the checked, activated concert demo to the existing public micro_cover origin. Reviewed source/API/UI/tunnel changes and preserved the genuine configured Git identity. Created 01a96aa (verified context API/storage and guarded tunnel launcher) and cb34f79 (concert and generic UI/session guards). Documentation is grouped in the third commit. No dependencies or contracts changed. Prior checks remain the applicable validation: application/service TypeScript and lint passed; 49 service/hosting tests with 621 assertions passed; candidate and normal production builds passed with recorded dependency/chunk warnings; actual tunnel browser activation checks passed. Staged path/credential-marker scans and diff whitespace checks passed. Ignored environment, external database/key/policy data, backups, dist and local hosting state are excluded. Normal push and remote-SHA verification follow commit creation; their actual result is reported in the task response. No wallet action or further deployment is authorized by this Git request. Release checkpoint remains pending the documented human and Studio gates.
