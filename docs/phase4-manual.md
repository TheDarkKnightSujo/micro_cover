# Phase 4 — current route and remaining human actions

Phase4 is IN_PROGRESS. Current closeout: human relay for guarantee2 and timeout/refund for guarantee3 complete; all3 guarantees CLOSED and whole contract balance0 verified. Six private Phase3/4 commits were pushed under specific authorization, finalSHA9d98930b05679dca5a1ddb2f6d9c980a08e93a6f. No public export or Studio reconciliation is claimed. Native receiver undeployed. User authorized Phase5 while deferring Studio reconciliation and Phase4 human terminal reproduction/review. No more wallet steps are needed on these closed guarantees.

Procedural material below preserves the earlier sequence. References to funded/unresolved guarantees or pending relay are historical, superseded by the closeout and appended verified receipts. Do not repeat completed wallet steps.

## Reproduce the actual integration

From PowerShell in `C:\GitHub\MicroCover-Private`, with the existing local evidence service running:

```powershell
bun install --cwd workflows/cre
bun run scripts/phase4-simulate.ts failure
bun run scripts/phase4-simulate.ts success
bun run scripts/phase4-simulate.ts uncertain
bun run scripts/phase4-simulate.ts unavailable
```

The wrapper invokes the installed `%LOCALAPPDATA%\Programs\cre\cre.exe` v1.39.0, restores the Windows global Bun binary PATH used in Phase 0, selects the Arc `local-simulation` target, and supplies all inputs noninteractively. It never supplies `--broadcast`, reads wallet keys, or sends an EVM write. SDK1.23.0/viem2.57.5 and the isolated workflow lockfile are pinned. CRE uses its default simulation key internally; this is not the user's MetaMask key or a production DON signature.

Results/logs: `docs/evidence/phase4/{failure,success,uncertain,unavailable}.{json,log}`. Cases use existing guarantee IDs1/2/3, their actual Arc terms/policy/cohort and existing cutoff receipt history. Failure ID1 is already closed: replaying its evidence evaluation demonstrates historical parity, not another eligible settlement. Success ID2 is unresolved and funded. Conflict ID3 is unresolved and funded. The unavailable case requests a deliberately nonexistent read route; it does not shut down collection or modify evidence. No new guarantee or repeated enrollment is required.

CRE reads `protocolVersion`, `usdc`, `getGuarantee`, `getEvidenceState` using the EVM capability on Arc selector3034092155422581607 and fetches the actual local API using HTTP capability. It recomputes public receipt hash links, source coverage, domain, frozen policy and cutoff, then uses the same pure evaluator as Phase3. Only compact outcome/root enters consensus (25kb observation limit); the complete receipt log is fetched in node mode. Established outcomes generate ABI-encoded `MicroCover.EvidenceReport` plus `runtime.report(prepareReportRequest(payload))` in simulation. UNCERTAIN generates no financial report. API/validation failure returns uncertainty; chain reads failing abort the workflow rather than inventing onchain state.

## Current deployed contract: explicit human demo relay

The current contract `0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0` has immutable operator Account1. It cannot be converted to a forwarder receiver. No general-purpose signing endpoint or automatic relayer was added.

For the next actual financial write, use the existing success reference ID2, Account1/operator, Arc Testnet, at `http://127.0.0.1:5173/?guarantee=2`:

1. In Evidence, expand **CRE simulation comparison** and click **Prepare matching simulated result**. It requires the saved CRE outcome/root to equal a freshly prepared Phase3 result with current onchain nonce/expiry. The saved local JSON is an unsigned execution record, not a cryptographically verified CRE network receipt.
2. Review the result as SUCCESS, correct chain/contract/ID/cohort/policy/root. Anchor it with the existing explicit human wallet action if needed, then prepare the matching result again.
3. Submit only after reviewing the wallet transaction. This is the trusted human operator relaying a simulated result, not the forwarder verifying production CRE output.
4. A full120-second review begins only after that onchain submission. Finalization and token release remain separate guarded human actions. No success-review protection was shortened, no failure admission substituted, and no transaction was signed by the agent.

This live relay has NOT been executed/verified. The closed ID1 cannot be reused for a live failure write. A fresh distinct-provider failure demonstration remains deferred; tests do not replace that human observation. ID3's onchain uncertainty timer has not started at the freeze audit; no timeout/refund success is claimed.

## Prepared native receiver route — new deployment required

`contracts/MicroCoverCREReceiver.sol` implements `onReport(bytes,bytes)` and ERC165, pins the forwarder/workflow ID/encoded name/owner, accepts documented62/64byte metadata, and atomically anchors then submits the bound report to a NEW MicroCover whose immutable operator is the receiver. It has no arbitrary payout or admin bypass. Existing MicroCover guards enforce nonce/domain/freshness/full review/non-resetting timeout. The original deployed source and both prior deployments remain untouched.

Arc is listed in the official **Simulation Testnets** directory with mock forwarder `0x6E9EE680ef59ef64Aa8C7371279c27E496b5eDc1`. A mock-forwarder caller/metadata check is not production DON authentication; it is unsuitable for real funds. Current simulation reports contain simulator workflow metadata, not approved production workflow identity. Never invent production IDs or silently configure zeros to bypass identity checks. Prepared receiver requires nonzero identity values; live mock delivery/production compatibility are not verified.

After a concrete workflow identity and supported write route are agreed, HUMAN-only deployment commands using the existing Foundry setup would be:

