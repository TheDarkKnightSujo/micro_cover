# First public commit — human commands

Execution update: after this guide was prepared, the user explicitly authorized Codex to execute this first release's commits, export and pushes on their behalf. The blocks below remain the prepared procedure; actual completion is recorded separately in private docs/releases.md after remote verification. Historical "not executed" wording describes preparation time, not a claimed later result.

The current user publishes first. Include the complete tested Phase 1 snapshot (foundation included), rather than assigning already-completed files to different teammate identities. Subsequent phase publishers are in contributions.md. Do not change author identity or add coauthors to manufacture participation.

The public checkout was empty except `.git` when inspected. These commands have NOT been executed. They first commit the private source, then export only the reviewed manifest from the resulting exact SHA, and finally let the human review/commit/push the public snapshot. No `.git` is copied and private history is retained in the private repo. A file snapshot does not reproduce that history publicly; this workflow is explicitly disclosed here. Event acceptance of snapshot history remains unverified.

## 1. Commit and push the private Phase 1 source

Run in PowerShell. Run each commit only if its preceding staged diff/check is correct. Source, UI and documentation are three coherent local groups; existing operator Git identity is retained.

```powershell
Set-Location C:\GitHub\MicroCover-Private
git status --short --branch

git add -- contracts/MicroCover.sol contracts/test/MicroCover.Invariant.t.sol contracts/test/MockUSDC.sol contracts/test/MicroCover.Phase1.t.sol contracts/test/MicroCover.Review.t.sol
git diff --cached --stat
git diff --cached --check
git commit -m "feat: settle provider-admitted failure with protected cohort accounting"

git add -- src/App.tsx src/microcover
git diff --cached --stat
git diff --cached --check
git commit -m "feat: connect Phase 1 funding enrollment and payout actions"

git add -- AGENTS.md README.md MicroCover_Phase_By_Phase_Runbook.md docs
git diff --cached --stat
git diff --cached --check
git commit -m "docs: record Phase 1 verification and first public release plan"

git status --short --branch
git log -3 --oneline
git push origin main
```

Do not continue if any command fails or if uncommitted work remains. These commands include the release guide/manifest and the completed financial evidence. All recorded JSON evidence is public chain data; no raw private evidence is included.

## 2. Export the exact committed files into the empty public checkout

This block validates each path against the source commit, rejects credential/build paths and refuses to overwrite any populated public checkout. It writes only the manifest files and a public source-SHA record; public `.git` stays untouched. No recursive delete/move is used.

```powershell
$privateRepo = 'C:\GitHub\MicroCover-Private'
$publicRepo = 'C:\GitHub\MicroCover'
Set-Location $privateRepo
if (@(git status --porcelain).Count -ne 0) { throw 'Private checkout must be clean before export.' }
$phase1SourceSha = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve private source commit.' }
$releaseFiles = @(Get-Content -LiteralPath "$privateRepo\docs\public-release-files.txt" | Where-Object { $_ -and -not $_.StartsWith('#') })
$sourceFiles = @(git ls-tree -r --name-only $phase1SourceSha)
if ($LASTEXITCODE -ne 0) { throw 'Cannot list committed source.' }
foreach ($releaseFile in $releaseFiles) {
    if ($releaseFile -notin $sourceFiles) { throw "Manifest file absent from source commit: $releaseFile" }
    if ($releaseFile -match '(^|/)(\.git|\.arc-studio|node_modules|dist|out|cache|broadcast|\.npmrc)(/|$)|(^|/)\.env($|\.)|\.(pem|key)$') {
        if ($releaseFile -ne '.env.example') { throw "Excluded path in manifest: $releaseFile" }
    }
}
$publicRoot = (git -C $publicRepo rev-parse --show-toplevel).Trim()
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($publicRoot) -ne [IO.Path]::GetFullPath($publicRepo)) { throw 'Public Git checkout mismatch.' }
if (@(Get-ChildItem -LiteralPath $publicRepo -Force | Where-Object Name -ne '.git').Count -ne 0) { throw 'Public checkout is no longer empty; inspect it before copying.' }
$releaseArchive = Join-Path $env:TEMP "microcover-phase1-$phase1SourceSha.zip"
git archive --format=zip "--output=$releaseArchive" $phase1SourceSha -- $releaseFiles
if ($LASTEXITCODE -ne 0) { throw 'Source archive failed.' }
Expand-Archive -LiteralPath $releaseArchive -DestinationPath $publicRepo
@(
    "Private source commit: $phase1SourceSha"
    'Release: first public snapshot, foundation plus completed Phase 1'
    'Implementation: current operator, with Arc Studio and Codex assistance; see docs/ai-usage.md'
    'Publication does not change implementation attribution. Retain genuine private history.'
) | Set-Content -LiteralPath "$publicRepo\SOURCE_SNAPSHOT.txt" -Encoding utf8
Set-Location $publicRepo
git remote -v
git var GIT_AUTHOR_IDENT
git status --short --branch
```

The manifest names every source/config/docs/vendor file to include. Export `.env.example` only; the deployed address is already documented publicly and can be configured locally later. Never copy the separate Studio export's `.env`. Review exported files and ensure the shown origin/account identity is the intended public repository and your actual identity.

## 3. Review, make the first public commit, then push

Continue in the same PowerShell session, retaining `$phase1SourceSha` and `$releaseFiles`. If using a new session, resolve them again from the clean private checkout; do not paste an invented SHA.

```powershell
Set-Location C:\GitHub\MicroCover
git add -- $releaseFiles SOURCE_SNAPSHOT.txt
git diff --cached --stat
git diff --cached --check
git diff --cached
# After reviewing the staged files and attribution:
git commit -m "feat: import verified Phase 1 MicroCover snapshot" -m "Private source: $phase1SourceSha. Includes Studio foundation, bond/escrow/failure settlement and verified testnet evidence. Implementation and AI assistance documented in docs/ai-usage.md."
git log -1 --format=fuller
git status --short --branch
git push -u origin main
```

Stop if checks fail or the diff contains unexpected files. After success, record the actual private/public SHAs and publisher in private docs/releases.md in a subsequent metadata commit. No push has been performed as part of preparing these instructions.

## Remaining publication limitations

Phase 1 functional checks pass. Judge access to Studio is still unresolved; this snapshot does not resolve it. An application-wide open-source licence remains a human decision (D14); existing third-party licence files must be retained. Future teammates publish complete verified phases or coherent reviewed tasks under their own genuine identity and record work they actually perform; existing implementation is not reassigned by copying it.
