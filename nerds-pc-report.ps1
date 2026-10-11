# NERDS PC Report - collects system and health info so NERDS Computer Repair
# can diagnose a PC without walking the owner through menus.
# READ-ONLY. It does not change anything, and it does not collect personal
# files, photos, passwords, browser history or messages.
# Output: a text file on the Desktop that the owner sends to Mike.
# Windows PowerShell 5.1 compatible. Run as administrator for full detail.

$ErrorActionPreference = 'SilentlyContinue'
if ($args -contains '-Deep') { $env:NERDS_REPORT_DEEP = '1' }   # set by "Run NERDS DEEP Report.bat"
$ProgressPreference = 'SilentlyContinue'
$stamp   = Get-Date -Format 'yyyy-MM-dd_HHmm'
$desktop = [Environment]::GetFolderPath('Desktop')
$out     = Join-Path $desktop ("NERDS-PC-Report_{0}_{1}.txt" -f $env:COMPUTERNAME, $stamp)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$sb = New-Object System.Text.StringBuilder
function W([string]$s = '') { [void]$sb.AppendLine($s) }
function Section([string]$t) { W ''; W ('=' * 70); W "  $t"; W ('=' * 70) }
function T($obj) { if ($obj) { W (($obj | Format-Table -AutoSize -Wrap | Out-String -Width 200).TrimEnd()) } else { W '  (none found)' } }
function Step([string]$m) { Write-Host "  - $m" -ForegroundColor Cyan }

Write-Host ''
Write-Host '  NERDS PC Report' -ForegroundColor Green
Write-Host '  Collecting system info (read-only). This takes about a minute.' -ForegroundColor Gray
Write-Host ''

W 'NERDS PC REPORT  -  NERDS Computer Repair  -  chattnerds.com  -  423-521-5694'
W ("Created: {0}   Computer: {1}   Ran as admin: {2}" -f (Get-Date), $env:COMPUTERNAME, $isAdmin)
W 'Contains system and hardware info only. No personal files, photos, passwords,'
W 'browser history or messages are collected. Nothing on this PC was changed.'

