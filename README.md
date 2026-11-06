# MicroCover

A generic programmable-guarantee protocol for Arc Testnet, settled in official USDC. A provider posts a bond and beneficiaries lock escrow to join a bounded cohort. Phase 2 source adds a restricted demo operator, a dispute/review window, irreversible success finalization, escrow release and bond return. Provider-admitted failure remains available until success is finalized. Disputed/uncertain guarantees stay locked unless the provider concedes failure. Use testnet only; evidence verdicts, CRE and Arkiv app integration belong to later phases.

Built with [Arc Studio](https://studio.arc.io)

The app includes provider setup, public detail, beneficiary enrollment/status, stored lifecycle summary and actual session receipts. Phase 2 passed local checks and the human testnet/UI checkpoint on 6 November 2026. The verified deployment is `0xa1e621497040d845fe4dc952dc524b88231ade16`; both reference guarantees are closed with zero remaining contract funds: see [Phase 2 checkpoint](docs/phase2-checkpoint.md). The old address `0xff679b65c1d09e8d49fb18bb656f4509b33af9a0` is the historical Phase 1 deployment, not this source; the new UI blocks writes to it. The synthetic reference uses a 15 USDC bond, 2 USDC escrow and 5 USDC compensation each: total locked 21, failure payout 7 each; on finalized success, 6 escrow goes to the provider and the 15 bond becomes returnable. [Phase 1](docs/phase1-checkpoint.md) passed its human testnet checkpoint. Studio judge access remains unresolved.

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
