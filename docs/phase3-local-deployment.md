# Phase 3 local deployment — human signs, agent verifies before configuration

Current MetaMask route: [temporary Vite deployment page](phase3-local-page.md). Foundry browser signing is discontinued after two connection timeouts; do not retry it.

The user explicitly authorized this local testnet route before Studio quota returns. This supersedes the earlier manual document's requirement to wait for Studio **for this human deployment**. Studio source reconciliation/eligibility remain pending; a local deployment does not resolve them. Phase2 deployment/evidence remain historical and unchanged. No commit, push or public checkout action is authorized.

## Verified route and settings

Use the existing WSL Foundry1.7.1 in this checkout; no new project/toolchain/factory is needed. `scripts/self-deploy.ts` is a Circle developer-wallet script with `/home/user/app` paths and Circle credentials. It is not a local MetaMask/keystore signer route. The existing CREATE2 script requires a separate deployed factory; it is unnecessary here.

The current source and compiled ABI both require **four** arguments:

| Setting | Value |
|---|---|
| Network | Arc Testnet5042002 |
| RPC | https://rpc.testnet.arc.io |
| Constructor1 IERC20/address | 0x3600000000000000000000000000000000000000 |
| Constructor2 demoOperator/address | 0x1d39fc0e5293ab949d63217ffb375357adf3933f (Account1) |
| Constructor3 uint64 reviewWindow | 120 seconds |
| Constructor4 uint64 uncertaintyTimeout | 120 seconds, separate immutable |
| Transaction value | 0; gas only, paid in native test USDC |
| Compiler | Existing0.8.28, Cancun, optimizer200 |

