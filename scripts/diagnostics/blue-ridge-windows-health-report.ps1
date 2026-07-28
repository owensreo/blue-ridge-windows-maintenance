#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputRoot = 'C:\ProgramData\BlueRidge\HealthReports',
    [int]$EventHours = 24
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $OutputRoot "$env:COMPUTERNAME-$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'windows-health-report.log'

function Write-Log { param([string]$Message) Add-Content -Path $log -Value "[$(Get-Date -Format s)] $Message" }
function Invoke-Safe { param([scriptblock]$Script) try { & $Script } catch { Write-Log $_.Exception.Message; $null } }
function Test-PendingReboot {
    $r = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $r += 'CBS' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $r += 'Windows Update' }
    try { if (Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations' -ErrorAction Stop) { $r += 'Pending file rename' } } catch {}
    [pscustomobject]@{ Pending = ($r.Count -gt 0); Reasons = $r }
}

Write-Log "Starting health report: $outDir"
$os = Get-CimInstance Win32_OperatingSystem
$computer = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,VolumeName,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}},@{n='FreeGB';e={[math]::Round($_.FreeSpace/1GB,2)}},@{n='FreePercent';e={if($_.Size){[math]::Round(($_.FreeSpace/$_.Size)*100,1)}}}
$physical = Invoke-Safe { Get-PhysicalDisk | Select-Object FriendlyName,MediaType,HealthStatus,OperationalStatus,@{n='SizeGB';e={[math]::Round($_.Size/1GB,2)}} }
$bitlocker = Invoke-Safe { Get-BitLockerVolume | Select-Object MountPoint,VolumeStatus,ProtectionStatus,EncryptionMethod }
$tpm = Invoke-Safe { Get-Tpm | Select-Object TpmPresent,TpmReady,TpmEnabled,TpmActivated,ManufacturerIdTxt }
$secureBoot = Invoke-Safe { Confirm-SecureBootUEFI }
$defender = Invoke-Safe { Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,BehaviorMonitorEnabled,AntivirusSignatureVersion,AntivirusSignatureLastUpdated,QuickScanAge,FullScanAge }
$net = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq 'Up' } | ForEach-Object {
    [pscustomobject]@{ Interface=$_.InterfaceAlias; IPv4=($_.IPv4Address.IPAddress -join ', '); Gateway=($_.IPv4DefaultGateway.NextHop -join ', '); DNS=($_.DNSServer.ServerAddresses -join ', ') }
}
$failedServices = Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.State -ne 'Running' } | Select-Object Name,DisplayName,State,StartMode
$events = Get-WinEvent -FilterHashtable @{LogName=@('System','Application'); Level=@(1,2); StartTime=(Get-Date).AddHours(-$EventHours)} -ErrorAction SilentlyContinue | Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,Message
$events | Export-Csv (Join-Path $outDir 'recent-errors.csv') -NoTypeInformation -Encoding UTF8
$pending = Test-PendingReboot
$updateServices = Get-Service wuauserv,bits,cryptsvc -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
$remote = [pscustomobject]@{
    RDPEnabled = ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -ErrorAction SilentlyContinue).fDenyTSConnections -eq 0)
    WinRM      = (Get-Service WinRM -ErrorAction SilentlyContinue).Status
    OpenSSH    = (Get-Service sshd -ErrorAction SilentlyContinue).Status
}

$report = [ordered]@{
    GeneratedAt = Get-Date
    ComputerName = $env:COMPUTERNAME
    OS = [pscustomobject]@{ Caption=$os.Caption; Version=$os.Version; Build=$os.BuildNumber; Architecture=$os.OSArchitecture; LastBoot=$os.LastBootUpTime; UptimeDays=[math]::Round(((Get-Date)-$os.LastBootUpTime).TotalDays,2) }
    Hardware = [pscustomobject]@{ Manufacturer=$computer.Manufacturer; Model=$computer.Model; BIOS=$bios.SMBIOSBIOSVersion; CPU=$cpu.Name; MemoryGB=[math]::Round($computer.TotalPhysicalMemory/1GB,2) }
    Domain = [pscustomobject]@{ PartOfDomain=$computer.PartOfDomain; Domain=$computer.Domain; Workgroup=$computer.Workgroup }
    Disks = $disks
    PhysicalDisks = $physical
    BitLocker = $bitlocker
    TPM = $tpm
    SecureBoot = $secureBoot
    Defender = $defender
    PendingReboot = $pending
    UpdateServices = $updateServices
    FailedAutomaticServices = $failedServices
    Network = $net
    RemoteAccess = $remote
    CriticalErrorEventCount = @($events).Count
}

$jsonPath = Join-Path $outDir 'health-report.json'
$textPath = Join-Path $outDir 'health-report.txt'
$htmlPath = Join-Path $outDir 'health-report.html'
$report | ConvertTo-Json -Depth 8 | Set-Content $jsonPath -Encoding UTF8
$report | Format-List * | Out-String -Width 240 | Set-Content $textPath -Encoding UTF8

$sections = @()
foreach ($key in $report.Keys) {
    $value = $report[$key]
    $sections += "<h2>$key</h2>"
    if ($value -is [System.Collections.IEnumerable] -and $value -isnot [string] -and $value -isnot [hashtable]) {
        $sections += ($value | ConvertTo-Html -Fragment)
    } else {
        $sections += "<pre>$([System.Net.WebUtility]::HtmlEncode(($value | Out-String)))</pre>"
    }
}
$html = @"
<!doctype html><html><head><meta charset='utf-8'><title>Blue Ridge Windows Health Report</title><style>body{font-family:Segoe UI,Arial;margin:32px;background:#f5f7fa;color:#172033}h1{color:#0b4f8a}table{border-collapse:collapse;width:100%;background:white;margin-bottom:18px}th,td{border:1px solid #ccd5df;padding:7px;text-align:left}pre{background:white;border:1px solid #ccd5df;padding:12px;white-space:pre-wrap}</style></head><body><h1>Blue Ridge Windows Health Report</h1>$($sections -join "`n")</body></html>
"@
$html | Set-Content $htmlPath -Encoding UTF8
Write-Log 'Health report completed.'
Write-Host "Health report created: $outDir" -ForegroundColor Green
