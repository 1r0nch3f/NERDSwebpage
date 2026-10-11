# NERDS Computer Repair - Remote Support (one-line version)
# Run:  irm https://www.chattnerds.com/remote.ps1 | iex
# Installs the official RustDesk remote support app (signed by its publisher, checked
# before install), connects it ONLY to the NERDS server, sets a fresh password, sends
# Mike the ID and password, and can send Mike a read-only PC report.
# Run it again to get a new password, send a report, or remove it.
# chattnerds.com  |  (423) 521-5694

$NerdsSelf = 'https://www.chattnerds.com/remote.ps1'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Server   = 'nerdsremote.duckdns.org'
$Key      = 'Bpv131D6wAsqpv12yHksQLEzkUeLTBxXjZoGW+WXH4Y='
$Fallback = '1.5.0'
$Checkin  = 'https://formspree.io/f/xrewykkv'
$Rd       = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'

function Say([string]$m, [string]$c = 'White') { Write-Host $m -ForegroundColor $c }
function Done { Write-Host ''; Read-Host 'Press Enter to close this window' | Out-Null }

Write-Host ''
Say 'NERDS Computer Repair - Remote Support' 'Green'
Say 'chattnerds.com  |  (423) 521-5694' 'Gray'
Write-Host ''

# Not admin? Reopen this same script in an admin window (Windows asks "allow changes?": Yes).
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Say 'Opening an administrator window. Click Yes when Windows asks.' 'Yellow'
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm $NerdsSelf | iex"
    return
}

function Get-RdId {
    for ($i = 0; $i -lt 15; $i++) {
        $id = (& $Rd --get-id | Out-String) -replace '\D', ''
        if ($id.Length -ge 6) { return $id }
        Start-Sleep 2
    }
    return ''
}

function Send-Checkin($id, $pw, $action) {
    $body = @{
        _subject = "NERDS Remote: $env:COMPUTERNAME - ID $id"
        name     = 'NERDS Remote Support check-in'
        message  = "$action`nComputer: $env:COMPUTERNAME`nWindows user: $env:USERNAME`nRustDesk ID: $id`nPassword: $pw`nTime: $(Get-Date -Format 'yyyy-MM-dd h:mm tt')"
    } | ConvertTo-Json
    try { Invoke-RestMethod $Checkin -Method Post -Body $body -ContentType 'application/json' -Headers @{ Accept = 'application/json' } | Out-Null; return $true }
    catch { return $false }
}

function Set-NerdsPassword($action) {
    Say 'Connecting it to NERDS...' 'Cyan'
    & $Rd --option custom-rendezvous-server $Server | Out-Null
    & $Rd --option relay-server $Server | Out-Null
    & $Rd --option key $Key | Out-Null
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789'.ToCharArray()   # no look-alikes
    $pw = -join (1..10 | ForEach-Object { $chars | Get-Random })
    & $Rd --password $pw | Out-Null
    Restart-Service RustDesk -ErrorAction SilentlyContinue
    Start-Sleep 6
    $id = Get-RdId
    if (-not $id) { Say "Couldn't read the RustDesk ID. Call Mike: (423) 521-5694" 'Red'; return }
    $sent = Send-Checkin $id $pw $action
    Write-Host ''
    Say '  ==============================================' 'Green'
    Say '        NERDS REMOTE SUPPORT IS READY' 'Green'
    Say '  ==============================================' 'Green'
    Write-Host ''
    Say "     YOUR ID:        $id" 'Yellow'
    Say "     YOUR PASSWORD:  $pw" 'Yellow'
    Write-Host ''
    if ($sent) { Say '  Mike has been sent your ID and password automatically.'; Say "  Leave this computer on; he'll connect shortly." }
    else { Say "  Couldn't send these to Mike automatically." 'Red'; Say '  Please text or read them to Mike: (423) 521-5694' }
    Write-Host ''
    Say '  When the job is done, run the same line again and pick' 'Gray'
    Say "  'Remove NERDS Remote Support' to take it off." 'Gray'
    $script:NerdsId = $id
}