Step 'System'
Section 'SYSTEM'
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$bios = Get-CimInstance Win32_BIOS
$bb = Get-CimInstance Win32_BaseBoard
$enc = Get-CimInstance Win32_SystemEnclosure
$isLaptop = [bool](Get-CimInstance Win32_Battery) -or (@(8,9,10,11,12,14,18,21,30,31,32) -contains ($enc.ChassisTypes | Select-Object -First 1))
W ("Make / model : {0} {1}   ({2})" -f $cs.Manufacturer, $cs.Model, $(if ($isLaptop) { 'LAPTOP' } else { 'desktop' }))
W ("Serial       : {0}" -f $bios.SerialNumber)
W ("Motherboard  : {0} {1}" -f $bb.Manufacturer, $bb.Product)
W ("BIOS         : {0} {1}  dated {2}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)
W ("Windows      : {0}  version {1}  build {2}" -f $os.Caption, (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion, $os.BuildNumber)
W ("Installed    : {0}   Last boot: {1}" -f $os.InstallDate, $os.LastBootUpTime)
$lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND Name LIKE 'Windows%'" | Select-Object -First 1
W ("Activation   : {0}" -f $(switch ($lic.LicenseStatus) { 1 {'Activated'} default {"NOT activated (status $($lic.LicenseStatus))"} }))

Step 'Processor and memory'
Section 'PROCESSOR AND MEMORY'
$cpu = Get-CimInstance Win32_Processor
foreach ($c in $cpu) { W ("CPU          : {0}  ({1} cores / {2} threads, {3} MHz max)" -f $c.Name.Trim(), $c.NumberOfCores, $c.NumberOfLogicalProcessors, $c.MaxClockSpeed) }
W ("RAM total    : {0:N1} GB   free now: {1:N1} GB" -f ($cs.TotalPhysicalMemory / 1GB), ($os.FreePhysicalMemory * 1KB / 1GB))
T (Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, DeviceLocator, @{n='GB';e={[math]::Round($_.Capacity/1GB)}}, @{n='MHz';e={$_.ConfiguredClockSpeed}}, Manufacturer, PartNumber)
$pf = Get-CimInstance Win32_PageFileUsage
W ("Page file    : {0}" -f $(if ($pf) { ($pf | ForEach-Object { "$($_.Name) $($_.AllocatedBaseSize) MB" }) -join ', ' } else { 'NONE (can cause game crashes)' }))

Step 'Graphics'
Section 'GRAPHICS'
$gpus = Get-CimInstance Win32_VideoController
foreach ($g in $gpus) {
    W ("GPU          : {0}" -f $g.Name)
    W ("  driver     : {0}  dated {1}   status {2}" -f $g.DriverVersion, $g.DriverDate, $g.Status)
    W ("  resolution : {0} x {1} @ {2} Hz" -f $g.CurrentHorizontalResolution, $g.CurrentVerticalResolution, $g.CurrentRefreshRate)
}
# real VRAM (Win32_VideoController caps at 4 GB)
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    if ($p.DriverDesc -and $p.'HardwareInformation.qwMemorySize') { W ("VRAM         : {0}  {1:N1} GB" -f $p.DriverDesc, ($p.'HardwareInformation.qwMemorySize' / 1GB)) }
}
if ($gpus.Count -gt 1) { W 'NOTE: more than one GPU. Games may be running on the weaker one.' }
$mon = Get-CimInstance -Namespace root\wmi WmiMonitorID
if ($mon) { W ("Monitors     : {0}" -f (($mon | ForEach-Object { -join ($_.UserFriendlyName | Where-Object { $_ } | ForEach-Object { [char]$_ }) }) -join ', ')) }

Step 'DirectX (dxdiag, about 20 seconds)'
$dx = Join-Path $env:TEMP "nerds_dxdiag_$stamp.txt"
Start-Process dxdiag -ArgumentList "/t `"$dx`"" -Wait -WindowStyle Hidden
if (Test-Path $dx) {
    $dxl = Get-Content $dx
    W ''
    W 'dxdiag highlights:'
    $dxl | Where-Object { $_ -match '^\s*(DirectX Version|Card name|Driver Version|Driver Date/Size|Dedicated Memory|Shared Memory|Feature Levels|Driver Model|Hardware Scheduling|Notes)\s*:' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -notmatch 'Unknown$' } | Select-Object -Unique -First 30 | ForEach-Object { W ("  " + $_) }
    Remove-Item $dx -Force
}

Step 'Drives'
Section 'DRIVES'
T (Get-PhysicalDisk | Select-Object FriendlyName, MediaType, BusType, @{n='GB';e={[math]::Round($_.Size/1GB)}}, HealthStatus, OperationalStatus)
$rel = Get-PhysicalDisk | Get-StorageReliabilityCounter
if ($rel) { W 'Wear / errors:'; T ($rel | Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours) }
$smart = Get-CimInstance -Namespace root\wmi MSStorageDriver_FailurePredictStatus
if ($smart) { foreach ($s in $smart) { W ("SMART predicts failure: {0}   ({1})" -f $s.PredictFailure, $s.InstanceName) } }
T (Get-Volume | Where-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem, @{n='SizeGB';e={[math]::Round($_.Size/1GB,1)}}, @{n='FreeGB';e={[math]::Round($_.SizeRemaining/1GB,1)}}, @{n='Free%';e={if($_.Size){[math]::Round(100*$_.SizeRemaining/$_.Size)}}}, HealthStatus)

if ($isLaptop) {
    Step 'Battery'
    Section 'BATTERY'
    $bs = Get-CimInstance -Namespace root\wmi BatteryStaticData
    $bf = Get-CimInstance -Namespace root\wmi BatteryFullChargedCapacity
    if ($bs -and $bf) { W ("Design capacity {0} mWh, full charge now {1} mWh  ->  {2:N0}% of original" -f $bs.DesignedCapacity, $bf.FullChargedCapacity, (100 * $bf.FullChargedCapacity / [math]::Max(1,$bs.DesignedCapacity))) }
    T (Get-CimInstance Win32_Battery | Select-Object Name, EstimatedChargeRemaining, BatteryStatus)
    W ("Power plan   : {0}" -f ((powercfg /getactivescheme) -replace '.*\((.*)\).*','$1'))
}

Step 'Crashes and errors (last 14 days)'
Section 'CRASHES AND ERRORS (last 14 days)'
$since = (Get-Date).AddDays(-14)
$bsod = Get-WinEvent -FilterHashtable @{LogName='System'; Id=1001; ProviderName='Microsoft-Windows-WER-SystemErrorReporting'; StartTime=$since}
W ("Blue screens (BugCheck): {0}" -f @($bsod).Count)
$bsod | Select-Object -First 5 | ForEach-Object { W ("  {0}  {1}" -f $_.TimeCreated, (($_.Message -split "`n")[0]).Trim()) }
$kp = Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; ProviderName='Microsoft-Windows-Kernel-Power'; StartTime=$since}
W ("Sudden power-offs / hard resets (Kernel-Power 41): {0}" -f @($kp).Count)
$tdr = Get-WinEvent -FilterHashtable @{LogName='System'; Id=4101; StartTime=$since}
W ("Graphics driver stopped responding (TDR 4101): {0}" -f @($tdr).Count)
$tdr | Select-Object -First 5 | ForEach-Object { W ("  {0}  {1}" -f $_.TimeCreated, (($_.Message -split "`n")[0]).Trim()) }
$whea = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; StartTime=$since}
W ("Hardware errors (WHEA): {0}" -f @($whea).Count)
$whea | Select-Object -First 3 | ForEach-Object { W ("  {0}  {1}" -f $_.TimeCreated, (($_.Message -split "`n")[0]).Trim()) }
$dumps = Get-ChildItem 'C:\Windows\Minidump' -Filter *.dmp | Sort-Object LastWriteTime -Descending
W ("Crash dump files: {0}" -f @($dumps).Count)
$dumps | Select-Object -First 5 | ForEach-Object { W ("  {0}  {1}" -f $_.LastWriteTime, $_.Name) }

