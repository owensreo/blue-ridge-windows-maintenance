#requires -RunAsAdministrator
<#
Blue Ridge Outlook Teams Soft Reset

Purpose:
- Soft-reset classic Outlook and Microsoft Teams when they will not open, hang, loop, or act goofy
- Clear Teams cache for classic Teams and new Teams
- Clear safe Outlook cache areas
- Reset Outlook navigation pane
- Optionally launch Excel briefly to wake Office update plumbing
- Optionally force Microsoft Office Click-to-Run update
- Optionally open Office Quick Repair
- Optionally launch classic Outlook in safe mode
- Optionally move Office identity cache folders to backup
- Avoid deleting mail, calendars, PST files, OST files, or Outlook profiles

Run context:
- Run from the affected user's Windows session when possible
- Run elevated as Administrator
- User-specific caches are per-profile, so this script targets the selected local user profile

Does not:
- Delete PST files
- Delete OST files by default
- Delete Outlook profiles
- Remove mail accounts
- Remove calendars
- Force new Outlook
- Uninstall Teams
- Uninstall Office
- Reset the user's password
- Delete Credential Manager entries by default
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$ToolRoot = "$BRRoot\OutlookTeamsSoftReset"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\outlook-teams-soft-reset.log"
$BackupRoot = "$ToolRoot\Backups"

New-Item -ItemType Directory -Force -Path $BRRoot, $ToolRoot, $LogDir, $BackupRoot | Out-Null

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

function Get-CurrentInteractiveUser {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        return $cs.UserName
    } catch {
        return $null
    }
}

function Get-LocalUserProfiles {
    $excluded = @(
        "Public",
        "Default",
        "Default User",
        "All Users",
        "defaultuser0"
    )

    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $excluded } |
        Sort-Object Name
}

function Select-TargetProfile {
    $profiles = @(Get-LocalUserProfiles)

    if (-not $profiles -or $profiles.Count -eq 0) {
        Write-BRLog "No local user profiles found."
        Write-Host "No local user profiles found."
        exit 1
    }

    $interactive = Get-CurrentInteractiveUser

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Select target user profile"
    Write-Host "============================================================"

    if ($interactive) {
        Write-Host "Current interactive user appears to be:"
        Write-Host "    $interactive"
        Write-Host ""
    }

    for ($i = 0; $i -lt $profiles.Count; $i++) {
        Write-Host "[$($i + 1)] $($profiles[$i].Name) - $($profiles[$i].FullName)"
    }

    Write-Host ""
    $choice = Read-Host "Enter profile number to repair"

    if (-not ($choice -as [int])) {
        Write-BRLog "Invalid profile selection: $choice"
        Write-Host "Invalid selection."
        exit 1
    }

    $index = [int]$choice - 1

    if ($index -lt 0 -or $index -ge $profiles.Count) {
        Write-BRLog "Profile selection out of range: $choice"
        Write-Host "Selection out of range."
        exit 1
    }

    return $profiles[$index]
}

function Stop-AppProcesses {
    Write-BRLog "Closing Outlook, Teams, Office apps, and related helper processes."

    $processNames = @(
        "OUTLOOK",
        "olk",
        "Teams",
        "ms-teams",
        "msteams",
        "EXCEL",
        "WINWORD",
        "POWERPNT",
        "ONENOTE",
        "MSPUB",
        "VISIO",
        "MSACCESS",
        "OfficeClickToRun"
    )

    foreach ($name in $processNames) {
        try {
            $procs = Get-Process -Name $name -ErrorAction SilentlyContinue

            foreach ($proc in $procs) {
                Write-BRLog "Stopping process: $($proc.ProcessName) PID $($proc.Id)"
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
        } catch {
            Write-BRLog "Could not stop process $name : $($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 3
}

function Clear-FolderContents {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        Write-BRLog "Skipping missing path for $Label : $Path"
        return
    }

    Write-BRLog "Clearing $Label : $Path"

    try {
        Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-BRLog "Cleared $Label"
    } catch {
        Write-BRLog "Could not fully clear $Label : $($_.Exception.Message)"
    }
}

function Move-FolderToBackup {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
        Write-BRLog "Skipping missing folder for backup/move: $Label : $Path"
        return
    }

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $safeLabel = $Label -replace '[^a-zA-Z0-9_\-]', '_'
        $dest = Join-Path $BackupRoot "$timestamp-$safeLabel"

        Move-Item -Path $Path -Destination $dest -Force -ErrorAction Stop
        Write-BRLog "Moved $Label to backup: $dest"
    } catch {
        Write-BRLog "Could not move $Label to backup: $($_.Exception.Message)"
    }
}

