# MicroCover

A generic programmable-guarantee protocol on Arc Testnet, settled in official USDC. A provider posts a bond, beneficiaries lock escrow to join a bounded cohort, and each beneficiary is covered by a fixed compensation. This first pass is the foundation only: creating a guarantee, joining a cohort and reading state. Settlement is not built yet, so funds sent to the contract stay locked. Use testnet only.

Built with [Arc Studio](https://studio.arc.io)

The app shows a synthetic example (an event with three attendees) of the generic model, the network setup, and a live reader for guarantees once the contract is deployed.

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
- From your own wallet with the sandbox script (needs Circle credentials in `.env`):
  `bun run deploy:self MicroCover '["0x3600000000000000000000000000000000000000"]' --chain ARC-TESTNET`

After deploying, add the contract address to `.env` as `VITE_MICROCOVER_ADDRESS`.

## Working with external tools

Keep the Arc Studio project as the source of truth and treat outside tools as reviewers and editors of the same files. See `AGENTS.md` for the full workflow.
