#requires -RunAsAdministrator
<#
Blue Ridge Windows Update Enforcer

Purpose:
- Force Windows to check for and install pending software updates
- Retry once if updates fail
- Ignore remaining failures after the second pass
- Force reboot after installed updates finish
- Schedule monthly run on the 3rd Sunday at 2:00 AM

Schedule:
- Third Sunday of every month
- 2:00 AM
- Runs as SYSTEM

Notes:
- Uses built-in Windows Update COM objects
- Does not require PSWindowsUpdate or external modules
- Does not disable services
- Does not reset Windows Update components
- Does not install drivers intentionally
#>

$ErrorActionPreference = "Continue"

$BRRoot       = "C:\ProgramData\BlueRidge"
$LogDir       = "$BRRoot\Logs"
$UpdateScript = "$BRRoot\br-windows-update-enforcer.ps1"
$SetupLog     = "$LogDir\windows-update-enforcer-setup.log"
$TaskName     = "Blue Ridge Monthly Windows Update Enforcer"

New-Item -ItemType Directory -Force -Path $BRRoot, $LogDir | Out-Null

function Write-BRLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    $line = "[$stamp] $Message"

    Write-Host $line
    Add-Content -Path $SetupLog -Value $line
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

Write-BRLog "=== Blue Ridge Windows Update Enforcer installer started ==="

# ------------------------------------------------------------
# Write the actual monthly update script
# ------------------------------------------------------------

$UpdateScriptContent = @'
$ErrorActionPreference = "Continue"

$BRRoot  = "C:\ProgramData\BlueRidge"
$LogDir  = "$BRRoot\Logs"
$LogFile = "$LogDir\windows-update-enforcer.log"

New-Item -ItemType Directory -Force -Path $BRRoot, $LogDir | Out-Null

function Write-BRLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    $line = "[$stamp] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Start-UpdateServices {
    Write-BRLog "Starting Windows Update related services."

    $Services = @(
        "wuauserv",
        "bits",
        "cryptsvc",
        "msiserver"
    )

    foreach ($Svc in $Services) {
        try {
            Set-Service -Name $Svc -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name $Svc -ErrorAction SilentlyContinue
            Write-BRLog "Service checked/started: $Svc"
        } catch {
            Write-BRLog "Could not start service $Svc : $($_.Exception.Message)"
        }
    }
}

function Get-PendingUpdates {
    Write-BRLog "Searching for pending Windows software updates."

    try {
        $Session = New-Object -ComObject Microsoft.Update.Session
        $Searcher = $Session.CreateUpdateSearcher()

        # Software updates only. Do not intentionally pull driver updates here.
        $SearchResult = $Searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")

        return $SearchResult.Updates
    } catch {
        Write-BRLog "Windows Update search failed: $($_.Exception.Message)"
        return $null
    }
}

function Install-PendingUpdates {
    param(
        [string]$PassName
    )

    $InstalledCount = 0
    $FailedCount = 0
    $RebootRequired = $false

    Write-BRLog "=== Update install pass started: $PassName ==="

    $Updates = Get-PendingUpdates

    if (-not $Updates -or $Updates.Count -eq 0) {
        Write-BRLog "No pending software updates found on pass: $PassName"
        return @{
            InstalledCount = 0
            FailedCount = 0
            RebootRequired = $false
        }
    }

    Write-BRLog "Pending software updates found: $($Updates.Count)"

    $UpdateCollection = New-Object -ComObject Microsoft.Update.UpdateColl

    for ($i = 0; $i -lt $Updates.Count; $i++) {
        $Update = $Updates.Item($i)

        try {
            Write-BRLog "Preparing update: $($Update.Title)"

            if (-not $Update.EulaAccepted) {
                $Update.AcceptEula()
                Write-BRLog "Accepted EULA for: $($Update.Title)"
            }

            [void]$UpdateCollection.Add($Update)
        } catch {
            Write-BRLog "Could not prepare update: $($Update.Title) : $($_.Exception.Message)"
            $FailedCount++
        }
    }

    if ($UpdateCollection.Count -eq 0) {
        Write-BRLog "No updates were prepared successfully on pass: $PassName"
        return @{
            InstalledCount = 0
            FailedCount = $FailedCount
            RebootRequired = $false
        }
    }

    try {
        Write-BRLog "Downloading prepared updates: $($UpdateCollection.Count)"

        $Session = New-Object -ComObject Microsoft.Update.Session
        $Downloader = $Session.CreateUpdateDownloader()
        $Downloader.Updates = $UpdateCollection

        $DownloadResult = $Downloader.Download()
        Write-BRLog "Download result code: $($DownloadResult.ResultCode)"
    } catch {
        Write-BRLog "Download failed on pass $PassName : $($_.Exception.Message)"
        return @{
            InstalledCount = 0
            FailedCount = $UpdateCollection.Count
            RebootRequired = $false
        }
    }

    try {
        Write-BRLog "Installing updates: $($UpdateCollection.Count)"

        $Session = New-Object -ComObject Microsoft.Update.Session
        $Installer = $Session.CreateUpdateInstaller()
        $Installer.Updates = $UpdateCollection

        $InstallResult = $Installer.Install()

        Write-BRLog "Install result code: $($InstallResult.ResultCode)"
        Write-BRLog "Install reboot required: $($InstallResult.RebootRequired)"

        if ($InstallResult.RebootRequired) {
            $RebootRequired = $true
        }

        for ($i = 0; $i -lt $UpdateCollection.Count; $i++) {
            $Update = $UpdateCollection.Item($i)
            $UpdateResult = $InstallResult.GetUpdateResult($i)

            # ResultCode values commonly map like:
            # 2 = Succeeded
            # 3 = SucceededWithErrors
            # 4 = Failed
            # 5 = Aborted

            if ($UpdateResult.ResultCode -eq 2 -or $UpdateResult.ResultCode -eq 3) {
                $InstalledCount++
                Write-BRLog "Installed or partially installed: $($Update.Title) | ResultCode: $($UpdateResult.ResultCode)"
            } else {
                $FailedCount++
                Write-BRLog "Update failed or did not install: $($Update.Title) | ResultCode: $($UpdateResult.ResultCode) | HResult: $($UpdateResult.HResult)"
            }
        }
    } catch {
        Write-BRLog "Install failed on pass $PassName : $($_.Exception.Message)"
        $FailedCount += $UpdateCollection.Count
    }

    Write-BRLog "=== Update install pass completed: $PassName | Installed: $InstalledCount | Failed: $FailedCount | RebootRequired: $RebootRequired ==="

    return @{
        InstalledCount = $InstalledCount
        FailedCount = $FailedCount
        RebootRequired = $RebootRequired
    }
}