W ''
W 'Programs that crashed (Application Error 1000), most frequent:'
$appErr = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; ProviderName='Application Error'; StartTime=$since}
$appErr | ForEach-Object {
    $m = $_.Message
    $app = if ($m -match 'Faulting application name: ([^,]+)') { $Matches[1] } else { '?' }
    $mod = if ($m -match 'Faulting module name: ([^,]+)') { $Matches[1] } else { '?' }
    [pscustomobject]@{ App = $app; Module = $mod }
} | Group-Object App, Module | Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object { W ("  {0,3}x  {1}" -f $_.Count, $_.Name) }

W ''
W 'Unreal Engine / game crash folders (most recent):'
$ue = foreach ($root in @($env:LOCALAPPDATA)) {
    Get-ChildItem $root -Directory | ForEach-Object { Get-ChildItem (Join-Path $_.FullName 'Saved\Crashes') -Directory }
}
if ($ue) {
    $ue | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | ForEach-Object {
        W ("  {0}  {1}" -f $_.LastWriteTime, $_.FullName.Replace($env:LOCALAPPDATA, '%LOCALAPPDATA%'))
        $ctx = Get-ChildItem $_.FullName -Filter 'CrashContext.runtime-xml' | Select-Object -First 1
        if ($ctx) {
            $x = Get-Content $ctx.FullName -Raw
            if ($x -match '<ErrorMessage>(.*?)</ErrorMessage>') { W ("      error: " + ($Matches[1] -replace '\s+', ' ').Substring(0, [math]::Min(300, $Matches[1].Length))) }
            if ($x -match '<RHIName>(.*?)</RHIName>') { W ("      graphics API: " + $Matches[1]) }
        }
    }
} else { W '  (none found)' }

