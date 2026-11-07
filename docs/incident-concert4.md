# Concert 4 availability investigation — 7 November 2026

Live URL: https://potatoes-parameter-mon-programmes.trycloudflare.com/?concert=4#concert

Six initial browser reloads encountered deployment-check unavailability. Captured POST https://rpc.testnet.arc.io/ eth_call (Multicall3 aggregate3, selector 0x82ad56cb) returned HTTP 429 with JSON-RPC code -32005 and `rate limit exceeded`. Console reported HTTP 429; a favicon 404 was unrelated. Metadata GET /api/evidence/v1/presentations/4 stayed HTTP 200 with the same record. During bad observations, /readyz returned HTTP 503 `Evidence chain check unavailable`. Direct getGuarantee/getState reads initially also returned `Request exceeds defined limit.`

Later successful direct reads showed matchesPresentation=true. Metadata and onchain cohort commitments both equal 0xd6571bef8af3ed15132c1b6a1657ee5c33d0b695b642fddc725ff5debc732ae4. Concert 4 has price 2 USDC, compensation 5 USDC, capacity/enrolled 2/2, bond 10 USDC, escrow 4 USDC, outcome FAILURE, failureOrigin=1 (provider admission), paidCount=0 and remainingOwed=14 USDC. No changed context was found.

Previously Event defined its guarantee snapshot only when every required read succeeded, then sent every failed verification to one generic message. An unavailable snapshot therefore looked like a metadata mismatch. This did not erase metadata. The exact reported Event message was not naturally recaptured in those six initial loads because throttling blocked the earlier capability probe; controlled browser RPC-429-after-success regression exercised that Event branch separately.

Evidence and gateway owning-terminal output was inspected: no new stdout/stderr lines. These processes do not have request access logging, so no server-side request transcript is claimed. Health reported CHAIN_OR_POLICY_UNAVAILABLE during the outage. Later readyz recovered to HTTP 200 while metadata remained HTTP 200. Ignored .local-hosting/concert4-*.json files retain network captures and read snapshots.

## Fix and validation

ConcertPage now distinguishes retryable API/RPC outages, missing records and actual mismatches. Failed reads disable actions and expose Retry event check. No stale financial snapshot enables actions; deployment guards remain intact. State-classification regression tests were added.

- bun run check: passed (lint and application TypeScript).
- bun test services/evidence/presentation.test.ts: 4 passed, 38 assertions.
- bun run vite build with VITE_EVIDENCE_API_URL=/: passed in 17.43s, existing third-party/chunk warnings.
- git diff --check: passed.
- Browser fixtures against the new public frontend: desktop organiser and 390px customer baseline, metadata 503/retry/recovery, RPC 429 after successful polling/recovery, and altered-venue mismatch blocking passed. No uncaught page errors. These wallet/RPC fixtures are not physical-device verification.
- Actual subsequent unmocked mobile-sized observations showed ARGITI SINGH, Failure confirmed, and 2 booked tickets. Metadata stayed HTTP 200; readyz recovered from 503 to 200.

Only frontend dist was rebuilt. Gateway serves dist directly; no service restart was needed. Collector PID 5560:8787, gateway PID 27916:10000 and tunnel PID 22928 were retained. No evidence data, configuration, contract, wallet or settlement changes were made by the investigation. No commit or push.

Physical organiser/customer devices still need a reload of the exact URL and confirmation of their account-specific payment status. Upstream RPC throttling can still recur: this patch fixes classification, not provider availability. Do not resume payout while a connection warning is present. Proposed commit: concert outage classification and regression coverage.

Final live pass: four desktop/mobile-sized reloads again hit the earlier capability outage, while metadata stayed HTTP 200. Readiness was 503 on three observations and 200 on the fourth. Reliable repeated live rendering is not established; upstream throttling remains active.

Publication authorization: user requested GitHub push and live activation of this fix. Before publication, verified that the tunnel JavaScript matches the local normal dist asset byte-for-byte and contains the new retryable outage message. Existing gateway/tunnel already serve the fix; no restart or contract deployment is required. Git push result and remote SHA are verified in the task response.


