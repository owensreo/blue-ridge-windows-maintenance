#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$RunDISM,
    [switch]$TriggerScan,
    [switch]$SkipRestorePoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = 'C:\ProgramData\BlueRidge\WindowsUpdateReset'
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $root,$logDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupDir = Join-Path $root $stamp
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$log = Join-Path $logDir 'windows-update-reset.log'
Start-Transcript -Path $log -Append | Out-Null

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "[+] $Text" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Text) Write-Host "[!] $Text" -ForegroundColor Yellow }

$services = 'bits','wuauserv','cryptsvc','msiserver'
$serviceState = foreach ($name in $services) {
    $svc = Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
    if ($svc) { [pscustomobject]@{Name=$name; State=$svc.State; StartMode=$svc.StartMode} }
}
$serviceState | ConvertTo-Json | Set-Content (Join-Path $backupDir 'service-state.json') -Encoding UTF8

try {
    if (-not $SkipRestorePoint) {
        Write-Step 'Attempting to create a restore point'
        if ($PSCmdlet.ShouldProcess($env:SystemDrive,'Create a system restore point')) {
            try {
                Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue
                Checkpoint-Computer -Description 'Before Blue Ridge Windows Update Reset' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop | Out-Null
                Write-Ok 'Restore point created'
            } catch { Write-WarnMsg 'Restore point unavailable or skipped by Windows' }
        }
    }

    Write-Step 'Stopping Windows Update services'
    foreach ($name in $services) {
        $svc = Get-Service $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            if ($PSCmdlet.ShouldProcess($name,'Stop service')) {
                try { Stop-Service $name -Force -ErrorAction Stop; Write-Ok "Stopped $name" } catch { Write-WarnMsg "Could not stop ${name}: $($_.Exception.Message)" }
            }
        }
    }

    $sd = Join-Path $env:windir 'SoftwareDistribution'
    $cr = Join-Path $env:windir 'System32\catroot2'
    $sdBackup = "$sd.BlueRidge-$stamp"
    $crBackup = "$cr.BlueRidge-$stamp"

    if (Test-Path $sd) {
        if ($PSCmdlet.ShouldProcess($sd,"Rename to $sdBackup")) { Rename-Item $sd $sdBackup -ErrorAction Stop; Write-Ok 'Renamed SoftwareDistribution' }
    }
    if (Test-Path $cr) {
        if ($PSCmdlet.ShouldProcess($cr,"Rename to $crBackup")) { Rename-Item $cr $crBackup -ErrorAction Stop; Write-Ok 'Renamed catroot2' }
    }

    Write-Step 'Starting Windows Update services'
    foreach ($name in $services) {
        $svc = Get-Service $name -ErrorAction SilentlyContinue
        if ($svc) {
            if ($PSCmdlet.ShouldProcess($name,'Start service')) {
                try { Start-Service $name -ErrorAction Stop; Write-Ok "Started $name" } catch { Write-WarnMsg "Could not start ${name}: $($_.Exception.Message)" }
            }
        }
    }

    if ($RunDISM -and $PSCmdlet.ShouldProcess('Windows component store','Run DISM RestoreHealth')) {
        Write-Step 'Running DISM RestoreHealth'
        $p = Start-Process dism.exe -ArgumentList '/Online','/Cleanup-Image','/RestoreHealth' -Wait -PassThru -NoNewWindow
        Write-Host "DISM exit code: $($p.ExitCode)"
    }

    if ($TriggerScan -and $PSCmdlet.ShouldProcess('Windows Update','Trigger update scan')) {
        Write-Step 'Triggering Windows Update scan'
        $uso = Join-Path $env:windir 'System32\UsoClient.exe'
        if (Test-Path $uso) { Start-Process $uso -ArgumentList 'StartScan' -WindowStyle Hidden }
        else { Write-WarnMsg 'UsoClient.exe was not found' }
    }

    [pscustomobject]@{ SoftwareDistributionBackup=$sdBackup; Catroot2Backup=$crBackup; CreatedAt=Get-Date } | ConvertTo-Json | Set-Content (Join-Path $backupDir 'reset-summary.json') -Encoding UTF8
    Write-Ok "Windows Update reset complete. Backup details: $backupDir"
}
finally {
    Stop-Transcript | Out-Null
}
