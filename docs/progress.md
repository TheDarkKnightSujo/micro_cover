# MicroCover verified progress

Local private checkout reconciled with the Studio export on 6 November 2026. The Studio app, contract, tests, manifests and Bun lockfile are present. Local checks and Studio sync evidence are recorded below. Human created root commit `91b692fd0a6192fc0ab031e6befa4389ae336faf` for the foundation; planning/evidence documentation remains uncommitted. No phase checkpoint is passed solely by these notes.

| Phase | Scope | Status | Human owner | Evidence / next action |
|---|---|---|---|---|
| Prerequisites | Reconcile instruction/plan files in actual private checkout | IN_PROGRESS | Assign | Local inventory recorded; human review and first commit pending |
| 0 | Studio, workspace and access | IN_PROGRESS | Current user | Arc/CRE/Arkiv smoke checks recorded; demo amounts selected; final human review/sharing limitation pending |
| 1 | Bond, escrow, admitted failure | NOT_STARTED | Assign | Complete Phase 0 first |
| 2 | Success/release and core UI | NOT_STARTED | Assign | Complete Phase 1 first |
| 3 | Evidence and deterministic verdict | NOT_STARTED | Assign | Complete Phase 2 first |
| 4 | CRE integration | NOT_STARTED | Assign | Complete Phase 3 first |
| 5 | Arkiv visible query | NOT_STARTED | Assign | Complete Phase 4 first |
| 6 | Deploy, verify and submit | NOT_STARTED | Assign | Prepare draft early; final gate after integrations |

Allowed statuses: NOT_STARTED, IN_PROGRESS, BLOCKED, PASSED. Only record PASSED with actual agent checks and required human verification.

## Current task

Phase 0 only. CRE and Arkiv smoke checks have run. The current user owns all implementation roles; publication rotation and snapshot tracking are recorded in contributions.md and releases.md. Resolve pending interface and sharing/checkpoint review items; do not start Phase 1.

Concrete checkpoint review is in `docs/phase0-review.md`. Under the user's delegated choice, Studio's 2 USDC escrow / 5 USDC compensation example was retained and conflicting demo notes reconciled. Observed Phase 0 ABI is recorded separately from future proposals in interfaces.md. Manual first-commit commands are in `docs/first-private-commits.md`.

Human staged the foundation. Cached whitespace check found five EOF blank lines; agent fixed those working files and synced them back to Studio with verified parity. Human must re-stage the five files and rerun `git diff --cached --check` before committing. No agent Git mutation performed.

Human then committed the corrected foundation: `91b692fd0a6192fc0ab031e6befa4389ae336faf` (`chore: import tested Arc Studio foundation`), author Abhiraj Kochale. Agent verified the commit and that only planning/evidence files remain untracked. No private push or public snapshot is recorded. Next action: human reviews and commits documentation as the second group.

## Phase 0 checkpoint record — 6 November 2026

