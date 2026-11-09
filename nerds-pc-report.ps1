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
Write-Host '  Collecting system info and testing the parts (read-only). This takes about 8 to 12 minutes.' -ForegroundColor Gray
Write-Host '  The PC will run hard for a few minutes near the end; that is the test. Leave it alone until it says Done.' -ForegroundColor Gray
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

# ---------------- PARTS INVENTORY (2026-11-09, Mike: "pull all parts it can and monitors as well") ----------------
# Every part Windows can identify, with serials and condition evidence, so a PC can be priced remotely.
Step 'Parts inventory'
Section 'PARTS INVENTORY (every part Windows can see, for pricing / resale)'
function WStr($a) { -join ($a | Where-Object { $_ } | ForEach-Object { [char]$_ }) }
$subVendor = @{ '1043'='ASUS'; '1462'='MSI'; '1458'='Gigabyte'; '3842'='EVGA'; '19DA'='Zotac'; '1569'='Palit'; '10B0'='Gainward'; '196E'='PNY'; '1DA2'='Sapphire'; '148C'='PowerColor'; '1682'='XFX'; '1849'='ASRock'; '1B4C'='Galax / KFA2'; '7377'='Colorful'; '10DE'='NVIDIA (Founders / reference)'; '1002'='AMD (reference)'; '8086'='Intel'; '1028'='Dell'; '103C'='HP'; '17AA'='Lenovo'; '1025'='Acer'; '1558'='Clevo'; '1414'='Microsoft'; '144D'='Samsung'; '106B'='Apple'; '1ACC'='Point of View' }
$pnpVendor = @{ ACR='Acer'; AUS='ASUS'; BNQ='BenQ'; DEL='Dell'; GSM='LG'; SAM='Samsung'; SNY='Sony'; HWP='HP'; HPN='HP'; LEN='Lenovo'; MSI='MSI'; AOC='AOC'; VSC='ViewSonic'; PHL='Philips'; GBT='Gigabyte'; SHP='Sharp'; APP='Apple'; NEC='NEC'; IVM='iiyama'; EIZ='EIZO'; HSD='HannStar'; XMI='Xiaomi'; AUO='AU Optronics (laptop panel)'; BOE='BOE (laptop panel)'; CMN='Innolux (laptop panel)'; LGD='LG Display (laptop panel)'; SDC='Samsung Display (laptop panel)'; IVO='InfoVision (laptop panel)' }
$memType = @{ 20='DDR'; 21='DDR2'; 24='DDR3'; 26='DDR4'; 29='LPDDR3'; 30='LPDDR4'; 34='DDR5'; 35='LPDDR5' }

$placeholder = 'To be filled|Default string|System Serial|O\.E\.M\.|^0+$|^None$|^$'
$chSer = @($enc.SerialNumber, $bios.SerialNumber) | Where-Object { "$_".Trim() -notmatch $placeholder } | Select-Object -First 1
W ("System       : {0} {1}  ({2})   serial {3}" -f $cs.Manufacturer, $cs.Model, $(if ($isLaptop) { 'laptop' } else { 'desktop' }), $(if ($chSer) { $chSer } else { 'none (custom build: the board model below is what identifies it)' }))
foreach ($c in Get-CimInstance Win32_Processor) {
    W ("CPU          : {0}   socket {1}, {2} cores / {3} threads, L3 {4} MB" -f $c.Name.Trim(), $c.SocketDesignation, $c.NumberOfCores, $c.NumberOfLogicalProcessors, [math]::Round($c.L3CacheSize / 1024))
}
W ("Motherboard  : {0} {1}   rev {2}   serial {3}" -f $bb.Manufacturer, $bb.Product, $bb.Version, $bb.SerialNumber)
W ("BIOS         : {0} {1}  dated {2}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion, $bios.ReleaseDate)

$sticks = @(Get-CimInstance Win32_PhysicalMemory)
$slots = (Get-CimInstance Win32_PhysicalMemoryArray | Where-Object { $_.Use -eq 3 } | Measure-Object MemoryDevices -Sum).Sum
W ("RAM          : {0} GB total, {1} stick(s) in {2} slot(s){3}" -f [math]::Round(($sticks | Measure-Object Capacity -Sum).Sum / 1GB), $sticks.Count, $slots, $(if ($slots -gt $sticks.Count) { ", $($slots - $sticks.Count) empty" } else { '' }))
T ($sticks | Select-Object @{n='Slot';e={$_.DeviceLocator}}, @{n='GB';e={[math]::Round($_.Capacity/1GB)}}, @{n='Type';e={ $t = $memType[[int]$_.SMBIOSMemoryType]; if ($t) { $t } else { "type $($_.SMBIOSMemoryType)" } }}, @{n='Form';e={ switch ($_.FormFactor) { 8 {'DIMM'} 12 {'SODIMM'} default {"$($_.FormFactor)"} } }}, @{n='SPD MHz';e={$_.Speed}}, @{n='Running MHz';e={$_.ConfiguredClockSpeed}}, @{n='Maker';e={ $pn = "$($_.PartNumber)".Trim(); $mf = "$($_.Manufacturer)".Trim(); if ($mf -and $mf -notmatch '^(Unknown|Undefined|0+|[0-9A-F]{4})$') { $mf } else { switch -Regex ($pn) { '^F[345]-' { 'G.Skill' } '^(CM|CMK|CMH|CMT|CMW|CMSX)' { 'Corsair' } '^KF|^KHX|^KVR|^KCP|^HX' { 'Kingston' } '^CT|^BL' { 'Crucial' } '^(TF|TD|TL|TP|TED|FF)' { 'TeamGroup' } '^M[34]' { 'Samsung / Micron (OEM)' } '^HMA|^HMC|^HMCG' { 'SK hynix (OEM)' } '^PSD|^PV' { 'Patriot' } '^(AX|AD)' { 'ADATA / XPG' } default { 'unknown' } } } }}, @{n='PartNumber';e={"$($_.PartNumber)".Trim()}}, @{n='Serial';e={"$($_.SerialNumber)".Trim()}})
W '  (the part number shows the kit''s real rated speed; SPD MHz is the safe default it falls back to without XMP / EXPO)'

$vram = @{}
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' | ForEach-Object {
    $p = Get-ItemProperty $_.PSPath
    if ($p.DriverDesc -and $p.'HardwareInformation.qwMemorySize') { $vram[$p.DriverDesc] = [math]::Round($p.'HardwareInformation.qwMemorySize' / 1GB, 1) }
}
foreach ($g in Get-CimInstance Win32_VideoController | Where-Object { $_.PNPDeviceID -like 'PCI\*' }) {
    $maker = 'unknown'; $ids = ''
    if ($g.PNPDeviceID -match 'VEN_([0-9A-F]{4})&DEV_([0-9A-F]{4})&SUBSYS_([0-9A-F]{4})([0-9A-F]{4})') {
        $maker = $(if ($subVendor[$Matches[4]]) { $subVendor[$Matches[4]] } else { "vendor id $($Matches[4])" })
        $ids = "VEN_$($Matches[1]) DEV_$($Matches[2]) SUBSYS_$($Matches[3])$($Matches[4])"
    }
    W ("GPU          : {0}   {1} GB   card made by {2}   ({3})" -f $g.Name, $(if ($vram[$g.Name]) { $vram[$g.Name] } else { '?' }), $maker, $ids)
}

