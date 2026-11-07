# Laptop hosting for the testnet demonstration

The production frontend and approved public APIs run through a loopback gateway. Cloudflare Quick Tunnel exposes that gateway over HTTPS. The existing evidence collector keeps its original external SQLite store and feed identities. No Vite development server, fixture signer, local deployment page or private filesystem is exposed.

Current temporary link (7 November 2026): https://potatoes-parameter-mon-programmes.trycloudflare.com/?guarantee=2

Keep the laptop plugged in, awake and connected to the internet. Keep the collector, gateway and tunnel processes running. The link can be opened on another device; wallet transactions require a compatible wallet browser/extension and Arc Testnet. Opening the app does not require a wallet. This is temporary demonstration hosting, not an availability guarantee. Restarting Quick Tunnel generates a different hostname.

## Restart after stopping

Run each long-running command in a separate PowerShell terminal, from `C:\GitHub\micro_cover`. First ensure no existing process is listening on ports 8787 or 10000; do not start another collector on the same database. Do not run `init-demo` or replace the original policy/keys.

1. `bun run evidence serve`
2. `bun run services/hosting/start-local.ts`
3. `& "$env:LOCALAPPDATA\Programs\MicroCoverTools\cloudflared.exe" tunnel --url http://127.0.0.1:10000 --http-host-header 127.0.0.1:10000 --protocol http2`
4. Copy the new HTTPS trycloudflare.com origin printed by command 3 (without a path). In a fourth terminal, run `Set-Content .local-hosting/origin.txt 'https://YOUR-NEW-HOST.trycloudflare.com'`. This exact origin enables browser API requests; no restart is needed.
5. Open the new URL with `/?guarantee=2`, check `/readyz`, then test from a phone using mobile data without connecting a wallet.

The ignored local `.env` is loaded by Bun. The production `dist` was built with `VITE_EVIDENCE_API_URL=/`, so public requests remain same-origin. After intentional frontend edits, rebuild with `$env:VITE_EVIDENCE_API_URL='/'; bun run vite build`. Do not upload `.env`, feed keys, SQLite data or tunnel state to Git.

Stop the tunnel first with Ctrl+C, then the gateway, then the collector. The currently agent-started processes are tunnel PID 22928, gateway PID 29552 and collector PID 34840; these IDs are only valid for this run. Verify identity before stopping any process. Current command sessions are kept running by the agent tooling; restart using the terminal instructions if those sessions end.

## Actual checks

7 November 2026: `bun run check` and `bun run evidence:check` passed; `bun test services/evidence services/hosting` passed 46 tests with 580 assertions; production Vite build passed with existing third-party PURE and bundle-size warnings. `git diff --check` passed (line-ending notice only).

Public HTTPS checks: `/`, `/healthz`, `/readyz`, policy and guarantee 2 Arkiv history returned 200. `.env`, service source, `local-deploy.html` and fixture path returned 404. Exact tunnel Origin returned 200; foreign Origin returned 403. These are HTTP checks, not mobile/browser rendering verification.

Official Windows client downloaded from Cloudflare's GitHub release asset: version 2026.10.7, SHA256 `2493dbc168923bb3e59e5e7716f71deced92992eea9acd6e9d74f84ac7751343` (also reported by the client). Initial GitHub API metadata request failed due to anonymous rate limiting; the official release download succeeded. No independent published checksum comparison is claimed.

No Render service was deployed. No contract was changed, deployed or signed; no Git commit/push was performed for this tunnel setup. Studio reconciliation and the other recorded Phase 6 checkpoint gates remain outstanding. Rotate the Arkiv access key exposed in the earlier screenshot privately and update the ignored server environment; rotation has not been confirmed.

Reference: https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/


## Concert activation update — 7 November 2026

The checked concert UI is now active at https://potatoes-parameter-mon-programmes.trycloudflare.com/#concert. The earlier process IDs above describe the original run, not the current processes. After an authorized backup and owning-terminal restart, collector PID 5560 listens on 8787 (wrapper PID 1844), gateway PID 27916 on 10000, and existing tunnel PID 22928 remains unchanged. Verify process identity before stopping anything. Local/public readyz and live browser checks passed; see docs/concert-demo.md for preservation details and outstanding human checks.
