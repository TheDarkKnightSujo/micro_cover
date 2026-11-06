# Architecture — proposed boundaries

No component below is claimed deployed or implemented. Reconcile with Studio output and update the actual architecture diagram during Phase 0/implementation.

| Component | Owns | Does not own |
|---|---|---|
| Studio-connected frontend | Provider/beneficiary workflows, chain reads, transaction/history feedback | Secrets, trusted browser-only verdicts |
| Arc guarantee contracts | Terms, membership, bond/escrow liabilities, settlement authorization and payouts | Truth of arbitrary webpages |
| Evidence service | Authenticated collection, private payloads, append receipts, deterministic evaluation | Arbitrary recipients/payout amounts |
| CRE workflow | Blockchain/API orchestration and supported report delivery | Unstated production deployment or automatic source independence |
| Arkiv adapter/read model | Public receipts/metadata and searchable visible history | Authoritative token balances or raw private evidence |

## Trust boundaries to document

- Provider admission authority is restricted to its guarantees.
- Early demo operator power is explicit; final CRE path follows actual supported verification.
- Evidence source independence is separate from transport/integrity.
- Hash commitments detect inconsistent history but cannot prove unreported events.
- Arkiv ownership/expiry and offchain collector/hosting availability remain dependencies.
- UNCERTAIN has no automatic fund release; document any restricted prototype recovery policy.

## Operational details pending

Actual framework, API paths, persistent store, background scheduling, ports, CORS, secrets, deployed URLs and source-sync method must be observed/chosen in Phase 0. Preserve source evidence and idempotent collection through restarts. Do not fabricate health checks or claim continuous monitoring on a sleeping host.