# Drive SMART read straight from the drive (2026-11-09): Windows' reliability counters leave power-on hours blank on many
# NVMe drives. NVMe = health log page 02 via IOCTL_STORAGE_QUERY_PROPERTY; SATA = SMART READ ATTRIBUTES. Read-only, needs admin.
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class NerdsSmart {
  [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern SafeFileHandle CreateFile(string n, uint a, uint s, IntPtr sa, uint c, uint f, IntPtr t);
  [DllImport("kernel32.dll", SetLastError=true)] static extern bool DeviceIoControl(SafeFileHandle h, uint code, byte[] inb, int inl, byte[] outb, int outl, out int ret, IntPtr ov);
  static SafeFileHandle Open(int n) { return CreateFile(@"\\.\PhysicalDrive" + n, 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero); }
  static ulong U64(byte[] b, int o) { return BitConverter.ToUInt64(b, o); }
  // NVMe: "poh|unitsWritten|unitsRead|pctUsed|spare|unsafeShutdowns|mediaErrors|powerCycles|criticalWarning"
  public static string Nvme(int n) {
    using (var h = Open(n)) {
      if (h.IsInvalid) return "";
      var inb = new byte[8 + 40 + 512];
      BitConverter.GetBytes(50).CopyTo(inb, 0);   // StorageDeviceProtocolSpecificProperty
      BitConverter.GetBytes(0).CopyTo(inb, 4);    // PropertyStandardQuery
      BitConverter.GetBytes(3).CopyTo(inb, 8);    // ProtocolTypeNvme
      BitConverter.GetBytes(2).CopyTo(inb, 12);   // NVMeDataTypeLogPage
      BitConverter.GetBytes(2).CopyTo(inb, 16);   // log page 02: SMART / health
      BitConverter.GetBytes(0).CopyTo(inb, 20);
      BitConverter.GetBytes(40).CopyTo(inb, 24);  // data offset
      BitConverter.GetBytes(512).CopyTo(inb, 28); // data length
      var outb = new byte[inb.Length]; int ret;
      if (!DeviceIoControl(h, 0x2D1400, inb, inb.Length, outb, outb.Length, out ret, IntPtr.Zero) || ret < 48 + 192) return "";
      int o = 48;
      return U64(outb, o + 128) + "|" + U64(outb, o + 48) + "|" + U64(outb, o + 32) + "|" + outb[o + 5] + "|" + outb[o + 3] + "|" + U64(outb, o + 144) + "|" + U64(outb, o + 160) + "|" + U64(outb, o + 112) + "|" + outb[o];
    }
  }
  // SATA: "id=raw;id=raw;..." for every SMART attribute
  public static string Ata(int n) {
    using (var h = Open(n)) {
      if (h.IsInvalid) return "";
      var inb = new byte[33];   // SENDCMDINPARAMS, packed
      BitConverter.GetBytes(512).CopyTo(inb, 0);
      inb[4] = 0xD0; inb[5] = 1; inb[6] = 1; inb[7] = 0x4F; inb[8] = 0xC2; inb[9] = 0xA0; inb[10] = 0xB0; inb[12] = 0;
      var outb = new byte[16 + 512]; int ret;
      if (!DeviceIoControl(h, 0x7C088, inb, inb.Length, outb, outb.Length, out ret, IntPtr.Zero)) return "";
      var sb = new System.Text.StringBuilder();
      for (int i = 0; i < 30; i++) {
        int o = 16 + 2 + i * 12; int id = outb[o]; if (id == 0) continue;
        ulong raw = 0; for (int k = 5; k >= 0; k--) raw = (raw << 8) | outb[o + 5 + k];
        sb.Append(id).Append('=').Append(raw).Append(';');
      }
      return sb.ToString();
    }
  }
}
'@
function DriveSmart($d) {
    $n = [int]$d.DeviceId
    $x = [pscustomobject]@{ Hours = $null; WrittenTB = $null; 'Life used%' = $null; Spare = $null; Unsafe = $null; MediaErr = $null; Note = '' }
    try {
        if ($d.BusType -eq 'NVMe') {
            $f = [NerdsSmart]::Nvme($n) -split '\|'
            if ($f.Count -ge 9) {
                $x.Hours = [uint64]$f[0]; $x.WrittenTB = [math]::Round([double]$f[1] * 512000 / 1e12, 1); $x.'Life used%' = [int]$f[3]; $x.Spare = "$($f[4])%"
                $x.Unsafe = [uint64]$f[5]; $x.MediaErr = [uint64]$f[6]
                if ([int]$f[8] -ne 0) { $x.Note = "CRITICAL WARNING flag $($f[8])" }
            }
        } elseif ($d.BusType -in 'SATA', 'ATA', 'RAID') {
            $a = @{}; foreach ($p in ([NerdsSmart]::Ata($n) -split ';' | Where-Object { $_ })) { $kv = $p -split '='; $a[[int]$kv[0]] = [uint64]$kv[1] }
            if ($a.Count) {
                if ($a.ContainsKey(9)) { $x.Hours = $a[9] -band 0xFFFFFFFF }
                if ($a.ContainsKey(241) -and $d.MediaType -eq 'SSD') { $x.WrittenTB = [math]::Round($a[241] * 512 / 1e12, 1) }
                if ($a.ContainsKey(192)) { $x.Unsafe = $a[192] } elseif ($a.ContainsKey(174)) { $x.Unsafe = $a[174] }
                $bad = @(); foreach ($id in 5, 197, 198) { if ($a.ContainsKey($id) -and $a[$id] -gt 0) { $bad += "attr $id = $($a[$id])" } }
                $x.MediaErr = $(if ($bad) { $bad -join ', ' } else { 0 })
                if ($bad) { $x.Note = 'reallocated / pending / bad sectors' }
            }
        }
    } catch {}
    if ($null -eq $x.Hours) { $r = $d | Get-StorageReliabilityCounter; if ($r.PowerOnHours) { $x.Hours = $r.PowerOnHours } }
    if ($null -eq $x.Hours -and -not $x.Note) { $x.Note = $(if ($isAdmin) { 'drive did not report SMART' } else { 'run as admin for SMART' }) }
    $x
}
W 'Drives       :'
$disks = foreach ($d in Get-PhysicalDisk | Sort-Object { [int]$_.DeviceId }) {
    $r = $d | Get-StorageReliabilityCounter
    $sm = DriveSmart $d
    [pscustomobject]@{ Disk = $d.DeviceId; Model = $d.FriendlyName; GB = [math]::Round($d.Size / 1GB); Type = "$($d.MediaType) $($d.BusType)".Trim(); Serial = ("$($d.SerialNumber)".Trim()).TrimEnd('.'); PowerOnHours = $sm.Hours; WrittenTB = $sm.WrittenTB; 'LifeUsed%' = $sm.'Life used%'; Spare = $sm.Spare; UnsafeOff = $sm.Unsafe; MediaErrors = $sm.MediaErr; TempC = $r.Temperature; Health = $d.HealthStatus; Note = $sm.Note }
}
foreach ($k in $disks) {
    W ("  Disk {0}: {1}  {2} GB  {3}  serial {4}" -f $k.Disk, $k.Model, $k.GB, $k.Type, $k.Serial)
    W ("          power-on hours {0}   written {1} TB   life used {2}%   spare {3}   unsafe power-offs {4}   media errors {5}   {6} C   health {7}{8}" -f $(if ($null -ne $k.PowerOnHours) { '{0:N0}' -f $k.PowerOnHours } else { '?' }), $(if ($null -ne $k.WrittenTB) { $k.WrittenTB } else { '?' }), $(if ($null -ne $k.'LifeUsed%') { $k.'LifeUsed%' } else { '?' }), $(if ($k.Spare) { $k.Spare } else { '?' }), $(if ($null -ne $k.UnsafeOff) { $k.UnsafeOff } else { '?' }), $(if ($null -ne $k.MediaErrors) { $k.MediaErrors } else { '?' }), $k.TempC, $k.Health, $(if ($k.Note) { "   NOTE: $($k.Note)" } else { '' }))
}
W '  (written = total data ever written; life used = the drive''s own wear estimate, 100 = rated life used up)'

# Monitors: EDID (maker, model, serial, build date, size) + Windows display modes (native resolution, max refresh).
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
public class NerdsDisp {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DD { public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string DeviceName; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceString;
    public int StateFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceID; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string DeviceKey; }
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct DM {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName; public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra; public int dmFields;
    public int dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput; public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName; public short dmLogPixels;
    public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency, dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplayDevices(string dev, uint i, ref DD dd, uint flags);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettings(string dev, int mode, ref DM dm);
  public static List<string> Scan() {
    var r = new List<string>();
    for (uint a = 0; ; a++) {
      var ad = new DD(); ad.cb = Marshal.SizeOf(ad); if (!EnumDisplayDevices(null, a, ref ad, 0)) break;
      if ((ad.StateFlags & 1) == 0) continue;
      var md = new DD(); md.cb = Marshal.SizeOf(md); string mon = EnumDisplayDevices(ad.DeviceName, 0, ref md, 0) ? md.DeviceID : "";
      var modes = new List<string>();
      for (int m = 0; ; m++) { var dm = new DM(); dm.dmSize = (short)Marshal.SizeOf(dm); if (!EnumDisplaySettings(ad.DeviceName, m, ref dm)) break; modes.Add(dm.dmPelsWidth + "x" + dm.dmPelsHeight + "@" + dm.dmDisplayFrequency); }
      r.Add(mon + "|" + ad.DeviceString + "|" + String.Join(";", modes));
    }
    return r;
  }
}
'@
# Windows display modes per screen (what the GPU offers on this cable), matched to the EDID by the PnP code.
$dispModes = @(); try { $dispModes = @([NerdsDisp]::Scan() | ForEach-Object { $f = $_ -split '\|'; [pscustomobject]@{ Code = $(if ($f[0] -match 'MONITOR\\([^\\]+)\\') { $Matches[1] } else { '' }); Gpu = $f[1]; Modes = @($f[2] -split ';' | Where-Object { $_ -match '^(\d+)x(\d+)@(\d+)$' } | ForEach-Object { [pscustomobject]@{ W = [int]$Matches[1]; H = [int]$Matches[2]; Hz = [int]$Matches[3] } }); Used = $false } }) } catch {}
$srcModes = @(Get-CimInstance -Namespace root\wmi WmiMonitorListedSupportedSourceModes)
# Raw EDID from the registry: the range-limits block (0xFD) holds the panel's real max refresh; WMI's mode list stops at 60 Hz.
function EdidMaxHz([string]$inst) {
    $key = 'HKLM:\SYSTEM\CurrentControlSet\Enum\' + ($inst -replace '_\d+$', '') + '\Device Parameters'
    $e = (Get-ItemProperty $key).EDID
    if (-not $e -or $e.Count -lt 128) { return 0 }
    foreach ($o in 54, 72, 90, 108) {
        if ($e[$o] -eq 0 -and $e[$o + 1] -eq 0 -and $e[$o + 3] -eq 0xFD) { return [int]$e[$o + 6] + $(if ($e[$o + 4] -band 2) { 255 } else { 0 }) }
    }
    return 0
}
$conns = @(Get-CimInstance -Namespace root\wmi WmiMonitorConnectionParams)
$basics = @(Get-CimInstance -Namespace root\wmi WmiMonitorBasicDisplayParams)
$monIds = @(Get-CimInstance -Namespace root\wmi WmiMonitorID)
W ("Monitors     : {0} connected" -f $monIds.Count)
foreach ($mi in $monIds) {
    $code = WStr $mi.ManufacturerName
    $maker = $(if ($pnpVendor[$code]) { $pnpVendor[$code] } else { $code })
    $model = WStr $mi.UserFriendlyName; if (-not $model) { $model = "product code $(WStr $mi.ProductCodeID)" }
    $serial = WStr $mi.SerialNumberID; if (-not $serial -or $serial -match '^0+$') { $serial = 'not reported' }
    $made = $(if ($mi.WeekOfManufacture -ge 1 -and $mi.WeekOfManufacture -le 54) { "week $($mi.WeekOfManufacture) of $($mi.YearOfManufacture)" } else { "model year $($mi.YearOfManufacture)" })
    $b = $basics | Where-Object { $_.InstanceName -eq $mi.InstanceName } | Select-Object -First 1
    $size = $(if ($b -and $b.MaxHorizontalImageSize -gt 0) { "about {0:N0} in" -f ([math]::Sqrt([math]::Pow($b.MaxHorizontalImageSize, 2) + [math]::Pow($b.MaxVerticalImageSize, 2)) / 2.54) } else { 'size ?' })
    $cn = $conns | Where-Object { $_.InstanceName -eq $mi.InstanceName } | Select-Object -First 1
    $via = $(switch ([int64]$cn.VideoOutputTechnology) { 0 {'VGA'} 4 {'DVI'} 5 {'HDMI'} 6 {'built-in (LVDS)'} 10 {'DisplayPort'} 11 {'built-in (eDP)'} 2147483648 {'built-in'} default { if ($cn) { "type $($cn.VideoOutputTechnology)" } else { '?' } } })
    $pcode = ($mi.InstanceName -split '\\')[1]
    $sm = $srcModes | Where-Object { $_.InstanceName -eq $mi.InstanceName } | Select-Object -First 1
    $nw = 0; $nh = 0
    if ($sm) { $pm = $sm.MonitorSourceModes[$sm.PreferredMonitorSourceModeIndex]; $nw = [int]$pm.HorizontalActivePixels; $nh = [int]$pm.VerticalActivePixels }
    $dm = $dispModes | Where-Object { $_.Code -eq $pcode -and -not $_.Used } | Select-Object -First 1
    $winHz = 0
    if ($dm) { $dm.Used = $true; $winHz = ($dm.Modes | Where-Object { ($_.W -eq $nw -and $_.H -eq $nh) -or ($_.W -eq $nh -and $_.H -eq $nw) } | Measure-Object Hz -Maximum).Maximum }
    $edidHz = EdidMaxHz $mi.InstanceName
    $modeTxt = $(if ($nw) { "native {0}x{1}" -f $nw, $nh } else { 'native ?' }) +
        $(if ($edidHz) { ", monitor currently reports up to $edidHz Hz on this connection (check the model's rated spec; Windows keeps only the basic EDID block)" } else { '' }) +
        $(if ($winHz) { ", Windows offers $winHz Hz at native on this cable / GPU" } elseif ($dm) { '' } else { ' (screen off or mirrored: modes not readable)' })
    W ("  {0} {1}   {2}   {3}   via {4}   serial {5}   made {6}" -f $maker, $model, $size, $modeTxt, $via, $serial, $made)
}

$nics = Get-NetAdapter -Physical | Sort-Object InterfaceDescription
W ("Network      : {0}" -f $(if ($nics) { ($nics.InterfaceDescription | Select-Object -Unique) -join '; ' } else { 'none found' }))
$snd = Get-CimInstance Win32_SoundDevice
W ("Sound        : {0}" -f $(if ($snd) { ($snd.Name | Select-Object -Unique) -join '; ' } else { 'none found' }))
$cd = Get-CimInstance Win32_CDROMDrive
if ($cd) { W ("Optical      : {0}" -f (($cd.Name | Select-Object -Unique) -join '; ')) }
if ($isLaptop) {
    $bsd = Get-CimInstance -Namespace root\wmi BatteryStaticData | Select-Object -First 1
    $bfc = Get-CimInstance -Namespace root\wmi BatteryFullChargedCapacity | Select-Object -First 1
    if ($bsd) { W ("Battery      : {0} {1}  serial {2}  design {3} mWh, now {4} mWh ({5:N0}% of original)" -f $bsd.ManufactureName, $bsd.DeviceName, $bsd.SerialNumber, $bsd.DesignedCapacity, $bfc.FullChargedCapacity, (100 * $bfc.FullChargedCapacity / [math]::Max(1, $bsd.DesignedCapacity))) }
}
W 'USB devices (keyboard, mouse, headset, webcam, capture card, AIO cooler, RGB / fan controllers, smart PSUs):'
$usbSeen = @{}
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB\\VID_[0-9A-F]{4}&PID_[0-9A-F]{4}\\' } | ForEach-Object {
    $vp = $(if ($_.InstanceId -match '^USB\\VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') { "$($Matches[1]):$($Matches[2])" })
    $desc = (Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName 'DEVPKEY_Device_BusReportedDeviceDesc').Data
    if (-not $desc) { $desc = $_.FriendlyName }
    if ($desc -and $desc -notmatch 'Hub$|Root Hub|^USB Composite Device$|^USB Input Device$' -and -not $usbSeen[$vp]) { $usbSeen[$vp] = $true; W ("  {0}  ({1})" -f $desc.Trim(), $vp) }
}
if (-not $usbSeen.Count) { W '  (none found)' }
$bt = Get-PnpDevice -PresentOnly -Class Bluetooth | Where-Object { $_.InstanceId -match '^(BTHENUM\\DEV_|BTHLE\\DEV_)' -and $_.FriendlyName }
if ($bt) { W ("Bluetooth    : paired: {0}" -f (($bt.FriendlyName | Select-Object -Unique) -join '; ')) }
$chan = $(if ($lic.Description -match '(\w+) channel') { $Matches[1] } else { 'unknown' })
$oa3 = [bool](Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKey
W ("Windows      : {0}, license channel {1}{2}   key built into the BIOS: {3}" -f $os.Caption, $chan, $(switch -Regex ($chan) { '^RETAIL' { ' (can move to another PC)' } '^OEM' { ' (tied to this motherboard)' } '^VOLUME' { ' (business / volume license)' } default { '' } }), $(if ($oa3) { 'yes' } else { 'no' }))
W 'Check by hand: power supply (brand / model / wattage label), case, CPU cooler, case fans. Windows cannot'
W '               read these unless they show up in the USB list above (some AIO coolers and PSUs do).'

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
    # Every screen from dxdiag's display section (2026-10-18, Emiko's video-playback freezes: the GPU line above
    # shows one mode per card, and multi-screen / mixed refresh setups are a common factor in idle and video hangs).
    $screens = @(); $card = ''; $m = $null
    foreach ($l in $dxl) {
        if ($l -match '^\s*Card name:\s*(.+)$') { $card = $Matches[1].Trim() }
        elseif ($l -match '^\s*Current Mode:\s*(.+)$') { if ($m) { $screens += $m }; $m = [pscustomobject]@{ Card = $card; Mode = $Matches[1].Trim(); Model = ''; Native = ''; Output = ''; Hdr = ''; Space = '' } }
        elseif ($m -and $l -match '^\s*Monitor Model:\s*(.+)$') { $m.Model = $Matches[1].Trim() }
        elseif ($m -and $l -match '^\s*Native Mode:\s*(.+)$') { $m.Native = $Matches[1].Trim() }
        elseif ($m -and $l -match '^\s*Output Type:\s*(.+)$') { $m.Output = $Matches[1].Trim() }
        elseif ($m -and $l -match '^\s*HDR Support:\s*(.+)$') { $m.Hdr = $Matches[1].Trim() }
        elseif ($m -and $l -match '^\s*Display Color Space:\s*(.+)$') { $m.Space = $Matches[1].Trim() }
    }
    if ($m) { $screens += $m }
    $screens = @($screens | Where-Object { $_.Mode -notmatch '^Unknown' -and ($_.Model -or $_.Output) })
    W ''
    W ("Screens      : {0} connected" -f $screens.Count)
    $i = 0
    foreach ($s in $screens) {
        $i++
        $hdr = if ($s.Space -match 'G2084') { 'HDR ON' } elseif ($s.Hdr -match '^Supported') { 'HDR off (supported)' } else { 'no HDR' }
        W ("  {0}: {1}  {2}  via {3}  {4}  (preferred {5})  on {6}" -f $i, $(if ($s.Model -and $s.Model -ne 'unknown') { $s.Model } else { 'unknown model' }), ($s.Mode -replace '\s*\(32 bit\)', ''), $s.Output, $hdr, $s.Native, $s.Card)
    }
    $hz = @($screens | ForEach-Object { if ($_.Mode -match '\((\d+)Hz\)') { [int]$Matches[1] } } | Sort-Object -Unique)
    if ($screens.Count -gt 1) { W ("NOTE: {0} screens connected." -f $screens.Count) }
    if ($hz.Count -gt 1) { W ("NOTE: screens run at different refresh rates ({0} Hz). Mixed refresh rates are a common factor in GPU idle / video-playback freezes and flicker." -f ($hz -join ' / ')) }
    Remove-Item $dx -Force
}

# Settings that matter for GPU freezes and devices dropping off (2026-10-18).
W ''
W 'Settings that affect GPU freezes:'
$gd = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
W ("  GPU scheduling (HAGS)    : {0}" -f $(switch ($gd.HwSchMode) { 2 { 'ON' } 1 { 'off' } default { 'Windows default' } }))
W ("  Driver timeout (TDR)     : {0}" -f $(if ($null -ne $gd.TdrDelay -or $null -ne $gd.TdrLevel) { (@($(if ($null -ne $gd.TdrDelay) { "TdrDelay=$($gd.TdrDelay) s" }), $(if ($null -ne $gd.TdrLevel) { "TdrLevel=$($gd.TdrLevel)" })) | Where-Object { $_ }) -join ', ' } else { 'Windows default' }))
$dwm = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
W ("  Multiplane overlay (MPO) : {0}" -f $(if ($dwm.OverlayTestMode -eq 5) { 'OFF (OverlayTestMode=5)' } else { 'on (Windows default)' }))
$aspm = powercfg /query SCHEME_CURRENT SUB_PCIEXPRESS ASPM 2>$null | Select-String '0x0000000[0-9]$'
$aspmName = @{ 0 = 'Off'; 1 = 'Moderate power savings'; 2 = 'Maximum power savings' }
if ($aspm.Count -ge 2) {
    $ac = [Convert]::ToInt32((($aspm[0].Line -split ':')[-1]).Trim(), 16); $dc = [Convert]::ToInt32((($aspm[1].Line -split ':')[-1]).Trim(), 16)
    W ("  PCIe Link State Power Mgmt: plugged in {0}, battery {1}" -f $aspmName[$ac], $aspmName[$dc])
} else { W '  PCIe Link State Power Mgmt: not readable' }
$hib = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power').HibernateEnabled
$fs = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power').HiberbootEnabled
W ("  Fast Startup             : {0}" -f $(if ($hib -eq 0) { 'off (hibernation is off)' } elseif ($fs -eq 0) { 'off' } else { 'ON' }))
W ("  Power plan               : {0}" -f ((powercfg /getactivescheme) -replace '.*\((.*)\).*','$1'))

Step 'Drives'
Section 'DRIVES'
# DeviceId matches the Wear / errors table below; FirmwareVersion added 2026-10-19 (Emiko's 990 EVO Plus dropping at boot).
T (Get-PhysicalDisk | Sort-Object DeviceId | Select-Object DeviceId, FriendlyName, FirmwareVersion, MediaType, BusType, @{n='GB';e={[math]::Round($_.Size/1GB)}}, HealthStatus, OperationalStatus)
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
# Dates come from EventTime inside Report.wer: Windows rewrites old report folders in bulk, so the folder date
# can make months-old GPU hangs look new (seen on Mike's PC 2026-11-02, 50 old reports re-dated at once).
function WerTime($txt, $dir) { if ($txt -match 'EventTime=(\d+)') { try { return [DateTime]::FromFileTime([int64]$Matches[1]) } catch {} }; return $dir.LastWriteTime }
$werDirs = @('C:\ProgramData\Microsoft\Windows\WER\ReportArchive', 'C:\ProgramData\Microsoft\Windows\WER\ReportQueue') |
    ForEach-Object { Get-ChildItem $_ -Directory } | Where-Object { $_.LastWriteTime -gt $since }
$lke = foreach ($d in $werDirs) {
    $r = Join-Path $d.FullName 'Report.wer'
    if (-not (Test-Path $r)) { continue }
    $txt = Get-Content $r -Encoding Unicode -Raw
    $when = WerTime $txt $d
    if ($when -lt $since) { continue }
    if ($txt -notmatch 'EventType=(LiveKernelEvent|BlueScreen)') { continue }
    $code = if ($txt -match 'Sig\[0\]\.Value=([0-9A-Fa-f]+)') { $Matches[1].ToLower() } else { '?' }
    $drv = if ($txt -match 'Sig\[\d\]\.Name=(?:Failure|Faulting)[^\r\n]*\r?\nSig\[\d\]\.Value=([^\r\n]+)') { $Matches[1] } else { '' }
    [pscustomobject]@{ When = $when; Type = $Matches[0] -replace '.*=', ''; Code = $code; Detail = $drv }
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
$flag = 'Afterburner|RivaTuner|RTSS|Overwolf|CurseForge|Thunderstore|r2modman|Vortex|Mod Organizer|Wabbajack|WowUp|ReShade|Special K|Lossless Scaling|OBS Studio|Streamlabs|StreamElements|SE\.Live|XSplit|NVIDIA Broadcast|Camera Hub|Elgato|Meld Studio|Twitch Studio|PRISM Live|vMix|ManyCam|Snap Camera|VTube|Voicemeeter|Wallpaper Engine|Razer Cortex|Driver Booster|Driver Easy|CCleaner|McAfee|Norton|Avast|AVG|Avira|Webroot|PC Optimizer|Ryzen Master|Armoury|iCUE|Lightshot|Discord|GeForce Experience|NVIDIA App|AMD Software|Steam|Epic Games|Battle\.net|EA app|Ubisoft'
W 'Programs that commonly matter for games / performance:'
$apps | Where-Object { $_.DisplayName -match $flag } | ForEach-Object { W ("  {0}  {1}" -f $_.DisplayName, $_.DisplayVersion) }
W ''
W 'Full list:'
$apps | ForEach-Object { W ("  {0}  {1}" -f $_.DisplayName, $_.DisplayVersion) }

Step 'Game mods and graphics hooks'
Section 'GAME MODS AND GRAPHICS HOOKS'
# Mods that hook the graphics pipeline (ReShade, ENB, Special K, DXVK, loaders) live as DLLs inside the game folder,
# so they never show up as installed programs (2026-10-18, Emiko: lots of games, mod folders seen).
$gameRoots = @()
$steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
foreach ($vdf in @("$steam\steamapps\libraryfolders.vdf", 'C:\Program Files (x86)\Steam\steamapps\libraryfolders.vdf')) {
    if (Test-Path $vdf) { Get-Content $vdf | Select-String '"path"\s+"(.+)"' | ForEach-Object { $gameRoots += (Join-Path ($_.Matches[0].Groups[1].Value -replace '\\\\', '\') 'steamapps\common') } }
}
foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }).Root) {
    foreach ($sub in 'Program Files (x86)', 'Program Files', 'Games', 'Riot Games', 'Epic Games', 'XboxGames', 'GOG Games') { $gameRoots += (Join-Path $d $sub) }
}
$gameRoots = @($gameRoots | Where-Object { Test-Path $_ } | Sort-Object -Unique)
$hookNames = 'dxgi.dll', 'd3d11.dll', 'd3d12.dll', 'd3d9.dll', 'd3d8.dll', 'dinput8.dll', 'opengl32.dll', 'ReShade.ini', 'ReShade.log', 'enbseries.ini', 'enblocal.ini', 'SpecialK64.dll', 'dxvk.conf', 'winhttp.dll'
$hooks = foreach ($r in $gameRoots) {
    Get-ChildItem $r -Directory | ForEach-Object {
        $g = $_
        Get-ChildItem $g.FullName -Recurse -Depth 3 -File -Include $hookNames |
            Where-Object { $_.DirectoryName -notmatch '\\(Microsoft|Windows|Common Files|WindowsApps|D3D12|d3d12on7|12on7|mesa)(\\|$)' } |
            ForEach-Object { [pscustomobject]@{ Game = $g.Name; File = $_.FullName.Substring($g.FullName.Length + 1) } }
    }
}
W 'Graphics hook / injector files inside game folders (ReShade, ENB, Special K, DXVK, mod loaders):'
if ($hooks) { $hooks | Group-Object Game | ForEach-Object { W ("  {0}: {1}" -f $_.Name, (($_.Group.File | Select-Object -First 6) -join ', ')) } } else { W '  (none found)' }
W ''
W 'Mod folders and mod managers found:'
$modHits = @()
foreach ($r in $gameRoots) {
    Get-ChildItem $r -Directory | ForEach-Object {
        foreach ($sub in 'BepInEx', 'MelonLoader', 'Mods', 'Data\SKSE', 'Interface\AddOns', '_retail_\Interface\AddOns') {
            $p = Join-Path $_.FullName $sub
            if (Test-Path $p) { $modHits += ("  {0}\{1}  ({2} items)" -f $_.Name, $sub, @(Get-ChildItem $p).Count) }
        }
    }
}
foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }).Root) {
    Get-ChildItem $d -Directory | Where-Object { $_.Name -match 'Vortex|Mod Organizer|ModOrganizer|Wabbajack|r2modman|Thunderstore' } | ForEach-Object { $modHits += "  $($_.FullName)" }
}
foreach ($p in "$env:APPDATA\Vortex", "$env:LOCALAPPDATA\ModOrganizer", "$env:APPDATA\r2modmanPlus-local", "$env:APPDATA\Thunderstore Mod Manager", "$env:LOCALAPPDATA\Overwolf", "$env:APPDATA\CurseForge") {
    if (Test-Path $p) { $modHits += "  $p" }
}
if ($modHits) { $modHits | Select-Object -Unique -First 40 | ForEach-Object { W $_ } } else { W '  (none found)' }