W ''
W 'Other recent System errors (top 15 by count):'
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} |
    Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 15 |
    ForEach-Object { W ("  {0,3}x  {1}" -f $_.Count, $_.Name) }

Step 'Event Viewer details'
Section 'EVENT VIEWER: RECENT CRITICAL AND ERROR EVENTS (full detail, last 14 days)'
function Ev($e) {
    $msg = (($e.Message -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 4) -join ' | '
    if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
    W ("{0}  [{1}] {2}  ID {3}" -f $e.TimeCreated.ToString('MM/dd HH:mm'), $e.LevelDisplayName, $e.ProviderName, $e.Id)
    W ("    {0}" -f $(if ($msg) { $msg } else { '(no message text)' }))
}
W 'SYSTEM log, newest 25:'
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -MaxEvents 25 | ForEach-Object { Ev $_ }
W ''
W 'APPLICATION log, newest 25:'
Get-WinEvent -FilterHashtable @{LogName='Application'; Level=1,2; StartTime=$since} -MaxEvents 25 | ForEach-Object { Ev $_ }
W ''
W 'Programs that froze (Application Hang 1002), newest 10:'
$hang = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1002; ProviderName='Application Hang'; StartTime=$since} -MaxEvents 10
if ($hang) { $hang | ForEach-Object { Ev $_ } } else { W '  (none)' }
W ''
W 'Windows Error Reporting crash details (WER 1001), newest 10:'
$wer = Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1001; ProviderName='Windows Error Reporting'; StartTime=$since} -MaxEvents 10
if ($wer) { $wer | ForEach-Object { Ev $_ } } else { W '  (none)' }
W ''
W 'Kernel crash reports (LiveKernelEvent codes from Windows Error Reporting):'
W '  141 = graphics driver hung and was reset, 117 = graphics driver timed out,'
W '  1a8/1b8 = graphics/display kernel issue, ab = session teardown, 193 = video memory issue'
$werDirs = @('C:\ProgramData\Microsoft\Windows\WER\ReportArchive', 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue') |
    ForEach-Object { Get-ChildItem $_ -Directory } | Where-Object { $_.LastWriteTime -gt $since }
$lke = foreach ($d in $werDirs) {
    $r = Join-Path $d.FullName 'Report.wer'
    if (-not (Test-Path $r)) { continue }
    $txt = Get-Content $r -Encoding Unicode -Raw
    if ($txt -notmatch 'EventType=(LiveKernelEvent|BlueScreen)') { continue }
    $code = if ($txt -match 'Sig\[0\]\.Value=([0-9A-Fa-f]+)') { $Matches[1].ToLower() } else { '?' }
    $drv = if ($txt -match 'Sig\[\d\]\.Name=(?:Failure|Faulting)[^\r\n]*\r?\nSig\[\d\]\.Value=([^\r\n]+)') { $Matches[1] } else { '' }
    [pscustomobject]@{ When = $d.LastWriteTime; Type = $Matches[0] -replace '.*=', ''; Code = $code; Detail = $drv }
}
if ($lke) {
    $lke | Group-Object Code | Sort-Object Count -Descending | ForEach-Object { W ("  code {0}: {1}x, last {2}" -f $_.Name, $_.Count, ($_.Group | Sort-Object When -Descending | Select-Object -First 1).When) }
} else { W '  (none)' }
W ''
W 'Graphics driver events (AMD / NVIDIA / Intel / Display), newest 15:'
$gfx = Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=$since} |
    Where-Object { $_.ProviderName -match 'amdkmdag|amdwddmg|amdfendr|nvlddmkm|igfx|Display|dxgkrnl' } | Select-Object -First 15
