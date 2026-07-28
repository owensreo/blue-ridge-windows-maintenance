#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ToolRoot = 'C:\ProgramData\BlueRidge\StartupAppChecker'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$disabledFolder = Join-Path $ToolRoot 'DisabledStartupItems'
$reviewCsv = Join-Path $ToolRoot 'startup-review.csv'
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$log = Join-Path $logDir 'startup-app-restore.log'
Start-Transcript -Path $log -Append | Out-Null

function Write-Info { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-Ok { param([string]$Text) Write-Host "[+] $Text" -ForegroundColor Green }
function Write-WarnMsg { param([string]$Text) Write-Host "[!] $Text" -ForegroundColor Yellow }

function Get-RegistryBackups {
    $items = @()
    foreach ($root in @('HKCU:\Software\BlueRidge\DisabledStartup','HKLM:\Software\BlueRidge\DisabledStartup')) {
        if (-not (Test-Path $root)) { continue }
        foreach ($key in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            try {
                $p = Get-ItemProperty $key.PSPath -ErrorAction Stop
                $items += [pscustomobject]@{
                    Type='Registry'; DisplayName=$p.OriginalName; BackupPath=$key.PSPath
                    OriginalPath=$p.OriginalPath; OriginalName=$p.OriginalName; OriginalCommand=$p.OriginalCommand
                }
            } catch { Write-WarnMsg "Could not read registry backup $($key.PSPath)" }
        }
    }
    $items
}

function Get-FolderBackups {
    if (-not (Test-Path $disabledFolder)) { return @() }
    $review = if (Test-Path $reviewCsv) { @(Import-Csv $reviewCsv) } else { @() }
    foreach ($file in Get-ChildItem $disabledFolder -File -ErrorAction SilentlyContinue) {
        $originalName = $file.Name -replace '^\d{8}-\d{6}-',''
        $match = $review | Where-Object { $_.Source -eq 'Startup Folder' -and $_.Name -eq $originalName } | Select-Object -First 1
        [pscustomobject]@{
            Type='Startup Folder'; DisplayName=$originalName; BackupPath=$file.FullName
            OriginalPath=if($match){$match.Path}else{$null}; OriginalName=$originalName; OriginalCommand=$null
        }
    }
}

function Get-TaskBackups {
    if (-not (Test-Path $reviewCsv)) { return @() }
    foreach ($item in Import-Csv $reviewCsv | Where-Object { $_.Source -eq 'Scheduled Task' }) {
        $full = [string]$item.Path
        $idx = $full.LastIndexOf('\')
        if ($idx -lt 0) { continue }
        $taskPath = $full.Substring(0,$idx+1)
        $taskName = $full.Substring($idx+1)
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($task -and $task.State -eq 'Disabled') {
            [pscustomobject]@{ Type='Scheduled Task'; DisplayName=$full; BackupPath=$null; OriginalPath=$full; TaskName=$taskName; TaskPath=$taskPath }
        }
    }
}

try {
    $items = @()
    $items += Get-RegistryBackups
    $items += Get-FolderBackups
    $items += Get-TaskBackups
    if (-not $items -or $items.Count -eq 0) { throw 'No disabled startup items were found.' }

    Write-Host ''
    Write-Host 'Blue Ridge Startup App Restore' -ForegroundColor Cyan
    for ($i=0; $i -lt $items.Count; $i++) { Write-Host "[$($i+1)] $($items[$i].Type) - $($items[$i].DisplayName)" }
    Write-Host '[A] Restore all items'
    $choice = Read-Host 'Enter a number or A'

    $selected = if ($choice -match '^[Aa]$') { @($items) } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $items.Count) { @($items[[int]$choice-1]) } else { throw 'Invalid selection.' }
    Write-Host ''
    $selected | Format-Table Type,DisplayName,OriginalPath -AutoSize
    if ((Read-Host 'Type RESTORE to continue') -ne 'RESTORE') { Write-Info 'Restore cancelled'; return }

    foreach ($item in $selected) {
        try {
            switch ($item.Type) {
                'Registry' {
                    if (-not (Test-Path $item.OriginalPath)) { New-Item -Path $item.OriginalPath -Force | Out-Null }
                    New-ItemProperty -Path $item.OriginalPath -Name $item.OriginalName -Value $item.OriginalCommand -PropertyType String -Force | Out-Null
                    Remove-Item -Path $item.BackupPath -Recurse -Force
                    Write-Ok "Restored registry startup item: $($item.DisplayName)"
                }
                'Startup Folder' {
                    if (-not $item.OriginalPath) { throw 'Original Startup-folder path is unavailable in startup-review.csv.' }
                    New-Item -ItemType Directory -Path (Split-Path $item.OriginalPath -Parent) -Force | Out-Null
                    Move-Item $item.BackupPath $item.OriginalPath -Force
                    Write-Ok "Restored Startup-folder item: $($item.DisplayName)"
                }
                'Scheduled Task' {
                    Enable-ScheduledTask -TaskName $item.TaskName -TaskPath $item.TaskPath -ErrorAction Stop | Out-Null
                    Write-Ok "Enabled scheduled task: $($item.DisplayName)"
                }
            }
        } catch { Write-WarnMsg "Could not restore $($item.DisplayName): $($_.Exception.Message)" }
    }
    Write-Ok 'Startup app restore workflow complete.'
}
finally { Stop-Transcript | Out-Null }
