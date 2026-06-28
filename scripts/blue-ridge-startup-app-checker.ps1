#requires -RunAsAdministrator
<#
Blue Ridge Startup App Checker

Purpose:
- Show startup apps/programs in a reviewable CSV
- Add a Disable column where the admin enters Y or N
- Disable only items marked Y after a second confirmation
- Avoid touching Windows services
- Avoid aggressive changes
- Preserve disabled startup items in backup locations where practical

Checks:
- HKCU Run
- HKCU RunOnce
- HKLM Run
- HKLM RunOnce
- HKLM WOW6432Node Run
- Current user Startup folder
- All Users Startup folder
- Scheduled Tasks with Logon or Startup triggers, excluding Microsoft\Windows tasks

Does not check/disable:
- Windows services
- Drivers
- Security products
- Browser extensions
- Store app background permissions
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$ToolRoot = "$BRRoot\StartupAppChecker"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\startup-app-checker.log"
$ReviewCsv = "$ToolRoot\startup-review.csv"
$DisabledStartupFolder = "$ToolRoot\DisabledStartupItems"

New-Item -ItemType Directory -Force -Path $BRRoot, $ToolRoot, $LogDir, $DisabledStartupFolder | Out-Null

function Write-BRLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    $line = "[$stamp] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Run this from PowerShell as Administrator."
    exit 1
}

function New-SafeId {
    param([string]$Text)

    $safe = $Text -replace '[^a-zA-Z0-9_\-]', '_'
    if ($safe.Length -gt 80) {
        $safe = $safe.Substring(0, 80)
    }
    return $safe
}

function Get-RegistryStartupItems {
    $items = @()

    $registryTargets = @(
        @{
            Hive = "HKCU"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            Scope = "Current User"
        },
        @{
            Hive = "HKCU"
            Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            Scope = "Current User RunOnce"
        },
        @{
            Hive = "HKLM"
            Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
            Scope = "All Users"
        },
        @{
            Hive = "HKLM"
            Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
            Scope = "All Users RunOnce"
        },
        @{
            Hive = "HKLM"
            Path = "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
            Scope = "All Users 32-bit"
        }
    )

    foreach ($target in $registryTargets) {
        if (-not (Test-Path $target.Path)) {
            continue
        }

        try {
            $props = Get-ItemProperty -Path $target.Path
            $propertyNames = $props.PSObject.Properties |
                Where-Object {
                    $_.Name -notin @(
                        "PSPath",
                        "PSParentPath",
                        "PSChildName",
                        "PSDrive",
                        "PSProvider"
                    )
                }

            foreach ($prop in $propertyNames) {
                $id = "REG|$($target.Hive)|$($target.Path)|$($prop.Name)"

                $items += [PSCustomObject]@{
                    Disable = "N"
                    Id = $id
                    Name = $prop.Name
                    Source = "Registry"
                    Scope = $target.Scope
                    Command = [string]$prop.Value
                    Path = $target.Path
                    Action = "Set Disable to Y to remove startup registry value after backing it up"
                }
            }
        } catch {
            Write-BRLog "Could not read registry startup path $($target.Path): $($_.Exception.Message)"
        }
    }

    return $items
}

function Get-StartupFolderItems {
    $items = @()

    $startupFolders = @(
        @{
            Scope = "Current User"
            Path = [Environment]::GetFolderPath("Startup")
        },
        @{
            Scope = "All Users"
            Path = [Environment]::GetFolderPath("CommonStartup")
        }
    )

    foreach ($folder in $startupFolders) {
        if ([string]::IsNullOrWhiteSpace($folder.Path) -or -not (Test-Path $folder.Path)) {
            continue
        }

        try {
            $files = Get-ChildItem -Path $folder.Path -File -Force -ErrorAction SilentlyContinue

            foreach ($file in $files) {
                $id = "FOLDER|$($folder.Scope)|$($file.FullName)"

                $items += [PSCustomObject]@{
                    Disable = "N"
                    Id = $id
                    Name = $file.Name
                    Source = "Startup Folder"
                    Scope = $folder.Scope
                    Command = $file.FullName
                    Path = $file.FullName
                    Action = "Set Disable to Y to move this startup item to the Blue Ridge disabled folder"
                }
            }
        } catch {
            Write-BRLog "Could not read startup folder $($folder.Path): $($_.Exception.Message)"
        }
    }

    return $items
}

