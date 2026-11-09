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
    Say 'This collects a full report for Mike (every part in the PC, drivers, errors and'
    Say 'crash logs) and tests the parts. It takes 8-12 minutes, and the PC runs hard for a'
    Say 'few minutes near the end: that is the test. Leave this window open until it says done.'
}
$stream = $false
if (-not $Nested) {
    Write-Host ''
    $a = Read-Host 'Is this for a streaming or camera problem? Type Y or N, then press Enter'
    $stream = $a -match '^\s*y'
    if ($stream) {
        Write-Host ''
        Say 'OK. Now open your game and OBS (or Streamlabs), turn your camera on, and play like normal.' 'Yellow'
        Say 'Take your time. You do NOT need to come back to this window: the report waits for your' 'Yellow'
        Say 'game (up to 10 minutes), measures it, and sends itself to Mike when it is done.' 'Yellow'
    }
}

$core = Join-Path $env:TEMP 'nerds-pc-report.ps1'
try {
    Invoke-WebRequest 'https://www.chattnerds.com/nerds-pc-report.ps1' -OutFile $core -UseBasicParsing
} catch {
    Say "Couldn't download the report tool: $($_.Exception.Message)" 'Red'
    Say 'Call Mike: (423) 521-5694'
    if (-not $Nested) { Read-Host 'Press Enter to close this window' | Out-Null }
    return
}

function Send-File([string]$path, [string]$name = '') {
    try {
        $body = @{
            key  = 'nerds-report-v1'
            name = $(if ($name) { $name } else { Split-Path $path -Leaf })
            pc   = $env:COMPUTERNAME
            user = $env:USERNAME
            rid  = "$env:NERDS_RID"
            data = [Convert]::ToBase64String([IO.File]::ReadAllBytes($path))
        } | ConvertTo-Json
        return [bool](Invoke-RestMethod $Upload -Method Post -Body $body -ContentType 'application/json').ok
    } catch { return $false }
}

Write-Host ''
Say 'Collecting the PC report and testing the parts (read-only, 8-12 minutes)...' 'Cyan'
$env:NERDS_REPORT_QUIET = '1'
Remove-Item Env:NERDS_REPORT_DEEP -ErrorAction SilentlyContinue   # Deep is always on in the core since 2026-11-09
if ($stream) { $env:NERDS_REPORT_STREAM = '1' } else { Remove-Item Env:NERDS_REPORT_STREAM -ErrorAction SilentlyContinue }
$report = ''
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $core *>&1 | ForEach-Object {
    $s = "$_".Trim()
    if ($s -match '^PRE-TESTS: (.+\.txt)$') {
        # The report is saved before the part tests run: send that copy now, so Mike has it even if the tests crash the PC.
        $pre = $Matches[1]
        if (Test-Path -LiteralPath $pre) { [void](Send-File $pre ([IO.Path]::GetFileNameWithoutExtension($pre) + '_before-tests.txt')) }
    }
    elseif ($s -match '\.(zip|txt)$' -and (Test-Path -LiteralPath $s)) { $report = $s }
    elseif ($s.StartsWith('- ')) { Say "   $s" 'Gray' }
}
Remove-Item $core -Force -ErrorAction SilentlyContinue

if (-not $report) {
    Say "The report didn't finish. Mike can run it with you later: (423) 521-5694" 'Red'
} else {
    Say 'Sending it to Mike...' 'Cyan'
    # The small text summary goes up on its own first (2026-11-02): Deep zips run ~10 MB, too big for
    # Mike's AI to open from Drive, while the summary is a few dozen KB and is what gets read first.
    $txt = [IO.Path]::ChangeExtension($report, '.txt')
    if ($report -ne $txt -and (Test-Path -LiteralPath $txt)) { [void](Send-File $txt) }
    $ok = Send-File $report
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
Remove-Item Env:NERDS_REPORT_STREAM -ErrorAction SilentlyContinue
if (-not $Nested) { Write-Host ''; Read-Host 'Press Enter to close this window' | Out-Null }