function Offer-Report {
    Write-Host ''
    Say 'Mike can also get a diagnostic report of this computer: hardware, drivers,'
    Say 'errors and crash logs. No personal files, photos, passwords or browsing'
    Say 'history are collected, and nothing is changed. It takes 2-5 minutes.'
    $a = (Read-Host 'Send Mike a diagnostic report now? (Y/n)').Trim().ToLower()
    if ($a -eq '' -or $a -eq 'y' -or $a -eq 'yes') {
        $env:NERDS_RID = $script:NerdsId
        irm 'https://www.chattnerds.com/report.ps1' | iex
    }
}

function Install-Nerds {
    Say 'This sets up a secure connection so Mike from NERDS can see and fix'
    Say 'this computer remotely. Nothing else on your computer is changed.'
    Write-Host ''
    $ver = $Fallback
    $url = "https://github.com/rustdesk/rustdesk/releases/download/$Fallback/rustdesk-$Fallback-x86_64.exe"
    try {
        $rel = Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -Headers @{ 'User-Agent' = 'NERDS-Remote-Support' }
        $asset = $rel.assets | Where-Object { $_.name -match '^rustdesk-.*-x86_64\.exe$' } | Select-Object -First 1
        if ($asset) { $ver = $rel.tag_name; $url = $asset.browser_download_url }
    } catch {}
    $tmp = Join-Path $env:TEMP 'nerds-rustdesk-setup.exe'
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Say "Downloading RustDesk $ver (official release)..." 'Cyan'
    try { Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing } catch {
        Say "Download failed: $($_.Exception.Message)" 'Red'; Say 'Check the internet connection and try again, or call Mike: (423) 521-5694'; return $false
    }
    $sig = Get-AuthenticodeSignature $tmp
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'PURSLANE') {
        Say 'The download failed its safety check (not signed by RustDesk). Stopping.' 'Red'
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue; return $false
    }
    Say 'Installing (this takes about a minute)...' 'Cyan'
    Start-Process $tmp -ArgumentList '--silent-install'   # no -Wait: the installer launches the app and never "finishes"
    for ($i = 0; $i -lt 90; $i++) {
        if ((Test-Path $Rd) -and ((Get-Service RustDesk -ErrorAction SilentlyContinue).Status -eq 'Running')) { break }
        Start-Sleep 2
    }
    if (-not (Test-Path $Rd)) { Say "RustDesk didn't finish installing. Call Mike: (423) 521-5694" 'Red'; return $false }
    Start-Sleep 5
    return $true
}

function Remove-Nerds {
    Say 'Removing NERDS Remote Support...' 'Cyan'
    Start-Process $Rd -ArgumentList '--uninstall' -Wait -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 30; $i++) { if (-not (Test-Path $Rd) -and -not (Get-Service RustDesk -ErrorAction SilentlyContinue)) { break }; Start-Sleep 2 }
    if ((Test-Path $Rd) -or (Get-Service RustDesk -ErrorAction SilentlyContinue)) { Say "Removal didn't finish. Remove 'RustDesk' from Settings > Apps, or call Mike." 'Red' }
    else { Say 'NERDS Remote Support has been removed. Nobody can connect to this computer now.' 'Green' }
}

try {
    if (-not (Test-Path $Rd)) {
        if (Install-Nerds) { Set-NerdsPassword 'New install'; if ($script:NerdsId) { Offer-Report } }
    } else {
        Say 'NERDS Remote Support is already on this computer.'
        Write-Host ''
        Say '  1  Show my ID and a new password (Mike gets them too)' 'Yellow'
        Say '  2  Send Mike a diagnostic report of this computer' 'Yellow'
        Say '  3  Remove NERDS Remote Support' 'Yellow'
        Say '  4  Close' 'Yellow'
        Write-Host ''
        switch ((Read-Host 'Type 1, 2, 3 or 4 and press Enter').Trim()) {
            '1' { Set-NerdsPassword 'New password requested' }
            '2' { $env:NERDS_RID = Get-RdId; irm 'https://www.chattnerds.com/report.ps1' | iex }
            '3' { Remove-Nerds }
        }
    }
} catch {
    Say "Something went wrong: $($_.Exception.Message)" 'Red'
    Say 'Call Mike: (423) 521-5694'
}
Done
