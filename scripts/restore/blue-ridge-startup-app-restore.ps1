#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$BackupRoot = 'C:\ProgramData\BlueRidge\StartupAppChecker\DisabledStartupItems',
    [switch]$RestoreAll
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'startup-app-restore.log'
Start-Transcript -Path $log -Append | Out-Null

function Write-Info { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "[+] $Text" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Text) Write-Host "[!] $Text" -ForegroundColor Yellow }

try {
    if (-not (Test-Path $BackupRoot)) { throw "Backup folder not found: $BackupRoot" }

    $manifests = Get-ChildItem $BackupRoot -Recurse -File -Include *.json,*.csv -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if (-not $manifests) { throw 'No startup-item backup manifests were found.' }

    Write-Info 'Available startup backup manifests:'
    for ($i=0; $i -lt $manifests.Count; $i++) { Write-Host "[$($i+1)] $($manifests[$i].FullName)" }

    if ($RestoreAll) { $selected = @($manifests) }
    else {
        $choice = Read-Host 'Enter manifest number to restore'
        if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $manifests.Count) { throw 'Invalid selection.' }
        $selected = @($manifests[[int]$choice-1])
    }

    foreach ($manifest in $selected) {
        Write-Info "Reading $($manifest.FullName)"
        $items = if ($manifest.Extension -eq '.json') { @(Get-Content $manifest.FullName -Raw | ConvertFrom-Json) } else { @(Import-Csv $manifest.FullName) }

        foreach ($item in $items) {
            $type = [string]$item.Type
            try {
                switch -Regex ($type) {
                    'Registry|Run' {
                        $path = [string]$item.Path
                        $name = [string]$item.Name
                        $value = [string]$item.Value
                        if (-not $path -or -not $name) { throw 'Registry backup is missing Path or Name.' }
                        if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
                        New-ItemProperty -Path $path -Name $name -Value $value -PropertyType String -Force | Out-Null
                        Write-Ok "Restored registry startup item: $name"
                    }
                    'StartupFolder|Shortcut|File' {
                        $source = [string]$item.BackupPath
                        $destination = [string]$item.OriginalPath
                        if (-not $source) { $source = [string]$item.Source }
                        if (-not $destination) { $destination = [string]$item.Destination }
                        if (-not (Test-Path $source)) { throw "Backup file not found: $source" }
                        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
                        Copy-Item $source $destination -Force
                        Write-Ok "Restored startup file: $destination"
                    }
                    'ScheduledTask|Task' {
                        $taskName = [string]$item.TaskName
                        $taskPath = [string]$item.TaskPath
                        if (-not $taskPath) { $taskPath = '\' }
                        Enable-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
                        Write-Ok "Enabled scheduled task: $taskPath$taskName"
                    }
                    default { Write-WarnMsg "Unknown backup item type '$type'; skipped." }
                }
            } catch { Write-WarnMsg "Could not restore item '$($item.Name)': $($_.Exception.Message)" }
        }
    }
    Write-Ok 'Startup app restore workflow complete.'
}
finally { Stop-Transcript | Out-Null }
