# MicroCover

A generic programmable-guarantee protocol for Arc Testnet, settled in official USDC. A provider posts a bond and beneficiaries lock escrow to join a bounded cohort. Phase 1 adds provider-admitted failure and fixed payouts derived from enrollment. Use testnet only. OPEN funds remain locked until the provider admits failure; success release, evidence verdicts, CRE and Arkiv app integration belong to later phases.

Built with [Arc Studio](https://studio.arc.io)

The app supports create/fund, enroll, provider failure admission and bounded payout continuation. Human initiated the Studio deployment to Arc Testnet at `0xff679b65c1d09e8d49fb18bb656f4509b33af9a0`; its runtime matches the reviewed local build. The synthetic three-beneficiary example uses a 15 USDC bond, 2 USDC escrow and 5 USDC compensation each: total locked 21, failure payout 7 each. Phase 1 passed its human testnet checkpoint: the reference guarantee and a partial-cohort withdrawal test are both closed with no funds remaining in the contract. Receipts, limits and proposed commit steps are in [the Phase 1 checkpoint](docs/phase1-checkpoint.md). Later phases and Studio judge access remain separate pending work.

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

- `VITE_MICROCOVER_ADDRESS`: address of the deployed MicroCover contract on Arc Testnet. Public value. Leave unset until you deploy; the app then shows "Not deployed yet". Restart the dev server after changing it.

### Deploy

The constructor takes one argument: the official Arc Testnet USDC address, `0x3600000000000000000000000000000000000000`.

- In Arc Studio, ask to deploy MicroCover to Arc Testnet.
- Inside the Studio sandbox with Circle developer-controlled wallet credentials, the generated script offers:
  `bun run deploy:self MicroCover '["0x3600000000000000000000000000000000000000"]' --chain ARC-TESTNET`

This script expects Studio filesystem paths and Circle credentials; it is not a verified local MetaMask deployment route. Follow the supported Studio workflow and human deployment request in the checkpoint. After deployment, set public `VITE_MICROCOVER_ADDRESS` in the relevant ignored environment file and restart Vite. Never put wallet keys or Circle secrets in browser variables or chat.

## Working with external tools

Keep the Arc Studio project as the source of truth and treat outside tools as reviewers and editors of the same files. See `AGENTS.md` for the full workflow.
