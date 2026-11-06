# Render deployment preparation — 7 November 2026

Prepared locally, not deployed. Use the final public clone `C:\GitHub\micro_cover`.
The fresh public HEAD `56c052d9d6db2efd27ecc6bb5f276646731fa6f0` and private HEAD
`7e1ff80d74595d21b9e0dfeb22a6ddebb3756b22` have the identical tracked tree
`7992ce9a3f5cce508d8455de065ad729dcf9474d`. Commit graphs differ; this is file-content parity,
not shared-history parity. The deployment-preparation changes below now exist only in this public clone.

## Architecture

One Docker web service serves the existing Vite production build and a narrow same-origin API
gateway. The existing evidence collector still binds to loopback8787; its origin/host guards are
unchanged. Only the gateway listens on `0.0.0.0:$PORT`. Browser build uses public v3 address
`0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0` and API base `/`. No new contract deployment.
The runtime ABI is exported from the current reviewed Foundry artifact and tested for exact parity.
The gateway never serves source, fixture routes, policy keys, SQLite or the deployment helper.
Public APIs retain the existing backend method/domain validations; a global600requests/minute
budget limits upstream use. This is a synthetic demo service, not production abuse protection.

`.dockerignore` excludes all `.env*`, keys, databases, Git metadata and generated local artifacts.
The image contains no historical private evidence store. The user's local `.env` was copied
without displaying values, SHA256 equality verified, and Git ignore/untracked status checked.
Do not import that Windows `.env` wholesale into Render: its paths and localhost URL are local-only.

## What you can do now in Render

1. Sign in. Connect GitHub and allow access to `TheDarkKnightSujo/micro_cover`.
   No separate Render project is necessary. Do not deploy the old remote code: the new Dockerfile
   must first be reviewed, committed and pushed by a human.
2. Choose **New → Web Service**, Git Provider, this repo, branch main, language **Docker**.
   Name e.g. `microcover-demo`; root directory blank; Dockerfile path `./Dockerfile`;
   Docker command blank (uses image CMD). Choose a region convenient for the team.
3. Choose a **paid web-service plan supporting a persistent disk**. Free web services have no
   persistent disk/SSH and cannot preserve this SQLite collector. Review Render's displayed cost.
   Use one instance only. Disable automatic deploys until the first transfer is verified.
4. In Advanced add a persistent disk named `microcover-evidence`, mount `/var/data`, size1GB.
   Health check `/healthz` measures only the web process. `/readyz` must separately pass before
   calling the full demo ready. Initially the app/API deliberately show storage unavailable.
5. Environment: set `ARKIV_ACCESS_KEY` privately in Render's Environment settings.
   The image defaults already set `MICROCOVER_EVIDENCE_HOME=/var/data/microcover` and
   `MICROCOVER_EVIDENCE_CONTRACT=0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0`.
   Render supplies PORT and RENDER_EXTERNAL_HOSTNAME. Do not set any VITE secret or upload `.env`.
6. **Create Web Service is the actual deployment action**, performed by the human after the
   reviewed changes are pushed. No wallet signature or contract deployment is needed.

## Securely move existing history before readiness

Do not run `init-demo`: it would generate new feed identities and lose the original policy/history.
Use the existing `C:\MicroCover-Evidence-Local` store, including policy, both feed PEM files and
the SQLite database. The PEMs are demo-feed authentication keys, never wallet private keys.

For a consistent transfer, stop the existing laptop evidence service gracefully from its own
terminal (Ctrl+C). Then make a private backup of the whole store outside both checkouts.
Retain SQLite WAL/SHM files if present; never copy only the main database while a writer runs.
Restart the laptop service afterward only when no new scenario can create split histories.
The cloud becomes the single collector after cutover; the laptop's frontend can remain available.

Render supports SSH on paid web services. Add only your SSH **public** key under Account settings
→ SSH Public Keys. The Dockerfile creates the required root `.ssh` directory and unlocks the
account per Render's Docker SSH guidance. Use the service's **Connect → SSH** command and
verify its host fingerprint against Render's regional documentation. No ephemeral shell: it
does not carry the persistent disk. Never paste the PEM contents or database into chat/logs.