function Clear-ClassicTeamsCache {
    param([string]$UserProfile)

    $teamsRoot = Join-Path $UserProfile "AppData\Roaming\Microsoft\Teams"

    if (-not (Test-Path $teamsRoot)) {
        Write-BRLog "Classic Teams cache path not found: $teamsRoot"
        return
    }

    Write-BRLog "Clearing classic Teams cache."

    $cachePaths = @(
        "Cache",
        "Code Cache",
        "GPUCache",
        "IndexedDB",
        "Local Storage",
        "Session Storage",
        "tmp",
        "databases",
        "blob_storage",
        "Service Worker\CacheStorage",
        "Service Worker\ScriptCache"
    )

    foreach ($relative in $cachePaths) {
        Clear-FolderContents -Path (Join-Path $teamsRoot $relative) -Label "Classic Teams $relative"
    }
}

function Clear-NewTeamsCache {
    param([string]$UserProfile)

    $newTeamsRoot = Join-Path $UserProfile "AppData\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"

    if (-not (Test-Path $newTeamsRoot)) {
        Write-BRLog "New Teams cache path not found: $newTeamsRoot"
        return
    }

    Write-BRLog "Clearing new Teams cache."

    $cachePaths = @(
        "Cache",
        "Code Cache",
        "GPUCache",
        "IndexedDB",
        "Local Storage",
        "Session Storage",
        "Service Worker\CacheStorage",
        "Service Worker\ScriptCache"
    )

    foreach ($relative in $cachePaths) {
        Clear-FolderContents -Path (Join-Path $newTeamsRoot $relative) -Label "New Teams $relative"
    }
}

function Clear-OutlookSafeCaches {
    param([string]$UserProfile)

    Write-BRLog "Clearing safe Outlook and Office cache areas."

    $local = Join-Path $UserProfile "AppData\Local"

    $outlookRoamCache = Join-Path $local "Microsoft\Outlook\RoamCache"
    $outlookTemp = Join-Path $local "Microsoft\Windows\INetCache\Content.Outlook"
    $officeFileCache = Join-Path $local "Microsoft\Office\16.0\OfficeFileCache"

    Clear-FolderContents -Path $outlookRoamCache -Label "Outlook RoamCache"
    Clear-FolderContents -Path $outlookTemp -Label "Outlook temp attachment cache"
    Clear-FolderContents -Path $officeFileCache -Label "Office file cache"

    # This intentionally does NOT delete:
    # AppData\Local\Microsoft\Outlook\*.ost
    # Documents\Outlook Files\*.pst
    # Outlook profiles
}

function Find-OutlookExe {
    $paths = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\root\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office16\OUTLOOK.EXE",
        "$env:ProgramFiles\Microsoft Office\Office15\OUTLOOK.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office15\OUTLOOK.EXE"
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    try {
        $searchRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }

        foreach ($root in $searchRoots) {
            $found = Get-ChildItem -Path $root -Filter "OUTLOOK.EXE" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($found) {
                return $found.FullName
            }
        }
    } catch {}

    return $null
}

function Find-ExcelExe {
    $paths = @(
        "$env:ProgramFiles\Microsoft Office\root\Office16\EXCEL.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\root\Office16\EXCEL.EXE",
        "$env:ProgramFiles\Microsoft Office\Office16\EXCEL.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office16\EXCEL.EXE",
        "$env:ProgramFiles\Microsoft Office\Office15\EXCEL.EXE",
        "$env:ProgramFiles(x86)\Microsoft Office\Office15\EXCEL.EXE"
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    try {
        $searchRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }

        foreach ($root in $searchRoots) {
            $found = Get-ChildItem -Path $root -Filter "EXCEL.EXE" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($found) {
                return $found.FullName
            }
        }
    } catch {}

    return $null
}

function Find-OfficeC2RClient {
    $paths = @(
        "$env:ProgramFiles\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe",
        "$env:ProgramFiles(x86)\Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe"
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }

    try {
        $searchRoots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) }

        foreach ($root in $searchRoots) {
            $found = Get-ChildItem -Path $root -Filter "OfficeC2RClient.exe" -Recurse -ErrorAction SilentlyContinue |
                Select-Object -First 1

            if ($found) {
                return $found.FullName
            }
        }
    } catch {}

    return $null
}

function Reset-OutlookNavPane {
    $outlookExe = Find-OutlookExe

    if (-not $outlookExe) {
        Write-BRLog "OUTLOOK.EXE not found. Cannot run /resetnavpane."
        Write-Host "OUTLOOK.EXE not found. Skipping Outlook /resetnavpane."
        return
    }

    Write-BRLog "Running Outlook /resetnavpane using: $outlookExe"

    try {
        Start-Process -FilePath $outlookExe -ArgumentList "/resetnavpane" -Wait -ErrorAction SilentlyContinue
        Write-BRLog "Outlook /resetnavpane command completed."
    } catch {
        Write-BRLog "Outlook /resetnavpane failed: $($_.Exception.Message)"
    }
}