- Starting commit: none; unborn `main`, `origin/main` not present locally.
- Local source: planning documents and `arkiv/` templates only; no nested `AGENTS.md`, runtime scripts, Studio source, or `.env.example` config names to verify.
- Local check: `eth_chainId` at the official Arc Testnet RPC returned `0x4cef52` (5042002). This proves read access only; no wallet, token transfer, or app connection was tested.
- Tool availability: Node, npm, and pnpm found; Bun, Forge, and CRE CLI absent. No package manager or contract framework is selected by the repo.
- Studio URL, share settings, export/import/source sync, test accounts, Arc transaction, CRE login/simulation, and Arkiv funded writer/query: pending human or generated-project setup.
- User-reported Studio output (6 November 2026): `contracts/MicroCover.sol`, `src/microcover/`, preview running, 33/33 tests, clean lint/type checks, contract not deployed. These are Studio claims; the generated source and logs are not in this checkout and have not been independently verified. Studio says settlement/release are absent, so a deployed version would lock deposited USDC.
- Export inspected at `C:\GitHub\MicroCover-Studio-Export`: contract, tests, React/Vite app, `package.json`, `bun.lock`, Foundry configuration and generated artifacts are present. A source snapshot was copied into this checkout without the export's `.env`, Studio `AGENTS.md`, or build outputs. Local Bun/Forge checks and Studio sharing remain unverified.
- Studio project URL supplied by the human: `https://studio.arc.io/app/c47658be-4463-462f-89b8-a0a418962a3d`. Ownership and judge access have not been verified. The CLI's public package documentation describes `--app <appId>` and diff-aware `pull`; authenticated login and a safe round trip for this project are still pending.
- Human authenticated Arc Studio CLI. CLI app inventory matched the supplied ID, and app-targeted `pull --dry-run` reported selected core files unchanged. No sync write or external-edit round trip was performed.
- Local Bun/Foundry setup completed. Forge build and 33/33 tests passed; Vite served HTTP 200; production build and app-source lint passed. Generated Windows check failures were reconciled in the same Studio project, pulled as seven reviewed tooling files, and `bun run check` then passed locally. The Studio deployment scripts remain unverified for local deployment; no contract was deployed. See `docs/runbook.md`.
- The private and public Git checkouts are distinct; the public checkout was read only.
- Human screenshot of the Studio Preview shows the expected synthetic 21 USDC example, Arc Testnet label and `Not deployed yet`. The preview is horizontally clipped at the left edge; visual layout needs later review. The Studio Share menu offers Netlify, Hugging Face or Vercel hosting deployment rather than a standalone read-only Studio share link. The Studio project URL is recorded, but judge/public app access remains pending. No hosting service was connected.
- Human wallet screenshot confirms the app displays the connected account and MetaMask explicitly shows `Network: Arc Testnet`, with 0 USDC. Wallet connection/network check recorded; faucet funding and an explorer transaction remain pending.
- Faucet funding verified on 6 November 2026: transaction `0xe038079ddeb2c9134094a20347dd89610d68dc412ffa040e4ea7f8e8a763324c` has successful RPC receipt (`0x1`) and a 20,000,000-base-unit USDC transfer to the connected account. Read-only `balanceOf` returned 20,000,000 (20 USDC). Explorer web fetch was unavailable; verification used official Arc Testnet RPC. No MicroCover deposit or deployment occurred.
- Human screenshot confirms signed-in access to Chainlink CRE Discover (`https://app.chain.link/cre/discover`). This verifies dashboard access only; CLI authentication, supported chains for the organization and simulation remain unverified.
- Human Arkiv Hub screenshot reported 10 tGLM delivered on Rabdi to the connected account. The full transaction hash was not supplied, so receipt/balance verification is pending. Human subsequently confirmed the Rabdi access key was generated and saved privately; its value was not requested or read.
- Subsequent human screenshot confirms Rabdi added to MetaMask, selected `Network: Arkiv Rabdi`, and wallet display of 10 tGLM. This records human network/balance verification; no entity write/query or full faucet receipt has been verified.
- CRE CLI 1.39.0 installed with the official Windows installer; installer reported release signature verification. `cre version`, `cre login --help`, and `cre whoami --help` succeeded. Human browser login is next; no CRE project or workflow was created.
- Human completed CRE CLI browser login; subsequent agent `whoami` returned exit 0. `workflow supported-chains --output json` returned exit 0 and included `arc-testnet` for this account, selector `3034092155422581607`, platform address `0x76c9cf548b4179F8901cda1f8623568b58215E62` and mock address `0x6E9EE680ef59ef64Aa8C7371279c27E496b5eDc1`. These are registry responses, not a deployed MicroCover receiver or successful workflow. Simulation remains unrun.
- Phase 0 CRE smoke simulation completed in `C:\Users\abhir\AppData\Local\Temp\microcover-phase0-cre-smoke`, outside the repository. Official `hello-world-ts` template with SDK 1.23.0 compiled and returned `Hello world!` (exit 0). Initial Windows child-process Bun lookup failure was resolved for the successful rerun by adding the actual Bun executable directory to the process PATH. No broadcast flag, wallet key, deployment or MicroCover integration was used; this does not prove CRE-to-Arc reporting.
- Phase 0 Arkiv smoke check: human signed a labelled synthetic forum entity in Arkiv Hub, key `0x948b565d57bc65cd125a5e8457dfc34ab1b020bb8fa88de20a2c5ffa37c0fccf`. Agent independently read it with `arkiv_getEntity`, then queried schema + board + owner with `arkiv_query`; exactly one match returned the same key and expected public values. Created block `0x43e3d`, expiry block `0x4e6fd`, mutable owner-controlled entity; summary in `docs/evidence/phase0-arkiv-smoke.json`. No access key or signing key was read. This is a Hub feasibility test, not Phase 5 MicroCover integration.
- User confirmed sole implementation on this laptop and supplied four GitHub accounts for publication. All implementation roles assigned to the current user; planned complete-phase publisher rotation and honest snapshot attribution recorded. No Git action was performed. Operator's Git author identity remains to be confirmed before the first human commit.
- Checkpoint status: IN_PROGRESS. Arc wallet/funding, CRE CLI smoke simulation and Arkiv sample write/read/query evidence recorded. Studio judge-sharing, interface decisions and human review of the final foundation remain pending. Complete the Phase 0 checkpoint review before requesting Phase 1. Do not deposit into or deploy the locked-funds foundation contract.

## Checkpoint entry — duplicate per phase

- Phase / date / actual author:
- Starting commit:
- Work implemented and changed files:
- Commands run and exact results:
- Manual checks and human reviewer:
- Studio/transaction/CRE/Arkiv evidence:
- Synthetic data and known limitations:
- Blockers and next action:
- Private source commit:
- Public commit/PR:
- Checkpoint status:
