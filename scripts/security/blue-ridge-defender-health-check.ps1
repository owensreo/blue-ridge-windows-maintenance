#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$UpdateSignatures,
    [switch]$RunQuickScan,
    [switch]$LaunchOfflineScan
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'defender-health-check.log'
Start-Transcript -Path $log -Append | Out-Null

function Write-Info { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "[+] $Text" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Text) Write-Host "[!] $Text" -ForegroundColor Yellow }
function Get-OptionalProperty {
    param([object]$InputObject,[string]$Name)
    if ($null -ne $InputObject -and $InputObject.PSObject.Properties[$Name]) {
        return $InputObject.PSObject.Properties[$Name].Value
    }
    return $null
}

try {
    if (-not (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Defender cmdlets are not available on this system.'
    }

    $status = Get-MpComputerStatus
    $prefs = Get-MpPreference
    $services = Get-Service WinDefend,SecurityHealthService,wscsvc -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
    $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue | Sort-Object InitialDetectionTime -Descending | Select-Object -First 20 ThreatName,Resources,ActionSuccess,InitialDetectionTime,LastThreatStatusChangeTime

    $summary = [pscustomobject]@{
        ComputerName = $env:COMPUTERNAME
        CheckedAt = Get-Date
        AntivirusEnabled = $status.AntivirusEnabled
        RealTimeProtectionEnabled = $status.RealTimeProtectionEnabled
        BehaviorMonitorEnabled = $status.BehaviorMonitorEnabled
        IoavProtectionEnabled = $status.IoavProtectionEnabled
        NISEnabled = $status.NISEnabled
        AntivirusSignatureVersion = $status.AntivirusSignatureVersion
        AntivirusSignatureLastUpdated = $status.AntivirusSignatureLastUpdated
        SignatureAgeHours = if ($status.AntivirusSignatureLastUpdated) { [math]::Round(((Get-Date)-$status.AntivirusSignatureLastUpdated).TotalHours,1) } else { $null }
        QuickScanAgeDays = $status.QuickScanAge
        FullScanAgeDays = $status.FullScanAge
        ScanAvgCPULoadFactor = $prefs.ScanAvgCPULoadFactor
        CloudBlockLevel = (Get-OptionalProperty -InputObject $prefs -Name 'CloudBlockLevel')
        MAPSReporting = $prefs.MAPSReporting
        SubmitSamplesConsent = $prefs.SubmitSamplesConsent
        ExclusionPath = @($prefs.ExclusionPath)
        ExclusionProcess = @($prefs.ExclusionProcess)
        ExclusionExtension = @($prefs.ExclusionExtension)
        Services = $services
        RecentThreats = $threats
    }

    $summary | Format-List *

    if (-not $status.AntivirusEnabled) { Write-WarnMsg 'Defender Antivirus is not enabled.' }
    if (-not $status.RealTimeProtectionEnabled) { Write-WarnMsg 'Real-time protection is not enabled.' }
    if ($summary.SignatureAgeHours -and $summary.SignatureAgeHours -gt 48) { Write-WarnMsg "Defender signatures are $($summary.SignatureAgeHours) hours old." }
    if (@($prefs.ExclusionPath).Count -gt 0 -or @($prefs.ExclusionProcess).Count -gt 0 -or @($prefs.ExclusionExtension).Count -gt 0) {
        Write-WarnMsg 'Defender exclusions are configured. Review them above.'
    }

    if ($UpdateSignatures) {
        Write-Info 'Updating Defender signatures'
        Update-MpSignature
        Write-Ok 'Signature update completed'
    }
    if ($RunQuickScan) {
        Write-Info 'Starting Defender quick scan'
        Start-MpScan -ScanType QuickScan
        Write-Ok 'Quick scan completed'
    }
    if ($LaunchOfflineScan) {
        Write-WarnMsg 'Defender Offline Scan will reboot the computer.'
        $confirm = Read-Host 'Type OFFLINE to continue'
        if ($confirm -eq 'OFFLINE') { Start-MpWDOScan }
        else { Write-Info 'Offline scan cancelled' }
    }
}
finally { Stop-Transcript | Out-Null }