Section 'STREAMING: GPU LOAD, CAMERAS, OBS / STREAMLABS'
# Added 2026-11-02 (a streamer's GPU overloads and the camera won't run while live). The rest of the report is a
# snapshot; this shows what the GPU is doing right now, who has the camera, and how OBS is set up.
# Never reads OBS service.json (holds the stream key).
$streamFiles = @()
# Streaming mode (report.ps1 asked "streaming or camera problem?" and got Y): wait for the customer to load the game
# and OBS before sampling, so slow PCs and single-screen setups never have to race the report or alt-tab back.
# v2 (2026-11-02, Mike's live test): a GPU-% threshold missed light games (modded Stardew ~5% on a 7900 XTX) and a
# 3-minute OBS cutoff left before a slow game finished loading. Now: detect the game itself (a process running from a
# game library folder, or any non-system process drawing on the GPU), give it 45 s to finish loading, then sample.
# Waits up to 10 minutes; OBS/Streamlabs is waited for up to 2 more minutes after the game shows up.
$streamWait = ''
if ($env:NERDS_REPORT_STREAM) {
    Step 'Waiting for your game (up to 10 minutes). Open it and OBS / Streamlabs and play like normal; no need to come back here.'
    $obsPat = $(if ($env:NERDS_STREAM_TEST_OBS) { $env:NERDS_STREAM_TEST_OBS } else { '^(obs64|obs32|obs)$|Streamlabs' })
    $maxWait = $(if ($env:NERDS_STREAM_TEST_MAX) { [int]$env:NERDS_STREAM_TEST_MAX } else { 600 })
    $settle = $(if ($env:NERDS_STREAM_TEST_SETTLE) { [int]$env:NERDS_STREAM_TEST_SETTLE } else { 45 })
    $gameDirs = @($gameRoots | Where-Object { $_ -match '\\steamapps\\common$|\\(Games|Riot Games|Epic Games|XboxGames|GOG Games)$' })
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null }).Root) {
        foreach ($sub in 'Program Files\EA Games', 'Program Files\Epic Games', 'Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games', 'Program Files (x86)\GOG Galaxy\Games') { $p = Join-Path $d $sub; if (Test-Path $p) { $gameDirs += $p } }
    }
    if ($env:NERDS_STREAM_TEST_GAMEROOT) { $gameDirs += $env:NERDS_STREAM_TEST_GAMEROOT }
    $gameDirs = @($gameDirs | Sort-Object -Unique)
    $notGame = '^(dwm|explorer|csrss|svchost|System|Idle|audiodg|ctfmon|conhost|powershell|pwsh|WindowsTerminal|OpenConsole|LockApp|SearchHost|StartMenuExperienceHost|ShellExperienceHost|TextInputHost|ApplicationFrameHost|SystemSettings|Widgets|WidgetService|PhoneExperienceHost|CrossDeviceService|backgroundTaskHost|RuntimeBroker|GameBar.*|XboxPcApp|obs64|obs32|obs|obs-browser-page|obs-ffmpeg-mux|chrome|msedge|msedgewebview2|firefox|opera|brave|vivaldi|Discord|steam|steamwebhelper|steamservice|EpicGamesLauncher|EpicWebHelper|Battle\.net|Agent|EADesktop|EABackgroundService|EAConnect.*|UbisoftConnect|upc|UplayWebCore|GalaxyClient.*|RiotClient.*|Overwolf.*|NVIDIA.*|nvcontainer|nvsphelper64|RadeonSoftware|AMDRSServ|AMDRSSrcExt|amdow|cncmd|atieclxx|Spotify|Teams|ms-teams|Code|Streamlabs.*|StreamElements.*|Insta360.*|Camera Hub|Voicemeeter.*|WigiDash.*|Wallpaper.*|Lively.*|iCUE|SignalRgb|Armoury.*|.*[Cc]rash[Hh]andler.*|.*[Cc]rash[Rr]eport.*|crashpad_handler|EasyAntiCheat.*|BEService.*|vc_redist.*|.*[Ll]auncher.*|.*[Uu]pdater.*|.*[Ss]etup.*)$'
    $t0 = Get-Date; $game = $null; $gameSince = $null; $obsSeen = $false; $lastNote = 0; $why = ''
    while ($true) {
        $el = ((Get-Date) - $t0).TotalSeconds
        $procs = Get-Process
        $obsUp = [bool]($procs | Where-Object { $_.ProcessName -match $obsPat })
        if ($obsUp) { $obsSeen = $true }
        # a process running from a game library folder...
        $found = $procs | Where-Object { $_.ProcessName -notmatch $notGame -and $_.Path } | Where-Object { $pp = $_.Path; [bool]($gameDirs | Where-Object { $pp.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }) } |
            Sort-Object WorkingSet64 -Descending | Select-Object -First 1
        # ...or any non-system process drawing on the GPU's 3D engine (games installed somewhere else)
        if (-not $found) {
            $use = @{}
            (Get-Counter '\GPU Engine(*engtype_3D)\Utilization Percentage' -SampleInterval 1 -MaxSamples 1).CounterSamples | ForEach-Object {
                if ($_.InstanceName -match '^pid_(\d+)_') { $use[$Matches[1]] = [double]$use[$Matches[1]] + $_.CookedValue }
            }
            $found = $use.Keys | Where-Object { $use[$_] -ge 2 } | ForEach-Object { $procs | Where-Object Id -eq ([int]$_) } |
                Where-Object { $_ -and $_.ProcessName -notmatch $notGame } | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
        }
        if ($found) {
            if (-not $game -or -not (Get-Process -Id $game.Id -ErrorAction SilentlyContinue)) { $game = $found; $gameSince = Get-Date }
        } elseif ($game -and -not (Get-Process -Id $game.Id -ErrorAction SilentlyContinue)) { $game = $null; $gameSince = $null }
        if ($game) {
            $gs = ((Get-Date) - $gameSince).TotalSeconds
            if ($gs -ge $settle -and $obsUp) { $why = "caught the game ($($game.ProcessName)) running $([int]$gs) s with OBS open"; break }
            if ($gs -ge $settle + 120) { $why = "caught the game ($($game.ProcessName)) running $([int]$gs) s; OBS / Streamlabs never opened"; break }
        }
        if ($el -ge $maxWait) { $why = "gave up after $([int]($maxWait / 60)) minutes (game: $(if ($game) { $game.ProcessName } else { 'none found' }), OBS open: $obsUp)"; break }
        if ($el - $lastNote -ge 60) { $lastNote = $el; if ($el -gt 5) { Step ("Still waiting ({0} min). Game: {1}. OBS: {2}." -f [int]($el / 60), $(if ($game) { $game.ProcessName } else { 'not seen yet' }), $(if ($obsUp) { 'open' } else { 'not open' })) } }
        Start-Sleep -Seconds 3
    }
    $streamWait = "Streaming mode: waited {0:N0} s, {1}." -f ((Get-Date) - $t0).TotalSeconds, $why
}
Step 'Measuring GPU load for 30 seconds, then checking cameras and OBS / Streamlabs'
if ($streamWait) { W $streamWait } elseif (-not $env:NERDS_REPORT_STREAM) { W 'Streaming mode: off (did not wait for a game; numbers are from whatever was running).' }
$liveApps = Get-Process | Where-Object { $_.ProcessName -match '^(obs64|obs32|obs)$|Streamlabs|StreamElements|SE\.Live|NVIDIA Broadcast|Camera Hub|XSplit|Meld|Twitch Studio|PRISM|vMix|ManyCam|Snap Camera|VTube|veadotube|Discord' } |
    Select-Object -ExpandProperty ProcessName -Unique
