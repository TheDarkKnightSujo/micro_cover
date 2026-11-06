# Phase 0 checkpoint review

Prepared from observed source and actual checks on 6 November 2026. No approval is assumed by this document.

## Verified technical foundation

- Existing Arc Studio project identified and CLI-authenticated; tooling changes made in that same project and pulled locally, selected files matched in dry run.
- Studio-generated React/Vite/Bun and Foundry toolchain retained. Local check command passes; Foundry build and 33 tests pass; production build passes with documented warnings.
- Human Preview and Arc wallet screenshots recorded; 20 USDC faucet transfer independently verified by RPC.
- CRE authenticated CLI and Hello World simulation verified outside the repo; tenant registry lists Arc Testnet. No MicroCover workflow/report integration claimed.
- Human signed labelled Arkiv Hub sample; public RPC read and owner/board/schema query verified. No Phase 5 app feature claimed.
- Separate private/public checkouts verified. No secrets copied from export. No deployment or Git commit performed.

## Selected demo amounts

| Term | Existing Studio example (recommended) | Older demo document |
|---|---|---|
| Beneficiaries | 3 separate test accounts | 3 separate test accounts |
| Escrow per beneficiary | 2 USDC | 20 USDC |
| Compensation per beneficiary | 5 USDC | 10 USDC |
| Provider bond | 15 USDC | 30 USDC |
| Total escrow | 6 USDC | 60 USDC |
| Total held when full | 21 USDC | 90 USDC |
| Future admitted-failure payout each | 7 USDC | 30 USDC |

Selected 6 November 2026 under the user's instruction to choose the better option: retain Studio's 2/5 example. The older values above are historical comparison only; demo-scenario.md and the phase runbook now use 2/5 consistently. No contract or app edit was required. Neither payout path exists in Phase 0.

## Remaining checkpoint record

- Demo amount decision is resolved. Human review/acceptance of the final foundation remains pending; delegated choice of demo amounts does not itself certify Phase 0.
- The Studio project URL is recorded; judge access remains unverified. Share currently offers external hosting. Preserve this as an explicit sharing limitation rather than publishing during Phase 0.
- Future success finality, evidence policy and CRE receiver/Arkiv receipt designs remain deferred to their requested phases; do not implement them to close Phase 0.
- Local Git has a configured author identity consistent with the operator name shown in the supplied screenshots. The human should verify it before running the commands in first-private-commits.md. The agent will not commit or push.

Status: IN_PROGRESS, not PASSED. Proposed commit groups after review: Studio foundation/safe configuration, then planning and verified checkpoint documentation. Next phase requires an explicit Phase 1 request.