```powershell
# In WSL, from /mnt/c/GitHub/MicroCover-Private. Do not run until placeholders
# are replaced with reviewed public metadata and an existing encrypted account name.
forge create contracts/MicroCoverCREReceiver.sol:MicroCoverCREReceiver --rpc-url https://rpc.testnet.arc.io --account <ENCRYPTED_ACCOUNT_NAME> --constructor-args 0x6E9EE680ef59ef64Aa8C7371279c27E496b5eDc1 <WORKFLOW_ID_BYTES32> <ENCODED_WORKFLOW_NAME_BYTES10> <WORKFLOW_OWNER_ADDRESS> --broadcast
forge create contracts/MicroCover.sol:MicroCover --rpc-url https://rpc.testnet.arc.io --account <ENCRYPTED_ACCOUNT_NAME> --constructor-args 0x3600000000000000000000000000000000000000 <VERIFIED_RECEIVER_ADDRESS> 120 120 --broadcast
```

These are templates, NOT ready-to-run commands or authorization to deploy. Keystore password is entered at Foundry's hidden prompt, never in command text/chat. The workflow currently has no `writeReport` call; authenticated receiver delivery must be wired/tested with the verified deployment before claiming it works. No address/environment guard should change before receipt/runtime/config verification. Do not redeploy the existing EOA-operated contract or overwrite its evidence.

## Checkpoint 4

- Actual CRE WASM simulation connects Arc and the evidence API: verified.
- SUCCESS/FAILURE/conflict parity and unavailable handling: verified, saved output.
- Current UI comparison + restricted human relay preparation: implemented, local HTTP/type/build checks only; wallet/browser action unverified.
- Native receiver authorization/replay/lifecycle tests: verified locally. Receiver not deployed/connected.
- Live relay/receiver transaction and human reproduction: outstanding.
- Studio source parity/sharing: outstanding. No eligibility claim.

Stop here before Phase5/Arkiv. Proposed future commit groups: Phase3 freeze audit; CRE workflow/snapshot/API/tests; receiver/tests; UI comparison/docs. All remain uncommitted.

Official API references checked6November2026:
- https://docs.chain.link/cre/reference/sdk/evm-client-ts
- https://docs.chain.link/cre/reference/sdk/http-client-ts
- https://docs.chain.link/cre/getting-started/part-1-project-setup-ts
- https://docs.chain.link/cre/guides/workflow/using-evm-client/forwarder-directory
- https://docs.chain.link/cre/guides/workflow/using-evm-client/onchain-write/building-consumer-contracts

Trust limits: both feeds belong to us; source signature verification happens in the trusted collector using private envelopes, while CRE checks only the exported public receipt log. Hashes/consensus do not prove truth, independence, completeness, or honest collection. Localhost is reachable in this observed local simulation, not from a deployed DON. Logs/simulation report signatures are demonstration artifacts, not proof of a deployed CRE network.

Studio reconciliation, human-run when quota returns: .\scripts\reconcile-phase3-studio.ps1 -Phase4 . Dry run with -WhatIf passed90files; actual upload/parity remains pending. Review docs/phase4-studio-files.txt first; no environment/storage/compiler intermediates included.

Phase3 timeout reference completed / Phase4 closeout observation6November2026: bun run contracts/out/check-phase4-close3.ts exit0. Guarantee3 UncertaintyMarked tx0x6f90ad96759bf905bd052ed1d071c3c20a4313a6e9621316fff367de7e155fd5 began first120s timer; UnresolvedFinalized tx0xb8b3af71850a28f895845afecdb97fd2c0b9fafeda2e1a419516e2db01ea5f90 occurred1793978739, after fixed deadline1793978711. Refund tx0xb1ccfaf0c93b98401cc77cd64ad73f40e50b7faf15b7bcf6743ffc3fcaf72b97 sent exact0.1USDC to beneficiary Account2; compensation0. Provider Account3 then withdrew exact0.2USDC in tx0x3f42e8f0ba96811709536e8d93782b7aa7ffc76e21fc23a13f8747f76879ca16, strictly after refund. CLOSED/UNRESOLVED_REFUNDED, refunded1/1, all holdings/reserve/owed0, duplicate refund rejected NothingToRefund. Whole deployed contract token balance0 and all3 existing guarantees CLOSED verified at a single pinned block. Proof docs/evidence/phase4/guarantee3-closed.json. No agent signatures, deploy, source/runtime change, tests rerun, commit/push or public repo modification.

Current financial reference coverage: evidence failure G1, reviewed success via explicit CRE-simulation-matching human relay G2, unresolved escrow-only refund G3 all completed and independently checked. Phase3 implementation remains frozen; separate-provider evidence-failure noncooperation demonstration and Studio reconciliation were deferred by user, not falsely passed. Phase4 actual local CRE runs and human relay demonstrated; native forwarder receiver remains prepared/tested but undeployed/unconnected. Local simulation/default simulator metadata/mock Arc forwarder must not be advertised as a deployed decentralized CRE workflow. Studio90-file reconciliation dry run only; eligibility/sharing still pending. No further wallet actions are needed on guarantees1–3. Next product phase is Phase5 visible Arkiv receipts/query, requiring explicit phase authorization; not started in this turn. Proposed uncommitted groups remain Phase3 collector/contracts/UI/evidence; Phase4 CRE workflow/receiver/UI/docs and actual reference receipts.