function Get-StartupScheduledTasks {
    $items = @()

    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object {
                $_.State -ne "Disabled" -and
                $_.TaskPath -notlike "\Microsoft\Windows\*" -and
                (
                    $_.Triggers.TriggerType -contains "Logon" -or
                    $_.Triggers.TriggerType -contains "Startup"
                )
            }

        foreach ($task in $tasks) {
            $taskName = $task.TaskName
            $taskPath = $task.TaskPath
            $fullTaskName = "$taskPath$taskName"

            $actionsText = ($task.Actions | ForEach-Object {
                $exe = $_.Execute
                $args = $_.Arguments
                "$exe $args".Trim()
            }) -join " ; "

            $triggerText = ($task.Triggers | ForEach-Object {
                $_.TriggerType
            }) -join ", "

            $id = "TASK|$taskPath|$taskName"

            $items += [PSCustomObject]@{
                Disable = "N"
                Id = $id
                Name = $taskName
                Source = "Scheduled Task"
                Scope = "Task Scheduler"
                Command = $actionsText
                Path = $fullTaskName
                Action = "Set Disable to Y to disable this scheduled task. Triggers: $triggerText"
            }
        }
    } catch {
        Write-BRLog "Could not read scheduled startup tasks: $($_.Exception.Message)"
    }

    return $items
}

function Backup-AndRemoveRegistryValue {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Command
    )

    try {
        $backupRoot = $null

        if ($Path -like "HKCU:*") {
            $backupRoot = "HKCU:\Software\BlueRidge\DisabledStartup"
        } elseif ($Path -like "HKLM:*") {
            $backupRoot = "HKLM:\Software\BlueRidge\DisabledStartup"
        } else {
            Write-BRLog "Unknown registry hive for $Name at $Path"
            return
        }

        $safeName = New-SafeId -Text $Name
        $backupPath = Join-Path $backupRoot $safeName

        New-Item -ItemType Directory -Force -Path $backupPath | Out-Null

        New-ItemProperty -Path $backupPath -Name "OriginalPath" -Value $Path -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $backupPath -Name "OriginalName" -Value $Name -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $backupPath -Name "OriginalCommand" -Value $Command -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $backupPath -Name "DisabledOn" -Value (Get-Date).ToString("yyyy-MM-dd hh:mm:ss tt") -PropertyType String -Force | Out-Null

        Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop

        Write-BRLog "Disabled registry startup item: $Name"
    } catch {
        Write-BRLog "Failed to disable registry startup item $Name : $($_.Exception.Message)"
    }
}

function Move-StartupFolderItem {
    param(
        [string]$Name,
        [string]$Path
    )

    try {
        if (-not (Test-Path $Path)) {
            Write-BRLog "Startup folder item no longer exists: $Path"
            return
        }

        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $destName = "$timestamp-$Name"
        $destPath = Join-Path $DisabledStartupFolder $destName

        Move-Item -Path $Path -Destination $destPath -Force -ErrorAction Stop

        Write-BRLog "Moved startup folder item to disabled folder: $Path -> $destPath"
    } catch {
        Write-BRLog "Failed to move startup folder item $Path : $($_.Exception.Message)"
    }
}

