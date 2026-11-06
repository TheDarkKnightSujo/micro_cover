# MicroCover

Programmable guarantees on Arc Testnet: a provider locks a bond; beneficiaries lock escrow to join a bounded cohort. Failure pays escrow plus fixed compensation. Reviewed success releases escrow and unlocks the bond. Unresolved uncertainty refunds escrow only, with bond return after all refunds.

Built with [Arc Studio](https://studio.arc.io/app/c47658be-4463-462f-89b8-a0a418962a3d). Later local changes are not yet reconciled to Studio. This is a synthetic testnet prototype with a trusted operator and two authenticated feeds controlled by the same team.

## What works

- React/Vite/wagmi frontend and Solidity/Foundry contracts with integer USDC accounting.
- Persistent Bun/SQLite collector outside Git: poll10s, freshness60s, matching explicit statuses required; invalid/missing/stale/conflicting evidence stays uncertain.
- Domain-bound evidence commitments/verdicts, full success review, separate non-resetting uncertainty timeout and bounded payouts/refunds.
- Actual CRE CLI simulations reuse the evaluator; a human operator relayed a matching SUCCESS result. No deployed DON delivery or automatic settlement is claimed. Native receiver is tested but undeployed.
- Public Arkiv history queries reconstruct receipts, recompute outcomes and compare the snapshot with Arc. Hashes establish consistency, not truth or completeness.

## Verified public references

| Item | Value |
|---|---|
| Arc chain | 5042002 |
| Official USDC ERC-20 | `0x3600000000000000000000000000000000000000`, 6 decimals; native gas precision is separate |
| Current protocol v3 | [0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0](https://explorer.testnet.arc.io/address/0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0) |
| Operator / Arkiv writer | `0x1d39fc0e5293ab949d63217ffb375357adf3933f` |
| Review / separate uncertainty timeout | 120s / 120s, synthetic demo timings |
| Historical Phase2 | `0xa1e621497040d845fe4dc952dc524b88231ade16`, preserved; unsupported by current write UI |
| Arkiv Rabdi | 7794095 |
| Arkiv publication | [19 guarantee2 entities](https://rabdi.explorer.arkiv.network/tx/0xe2852a9ef807a9145ee983f04327eb8c6cc43422810d248e36ba1166185784fc) |
| Example entity | [public receipt](https://rabdi.explorer.arkiv.network/entity/0x03b0c9ebfd773ceb4c23d63b50048ea6b562d41c7d11955d66454c34591eab07) |

Guarantees1/2/3 demonstrate evidence failure, reviewed success and unresolved escrow-only refund. All are closed; see [final live audit](docs/evidence/phase6/live-audit.json). Original transaction proofs remain under docs/evidence. Arkiv retention is nominal7days/302400blocks. Read-only attributes do not prevent owner deletion/transfer or expiry. Permissionless extension is enabled. Money remains authoritative on Arc.

## Local Windows setup

Use Bun1.3.14 and existing WSL Foundry1.7.1; reuse this toolchain.

```powershell
bun install --frozen-lockfile
bun install --cwd workflows/cre --frozen-lockfile
```

Create ignored `.env` from `.env.example` only if it does not already exist. Configure:

```dotenv
VITE_MICROCOVER_ADDRESS=0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0
VITE_EVIDENCE_API_URL=http://127.0.0.1:8787
MICROCOVER_EVIDENCE_CONTRACT=0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0
MICROCOVER_EVIDENCE_HOME=C:\MicroCover-Evidence-Local
MICROCOVER_EVIDENCE_PORT=8787
ARKIV_ACCESS_KEY=<server-only key saved privately>
```

Preserve the existing external keys/SQLite store. Do not run init-demo over it or replace its policy. A clean checkout alone cannot recover private historical evidence. Public Arkiv history can be queried; collector/CRE historical reproduction requires secure transfer of the external store, or a separate new policy and fresh scenarios. Never commit keys/storage or expose the access key through VITE_ variables.

Terminal1: `bun run evidence serve`. Terminal2:

```powershell
bun run dev --host 127.0.0.1 --port 5173 --strictPort
```

Open http://127.0.0.1:5173/?guarantee=2. Public history needs no wallet. Financial actions require the correct human wallet on Arc; publication requires Account1 on Rabdi. Do not republish to read existing records.

## Checks

```powershell
bun run check
bun run evidence:check
bun run evidence:test
bun run --cwd workflows/cre check
wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge test'
bun run vite build
bun run scripts/phase6-audit.ts
bun run arkiv query 2
```

Substitute your WSL checkout path if different. The Windows contracts:test script requires Forge on Windows PATH; this laptop uses WSL. The final audit is read-only and writes a proof. [CRE reproduction/trust](docs/phase4-manual.md) distinguishes CLI simulation, human relay and network deployment.

The separate local deployment helper is outside the main app entry. Current constructor has four arguments: USDC, operator, review seconds, uncertainty timeout seconds. Phase2 three-argument commands are historical. Do not redeploy the verified contract. [Human deployment route](docs/phase3-local-page.md).

## Release status

Phase5 live write/query, reload, no-wallet InPrivate and outage-display checks are recorded. Phase6 is final local verification, not completed publication. Public hosting/persistent service, Studio reconciliation/judge access, teammate reproduction, licence choice, public-source promotion, video and dashboard submission remain pending. Localhost works only on this laptop; a frontend-only static host cannot expose the loopback API.

See [architecture](docs/architecture.md), [release checkpoint](docs/phase6-checkpoint.md), [demo script](docs/demo-script.md), [AI use](docs/ai-usage.md), [actual contributions](docs/contributions.md), and [Arkiv schema/query](arkiv/schema.md). Original-code licence selection is pending; dependencies retain their own licences/notices.


Render hosting preparation and human dashboard/storage steps: [docs/render-deployment.md](docs/render-deployment.md). Prepared locally; hosted readiness still pending.
