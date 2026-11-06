# Human-run Foundry wrapper. Default is unsigned preflight; -Broadcast requires a separate review.
[CmdletBinding()]
param(
    [ValidateSet('Browser','Keystore')][string]$Signer='Browser',
    [ValidatePattern('^0x[0-9a-fA-F]{40}$')][string]$Sender='0x1d39fc0e5293ab949d63217ffb375357adf3933f',
    [ValidatePattern('^[A-Za-z0-9_-]+$')][string]$Account='microcover-testnet',
    [switch]$Broadcast,
    [ValidateRange(1024,65535)][int]$BrowserPort=9545
)
$ErrorActionPreference='Stop'
if($Broadcast -and $Signer -eq 'Browser'){throw 'Foundry browser signing is discontinued after timeouts. Use bun run deploy:local:page; the human connects and signs in MetaMask there.'}
$repoRoot=Split-Path -Parent $PSScriptRoot
$forge='/home/abhir/.foundry/bin/forge'
$browserOpener=$null
$wslRoot=(& wsl --exec wslpath -u $repoRoot).Trim()
if($LASTEXITCODE -ne 0){throw 'WSL checkout path unavailable'}
Push-Location -LiteralPath $repoRoot
try {
    & wsl --cd $wslRoot --exec $forge build
    if($LASTEXITCODE -ne 0){throw 'Foundry build failed; no signing requested'}
    & bun run scripts/phase3-local.ts prepare $Sender
    if($LASTEXITCODE -ne 0){throw 'Unsigned preflight failed; no signing requested'}
    $plan=Get-Content -LiteralPath 'contracts/out/phase3-local-plan.json' -Raw | ConvertFrom-Json
    Write-Host "Review: Arc TESTNET $($plan.chainId), RPC $($plan.rpc), sender $Sender"
    Write-Host "Constructor (address,address,uint64,uint64): $($plan.usdc), $($plan.operator), 120, 120"
    Write-Host "Value 0 USDC. Estimated gas $($plan.gasEstimate); gas limit $($plan.gasLimit). Wallet shows final fee before signing."
    Write-Host "Creation hash $($plan.creationHash); expected runtime hash $($plan.runtimeHash)"
    Write-Host 'No approvals, guarantees, funding transfers or Studio actions are included.'
    if(-not $Broadcast){Write-Host 'PREFLIGHT ONLY. No signer opened; nothing broadcast. Use -Broadcast only when ready to review and sign yourself.';return}
    if($Signer -eq 'Browser') {
        if(Get-NetTCPConnection -LocalPort $BrowserPort -State Listen -ErrorAction SilentlyContinue){throw "Port $BrowserPort already has a listener. Inspect the existing session; do not start another deployment."}
        $walletUrl="http://127.0.0.1:$BrowserPort/"
        Write-Host "WALLET CONNECTION URL: $walletUrl"
        Write-Host 'Keep this URL ready in your normal Windows browser with MetaMask. It works only after Foundry starts; refresh if initially unavailable.'
        Write-Host 'Before typing DEPLOY, inspect MetaMask Activity for this sender on Arc Testnet. If a deployment is queued/pending, stop and inspect it instead of retrying.'
    }
    $confirmation=Read-Host 'Type DEPLOY to open your signer for this Arc Testnet contract creation'
    if($confirmation -cne 'DEPLOY'){Write-Host 'Cancelled before signing';return}
    $forgeArgs=@('create','contracts/MicroCover.sol:MicroCover','--rpc-url',$plan.rpc,'--chain','5042002','--from',$Sender,'--gas-limit',[string]$plan.gasLimit)
    if($Signer -eq 'Browser') {
        $forgeArgs+=@('--browser','--browser-port',[string]$BrowserPort,'--browser-disable-open')
        Write-Host "OPEN NOW when ready: $walletUrl (refresh as soon as Foundry says Waiting for wallet connection)."
        Write-Host 'A Windows helper will also open this URL once the Foundry page responds. It never connects or signs. Select the sender above and Arc Testnet; review contract creation before confirming in MetaMask.'
        # The human-run wrapper starts ONE forge process below. This helper only
        # waits for that process's HTTP page and opens it through Windows.
        $browserOpener=Start-Job -ArgumentList $walletUrl -ScriptBlock {
            param($url)
            $until=[DateTime]::UtcNow.AddSeconds(90)
            while([DateTime]::UtcNow -lt $until) {
                try {
                    $page=Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 1
                    if($page.StatusCode -eq 200 -and $page.Content -match '<title>Foundry</title>') {
                        Start-Process -FilePath $url
                        return
                    }
                } catch { }
                Start-Sleep -Milliseconds 250
            }
            Write-Warning "Automatic browser opening timed out. Manually open $url while the original Foundry process is running. Do not launch a second deployment."
        }
    } else {
        $forgeArgs+=@('--account',$Account)
        Write-Host "Foundry will unlock encrypted account '$Account' via its hidden terminal password prompt. Do not supply a password/key as a command argument."
    }
    $forgeArgs+=@('--broadcast','--constructor-args',$plan.usdc,$plan.operator,'120','120')
    # Executed ONLY by the human after -Broadcast and the explicit review above.
    & wsl --cd $wslRoot --exec $forge @forgeArgs
    if($LASTEXITCODE -ne 0){throw 'Foundry did not report completion. Check wallet/activity before retrying; do not assume nothing was broadcast.'}
    Write-Host 'Keep the public transaction hash and address. Do not use the app yet; independent receipt/runtime/config verification comes first.'
} finally {
    if($null -ne $browserOpener) {
        if($browserOpener.State -eq 'Running'){Stop-Job -Job $browserOpener}
        Receive-Job -Job $browserOpener
        Remove-Job -Job $browserOpener
    }
    Pop-Location
}