function Optional-LaunchExcelToWakeOffice {
    $excelExe = Find-ExcelExe

    if (-not $excelExe) {
        Write-BRLog "EXCEL.EXE not found. Skipping Excel wake-up."
        Write-Host ""
        Write-Host "EXCEL.EXE not found. Skipping Excel wake-up."
        return
    }

    Write-Host ""
    Write-Host "Excel wake-up note:"
    Write-Host "Sometimes launching Excel briefly wakes up Office Click-to-Run/update plumbing."
    Write-Host "The script will open Excel, wait about 12 seconds, then close it."
    Write-Host ""

    $choice = Read-Host "Launch Excel briefly? Type EXCEL to launch"

    if ($choice -ne "EXCEL") {
        Write-BRLog "Admin skipped Excel wake-up."
        return
    }

    Write-BRLog "Launching Excel briefly: $excelExe"

    try {
        $proc = Start-Process -FilePath $excelExe -PassThru
        Start-Sleep -Seconds 12

        if ($proc -and -not $proc.HasExited) {
            Write-BRLog "Closing Excel after wake-up attempt."
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }

        Write-BRLog "Excel wake-up attempt completed."
    } catch {
        Write-BRLog "Excel wake-up failed: $($_.Exception.Message)"
    }
}

function Invoke-OfficeClickToRunUpdate {
    $c2r = Find-OfficeC2RClient

    if (-not $c2r) {
        Write-BRLog "OfficeC2RClient.exe not found. Office may not be Click-to-Run/Microsoft 365."
        Write-Host ""
        Write-Host "OfficeC2RClient.exe not found."
        Write-Host "Office may be MSI-based, Store-based, missing, or installed oddly."
        return
    }

    Write-Host ""
    Write-Host "Office update note:"
    Write-Host "This asks Microsoft Office Click-to-Run to check for and install updates."
    Write-Host "It should not delete Outlook profiles, mail, calendars, PST files, or OST files."
    Write-Host ""

    $choice = Read-Host "Force Microsoft Office update now? Type UPDATEOFFICE to continue"

    if ($choice -ne "UPDATEOFFICE") {
        Write-BRLog "Admin skipped Office Click-to-Run update."
        return
    }

    Write-BRLog "Starting Office Click-to-Run update using: $c2r"

    try {
        Start-Process -FilePath $c2r -ArgumentList "/update user" -Wait -ErrorAction SilentlyContinue
        Write-BRLog "Office Click-to-Run update command completed."
    } catch {
        Write-BRLog "Office Click-to-Run update failed: $($_.Exception.Message)"
    }
}

function Optional-OfficeQuickRepair {
    Write-Host ""
    Write-Host "Office Quick Repair note:"
    Write-Host "This opens Microsoft's installed apps/program repair workflow."
    Write-Host "Choose Microsoft 365 / Office, then Modify, then Quick Repair."
    Write-Host "It should not delete mailbox data, PST files, calendars, or Outlook profiles."
    Write-Host ""

    $choice = Read-Host "Open Office repair applet? Type REPAIR to open"

    if ($choice -ne "REPAIR") {
        Write-BRLog "Admin skipped Office repair applet."
        return
    }

    Write-BRLog "Opening Programs and Features for Office repair."

    try {
        Start-Process "appwiz.cpl"
    } catch {
        Write-BRLog "Could not open appwiz.cpl: $($_.Exception.Message)"
    }
}

function Optional-OutlookSafeMode {
    $outlookExe = Find-OutlookExe

    if (-not $outlookExe) {
        Write-BRLog "OUTLOOK.EXE not found. Cannot launch safe mode."
        return
    }

    Write-Host ""
    $choice = Read-Host "Launch classic Outlook in safe mode after cleanup? Type SAFE to launch"

    if ($choice -eq "SAFE") {
        Write-BRLog "Launching Outlook safe mode."
        try {
            Start-Process -FilePath $outlookExe -ArgumentList "/safe"
        } catch {
            Write-BRLog "Could not launch Outlook safe mode: $($_.Exception.Message)"
        }
    } else {
        Write-BRLog "Admin skipped Outlook safe mode launch."
    }
}