Native gas balances/fees use18 decimals; the USDC ERC20 interface uses6. These are the same underlying asset, not two balances to add. Official references: [Arc connection/network](https://docs.arc.io/arc/references/connect-to-arc), [USDC address/precision](https://docs.arc.io/arc/references/contract-addresses), [Foundry create](https://getfoundry.sh/forge/reference/forge-create). Installed `forge create --help` confirms `--browser`, `--account`, `--from`, `--chain`, `--constructor-args` and explicit `--broadcast`. No wallet/RPC address is inferred from the old three-argument constructor.

## 1. Unsigned preflight

PowerShell, on this laptop:

```powershell
cd C:\GitHub\MicroCover-Private
.\scripts\deploy-phase3-local.ps1
```

This builds the current source, checks RPC chain/token decimals, verifies artifact source hashes, simulates contract creation with read-only `eth_call`, checks the entire returned runtime against the compiled template and expected immutables, estimates gas and prints the exact public settings. It never opens a signer or broadcasts. It writes an unsigned plan under ignored `contracts/out/`, not a deployment record. Fee estimates change; review the actual fee in your signer. The proposed sender defaults to Account1; use `-Sender <PUBLIC_ADDRESS>` only if deploying from another wallet. Operator remains the explicitly frozen Account1 above.

## 2A. Browser wallet (no private-key export)

**Superseded after two Foundry browser-wallet connection timeouts. Do not retry this route.** The wrapper now rejects `-Signer Browser -Broadcast`. Use the local Vite page below instead. Historical instructions are retained for traceability only.

After reviewing the unsigned preflight, run this **yourself**:

```powershell
.\scripts\deploy-phase3-local.ps1 -Signer Browser -Broadcast
```

1. Review the printed network, sender, four constructor values, zero transaction value and creation/runtime hashes.
2. Type `DEPLOY` in your own terminal only when they match.
3. The wrapper prints **http://127.0.0.1:9545/** before the `DEPLOY` prompt and passes an explicit `--browser-port 9545`. Keep it ready in your normal Windows browser with MetaMask; after `Waiting for wallet connection`, open/refresh it immediately. A Windows background helper also opens the URL once it returns the Foundry HTML page. The helper never starts Foundry, connects a wallet or signs. WSL localhost forwarding must work. `--browser-disable-open` disables only the unreliable WSL opener; do not rely on Foundry printing a URL. An occupied Windows port blocks the attempt. An optional `-BrowserPort <PORT>` changes both the printed URL and Foundry port.
4. Select the intended sender (default Account1), connect, and choose Arc Testnet5042002. Review the contract creation and actual gas fee. **You** confirm in MetaMask; the agent does not click/sign it. No private key is exported or entered in a webpage.
5. Copy only the public transaction hash and resulting contract address. Do not create a guarantee or change frontend configuration yet.

If the browser signer/WSL forwarding is unavailable, cancel before confirming and use the encrypted-keystore route. If a command errors after a wallet confirmation, inspect wallet activity/transaction receipt before retrying; avoid duplicate deployments. A smart-account inner deployment is not this direct-EOA route; the verifier deliberately rejects it rather than inventing direct-create evidence.

Timeout recovery, 6 November 2026: the first human-run browser attempt ended with `Wallet connection timeout`; its process exited and port9545 closed. The old URL cannot work until a fresh human-run attempt starts. Read-only checks found Account1 transaction count20 both at preflight block71031879 and at latest/pending. Arcscan returned20 outgoing transactions with no pagination, no contract creations and no transaction newer than preflight; newest was the recorded Phase2 withdrawal0x11bf92ff185cd3c9957592dfd548a25c02e0906b2649e1a94df6435ed7a8b9f3 at block71011444. No Foundry broadcast directory was present at either `broadcast/` or `contracts/broadcast/`. This is no broadcast found in the checked records, not proof about every mempool or an unsubmitted wallet queue. Before the one fresh attempt, the human must inspect Account1 / Arc Testnet / Activity and stop if any deployment is queued or pending. Direct MetaMask activity was not successfully inspected by the agent. No retry or signature was made by the agent.

## 2B. Existing encrypted Foundry keystore

Keystore lives in WSL's default `~/.foundry/keystores`, outside this Windows checkout. To list account names locally:

```powershell
wsl --exec /home/abhir/.foundry/bin/cast wallet list
```

For an account named `microcover-testnet`, derive its public address using a hidden password prompt:

```powershell
wsl --exec /home/abhir/.foundry/bin/cast wallet address --account microcover-testnet
```

Then run the deployment wrapper yourself, using that public sender:

```powershell
.\scripts\deploy-phase3-local.ps1 -Signer Keystore -Account microcover-testnet -Sender '<PUBLIC_ADDRESS>' -Broadcast
```

The wrapper shows the same review, requires `DEPLOY`, then Foundry prompts privately for the keystore password and signs locally. No `--password`, password file, private-key argument or transcript is used. Do not enable PowerShell transcription/shell tracing around secret input, and never send secret prompts/screenshots here.

If you do not have a keystore and deliberately choose to import a **testnet** wallet locally, run this yourself in a non-recorded terminal:

```powershell
wsl --exec /home/abhir/.foundry/bin/cast wallet import microcover-testnet --interactive
```

Foundry's interactive private-key/password prompts are hidden; enter them only there, never in the command, repo, chat or logs. This is optional; browser signing avoids exporting a key. Do not import a seed phrase or use raw-key command flags. Fund the selected public address with faucet test USDC if required; no agent transfer is performed.

## 3. Independent verification — before `.env` changes

Send only the public transaction hash/address. The agent will run (or you can run locally):

```powershell
bun run scripts/phase3-local.ts verify '<DEPLOYMENT_TRANSACTION_HASH>'
```

The read-only verifier requires a successful canonical direct-create receipt, at least two confirmations, expected sender/chain/value, exact compiled creation input with all four arguments, the CREATE-derived address, no code in the prior block, exact runtime match at deployment/latest, and independently read getters at deployment/latest: version3, official USDC, Account1 operator, review120, uncertainty120, cohort cap100, batch cap20, evidence freshness60 and initial nextGuaranteeId1. It rejects the old Phase2 address. Source hashes must still match the unsigned plan; no success is inferred from a printed address alone. RPC failures or unsupported history block verification.

Successful verification writes a transaction-specific public receipt/config/source-hash record in `docs/evidence/phase3-deployment-<hash-prefix>.json` plus an ignored local verification marker. It neither broadcasts nor edits `.env`. The verifier uses the official RPC and local artifact; it does not claim multiple independent RPC sources or explorer source-publication verification.

Only after these checks pass, the agent is authorized to preserve other ignored `.env` entries, set the actual public `VITE_MICROCOVER_ADDRESS` and `MICROCOVER_EVIDENCE_CONTRACT`, restart the existing local Vite process, initialize/reuse private evidence storage safely and start `bun run evidence serve`. No changes to the verified Phase2 records. The frontend's protocol guard remains enabled.

## 4. Fresh Phase3 scenarios

After verification/service health, use [phase3-manual.md sections4–6](phase3-manual.md): failure from authenticated CANCELLED feeds without provider admission, separately reviewed success, and an explicit onchain uncertainty timeout with full escrow refunds/zero compensation/bond last. Each uses fresh guarantee IDs on the new contract. Keep collection active before claims and the same persisted policy keys across restart; use actual `bun run evidence set-mode <ID> failure|success|conflict` scripts. Record actual receipts, anchors and final liabilities after each step. Phase3 remains IN_PROGRESS until required human checks pass; Studio reconciliation remains explicitly pending even if these local financial flows pass.
