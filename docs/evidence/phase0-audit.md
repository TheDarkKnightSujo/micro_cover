# Phase 0 agent audit — 6 November 2026

Scope: existing foundation and setup only. No Phase 1 settlement implementation, deployment, wallet signing or public publication.

## Checks performed

| Check | Exact command or method | Actual result |
|---|---|---|
| Working state and remote | `git status --short --branch`; `git ls-remote --heads origin main` | Initial tree clean; local ahead one workflow commit; remote main at `3d01d41c209132d32b9b542fe087db5fb1c156c1` |
| Studio parity | `arc-studio pull --app c47658be-4463-462f-89b8-a0a418962a3d --out C:\GitHub\MicroCover-Private --paths 'src/**' 'contracts/MicroCover.sol' 'contracts/test/**' 'package.json' 'bun.lock' 'scripts/**' 'index.html' 'postcss.config.js' 'tailwind.config.js' 'tsconfig.json' --dry-run` | Every selected file unchanged, zero writes |
| Local checks | `bun run check` | Exit 0; lint and typecheck passed; repeated after wallet-config fix, passed |
| Contract tests | `wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge test'` | Exit 0; 33 passed, zero failed/skipped; unit, fuzz and two 128,000-call invariants |
| Production build | `bunx vite build` | Exit 0 before and after wallet-config fix; third-party annotation/large-chunk warnings remain |
| Browser render | `bun run dev --host 127.0.0.1`; browser at `http://127.0.0.1:5173/` | Correct 21/15/6/5 example and undeployed state. Screenshot showed vertical cards; earlier Studio clipping not reproduced locally |
| Post-fix browser smoke | `bunx vite preview --host 127.0.0.1`; browser at `http://127.0.0.1:4173/` | App rendered; Connect opened wallet-choice dialog. No extension wallet connected or transaction signed by agent |
| Token units | `eth_call` decimals selector `0x313ce567` on official Arc USDC `0x3600000000000000000000000000000000000000`, at `https://rpc.testnet.arc.io` | Returned 6 |
| Arkiv creation receipt | `eth_getTransactionReceipt` at public Rabdi RPC for `0xb74fc5ae65d98a6bc416e913eb7c341082aac43d4c3183acad0fb88b90078ebf` | Status `0x1`, block `0x43e3d`, from the human wallet; entity explorer links this creation transaction |
| Credential hygiene | `git ls-files -- .env '.env.*' .npmrc`; `git grep -I -l -E 'BEGIN ([A-Z ]+)?PRIVATE KEY\|sk_live_[A-Za-z0-9]+\|ghp_[A-Za-z0-9]{36}' HEAD` | Only `.env.example` tracked; zero matches from this limited high-signal pattern check. Not proof of absence of all secrets |

All temporary dev/preview servers were stopped after inspection. Native Edge accessibility read exposed the Arkiv entity/creation transaction, but native screenshots/input geometry were inconsistent, so they were not used to claim a Studio visual pass. Separate in-app browser checks supplied the reliable local render and anonymous-access observations.

## Setup correction

`src/config.ts` included Ethereum mainnet solely for ENS name lookup. Removed that import, chain and transport to follow the accepted Arc-only/no-ENS scope. Uploaded the exact file into the existing Studio project with `--file src/config.ts:src/config.ts` using `docs/prompts/phase0-arc-wallet-sync.txt`; CLI exit 0. Targeted Studio pull dry run reported the file unchanged. No contract or financial API changed.

## Current official requirements

- [Arc selected track](https://ethglobal.com/events/mumbai/prizes/arc): Studio build origin, contract writing/testing/deployment and app connection in Studio, plus a Studio project URL judges can open. Deployment/app-money flow are later phase work. Hosting an app does not itself prove Studio project access.
- [CRE selected track](https://ethglobal.com/events/mumbai/prizes/chainlink): project-used workflow connecting a blockchain and external data; CLI simulation is sufficient for the track. Phase 0 Hello World is feasibility only.
- [Arkiv selected track](https://ethglobal.com/events/mumbai/prizes/arkiv): real current-network writes and a user feature/query reading the data. Hub sample is feasibility only; Phase 5 feature remains absent.

## Manual access check still needed

Opening `https://studio.arc.io/app/c47658be-4463-462f-89b8-a0a418962a3d` in a separate unauthenticated browser redirected to `https://studio.arc.io/` with Sign in/Sign up. This proves anonymous access is unavailable; it does not establish whether another signed-in account has project access.

Human subsequently supplied screenshots from a different signed-in teammate account at the exact URL: the title is `New Project`, chat/Recents are empty, and opening Code shows an empty Files pane/editor. MicroCover source was not visible. This independent test failed to demonstrate project access; screenshots do not identify the underlying service cause. No prompts were submitted on that account. Official-site search and installed CLI 1.2.2 help did not reveal a confirmed project permission/share command. Next action: obtain Arc staff's supported judge-access method using `docs/arc-sharing-question.md`. Do not share credentials or substitute hosting for project access.

Status: technical setup checks complete; overall Phase 0 remains BLOCKED on the unresolved Studio-sharing route after the failed independent-account test. Existing human wallet/network/faucet/Arkiv signing screenshots supply the manual operational evidence already performed. No repeat blanket document approval is needed for the agent's code audit. Phase 1 has not started.

Subsequent workflow decision: user authorized continuing into Phase 1 with sharing retained as an unresolved submission requirement (D17). The initial blocked audit status above is historical; current progress is tracked in progress.md. No Phase 0 pass or judge access is implied by this exception.
