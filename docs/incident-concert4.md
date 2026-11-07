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
