# AI assistance disclosure

This log must reflect actual work. Agent suggestions are not independent validation. Humans remain responsible for the product decisions, review, integration and demo. Add file paths and real checks after each phase.

## Preparation performed in this ChatGPT session

- Tool: ChatGPT coding/planning assistant.
- Work: drafted the full implementation plan, phase runbook and this prerequisite documentation bundle from the user's scope and reviewed sponsor requirements.
- Generated/assisted files: both plan files, root AGENTS.md, SETUP_CHECKLIST.md and docs/arkiv documentation templates in this bundle.
- Product implementation/tests/deployment: none performed by creating these documents.
- Human validation: pending team review and reconciliation against the real private checkout.

## Implementation entries — complete as work happens

| Date/phase | Actual human | Tool/model used | Files/behavior assisted | Human decisions/review | Actual checks/result | Commit |
|---|---|---|---|---|---|---|
| Pending | Pending | Pending | Pending | Pending | Not run | Pending |

## Phase 0 local audit — 6 November 2026

- Tool: Codex coding assistant. Human owner/reviewer: pending.
- Assisted files: `.gitignore`, `docs/progress.md`, `docs/runbook.md`, `docs/ai-usage.md`.
- Work: inspected this checkout, Git state, scripts and official sponsor documentation; recorded absent scaffold and Phase 0 blockers. No product implementation, Studio action, deployment, signing or commit.
- Checks: repository inventory and Git status/history; read-only Arc Testnet `eth_chainId` succeeded with `0x4cef52`. CRE CLI unavailable; no CRE or Arkiv integration run. Human validation pending.

## User-reported Arc Studio generation — 6 November 2026