W ("Streaming / camera apps running during this report: {0}" -f $(if ($liveApps) { $liveApps -join ', ' } else { 'none (GPU numbers below are NOT from a live stream)' }))
W ''
W 'GPU load, 30-second sample (per graphics adapter; only means something if the game and OBS were running):'
$gs = Get-Counter -Counter '\GPU Engine(*)\Utilization Percentage', '\GPU Adapter Memory(*)\Dedicated Usage' -SampleInterval 2 -MaxSamples 15
if ($gs) {
    $typeVals = @{}   # "luid|engtype" -> per-sample % (busiest engine of that type)
    $procSum = @{}    # "pid|engtype" -> summed %
    $vramPeak = @{}   # luid -> peak dedicated bytes
    $n = 0
    foreach ($s in $gs) {
        $n++
        $engSum = @{}; $engKey = @{}
        foreach ($c in $s.CounterSamples) {
            if ($c.InstanceName -match '^pid_(\d+)_luid_(0x[0-9a-f]+_0x[0-9a-f]+)_phys_(\d+)_eng_(\d+)_engtype_(.*)$') {
                $procId = $Matches[1]; $luid = $Matches[2]; $t = $(if ($Matches[5]) { $Matches[5] } else { 'other' })
                $k = "$luid|$($Matches[3])|$($Matches[4])"
                $engSum[$k] = [double]$engSum[$k] + $c.CookedValue; $engKey[$k] = "$luid|$t"
                $procSum["$procId|$t"] = [double]$procSum["$procId|$t"] + $c.CookedValue
            } elseif ($c.InstanceName -match '^luid_(0x[0-9a-f]+_0x[0-9a-f]+)_phys') {
                $luid = $Matches[1]; if ($c.CookedValue -gt [double]$vramPeak[$luid]) { $vramPeak[$luid] = $c.CookedValue }
            }
        }
        $perType = @{}
        foreach ($k in $engSum.Keys) { $v = [math]::Min(100, $engSum[$k]); if ($v -gt [double]$perType[$engKey[$k]]) { $perType[$engKey[$k]] = $v } }
        foreach ($tk in $perType.Keys) { if (-not $typeVals[$tk]) { $typeVals[$tk] = New-Object System.Collections.ArrayList }; [void]$typeVals[$tk].Add($perType[$tk]) }
    }
    $luids = @($typeVals.Keys | ForEach-Object { ($_ -split '\|')[0] } | Sort-Object -Unique | Sort-Object { -[double]$vramPeak[$_] })
    foreach ($l in $luids) {
        W ("  Adapter {0}  (dedicated VRAM in use, peak {1:N1} GB)" -f $l, ([double]$vramPeak[$l] / 1GB))
        foreach ($t in '3D', 'VideoEncode', 'VideoDecode', 'Compute', 'Copy') {
            $vals = $typeVals["$l|$t"]
            if (-not $vals) { continue }
            $avg = ($vals | Measure-Object -Average).Average * $vals.Count / $n   # samples where the engine was idle count as 0
            $peak = ($vals | Measure-Object -Maximum).Maximum
            W ("    {0,-12} average {1,3:N0}%   peak {2,3:N0}%" -f $t, $avg, $peak)
        }
    }
    $main = $luids | Select-Object -First 1
    if ($main -and $typeVals["$main|3D"]) {
        $peak3d = ($typeVals["$main|3D"] | Measure-Object -Maximum).Maximum
        $avg3d = ($typeVals["$main|3D"] | Measure-Object -Average).Average * $typeVals["$main|3D"].Count / $n
        if ($avg3d -ge 90) { W ("NOTE: main GPU 3D engine averaged {0:N0}% (peak {1:N0}%). It is maxed out: OBS and the camera are starved. Cap the game's FPS." -f $avg3d, $peak3d) }
    }
    W '  Top GPU users during the sample (average %):'
    $top = foreach ($k in $procSum.Keys) {
        $procId, $t = $k -split '\|', 2
        if ($t -notin '3D', 'VideoEncode', 'VideoDecode', 'Compute') { continue }
        $p = Get-Process -Id $procId
        [pscustomobject]@{ Process = $(if ($p) { $p.ProcessName } else { "pid $procId (exited)" }); Engine = $t; Avg = $procSum[$k] / $n }
    }
    $top = @($top | Group-Object Process, Engine | ForEach-Object { [pscustomobject]@{ Process = $_.Group[0].Process; Engine = $_.Group[0].Engine; Avg = ($_.Group | Measure-Object Avg -Sum).Sum } } |
        Where-Object { $_.Avg -ge 0.5 } | Sort-Object Avg -Descending | Select-Object -First 10)
    if ($top) { $top | ForEach-Object { W ("    {0,5:N1}%  {1,-12} {2}" -f $_.Avg, $_.Engine, $_.Process) } } else { W '    (nothing using the GPU)' }
} else { W '  (GPU performance counters not available)' }
$smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
if (Test-Path $smi) {
    W '  nvidia-smi (end of sample):'
    & $smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw,power.limit,clocks.gr,pstate,pcie.link.gen.current,pcie.link.width.current --format=csv 2>$null | ForEach-Object { W ("    " + $_) }
}