function Test-PendingReboot {
    try {
        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
            return $true
        }

        if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
            return $true
        }

        $PendingFileRename = Get-ItemProperty `
            -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
            -Name "PendingFileRenameOperations" `
            -ErrorAction SilentlyContinue

        if ($PendingFileRename) {
            return $true
        }
    } catch {
        Write-BRLog "Pending reboot check issue: $($_.Exception.Message)"
    }

    return $false
}

Write-BRLog "=== Blue Ridge Windows Update Enforcer started ==="

Start-UpdateServices

$TotalInstalled = 0
$TotalFailed = 0
$NeedsReboot = $false

$Pass1 = Install-PendingUpdates -PassName "First pass"

$TotalInstalled += $Pass1.InstalledCount
$TotalFailed += $Pass1.FailedCount

if ($Pass1.RebootRequired) {
    $NeedsReboot = $true
}

if ($Pass1.FailedCount -gt 0) {
    Write-BRLog "Some updates failed on first pass. Running one retry pass."

    $Pass2 = Install-PendingUpdates -PassName "Second pass retry"

    $TotalInstalled += $Pass2.InstalledCount
    $TotalFailed += $Pass2.FailedCount

    if ($Pass2.RebootRequired) {
        $NeedsReboot = $true
    }
} else {
    Write-BRLog "No failed updates reported on first pass. Skipping retry pass."
}

if (Test-PendingReboot) {
    Write-BRLog "Pending reboot detected."
    $NeedsReboot = $true
}

Write-BRLog "Update run summary: Installed=$TotalInstalled FailedOrSkipped=$TotalFailed RebootNeeded=$NeedsReboot"

if ($TotalInstalled -gt 0 -or $NeedsReboot) {
    Write-BRLog "Installed updates or pending reboot detected. Forcing reboot in 60 seconds."
    shutdown.exe /r /f /t 60 /c "Blue Ridge Windows Update Enforcer completed updates and is forcing a reboot."
} else {
    Write-BRLog "No updates installed and no reboot required. No reboot will be forced."
}

Write-BRLog "=== Blue Ridge Windows Update Enforcer completed ==="
'@

Set-Content -Path $UpdateScript -Value $UpdateScriptContent -Encoding UTF8

Write-BRLog "Wrote update enforcer script to: $UpdateScript"

# ------------------------------------------------------------
# Create scheduled task for 3rd Sunday at 2:00 AM
# Using schtasks because it cleanly supports THIRD SUN monthly syntax
# ------------------------------------------------------------

Write-BRLog "Checking for existing scheduled task: $TaskName"

$TaskExists = $false

try {
    schtasks.exe /Query /TN $TaskName | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $TaskExists = $true
    }
} catch {
    $TaskExists = $false
}

if ($TaskExists) {
    Write-BRLog "Scheduled task already exists. Leaving it as-is: $TaskName"
} else {
    Write-BRLog "Creating scheduled task for the 3rd Sunday of every month at 2:00 AM."

    $TaskCommand = "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""

    schtasks.exe `
        /Create `
        /TN $TaskName `
        /TR $TaskCommand `
        /SC MONTHLY `
        /MO THIRD `
        /D SUN `
        /ST 02:00 `
        /RU SYSTEM `
        /RL HIGHEST `
        /F | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-BRLog "Scheduled task created successfully: $TaskName"
    } else {
        Write-BRLog "Scheduled task creation may have failed. schtasks exit code: $LASTEXITCODE"
    }
}

Write-BRLog "=== Blue Ridge Windows Update Enforcer installer completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Windows Update Enforcer installed."
Write-Host ""
Write-Host "Scheduled task:"
Write-Host "    $TaskName"
Write-Host ""
Write-Host "Schedule:"
Write-Host "    3rd Sunday of every month at 2:00 AM"
Write-Host ""
Write-Host "Update script:"
Write-Host "    $UpdateScript"
Write-Host ""
Write-Host "Logs:"
Write-Host "    $SetupLog"
Write-Host "    $LogDir\windows-update-enforcer.log"
Write-Host ""
Write-Host "Verify task:"
Write-Host "    schtasks /Query /TN `"$TaskName`" /V /FO LIST"
Write-Host ""
Write-Host "Run manually:"
Write-Host "    PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File `"$UpdateScript`""
Write-Host "============================================================"