Once the actual SSH target exists, prepare the exact binary-safe transfer command against that
target; transfer through SSH to `/var/data/microcover`, with directory0700/files0600.
Do not use a public upload URL, Git, build arguments, or browser-exposed environment variables.
Do not overwrite an existing cloud history blindly. Verify policy hash and database integrity,
then restart the service. The service starts the collector only when all four required files
exist at boot. Missing storage never triggers silent replacement initialization.

## Checks before announcing deployment

- Docker build/run still needs validation on a Docker-capable machine or Render build logs.
  Docker is not installed on this laptop; no container success is claimed.
- `/healthz`200 is liveness only. Require `/readyz`200 and policy API matching the frozen policy.
- Read guarantees1/2/3 without a wallet: closed outcomes failure/success/unresolved-refunded.
- Query guarantee2 Arkiv history: compare current live result and anchor; old seven-day records
  can expire, and expiry must remain explicit rather than manufactured history.
- Verify source/fixture/`.env` paths404, foreign-origin API403, no local deployment helper in assets.
- Restart Render once and confirm retained receipt counts/roots/policy identities.
- Verify on another device, with no wallet, then human wallet connection/network guard.
- Check local preparation changes into public main only after review; synchronize approved
  changes back to private separately. No automatic push or private-source modification here.

Studio reconciliation, CRE live-network limitations, licence choice and human submission gates
remain as recorded in the Phase6 checkpoint. Hosting does not resolve those requirements.

## Reproducible commands and proposed commits

From the public clone:

```powershell
bun install --frozen-lockfile
bun install --cwd workflows/cre --frozen-lockfile
bun run check
bun run evidence:check
wsl bash -lc 'cd /mnt/c/GitHub/micro_cover && ~/.foundry/bin/forge test'
bun test services/evidence services/hosting
bun run --cwd workflows/cre check
$env:VITE_EVIDENCE_API_URL='/'
bun run vite build
Remove-Item Env:VITE_EVIDENCE_API_URL
```

Deployment-helper tests also require the original ignored `contracts/out/phase3-local-plan.json`.
This clone reused the existing unsigned public preflight from the private checkout; its source,
creation and runtime hashes were validated by the tests. A fresh prepare attempt hit Arc RPC rate
limits and failed, so it is not claimed as newly completed. No deployment was retried.

On a Docker-capable machine, build with `docker build -t microcover-demo .` before release.
Do not mount a live laptop store into a test container that would start a second collector.
Proposed commits: (1) Docker/gateway/ABI/boundary tests; (2) deployment guide and actual checks.
Human commands after review: `git add Dockerfile .dockerignore services/hosting`,
`git commit -m "chore: prepare persistent Render demo hosting"`, then stage the changed docs,
`git commit -m "docs: record repository parity and Render deployment steps"`,
`git push origin main`. Inspect `git diff --cached --stat` and `git diff --cached --check` before
each commit. Do not stage `.env`, keys or external storage.

Official references checked7November2026:
[Render Docker](https://render.com/docs/docker), [web services](https://render.com/docs/web-services),
[persistent disks](https://render.com/docs/disks), [SSH](https://render.com/docs/ssh),
[Bun Docker guide](https://bun.sh/guides/ecosystem/docker).

### Authorized final-public hosting release — 7 November 2026

User explicitly instructed proceeding with the reviewed public hosting commits/push after identifying that Render could not find the local Dockerfile. This scoped authorization supersedes the general human-only Git restriction for this hosting release only; it does not authorize Render deployment, billing changes, wallet actions or private/public history rewriting. Genuine existing Git author used, no overrides. Hosting commit c402c9d contains Docker exclusions, one-service persistent hosting gateway, exact exported Foundry ABI and two hosting boundary/ABI tests. Documentation forms the second commit. Current rerun: bun run check exit0; bun run evidence:check exit0; bun test services/evidence services/hosting46pass0fail580assertions exit0. Earlier unchanged production build/CRE types/299contract tests are retained, not claimed rerun now. Staged filename/literal-key/PEM scan passed; .env ignored/untracked. Private checkout untouched. No Docker executable/container validation available; first Render build remains a required check. Push/remote verification will be reported after the command actually completes. Phase6 stays IN_PROGRESS; storage transfer, readiness, public host checks and previously recorded sponsor/human gates remain pending.