function Optional-OfficeIdentityCacheReset {
    param([string]$UserProfile)

    Write-Host ""
    Write-Host "Office identity cache reset warning:"
    Write-Host "This may sign the user out of Office, Outlook, Teams, OneDrive, or Microsoft 365 apps."
    Write-Host "It does NOT delete mailbox data, calendars, PST files, or OST files."
    Write-Host "Only use this if Outlook/Teams are stuck in sign-in/token weirdness."
    Write-Host ""

    $choice = Read-Host "Type IDENTITYRESET to move Office identity cache folders to backup"

    if ($choice -ne "IDENTITYRESET") {
        Write-BRLog "Admin skipped Office identity cache reset."
        return
    }

    Write-BRLog "Admin chose Office identity cache reset."

    $local = Join-Path $UserProfile "AppData\Local"
    $roaming = Join-Path $UserProfile "AppData\Roaming"

    $identityPaths = @(
        @{
            Path = Join-Path $local "Microsoft\Office\16.0\Wef"
            Label = "Office_Wef"
        },
        @{
            Path = Join-Path $local "Microsoft\Office\16.0\Licensing"
            Label = "Office_Licensing"
        },
        @{
            Path = Join-Path $local "Microsoft\OneAuth"
            Label = "Microsoft_OneAuth"
        },
        @{
            Path = Join-Path $local "Microsoft\IdentityCache"
            Label = "Microsoft_IdentityCache"
        },
        @{
            Path = Join-Path $roaming "Microsoft\Teams"
            Label = "Classic_Teams_Profile_Folder"
        }
    )

    foreach ($item in $identityPaths) {
        Move-FolderToBackup -Path $item.Path -Label $item.Label
    }
}

function Show-DataSafetyReminder {
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Data safety guardrails"
    Write-Host "============================================================"
    Write-Host "This script does NOT delete:"
    Write-Host "    Outlook PST files"
    Write-Host "    Outlook OST files by default"
    Write-Host "    Outlook profiles"
    Write-Host "    Mail accounts"
    Write-Host "    Calendar entries"
    Write-Host "    Contacts"
    Write-Host ""
    Write-Host "It clears cache, pokes Office update, and offers repair steps."
    Write-Host "============================================================"
    Write-Host ""
}

Write-BRLog "=== Blue Ridge Outlook Teams Soft Reset started ==="

Show-DataSafetyReminder

$profile = Select-TargetProfile
$UserProfile = $profile.FullName

Write-BRLog "Selected target profile: $($profile.Name) at $UserProfile"

Write-Host ""
Write-Host "Selected profile:"
Write-Host "    $($profile.Name)"
Write-Host "    $UserProfile"
Write-Host ""

$confirm = Read-Host "Type SOFTRESET to close Outlook/Teams/Office apps and clear safe caches"

if ($confirm -ne "SOFTRESET") {
    Write-BRLog "Admin did not confirm soft reset."
    Write-Host "No changes made."
    exit 0
}

Stop-AppProcesses

Clear-ClassicTeamsCache -UserProfile $UserProfile
Clear-NewTeamsCache -UserProfile $UserProfile
Clear-OutlookSafeCaches -UserProfile $UserProfile

Reset-OutlookNavPane

Optional-LaunchExcelToWakeOffice
Invoke-OfficeClickToRunUpdate
Optional-OfficeQuickRepair
Optional-OutlookSafeMode
Optional-OfficeIdentityCacheReset -UserProfile $UserProfile

Write-BRLog "=== Blue Ridge Outlook Teams Soft Reset completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Outlook Teams Soft Reset completed."
Write-Host ""
Write-Host "What it did:"
Write-Host "    Closed Outlook, Teams, and Office apps"
Write-Host "    Cleared classic Teams cache if present"
Write-Host "    Cleared new Teams cache if present"
Write-Host "    Cleared Outlook RoamCache"
Write-Host "    Cleared Outlook temp attachment cache"
Write-Host "    Cleared Office file cache"
Write-Host "    Ran Outlook /resetnavpane if Outlook was found"
Write-Host "    Offered Excel launch to wake Office"
Write-Host "    Offered Microsoft Office Click-to-Run update"
Write-Host "    Offered Office Quick Repair applet"
Write-Host "    Offered Outlook safe mode launch"
Write-Host "    Offered Office identity cache reset"
Write-Host ""
Write-Host "What it did NOT do:"
Write-Host "    Did not delete PST files"
Write-Host "    Did not delete OST files by default"
Write-Host "    Did not delete Outlook profiles"
Write-Host "    Did not remove mail accounts"
Write-Host "    Did not remove calendar entries"
Write-Host "    Did not force new Outlook"
Write-Host "    Did not uninstall Teams"
Write-Host "    Did not uninstall Office"
Write-Host ""
Write-Host "Backup folder for optional moved identity/profile cache:"
Write-Host "    $BackupRoot"
Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
Write-Host "============================================================"
