# MicroCover

A generic programmable-guarantee protocol for Arc Testnet, settled in official USDC. A provider posts a bond and beneficiaries lock escrow to join a bounded cohort. Phase 3 local source adds two authenticated, team-controlled synthetic feeds, deterministic evidence verdicts and bounded escrow-only refunds after a separate non-resetting uncertainty timeout. Success still requires its full review window. Provider admission is separate from evidence failure. CRE and Arkiv app integration are not started. Testnet only.

Built with [Arc Studio](https://studio.arc.io)

The app includes provider setup, public detail, evidence/anchor comparison, uncertainty/refund progress, stored lifecycle summary and actual session receipts. Phase 3 is **IN_PROGRESS**: local tests pass, but Studio reconciliation and human deployment/wallet checks remain. Arc Studio stopped its contract turn at the daily usage limit; subsequent local fixes/UI must be reconciled there before deployment. See [Phase 3 checkpoint](docs/phase3-checkpoint.md) and [manual steps](docs/phase3-manual.md).

The verified Phase 2 deployment `0xa1e621497040d845fe4dc952dc524b88231ade16` and its evidence are preserved. This Phase 3 UI blocks writes to that version2 address and does not replace it automatically. See [Phase 2 checkpoint](docs/phase2-checkpoint.md). The synthetic reference amounts remain bond15, escrow2 and compensation5 USDC each for three beneficiaries: total21, failure payout7 each. On success, escrow6 and bond15 go to the provider. Unresolved timeout refunds escrow2 each, compensation0, then bond15. Studio judge access remains unresolved.

## Tech stack

- React, Vite, TypeScript, Tailwind CSS
- wagmi, viem, ConnectKit
- Solidity 0.8.28 with Foundry and OpenZeppelin
- Arc Testnet (chain ID 5042002) and its official USDC

## Development

Prerequisites: [Bun](https://bun.sh) and [Foundry](https://book.getfoundry.sh).

```bash
bun install
bun run dev              # app on http://localhost:5173
bun run contracts:build  # compile contracts
bun run contracts:test   # unit, fuzz and invariant tests
bun run check            # lint and typecheck
```

### Environment variables

- `VITE_MICROCOVER_ADDRESS`: public address of a reviewed Phase 2 MicroCover deployment on Arc Testnet. Leave unset for preview-only mode. A Phase 1 address is unsupported and every funding/action control stays disabled. Restart the dev server after changing it.

### Deploy

The Phase 2 constructor takes three arguments: official Arc Testnet USDC `0x3600000000000000000000000000000000000000`, a human-controlled demo operator address, and a positive review window in seconds (suggested synthetic test: 120). Both authority and window are immutable. The verified Phase 2 address is `0xa1e621497040d845fe4dc952dc524b88231ade16`, configured with Account 1 as operator and 120 seconds. The old Phase 1 deployment cannot be upgraded.

- Follow the exact human Studio request in [the checkpoint](docs/phase2-checkpoint.md), after reviewing the immutable operator/window.
- Inside the Studio sandbox with Circle developer-controlled wallet credentials, the generated script offers:
  `bun run deploy:self MicroCover '["0x3600000000000000000000000000000000000000","<HUMAN_OPERATOR_ADDRESS>",120]' --chain ARC-TESTNET`

This script expects Studio filesystem paths and Circle credentials; it is not a verified local MetaMask deployment route. Follow the supported Studio workflow and human deployment request in the checkpoint. After deployment, set public `VITE_MICROCOVER_ADDRESS` in the relevant ignored environment file and restart Vite. Never put wallet keys or Circle secrets in browser variables or chat.

## Working with external tools

Keep the Arc Studio project as the source of truth and treat outside tools as reviewers and editors of the same files. See `AGENTS.md` for the full workflow.