if ($gfx) { $gfx | ForEach-Object { Ev $_ } } else { W '  (none)' }

Step 'Drivers with problems'
Section 'DEVICES WITH PROBLEMS'
T (Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } | Select-Object Name, @{n='ErrorCode';e={$_.ConfigManagerErrorCode}}, DeviceID)

Step 'Security and updates'
Section 'SECURITY AND UPDATES'
T (Get-CimInstance -Namespace root/SecurityCenter2 AntiVirusProduct | Select-Object displayName, productState)
$mp = Get-MpComputerStatus
if ($mp) { W ("Defender: real-time {0}, signatures {1}, last quick scan {2}" -f $mp.RealTimeProtectionEnabled, $mp.AntivirusSignatureLastUpdated, $mp.QuickScanEndTime) }
W 'Recent Windows updates:'
T (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 8 HotFixID, Description, InstalledOn)
$wuFail = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; Id=20; StartTime=$since}
W ("Failed update installs (14 days): {0}" -f @($wuFail).Count)

Step 'Installed programs and startup'
Section 'INSTALLED PROGRAMS'
$apps = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*') |
    ForEach-Object { Get-ItemProperty $_ } | Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
    Sort-Object DisplayName -Unique
W ("{0} programs installed." -f @($apps).Count)
$flag = 'Afterburner|RivaTuner|RTSS|Overwolf|Wallpaper Engine|Razer Cortex|Driver Booster|Driver Easy|CCleaner|McAfee|Norton|Avast|AVG|Avira|Webroot|PC Optimizer|Ryzen Master|Armoury|iCUE|Lightshot|Discord|GeForce Experience|NVIDIA App|AMD Software|Steam|Epic Games|Battle\.net|EA app|Ubisoft'
W 'Programs that commonly matter for games / performance:'
$apps | Where-Object { $_.DisplayName -match $flag } | ForEach-Object { W ("  {0}  {1}" -f $_.DisplayName, $_.DisplayVersion) }
W ''
W 'Full list:'
$apps | ForEach-Object { W ("  {0}  {1}" -f $_.DisplayName, $_.DisplayVersion) }

Section 'STARTUP ITEMS'
T (Get-CimInstance Win32_StartupCommand | Select-Object Name, Location)

