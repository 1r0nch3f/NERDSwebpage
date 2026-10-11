# NERDS Computer Repair - PC Report (one-line version)
# Run:  irm https://www.chattnerds.com/report.ps1 | iex
# Collects a READ-ONLY diagnostic report (hardware, drivers, crashes, Event Viewer,
# game crash logs) and sends it straight to Mike. No personal files, photos,
# passwords, browser history or messages are collected. Nothing is changed.
# chattnerds.com  |  (423) 521-5694

$NerdsSelf = 'https://www.chattnerds.com/report.ps1'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Upload = 'https://script.google.com/macros/s/AKfycbxs3Gd2ymT46niXQMmQnIqV1dQB9vRUePMs8OBKCO90C4YPEBWvGKpqvM-ZocdmASX-/exec'
$Nested = [bool]$env:NERDS_RID   # called from remote.ps1 (already admin, has its own "Press Enter")

function Say([string]$m, [string]$c = 'White') { Write-Host $m -ForegroundColor $c }

if (-not $Nested) {
    Write-Host ''
    Say 'NERDS Computer Repair - PC Report' 'Green'
    Say 'chattnerds.com  |  (423) 521-5694' 'Gray'
    Write-Host ''
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Say 'Opening an administrator window for the full report. Click Yes when Windows asks.' 'Yellow'
        Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm $NerdsSelf | iex"
        return
    }
    Say 'This collects a full report for Mike (hardware, drivers, errors and crash'
    Say 'logs). It takes 2-5 minutes. Leave this window open until it says done.'
}
$deep = $true

$core = Join-Path $env:TEMP 'nerds-pc-report.ps1'
try {
    Invoke-WebRequest 'https://www.chattnerds.com/nerds-pc-report.ps1' -OutFile $core -UseBasicParsing
} catch {
    Say "Couldn't download the report tool: $($_.Exception.Message)" 'Red'
    Say 'Call Mike: (423) 521-5694'
    if (-not $Nested) { Read-Host 'Press Enter to close this window' | Out-Null }
    return
}

Write-Host ''
Say ("Collecting the PC report (read-only{0})..." -f $(if ($deep) { ', deep: 2-5 minutes' } else { ', about a minute' })) 'Cyan'
$env:NERDS_REPORT_QUIET = '1'
if ($deep) { $env:NERDS_REPORT_DEEP = '1' } else { Remove-Item Env:NERDS_REPORT_DEEP -ErrorAction SilentlyContinue }
$report = ''
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $core *>&1 | ForEach-Object {
    $s = "$_".Trim()
    if ($s -match '\.(zip|txt)$' -and (Test-Path -LiteralPath $s)) { $report = $s }
    elseif ($s.StartsWith('- ')) { Say "   $s" 'Gray' }
}
Remove-Item $core -Force -ErrorAction SilentlyContinue

if (-not $report) {
    Say "The report didn't finish. Mike can run it with you later: (423) 521-5694" 'Red'
} else {
    Say 'Sending it to Mike...' 'Cyan'
    $ok = $false
    try {
        $body = @{
            key  = 'nerds-report-v1'
            name = (Split-Path $report -Leaf)
            pc   = $env:COMPUTERNAME
            user = $env:USERNAME
            rid  = "$env:NERDS_RID"
            data = [Convert]::ToBase64String([IO.File]::ReadAllBytes($report))
        } | ConvertTo-Json
        $r = Invoke-RestMethod $Upload -Method Post -Body $body -ContentType 'application/json'
        $ok = [bool]$r.ok
    } catch {}
    $txt = [IO.Path]::ChangeExtension($report, '.txt')
    if ($report -ne $txt) { Remove-Item -LiteralPath $txt -Force -ErrorAction SilentlyContinue }   # it's inside the zip
    if ($ok) {
        Remove-Item -LiteralPath $report -Force -ErrorAction SilentlyContinue   # Mike has it; keep the Desktop clean
        Say 'Report sent. Mike has it.' 'Green'
    }
    else {
        Say "Couldn't send the report automatically. It's saved on your Desktop:" 'Red'
        Say "  $report"
        Say '  Please email it to mike@chattnerds.com.'
    }
}
Remove-Item Env:NERDS_RID -ErrorAction SilentlyContinue
if (-not $Nested) { Write-Host ''; Read-Host 'Press Enter to close this window' | Out-Null }