W ''
W 'Cameras and capture devices:'
$cams = Get-PnpDevice -PresentOnly | Where-Object { $_.Class -in 'Camera', 'Image' -or ($_.Class -eq 'MEDIA' -and $_.FriendlyName -match 'Capture|Elgato|AVerMedia|Cam Link|Webcam|Camera|Razer|Logi|Magewell') }
T ($cams | Select-Object Status, Class, FriendlyName, @{n='HardwareId';e={($_.InstanceId -split '\\')[1]}})
$cb = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam'
W ("Camera privacy: whole PC {0}, this user {1}, desktop apps {2}" -f (Get-ItemProperty ($cb -replace '^HKCU', 'HKLM')).Value, (Get-ItemProperty $cb).Value, (Get-ItemProperty "$cb\NonPackaged").Value)
$camUse = foreach ($k in @(Get-ChildItem $cb | Where-Object { $_.PSChildName -ne 'NonPackaged' }) + @(Get-ChildItem "$cb\NonPackaged")) {
    $p = Get-ItemProperty $k.PSPath
    if (-not $p.LastUsedTimeStart) { continue }
    [pscustomobject]@{ InUseNow = $(if ($p.LastUsedTimeStop -eq 0) { 'YES' } else { '' }); LastUsed = [DateTime]::FromFileTime($p.LastUsedTimeStart); App = ($k.PSChildName -replace '#', '\').Replace($env:USERPROFILE, '%USERPROFILE%') }
}
W 'Apps that used the camera, newest first (InUseNow YES = holding it right now; only one app can hold most webcams):'
T ($camUse | Sort-Object LastUsed -Descending | Select-Object -First 10)
W 'Note: Windows does not record every camera use (OBS often never shows here). The OBS camera lines below are the better check.'

# Overlay / alert sites behind browser sources (StreamElements, Streamlabs widgets...): host name only,
# never the full link (those links carry account tokens). 2026-11-02.
function UrlHosts($urls) {
    $h = foreach ($u in $urls) { if ($u -match '^https?://([^/:?#]+)') { $Matches[1].ToLower() -replace '^www\.', '' } elseif ($u) { 'local files' } }
    if ($h) { ($h | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', ' } else { '' }
}
# Walk any scene-collection JSON (OBS or Streamlabs format) and return every object that looks like a source or filter.
function SceneObjects($o, [int]$depth = 0) {
    if ($null -eq $o -or $depth -gt 12) { return }
    if ($o -is [System.Array]) { foreach ($x in $o) { SceneObjects $x ($depth + 1) }; return }
    if ($o -isnot [System.Management.Automation.PSCustomObject]) { return }
    $kind = $(if ($o.PSObject.Properties['type'] -and $o.type -is [string] -and $o.PSObject.Properties['settings']) { $o.type } elseif ($o.PSObject.Properties['id'] -and $o.id -is [string] -and $o.PSObject.Properties['settings']) { $o.id })
    if ($kind) { [pscustomobject]@{ Kind = $kind; Name = $o.name; Settings = $o.settings } }
    foreach ($p in $o.PSObject.Properties) { if ($p.Name -ne 'settings') { SceneObjects $p.Value ($depth + 1) } }
}
$obs = Join-Path $env:APPDATA 'obs-studio'
if (Test-Path $obs) {
    W ''
    W 'OBS Studio setup:'
    $active = @{}
    foreach ($gi in 'user.ini', 'global.ini') {
        $p = Join-Path $obs $gi
        if (Test-Path $p) { Get-Content $p | Where-Object { $_ -match '^(Profile|SceneCollection)=(.*)$' } | ForEach-Object { $active[$Matches[1]] = $Matches[2] }; if ($active.Count) { break } }
    }
    W ("  Active profile: {0}   scene collection: {1}" -f $active['Profile'], $active['SceneCollection'])
    $profs = @(Get-ChildItem (Join-Path $obs 'basic\profiles') -Directory)
    if ($profs.Count -gt 1) { W ("  All profiles: " + (($profs | ForEach-Object { $_.Name }) -join ', ')) }
    foreach ($pd in $profs | Where-Object { $_.Name -eq $active['Profile'] -or $profs.Count -eq 1 }) {
        $ini = Join-Path $pd.FullName 'basic.ini'
        $sec = ''
        $keys = if (Test-Path $ini) { foreach ($il in Get-Content $ini) {
            if ($il -match '^\[(.+)\]$') { $sec = $Matches[1] }
            elseif ($il -match '^(Mode|BaseCX|BaseCY|OutputCX|OutputCY|FPSType|FPSCommon|FPSInt|StreamEncoder|VBitrate|Preset|NVENCPreset2|Encoder|RecEncoder|RecQuality|Rescale|RescaleRes|ScaleType|ColorFormat|ColorSpace)=') { "$sec.$il" }
        } }
        W ("  Profile '{0}' settings: {1}" -f $pd.Name, $(if ($keys) { $keys -join ', ' } else { '(no settings file)' }))
        foreach ($e in 'streamEncoder.json', 'recordEncoder.json') {
            $p = Join-Path $pd.FullName $e
            if (Test-Path $p) { W ("    {0}: {1}" -f $e, ((Get-Content $p -Raw) -replace '\s+', ' ')) }
        }
    }
    # The scene JSON is only saved on exit / edits, so the live scene comes from the newest log's switch lines (2026-11-02).
    $obsLog = Get-ChildItem (Join-Path $obs 'logs') -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $switches = @(); if ($obsLog) { $switches = @(Select-String -Path $obsLog.FullName -Pattern "^(\d\d:\d\d:\d\d)\.\d{3}: (?:User )?[Ss]witched to scene '(.+)'$" | ForEach-Object { [pscustomobject]@{ Time = $_.Matches[0].Groups[1].Value; Scene = $_.Matches[0].Groups[2].Value } }) }
    $liveScene = $(if ($switches) { $switches[-1].Scene })
    foreach ($sc in Get-ChildItem (Join-Path $obs 'basic\scenes') -Filter *.json) {
        $j = $null; try { $j = Get-Content $sc.FullName -Raw | ConvertFrom-Json } catch {}
        if (-not $j -or -not $j.sources) { continue }
        $src = @($j.sources)
        W ("  Scene collection '{0}': {1} sources" -f $sc.BaseName, $src.Count)
        W ("    source types: " + (($src | Group-Object id | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', '))
        $flt = @($src | ForEach-Object { $_.filters } | Where-Object { $_ })
        $bs = UrlHosts @($src | Where-Object { $_.id -eq 'browser_source' } | ForEach-Object { if ($_.settings.is_local_file) { 'file' } else { $_.settings.url } })
        if ($bs) { W ("    browser sources by site: " + $bs) }
        if ($flt) { W ("    filters: " + (($flt | Group-Object id | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', ')) }
        foreach ($s in $src | Where-Object { $_.id -match 'dshow_input|mediafoundation|av_capture' }) {
            $fi = [double]$s.settings.frame_interval
            W ("    camera source '{0}': device {1}, resolution {2}, fps {3}, filters: {4}" -f $s.name, $(if ($s.settings.video_device_id) { ($s.settings.video_device_id -split ':')[0] } else { 'not set' }),
                $(if ($s.settings.res_type -eq 1) { $s.settings.resolution } else { 'device default' }), $(if ($fi -gt 0) { [math]::Round(1e7 / $fi) } else { 'default' }),
                $(if ($s.filters) { (@($s.filters) | ForEach-Object { "$($_.name) ($($_.id))" }) -join ', ' } else { 'none' }))
        }
        # which scene OBS last saved as active, and whether a camera source is in it (directly or one nested scene down)
        $camNames = @($src | Where-Object { $_.id -match 'dshow_input|mediafoundation|av_capture' } | ForEach-Object { $_.name })
        if ($liveScene) { $sceneChecks = @(, @($liveScene, "Active scene (from today's OBS log, $($switches[-1].Time))")) }
        else { $sceneChecks = @(@($j.current_program_scene, 'Active scene (as OBS last saved it)'), @($(if ($j.current_scene -ne $j.current_program_scene) { $j.current_scene }), 'Preview scene (as OBS last saved it)')) }
        foreach ($which in $sceneChecks) {
            $sn = $which[0]; if (-not $sn) { continue }
            $items = @(($src | Where-Object { $_.id -eq 'scene' -and $_.name -eq $sn } | Select-Object -First 1).settings.items | ForEach-Object { $_.name })
            $nested = @($items | ForEach-Object { $n = $_; ($src | Where-Object { $_.id -eq 'scene' -and $_.name -eq $n } | Select-Object -First 1).settings.items | ForEach-Object { $_.name } })
            $camIn = @($camNames | Where-Object { $items -contains $_ -or $nested -contains $_ })
            W ("    {0}: '{1}'  camera in it: {2}" -f $which[1], $sn, $(if ($camIn) { 'YES (' + ($camIn -join ', ') + ')' } elseif ($camNames) { 'no' } else { 'no camera source in OBS' }))
        }
        if ($switches) { W ("    Scene switches in today's OBS log: " + (($switches | Select-Object -Last 12 | ForEach-Object { "$($_.Time) $($_.Scene)" }) -join ', ')) }
        if ($flt | Where-Object { $_.id -match 'greenscreen|nv_|shader|blur|upscal' }) { W '    NOTE: GPU-heavy filters in use (background removal / blur / shaders). These cost real GPU time every frame.' }
    }
}

function ObsLogSummary($dir, $label) {
    $all = @(Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.txt', '.log' } | Sort-Object LastWriteTime -Descending)
    if (-not $all) { return @() }
    $logs = @($all | Select-Object -First 3)
    $f = $logs[0]   # current / latest session (2026-11-02: was "newest log with a stream", which skipped today's session)
    $sl = $all | Select-Object -First 15 | Where-Object { Select-String -Path $_.FullName -Pattern '==== (Streaming|Recording) Start' -Quiet } | Select-Object -First 1
    $zipLogs = @($logs) + @($(if ($sl -and $logs -notcontains $sl) { $sl }))
    $files = @($zipLogs | Where-Object { $_.Length -lt 5MB } | ForEach-Object { [pscustomobject]@{ Src = $_.FullName; Name = "$label-$($_.Name)" } })
    W ''
    W ("{0} log summary (latest session): {1}  (last written {2}; newest 3 logs + the last streamed one are in the zip under Streaming\)" -f $label, $f.Name, $f.LastWriteTime)
    $lines = Get-Content $f.FullName | ForEach-Object { $_ -replace '^\d\d:\d\d:\d\d\.\d{3}:\s?', '' }
    $key = $lines | Where-Object { $_ -match 'OBS \d+\.\d+\.\d+|Running as administrator|Loading up D3D1[12] on adapter|Hardware-Accelerated GPU Scheduling|Game Mode|base resolution|output resolution|downscale filter|^\s*fps:\s+\d+/\d+\s*$|==== (Streaming|Recording) (Start|Stop)|skipped frames due to encoding lag|lagged frames due to rendering lag|dropped frames due to insufficient bandwidth' }
    $key | Select-Object -First 40 | ForEach-Object { W ("  " + $_.Trim()) }
    # encoder blocks: the "[<encoder>: '<output>'] ..." line plus its indented detail lines
    $encL = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $lines.Count -and $encL.Count -lt 40; $i++) {
        if ($lines[$i] -match "^\[(obs-nvenc|jim-nvenc|NVENC|texture-amf|AMF|amf|x264|obs_x264|qsv|QSV|av1|hevc|h264|h265|ffmpeg)[^\]]*'[^']*'\]" -or $lines[$i] -match "^encoder '") {
            if ($encL -notcontains $lines[$i].Trim()) { [void]$encL.Add($lines[$i].Trim()) }
            for ($j = $i + 1; $j -lt [math]::Min($lines.Count, $i + 20) -and $lines[$j] -match '^\s+\S'; $j++) { [void]$encL.Add('  ' + $lines[$j].Trim()) }
        }
    }
    if ($encL.Count) { W '  Encoder:'; $encL | ForEach-Object { W ("    " + $_) } }
    # Camera lines: OBS logs the device when the camera source starts or its settings load, and logs failures (device busy etc.).
    $camL = @($lines | Where-Object { $_ -match '\[dshow|\[DShow|win-dshow:|DShow:|video device|Video Capture Device' -and $_ -notmatch '^\s*win-dshow\.dll\s*$|obs_init_module' } | Select-Object -Unique -First 20)
    W '  Camera lines from OBS this session:'
    if ($camL) { $camL | ForEach-Object { W ("    " + $_.Trim()) } } else { W '    (none: OBS did not start or report a camera this session)' }
    $noise = 'error_reporting|ErrorMode|CEF|\[browser|Failed to initialize module|Failed to load .en-US|DeckLink|version info size|redistributable not found|LoadLibrary failed|Failed to open config file|CoreAudio|^\s*win-dshow\.dll\s*$'
    $errL = @($lines | Where-Object { $_ -match 'Could not|Failed to|[Ee]rror|timed out|device.*(busy|in use|lost)' -and $_ -notmatch $noise } | Select-Object -Unique -First 15)
    if ($errL) { W '  Errors:'; $errL | ForEach-Object { W ("    " + $_.Trim()) } }
    if ($sl -and $sl.FullName -ne $f.FullName) {
        W ("  Last stream / recording was in {0} (last written {1}):" -f $sl.Name, $sl.LastWriteTime)
        Get-Content $sl.FullName | ForEach-Object { $_ -replace '^\d\d:\d\d:\d\d\.\d{3}:\s?', '' } |
            Where-Object { $_ -match '==== (Streaming|Recording) (Start|Stop)|skipped frames due to encoding lag|lagged frames due to rendering lag|dropped frames due to insufficient bandwidth|^\s*fps:\s+\d+/\d+\s*$|output resolution' } |
            Select-Object -First 25 | ForEach-Object { W ("    " + $_.Trim()) }
    } elseif (-not $sl) { W '  No stream or recording found in the last 15 logs.' }
    return $files
}
$sePlug = @("$env:ProgramFiles\obs-studio\obs-plugins\64bit", "$env:ProgramData\obs-studio\plugins", (Join-Path $obs 'plugin_config')) | Where-Object { Test-Path $_ } |
    ForEach-Object { Get-ChildItem $_ | Where-Object { $_.Name -match 'streamelements|se\.live' } } | Select-Object -First 1
if ($sePlug) { W ''; W ("StreamElements SE.Live plugin found in OBS: {0}" -f $sePlug.FullName) }
$streamFiles += @(ObsLogSummary (Join-Path $obs 'logs') 'OBS')
$slRoots = @(foreach ($base in $env:APPDATA, $env:LOCALAPPDATA) { Get-ChildItem $base -Directory | Where-Object { $_.Name -match '^(slobs-client|streamlabs)' -and $_.Name -notmatch 'updater' } })
W ''
if (-not $slRoots) { W 'Streamlabs Desktop: no data folder found for this user (not installed or never run).' }
foreach ($sr in $slRoots) {
    W ("Streamlabs data folder: {0}" -f $sr.FullName.Replace($env:USERPROFILE, '%USERPROFILE%'))
    $logDirs = @(Get-ChildItem $sr.FullName -Directory -Recurse -Depth 2 | Where-Object { $_.Name -eq 'logs' })
    if ($logDirs) { foreach ($ld in $logDirs) { $streamFiles += @(ObsLogSummary $ld.FullName ('Streamlabs-' + ($ld.Parent.Name -replace '[^\w-]', ''))) } }
    else { W '  (no logs folder found in it)' }
    $scDir = Join-Path $sr.FullName 'SceneCollections'
    foreach ($sc in Get-ChildItem $scDir -Filter *.json | Where-Object { $_.Name -notmatch 'manifest' } | Sort-Object LastWriteTime -Descending | Select-Object -First 3) {
        $j = $null; try { $j = Get-Content $sc.FullName -Raw | ConvertFrom-Json } catch {}
        $objs = @(SceneObjects $j)
        if (-not $objs) { continue }
        W ("  Streamlabs scene collection {0} (saved {1}): {2} sources/filters" -f $sc.BaseName, $sc.LastWriteTime, $objs.Count)
        W ("    types: " + (($objs | Group-Object Kind | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) x$($_.Count)" }) -join ', '))
        $bs = UrlHosts @($objs | Where-Object { $_.Kind -eq 'browser_source' } | ForEach-Object { if ($_.Settings.is_local_file) { 'file' } else { $_.Settings.url } })
        if ($bs) { W ("    browser sources by site: " + $bs) }
        foreach ($c in $objs | Where-Object { $_.Kind -match 'dshow_input|mediafoundation' }) {
            W ("    camera source '{0}': device {1}, resolution {2}" -f $c.Name, $(if ($c.Settings.video_device_id) { ($c.Settings.video_device_id -split ':')[0] } else { 'not set' }), $(if ($c.Settings.res_type -eq 1) { $c.Settings.resolution } else { 'device default' }))
        }
        if ($objs | Where-Object { $_.Kind -match 'greenscreen|nv_|shader|blur|upscal|background' }) { W '    NOTE: GPU-heavy filters in use (background removal / blur / shaders).' }
    }
}
if (-not (Test-Path $obs) -and -not $slRoots) { W 'OBS Studio: not found for this user either.' }

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
if ($streamFiles) { W 'Also in the zip: Streaming\ (newest OBS / Streamlabs logs).' }
# Saved now with a marker; the TESTS section is added at the end. If the PC crashes under the tests, this copy survives.
[IO.File]::WriteAllText($out, $sb.ToString() + "`r`n--- TESTS NOT FINISHED: if the report ends here, the PC crashed or was shut off during the tests ---`r`n", [Text.Encoding]::UTF8)

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
if ($streamFiles) {
    $sd = Join-Path $work 'Streaming'; New-Item -ItemType Directory -Force $sd | Out-Null
    foreach ($sf in $streamFiles) { Copy-Item -LiteralPath $sf.Src (Join-Path $sd $sf.Name) }
}

# ---------------- DEEP: everything needed to pin down a crash in one pull ----------------
# Deep is the only mode since 2026-11-09 (Mike: "i want full information as its always needed"). NERDS_REPORT_DEEP / -Deep are ignored.
$bigDumps = @()
if ($true) {
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
            if ((Test-Path $r) -and (WerTime (Get-Content $r -Encoding Unicode -Raw) $_) -gt (Get-Date).AddDays(-30)) { Copy-Item $r (Join-Path $wr ($_.Name + '.wer')) }
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
# report.ps1 / the Remote Support EXE upload this pre-tests copy right away, so Mike has the report even if the tests crash the PC.
if ($env:NERDS_REPORT_QUIET) { Write-Host "PRE-TESTS: $out" }

# ---------------- TESTS (2026-11-09): prove the parts work, for pricing / resale and for diagnosis ----------------
# Windows built-in tools only. Run last, after the report is saved and zipped.
$testStart = Get-Date
Section 'TESTS (built-in Windows tools; run after the rest of the report was saved)'
$skipLoad = ''
if ($env:NERDS_REPORT_STREAM) { $skipLoad = 'skipped: streaming mode (the game and OBS are running; a full CPU load would wreck the numbers above)' }
elseif (-not $isAdmin) { $skipLoad = 'skipped: not run as administrator (Windows benchmarks need admin)' }
elseif ($isLaptop -and (Get-CimInstance -Namespace root\wmi BatteryStatus | Where-Object { $_.PowerOnline -eq $false })) { $skipLoad = 'skipped: laptop is on battery. Plug it in and run the report again for the tests.' }
if ($skipLoad) { W "CPU load test and benchmarks: $skipLoad" }
else {
    $secs = $(if ($env:NERDS_TEST_LOAD_SECONDS) { [int]$env:NERDS_TEST_LOAD_SECONDS } else { 120 })
    Step ("Test: CPU at full load on every core ({0} seconds)" -f $secs)
    $n = [Environment]::ProcessorCount
    $until = [DateTime]::UtcNow.AddSeconds($secs)
    $pool = [runspacefactory]::CreateRunspacePool(1, $n); $pool.Open()
    $burn = foreach ($i in 1..$n) {
        $ps = [powershell]::Create(); $ps.RunspacePool = $pool
        [void]$ps.AddScript({ param($u) $x = 1.0; while ([DateTime]::UtcNow -lt $u) { for ($k = 0; $k -lt 200000; $k++) { $x = [math]::Sqrt($x * 1.000001 + $k) } }; $x }).AddArgument($until)
        [pscustomobject]@{ PS = $ps; H = $ps.BeginInvoke() }
    }
    $samples = @()
    while ([DateTime]::UtcNow -lt $until) {
        Start-Sleep -Seconds 5
        $pi = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'"
        # skip a sample that lands after the load stopped
        if ($pi -and [DateTime]::UtcNow -lt $until.AddSeconds(-1)) { $samples += [pscustomobject]@{ S = [int]((Get-Date) - $testStart).TotalSeconds; Load = [int]$pi.PercentProcessorTime; MHz = [int]($pi.ProcessorFrequency * $pi.PercentProcessorPerformance / 100) } }
    }
    foreach ($j in $burn) { try { [void]$j.PS.EndInvoke($j.H) } catch {}; $j.PS.Dispose() }
    $pool.Close(); $pool.Dispose()
    if ($samples) {
        $k = [math]::Max(1, [math]::Min(4, [math]::Floor($samples.Count / 2)))
        $fMHz = ($samples | Select-Object -First $k | Measure-Object MHz -Average).Average
        $lMHz = ($samples | Select-Object -Last $k | Measure-Object MHz -Average).Average
        $avgLoad = ($samples | Measure-Object Load -Average).Average
        W ("CPU full-load test: {0} s on all {1} threads, average load {2:N0}%" -f $secs, $n, $avgLoad)
        W ("  effective clock: start {0:N0} MHz, end {1:N0} MHz, lowest {2:N0} MHz" -f $fMHz, $lMHz, ($samples | Measure-Object MHz -Minimum).Minimum)
        if ($lMHz -lt 0.85 * $fMHz) { W '  NOTE: the clock fell more than 15% during the run = thermal or power throttling (cooler, paste, fans, airflow).' }
        if ($avgLoad -lt 70) { W '  NOTE: load stayed under 70%; something else was competing, or the CPU parked cores.' }
        W ('  samples: ' + (($samples | ForEach-Object { "$($_.S)s $($_.MHz) MHz $($_.Load)%" }) -join ', '))
    }

    # Windows System Assessment Tool: one line per measured number (lines starting with '>').
    function WinSat([string[]]$a) {
        $o = & "$env:SystemRoot\System32\WinSAT.exe" @a 2>&1 | Out-String
        $l = @(($o -split "`r?`n") | Where-Object { $_ -match '^>\s' -and $_ -match '\d' -and $_ -notmatch 'Run Time|Running|Dshow|Media Foundation' } | ForEach-Object { '  ' + (($_ -replace '^>\s*', '') -replace '\s{2,}', '   ').Trim() } | Select-Object -Unique)
        if ($l) { $l } else { '  (no result: ' + ((($o -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -Last 1)) + ')' }
    }
    Step 'Test: CPU and memory speed (Windows benchmark)'
    W ''; W 'CPU benchmark (winsat cpuformal):'; WinSat @('cpuformal') | ForEach-Object { W $_ }
    W ''; W 'Memory benchmark (winsat memformal):'; WinSat @('memformal') | ForEach-Object { W $_ }
    W ''; W 'Drive read speed (winsat; compare to the drive''s rated speed, a slow result = worn drive, wrong slot or PCIe lanes):'
    foreach ($d in Get-PhysicalDisk | Where-Object { $_.Size -gt 0 -and $_.BusType -ne 'USB' } | Sort-Object { [int]$_.DeviceId }) {
        Step ("Test: drive {0} read speed ({1})" -f $d.DeviceId, $d.FriendlyName)
        $seq = @(WinSat @('disk', '-seq', '-read', '-n', "$($d.DeviceId)")) -join ' ' -replace '^\s+', ''
        $ran = @(WinSat @('disk', '-ran', '-read', '-n', "$($d.DeviceId)")) -join ' ' -replace '^\s+', ''
        W ("  Drive {0} {1}:  {2}  |  {3}" -f $d.DeviceId, $d.FriendlyName, $seq, $ran)
    }
    # winsat d3d caps every result near 42 F/s on modern cards, so it is a works / doesn't-work check, not a speed number.
    Step 'Test: graphics card renders (a test window may flash on screen)'
    $gfx3d = @(WinSat @('d3d'))
    W ''
    W ("Graphics render check (winsat d3d): {0}" -f $(if ($gfx3d -match 'Direct3D') { 'PASSED, the card rendered every Direct3D test (Windows caps the speed numbers, so this proves it works, not how fast it is)' } else { 'FAILED or did not run: ' + ($gfx3d -join ' ') }))
}

W ''
W 'Windows Memory Diagnostic results on this PC (RAM tests need a reboot, so the report reads past runs):'
$mdr = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results'} -MaxEvents 3
if ($mdr) { $mdr | ForEach-Object { W ("  {0}  {1}" -f $_.TimeCreated, (($_.Message -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1)) } } else { W '  never run on this PC' }

W ''
W 'Temperatures Windows can read honestly:'
Get-PhysicalDisk | Sort-Object { [int]$_.DeviceId } | ForEach-Object { $r = $_ | Get-StorageReliabilityCounter; W ("  Drive {0} {1}: {2}" -f $_.DeviceId, $_.FriendlyName, $(if ($r.Temperature) { "$($r.Temperature) C" } else { 'not reported' })) }
$smi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
if ($smi) { & $smi.Source --query-gpu=name,temperature.gpu,utilization.gpu,clocks.sm,power.draw,fan.speed --format=csv,noheader 2>$null | ForEach-Object { W "  NVIDIA GPU (name, temp C, load, clock, power, fan): $_" } }
else { W '  GPU temperature: only readable on NVIDIA cards (nvidia-smi); CPU temperature is not reliable without extra tools, so it is left out.' }

W ''
$testErr = @(Get-WinEvent -FilterHashtable @{LogName='System'; StartTime=$testStart} | Where-Object {
    $_.ProviderName -eq 'Microsoft-Windows-WHEA-Logger' -or $_.Id -eq 4101 -or
    ($_.ProviderName -eq 'Microsoft-Windows-Kernel-Processor-Power' -and $_.Id -eq 37) -or
    ($_.Level -le 2 -and $_.ProviderName -match 'nvlddmkm|amdkmdag|amdwddmg|igfx|dxgkrnl|Display') })
W ("Errors logged during the tests (hardware errors, GPU driver resets, CPU speed limited by firmware): {0}" -f $testErr.Count)
$testErr | Select-Object -First 10 | ForEach-Object { W ("  {0}  {1} {2}: {3}" -f $_.TimeCreated, $_.ProviderName, $_.Id, ((($_.Message -split "`r?`n") | Select-Object -First 1))) }
W ("TESTS: {0}   ({1:N0} s)" -f $(if ($skipLoad) { 'PARTIAL, see above' } elseif ($testErr.Count) { 'PROBLEM: errors were logged under load, see above' } else { 'PASSED: no hardware errors, no driver resets, no crash under load' }), ((Get-Date) - $testStart).TotalSeconds)
W '--- end of report ---'
[IO.File]::WriteAllText($out, $sb.ToString(), [Text.Encoding]::UTF8)
if (Test-Path $zip) { Compress-Archive -Path $out -DestinationPath $zip -Update }
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