Step 'Network'
Section 'NETWORK'
T (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed, MediaType)
T (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object InterfaceAlias, @{n='IPv4';e={$_.IPv4Address.IPAddress}}, @{n='Gateway';e={$_.IPv4DefaultGateway.NextHop}}, @{n='DNS';e={($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses -join ', '}})
$wlan = netsh wlan show interfaces 2>$null | Select-String 'Signal|Radio type|Receive rate'
if ($wlan) { $wlan | ForEach-Object { W ("  " + $_.Line.Trim()) } }

W ''
W 'Attached in the zip: System.evtx and Application.evtx (last 14 days, warnings and errors)'
W 'for opening in Event Viewer.'
W '--- end of report ---'
[IO.File]::WriteAllText($out, $sb.ToString(), [Text.Encoding]::UTF8)

# Raw Event Viewer logs (warnings and up, last 14 days) so Mike can open them in Event Viewer.
Step 'Exporting Event Viewer logs'
$work = Join-Path $env:TEMP "NERDS-Report-$stamp"
New-Item -ItemType Directory -Force $work | Out-Null
Copy-Item $out $work
$ms = [int64](14 * 24 * 3600 * 1000)
$q = "*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[timediff(@SystemTime) <= $ms]]]"
foreach ($log in 'System', 'Application') {
    wevtutil epl $log (Join-Path $work "$log.evtx") "/q:$q" /ow:true 2>$null
}

# ---------------- DEEP mode: everything needed to pin down a crash in one pull ----------------
$bigDumps = @()
if ($env:NERDS_REPORT_DEEP) {
    $deep = Join-Path $work 'Deep'
    New-Item -ItemType Directory -Force $deep | Out-Null
    $ms30 = [int64](30 * 24 * 3600 * 1000)
    $q30 = "*[System[TimeCreated[timediff(@SystemTime) <= $ms30]]]"

    Step 'DEEP: full event logs (30 days, every level)'
    $evDir = Join-Path $deep 'EventLogs'; New-Item -ItemType Directory -Force $evDir | Out-Null
    foreach ($log in 'System', 'Application',
                     'Microsoft-Windows-Kernel-PnP/Configuration',
                     'Microsoft-Windows-Kernel-WHEA/Errors',
                     'Microsoft-Windows-Kernel-WHEA/Operational',
                     'Microsoft-Windows-DxgKrnl-Admin',
                     'Microsoft-Windows-DxgKrnl-Operational',
                     'Microsoft-Windows-Display/Operational',
                     'Microsoft-Windows-Kernel-LiveDump/Operational',
                     'Microsoft-Windows-Kernel-Power/Thermal-Operational',
                     'Microsoft-Windows-WindowsUpdateClient/Operational') {
        $exists = wevtutil gl $log 2>$null
        if ($LASTEXITCODE -eq 0) {
            $file = Join-Path $evDir (($log -replace '[/\\]', '_') + '.evtx')
            wevtutil epl $log $file "/q:$q30" /ow:true 2>$null
        }
    }

    Step 'DEEP: game crash logs (Unreal Saved\Logs and Crashes)'
    $gl = Join-Path $deep 'GameLogs'; New-Item -ItemType Directory -Force $gl | Out-Null
    Get-ChildItem $env:LOCALAPPDATA -Directory | ForEach-Object {
        $game = $_.Name
        $logs = Get-ChildItem (Join-Path $_.FullName 'Saved\Logs') -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        $crashes = Get-ChildItem (Join-Path $_.FullName 'Saved\Crashes') -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 3
        if ($logs -or $crashes) {
            $gd = Join-Path $gl $game; New-Item -ItemType Directory -Force $gd | Out-Null
            $logs | ForEach-Object { Copy-Item $_.FullName $gd }
            foreach ($c in $crashes) {   # small text files only (no big dumps)
                $cd = Join-Path $gd ("Crash_" + $c.Name); New-Item -ItemType Directory -Force $cd | Out-Null
                Get-ChildItem $c.FullName -File | Where-Object { $_.Extension -in '.xml', '.log', '.txt', '.json' -or $_.Name -like '*.runtime-xml' } |
                    Where-Object { $_.Length -lt 20MB } | ForEach-Object { Copy-Item $_.FullName $cd }
            }
        }
    }

    Step 'DEEP: Windows crash and GPU hang reports'
    $wr = Join-Path $deep 'CrashReports'; New-Item -ItemType Directory -Force $wr | Out-Null
    foreach ($root in 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive', 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue') {
        Get-ChildItem $root -Directory | Where-Object { $_.LastWriteTime -gt (Get-Date).AddDays(-30) } | ForEach-Object {
            $r = Join-Path $_.FullName 'Report.wer'
            if (Test-Path $r) { Copy-Item $r (Join-Path $wr ($_.Name + '.wer')) }
        }
    }
    Get-ChildItem 'C:\Windows\Minidump' -Filter *.dmp | Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
        ForEach-Object { Copy-Item $_.FullName $wr }
    # GPU watchdog / live kernel dumps are often 100s of MB: list them, don't zip them
    $bigDumps = Get-ChildItem 'C:\Windows\LiveKernelReports' -Recurse -Filter *.dmp | Sort-Object LastWriteTime -Descending
    $bigDumps | Select-Object FullName, @{n='MB';e={[math]::Round($_.Length/1MB)}}, LastWriteTime |
        Format-Table -AutoSize | Out-String -Width 200 | Set-Content (Join-Path $wr 'LiveKernelReports-list.txt')
    # small ones (under 8 MB) can ride along
    $bigDumps | Where-Object { $_.Length -lt 8MB } | Select-Object -First 3 | ForEach-Object { Copy-Item $_.FullName $wr }

    Step 'DEEP: Reliability Monitor history (30 days)'
    Get-CimInstance Win32_ReliabilityRecords | Where-Object { $_.TimeGenerated -gt (Get-Date).AddDays(-30) } |
        Sort-Object TimeGenerated -Descending |
        Select-Object TimeGenerated, SourceName, EventIdentifier, ProductName, @{n='Message';e={($_.Message -replace '\s+', ' ').Substring(0, [math]::Min(300, $_.Message.Length))}} |
        Export-Csv (Join-Path $deep 'ReliabilityHistory.csv') -NoTypeInformation -Encoding UTF8

    Step 'DEEP: full DirectX diagnostics'
    Start-Process dxdiag -ArgumentList "/t `"$(Join-Path $deep 'dxdiag.txt')`"" -Wait -WindowStyle Hidden

    Step 'DEEP: full System Information (1 to 2 minutes)'
    Start-Process msinfo32.exe -ArgumentList "/report `"$(Join-Path $deep 'msinfo32.txt')`"" -Wait -WindowStyle Hidden

    Step 'DEEP: drivers, BIOS mode, boot settings'
    $drv = Join-Path $deep 'Drivers-and-Boot.txt'
    & { 'Display drivers installed in the driver store:'; pnputil /enum-drivers /class Display 2>$null
        ''; 'Firmware: '; try { $env:firmware_type } catch {}
        'Secure Boot on: '; try { Confirm-SecureBootUEFI } catch { 'unknown (legacy BIOS/CSM or no access)' }
        ''; 'bcdedit:'; bcdedit /enum '{current}' 2>$null
        ''; 'GPU registry (driver desc, version, date, memory):'
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath; if ($p.DriverDesc) { "  {0} | {1} | {2} | {3:N1} GB" -f $p.DriverDesc, $p.DriverVersion, $p.DriverDate, ($p.'HardwareInformation.qwMemorySize'/1GB) } }
        ''; 'Page file settings:'; Get-CimInstance Win32_PageFileSetting | Format-List | Out-String
        ''; 'Power plan:'; powercfg /getactivescheme
    } | Out-File $drv -Encoding UTF8 -Width 250
}