function Disable-StartupScheduledTask {
    param([string]$Path)

    try {
        $normalized = $Path.Trim()
        $lastSlash = $normalized.LastIndexOf("\")

        if ($lastSlash -lt 0) {
            Write-BRLog "Could not parse scheduled task path: $Path"
            return
        }

        $taskPath = $normalized.Substring(0, $lastSlash + 1)
        $taskName = $normalized.Substring($lastSlash + 1)

        Disable-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
        Write-BRLog "Disabled scheduled task: $Path"
    } catch {
        Write-BRLog "Failed to disable scheduled task $Path : $($_.Exception.Message)"
    }
}

Write-BRLog "=== Blue Ridge Startup App Checker started ==="

Write-BRLog "Collecting startup registry entries."
$registryItems = Get-RegistryStartupItems

Write-BRLog "Collecting startup folder entries."
$folderItems = Get-StartupFolderItems

Write-BRLog "Collecting scheduled tasks with logon/startup triggers."
$taskItems = Get-StartupScheduledTasks

$allItems = @()
$allItems += $registryItems
$allItems += $folderItems
$allItems += $taskItems

if (-not $allItems -or $allItems.Count -eq 0) {
    Write-BRLog "No startup items found."
    Write-Host ""
    Write-Host "No startup items found."
    exit 0
}

$allItems |
    Sort-Object Source, Scope, Name |
    Export-Csv -Path $ReviewCsv -NoTypeInformation -Encoding UTF8

Write-BRLog "Startup review CSV created: $ReviewCsv"

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Startup App Checker"
Write-Host "============================================================"
Write-Host ""
Write-Host "A review file has been created:"
Write-Host "    $ReviewCsv"
Write-Host ""
Write-Host "In the Disable column, put:"
Write-Host "    Y = disable that startup item"
Write-Host "    N = leave it alone"
Write-Host ""
Write-Host "Save the file in Notepad when finished."
Write-Host "Then return to this PowerShell window and press Enter."
Write-Host ""
Write-Host "This script does not disable services."
Write-Host "============================================================"
Write-Host ""

Start-Process notepad.exe -ArgumentList "`"$ReviewCsv`"" -Wait

Read-Host "Press Enter after saving the CSV review file"

Write-BRLog "Reading review decisions from CSV."

try {
    $decisions = Import-Csv -Path $ReviewCsv
} catch {
    Write-BRLog "Could not read review CSV: $($_.Exception.Message)"
    exit 1
}

$toDisable = $decisions | Where-Object {
    $_.Disable -match '^(Y|y|Yes|YES|yes)$'
}

if (-not $toDisable -or $toDisable.Count -eq 0) {
    Write-BRLog "No startup items were marked for disable."
    Write-Host ""
    Write-Host "No items marked Y. Nothing disabled."
    exit 0
}

Write-Host ""
Write-Host "The following startup items were marked for disable:"
Write-Host ""

$toDisable |
    Select-Object Name, Source, Scope, Command |
    Format-Table -AutoSize

Write-Host ""
$confirm = Read-Host "Type DISABLE to confirm disabling these startup items"

if ($confirm -ne "DISABLE") {
    Write-BRLog "Admin did not confirm disable operation. Exiting."
    Write-Host "No changes made."
    exit 0
}

foreach ($item in $toDisable) {
    switch ($item.Source) {
        "Registry" {
            Backup-AndRemoveRegistryValue `
                -Name $item.Name `
                -Path $item.Path `
                -Command $item.Command
        }

        "Startup Folder" {
            Move-StartupFolderItem `
                -Name $item.Name `
                -Path $item.Path
        }

        "Scheduled Task" {
            Disable-StartupScheduledTask `
                -Path $item.Path
        }

        default {
            Write-BRLog "Unknown startup source for item $($item.Name): $($item.Source)"
        }
    }
}

Write-BRLog "=== Blue Ridge Startup App Checker completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Startup App Checker completed."
Write-Host ""
Write-Host "Review CSV:"
Write-Host "    $ReviewCsv"
Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
Write-Host ""
Write-Host "Moved startup folder items are stored here:"
Write-Host "    $DisabledStartupFolder"
Write-Host ""
Write-Host "Registry startup backups are stored under:"
Write-Host "    HKCU:\Software\BlueRidge\DisabledStartup"
Write-Host "    HKLM:\Software\BlueRidge\DisabledStartup"
Write-Host "============================================================"
