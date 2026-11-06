# Phase 3 temporary local deployment page

The user discontinued the Foundry browser signer after a second connection timeout. This helper reuses the installed Vite, viem, wagmi configuration and injected MetaMask connection. It reads the existing reviewed Foundry artifact; it does not compile Solidity or change the main app's version guard/address. Studio reconciliation remains pending.

## Open the helper

The agent started `bun run deploy:local:page` on **http://127.0.0.1:5174/**. If it is no longer running, start that command once from `C:\GitHub\MicroCover-Private`. Use a normal browser window with MetaMask. There is no Foundry browser connection deadline. Browser automation could not confidently determine the active URL and stopped; visual rendering and wallet interaction require human verification.

1. Inspect MetaMask Account1 / Arc Testnet / Activity. Stop if an unexpected pending deployment exists.
2. Open the URL and connect Account1: `0x1d39fc0e5293ab949d63217ffb375357adf3933f`. Select Arc Testnet5042002; a different account/network blocks deployment.
3. Click **Run unsigned review**. It checks public RPC chain and latest/pending nonce20, simulates creation, matches the expected runtime hash and estimates gas. No wallet signing occurs in this step.
4. Review official USDC `0x3600000000000000000000000000000000000000`, immutable operator Account1, success review120seconds, separate uncertainty timeout120seconds, transaction value0, the gas estimate/limit and creation-data hash `0x3ad431344208f00e3c12cce7b6a20baf54c775a5872e5765c2ca8fc2ce28cb1a`. The fee is native test USDC at18decimals, separate from the ERC20 interface's6decimals. MetaMask supplies the actual final fee.
5. Check the review box, click **Deploy — confirm personally in MetaMask** once, then review/confirm personally. The unsigned review expires after60seconds; rerun it if expired. No agent connection/signature is authorized.
6. The returned public transaction hash is displayed immediately, stored in browser localStorage and saved in ignored `contracts/out/phase3-local-browser-attempt.json`. Copy/download the submission record and send the hash to the agent. If server persistence fails, use **Retry saving this hash only**; never deploy again.

The server persists `wallet_requested` before asking the wallet. A synchronous UI lock and server claim lock prevent repeated clicks/tabs. Reloads retain the server lock. Only an explicit wallet rejection code4001 can mark the attempt cancelled. Other errors remain locked until a human/agent inspects wallet and chain activity. Do not delete the attempt file to bypass a lock. A submitted transaction stays locked even after a failed receipt. No nonce override, force retry or reset control exists. Expected sender nonce20 is frozen to this reviewed attempt; if it changes, inspect rather than editing the helper to evade the guard.

The local server accepts only loopback host127.0.0.1:5174, requires same-origin JSON POSTs, rejects cross-origin requests and sends no-store headers. It exposes only public ABI/bytecode/configuration and public attempt records. No key or secret is requested. Do not expose this temporary dev server to a LAN or tunnel. The main production entry/config never imports it, publicDir is disabled, and its own config refuses a production build. Stop its server after the deployment hash is safely recorded; keep verification records.

## After submission

Do not use/fund the new contract or edit `.env` yet. Run the existing read-only verifier:

```powershell
bun run scripts/phase3-local.ts verify '<PUBLIC_DEPLOYMENT_TRANSACTION_HASH>'
```

It checks canonical successful receipt/two confirmations, exact sender/chain/zero value, full creation input with four arguments, CREATE-derived address/prior empty code, complete runtime plus immutables and configuration including version3, official USDC, operator,120/120 and bounds. Only after it passes may the ignored main-app address be updated and Vite/evidence service configured. Phase2 contract/evidence remain unchanged. Follow `docs/phase3-manual.md` for the subsequent fresh scenarios. Phase3 is IN_PROGRESS until required human checks and Studio reconciliation are recorded.

## Actual recovery checks

After the second timeout, no Foundry create/script process or port9545 listener existed; no stale signer needed termination. Windows process enumeration also found no forge/wsl signer process. Account1 latest/pending transaction counts remain20, matching original preflight block71031879. Arcscan returned20 outgoing records/no further page; newest remains historical nonce19 Phase2 withdrawal at block71011444, tx `0x11bf92ff185cd3c9957592dfd548a25c02e0906b2649e1a94df6435ed7a8b9f3`. No new broadcast was found in these checked records; this does not prove every mempool or local wallet queue is empty. Direct MetaMask activity remains a human check.

Official APIs verified against installed package types and documentation: [viem deployContract](https://viem.sh/docs/contract/deployContract), [Vite server restrictions](https://vite.dev/config/server-options), [Vite production entry](https://vite.dev/guide/build). No different toolchain, sponsor integration or deployment authority was added.