$zip = [IO.Path]::ChangeExtension($out, '.zip')
Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
Remove-Item $work -Recurse -Force
$send = if (Test-Path $zip) { $zip } else { $out }

Write-Host ''
Write-Host '  Done! Your report is saved on your Desktop:' -ForegroundColor Green
Write-Host "  $send" -ForegroundColor White
Write-Host ''
Write-Host '  Please send that file to Mike (drag it into Discord, or email it to mike@chattnerds.com).' -ForegroundColor Yellow
$zipMB = if (Test-Path $zip) { (Get-Item $zip).Length / 1MB } else { 0 }
if ($zipMB -gt 9.5) {
    Write-Host ("  It's {0:N0} MB, which is too big for Discord: email it, or upload it to Google Drive and send the link." -f $zipMB) -ForegroundColor Yellow
}
$huge = @($bigDumps | Where-Object { $_.Length -ge 8MB })
if ($huge.Count) {
    Write-Host ("  Note: there are {0} large GPU crash dump file(s) in C:\Windows\LiveKernelReports. Mike may ask for them later." -f $huge.Count) -ForegroundColor Gray
}
Write-Host ''
if (-not $env:NERDS_REPORT_QUIET) {
    Start-Process explorer.exe -ArgumentList "/select,`"$send`""
    Read-Host '  Press Enter to close'
}
