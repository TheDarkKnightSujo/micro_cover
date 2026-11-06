# Human-run only, after Studio quota is available. Uploads reviewed source, never .env/keys/storage.
[CmdletBinding(SupportsShouldProcess)]
param([switch]$Phase4)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot $(if ($Phase4) { 'docs/phase4-studio-files.txt' } else { 'docs/phase3-studio-files.txt' })
$files = @(Get-Content -LiteralPath $manifestPath | Where-Object { $_ -and -not $_.StartsWith('#') })
$promptPath = if ($Phase4) { 'docs/prompts/phase4-reconcile.txt' } else { 'docs/prompts/phase3-reconcile.txt' }
$arguments = @('run','--app','c47658be-4463-462f-89b8-a0a418962a3d','--prompt-file',$promptPath,'--output','json')
foreach ($file in $files) {
    $fullPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $file))
    if (-not $fullPath.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifest path escaped checkout' }
    if ($file -match '(^|/)(\.git|node_modules|out|cache|broadcast)(/|$)|\.(pem|key|sqlite)(\.|$)' -or $file -match '(^|/)\.env') { throw "Forbidden upload path: $file" }
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Missing source: $file" }
    $arguments += @('--file',($file + ':' + $file))
}
if ($PSCmdlet.ShouldProcess('Existing private Arc Studio MicroCover project', "Reconcile $($files.Count) reviewed source files and run checks; no deployment")) {
    Push-Location -LiteralPath $repoRoot
    try {
        & arc-studio @arguments
        if ($LASTEXITCODE -ne 0) { throw "Studio reconciliation failed with exit $LASTEXITCODE; checkpoint remains pending" }
    } finally { Pop-Location }
}