- Tool: Arc Studio, prompted by the human with the Phase 0 foundation prompt.
- Reported output: generic guarantee contract and app preview; Studio reported 33 passing tests and clean lint/type checks. Generated files, logs and project URL have not yet been supplied to this checkout, so these results are not independently verified here.
- Reported limitation: contract has no settlement or release path and is not deployed. Do not treat the Studio safety summary as an independent audit.
- Codex then inspected the separate Studio export's file inventory, contract, manifests and configuration on 6 November 2026. It did not run the exported tests or import source into the private checkout. The export's `.env` values were kept out of notes and tool output.
- After the human supplied the Studio project URL, Codex copied the exported source and toolchain into the private checkout, excluding `.env`, generated Foundry output and Studio's separate `AGENTS.md`. It added a placeholder `.env.example` and updated the repository audit. No local runtime tests, Studio CLI round trip or deployment has yet been verified.
- Codex installed and inspected Arc Studio CLI 1.2.2. `arc-studio whoami` failed because the human has not authenticated this machine. No credential, app-targeted read, push or round trip was performed.
- After the human authenticated, Codex matched the app ID and ran a read-only CLI source comparison. It installed the Studio-pinned Bun and Foundry versions, ran the exported checks, and recorded both passing tests and generated-script failures. No contract deployment, wallet action, Git commit or Studio code edit was performed.
- Codex then prompted the same Arc Studio project twice using `docs/prompts/phase0-studio-check-fix.txt` and `docs/prompts/phase0-studio-arc-only.txt` to repair portable checks and constrain the generated deployment tooling to Arc Testnet. Studio changed `package.json` and six `scripts/` files; Codex reviewed and pulled those seven files, then reran `bun run check` successfully on Windows. Forge build and 33/33 tests had also passed locally before these tooling-only edits. Studio reported matching checks after its edits. Human review of the final diff and browser/wallet verification remain pending; no deployment, transaction or Git commit was performed.
- Human supplied screenshots of the Studio Preview and Share menu. Codex recorded the visible undeployed state and that Share offers external hosting options; no publication or account connection occurred.
- A subsequent human screenshot shows the app connected to the wallet and MetaMask set to Arc Testnet with 0 USDC. Codex recorded this as wallet/network evidence; no faucet or transfer success is inferred.
- Human supplied a Circle faucet success screenshot and transaction hash. Codex verified its successful receipt, 20 USDC Transfer log and recipient ERC-20 balance through read-only Arc Testnet RPC calls. No signing or transfer was performed by Codex.
- Human supplied a signed-in CRE Discover screenshot. Codex recorded dashboard access only; no CRE CLI authentication or simulation is inferred.
- Human supplied Arkiv Hub faucet/access-key screens and confirmed the key was saved privately. Codex recorded these as user-provided setup evidence without reading the key. Codex installed the official Windows CRE CLI 1.39.0 and verified version/login help; account authorization remains a human step. No workflow or Arkiv write/query was created.
- Human then completed CRE CLI browser login. Codex verified `whoami` exit 0 and queried the tenant's supported-chain registry, which included Arc Testnet. No workflow, simulation, signing or deployment occurred.
- Codex subsequently ran the official Hello World TypeScript template in a separate temporary folder for Phase 0 compiler/simulator feasibility. The first simulation failed on Windows `spawn bun ENOENT`; a process-only PATH adjustment resolved it and the rerun returned `Hello world!`. No MicroCover CRE workflow was implemented, no user wallet key was used, and nothing was broadcast or deployed.
- Human screenshot confirms MetaMask on Arkiv Rabdi with 10 tGLM. Codex recorded this as human wallet evidence; no Arkiv entity write/query is inferred.
- Human filled the labelled synthetic sample and signed its creation in Arkiv Hub, then supplied the public entity key/link. Codex used official read-only Rabdi JSON-RPC methods to verify the stored fields and an owner/board/schema query returning one match. It saved an observed summary in `docs/evidence/phase0-arkiv-smoke.json` and updated progress/runbook. No signing or key access was performed by Codex.
- At the user's direction, Codex recorded sole implementation ownership on this laptop, a proposed rotation for four supplied publisher accounts, and a private-SHA/public-snapshot record template. Assisted files: contributions.md, git-workflow.md, releases.md, decisions.md, progress.md and this log. Account identities/permissions and future publication are not independently verified; no Git commit or push was performed.
- Codex compared the observed contract ABI and demo notes, documented a 2/5 versus 20/10 illustrative-amount mismatch, and prepared phase0-review.md for human selection. It updated interfaces.md to distinguish implemented foundation from future proposals. No contract change, financial decision acceptance or Phase 1 work is inferred.
- User delegated the demo-amount choice. Codex retained Studio's 2/5 example, reconciled demo-scenario.md and the phase runbook (including later validation arithmetic), and recorded the decision in interfaces.md, decisions.md, phase0-review.md and progress.md. It prepared first-private-commits.md without staging, committing or pushing. No product code changed; this documentation change does not mark Phase 0 passed.
- After human staging, Codex removed one extra EOF blank line from each of index.html, postcss.config.js, src/main.tsx, tailwind.config.js and tsconfig.json to fix cached whitespace-check findings. It uploaded the corrected files into the same Studio app and verified zero dry-run differences. The human must re-stage them; Codex did not stage, commit or push. No functional changes or runtime tests were needed for this cleanup.
- Human created foundation commit `91b692fd0a6192fc0ab031e6befa4389ae336faf` under Abhiraj Kochale's configured identity. Codex verified the commit/status read-only and updated current progress/contribution/release records before the documentation commit. No agent commit or push occurred.
- Human created documentation commit `3d01d41c209132d32b9b542fe087db5fb1c156c1` and pushed both commits to private main. Codex verified remote SHA parity. User then explicitly authorized future agent local commits and verification; Codex reconciled AGENTS.md and workflow/progress notes and will commit this documentation update under the existing configured author identity. No product code or public checkout changed; no agent push is authorized by this update.

Record Studio prompts and meaningful agent task prompts under docs/prompts/ when used. Keep secrets and private evidence out of prompt logs. Include spec/planning artifacts actually used; do not invent a prompt history after the fact.
