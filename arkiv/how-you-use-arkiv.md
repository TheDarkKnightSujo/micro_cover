# Phase5 implementation — live proof pending

Complete in Phase 5 with:

- SDK/version/current network and actual writer address.
- Source file/function performing writes and query reads.
- One entity key and runnable query.
- UI route that displays queried records on a fresh load.
- Why filtered attributes, ownership and expiry suit guarantee history.
- Deduplication/retry and unavailable-service behavior.
- Evidence commitment check and privacy limits.

A planned schema or SDK dependency is not a completed integration.

Implemented6November2026: SDK1.0.1, Rabdi7794095. `services/evidence/arkiv-cli.ts` prepares public cutoff receipts and real Arc logs; `arkiv-outbox.ts` persists stable IDs outside Git. `src/microcover/arkivClient.ts` uses actual SDK executeBatch via MetaMask, writer/network checks, explicit click, retained pending attempt and immediate public hash capture. No server signer/write route.

`arkiv-reader.ts` sends live arkiv_query; GET /api/arkiv/v1/guarantees/2 proxies it, with optional type/keyset cursor. Access key is server-only. No silent fallback to local records. ArkivHistoryCard in the existing guarantee page distinguishes loading/empty/stale/unavailable/incomplete history and compares reconstructed receipt commitment with Arc. Payment authority stays on Arc.

Queries filter schema, creator, owner, consumer and guarantee. Stable IDs/durable queue, live dedup query and browser Web Lock protect ordinary retries; salts do not enforce global uniqueness, so use one writer browser/device. Proposed seven-day readonly attributes/permissionless extension and owner deletion/expiry limits are documented in schema.md.

Real writer signature, entity key, successful live query, duplicate retry and browser proof remain pending. First current query returnedHTTP429 anonymous quota exhaustion. Exact process and current check results: docs/phase5-manual.md. Phase0 Hub entity is separate feasibility evidence.

Phase5 access-key follow-up: user confirmed saved. Agent verified presence only, restarted the identified evidence service with unchanged external store/Phase3 consumer, and ran bun run arkiv query2: exit0, live Rabdi block0x48e2c, empty records. App-proxy history GET200, queue GET200/19 records; keyed SDK-read proxy eth_chainId returned7794095 and expected writer balance was positive. Sanitized proof docs/evidence/phase5-read-access.json. This resolves the earlier anonymous-query/access-key blocker; no live entity write, signature or browser proof exists yet. Next human action is Account1 explicit MetaMask publication for existing G2. Phase5 IN_PROGRESS; no commit/push/Studio parity claim.

Phase5 publication-size fix: human screenshot showed pre-wallet preparation failure. Unsigned SDK diagnostics reproduced HTTP413 for the uncompressed19-record eth_estimateGas request (483491 JSON bytes;241668 calldata bytes). Added explicit bodyEncoding=gzip-json-v1; only transport bytes are compressed, canonical JSON IDs/hashes/Arc anchors unchanged. Server bounded gunzip decoding(max60000bytes) rechecks the original canonical body hash. Exact browser CompressionStream path with all19records then passed actual Rabdi estimation:190883request bytes, estimate0x488048(4751432gas). Diagnostic was hard-stopped before every send method; no signature/broadcast. Latest/pending writer nonce both0x1. Proof docs/evidence/phase5-estimation.json. Evidence service restarted with updated decoder. App/service checks pass; full suite44passes/0failures/556assertions, including gzip roundtrip/hash preservation and live-reader wire decoding/spoof rejection. Human live publication/query/browser proof still pending; no checkpoint pass, Git push or Studio reconciliation claim.

Phase5 functional verification complete,6November2026: human InPrivate outage screenshot shows explicit Arkiv-history-unavailable warning and cached-record staleness disclosure, with cached19records preserved. Restored evidence service using unchanged persistent home and contract; live API returnedHTTP200/sourceARKIV_RABDI_LIVE_RPC/19entities. Publication/read/integrity, reload persistence, fresh no-wallet browser and outage UI now demonstrated; live-ID retry filter returned0writes/0transaction requests using a test-double wallet. Proofs phase5-publication.json, phase5-retry.json, phase5-browser-checks.json. No further wallet steps required. Phase5 functional work is complete; formal checkpoint remains IN_PROGRESS with inherited Studio reconciliation/judge-access and Phase4 human reproduction/review deferrals explicit, not silently PASSED. No new source change/tests rerun for this runtime/documentation update; git diff --check passed. Proposed commits: receipt adapter/schema/service/tests; visible history/publication UI; actual proofs/docs/Studio-helper corrections. No commits/pushes, public checkout edit, signing or Phase6 work. Next: checkpoint/deferral review and separately authorize the next phase.