## Arc RPC failover and local funding preflight — 7 November 2026

Confirmed primary Arc RPC HTTP 429 in the earlier concert incident. Official docs list alternate testnet endpoints: https://docs.arc.io/arc/references/rpc-endpoints. Blockdaemon and dRPC each returned chain 5042002/protocolVersion 3; browser-origin requests to both returned HTTP 200 with the correct chain. QuickNode returned a limit error and was excluded. Added shared viem fallback (Blockdaemon, dRPC, Circle), 5-second per-provider timeout, no nested retries or ranking pings. Contract reverts remain terminal; no financial-response cache was introduced. Frontend and collector share this transport.

Before restarting the sole collector, created and integrity-checked SQLite online backup C:\MicroCover-Backups\rpc-failover-20261107-065258, preserving policy/key copies and environment fingerprints. Stopped prior collector through its owning terminal and restarted bun run evidence serve with existing ignored configuration/storage. Collector PID 35708 on 8787, gateway PID 27916 on 10000 retained, tunnel retained. /readyz and presentations/4 returned HTTP 200. Started local Vite on 127.0.0.1:5173 using the existing collector. An unmocked headless local concert-4 read displayed ARGITI SINGH with no deployment-outage warning or uncaught page errors.

Following the user's funding-limit screenshot, code inspection found CreateCard still delegated estimation to the wallet RPC. Added unsigned public-client simulation, gas estimation with the existing 20% margin helper, fresh deadline recheck, explicit account, and a synchronous duplicate-preparation lock before requesting wallet confirmation. No transaction was requested by the agent. The screenshot alone does not establish whether an earlier funding attempt broadcast; MetaMask Activity must be checked before human retry. Existing allowance is reused. Contract, data, policy and settlement were not changed.

Checks: bun run check passed; bun run evidence:check passed for transport changes; bun test services/evidence/arc-transport.test.ts services/evidence/submission.test.ts services/evidence/presentation.test.ts passed (9 tests, 50 assertions). Tests cover 429 failover, all-provider failure, terminal reverts, gas-estimate failure/zero, and expired preflight. Local Vite serves current source. Human wallet funding and physical-device verification remain pending; no full-release or Studio-reconciliation completion is claimed. Changes are uncommitted. Proposed commit: Arc RPC failover and funding preflight, with validation notes.


### Live activation and publication authorized — 7 November 2026

User requested deployment and GitHub push of the latest fix. Normal production build with VITE_EVIDENCE_API_URL=/ passed in 41.07s (existing third-party/chunk warnings). Existing gateway serves the new dist without restart; collector already uses the new transport. Actual tunnel https://potatoes-parameter-mon-programmes.trycloudflare.com serves /assets/index-CoV5F1jJ.js byte-for-byte matching the local build (SHA256 6ed008f386f6bf1809a5288b50bddb71b201d53631e457cae4356bbdbbdda8b2), including the funding preflight.

Four unmocked public loads (two desktop, two mobile-sized) all displayed concert 4, with no deployment/outage warning and HTTP 200 for both /readyz and presentations/4 on every observation. A headless browser funding fixture forced Blockdaemon HTTP 429 and verified dRPC failover, unsigned simulation/estimation, gas 120000 for estimate 100000, exactly one wallet request, and correct cancellation handling. The fixture wallet denies signing; no real wallet request or broadcast occurred. Tests do not establish future RPC uptime or physical-device wallet completion.

Application lint/TypeScript, service TypeScript, 9 focused tests/50 assertions, production build, live asset comparison and git whitespace checks passed. Existing contract/address, event/settlement state, database, policy, keys, gateway and tunnel configuration are preserved. Source and validation records are being published in two scoped commits under the existing genuine identity; final remote SHA and clean status are checked after push. Ignored environment, local QA scripts, dist and evidence storage are excluded. Studio reconciliation and human wallet completion remain pending. Next human action: reload the live page, check wallet Activity before any repeat funding, then personally review and sign only if no funding is already pending/confirmed.
