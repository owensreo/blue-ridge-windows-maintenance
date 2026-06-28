#requires -RunAsAdministrator
<#
Blue Ridge Windows 11 Standard Maintenance Baseline

Purpose:
- Safe Windows 11 tune-up for student, home, and light business PCs
- Does not aggressively disable services
- Does not remove applications
- Does not delete user documents, Downloads, Desktop files, bookmarks, passwords, extensions, or browser profiles
- Enables Blue Ridge support access through a local admin account, SSH, and RDP
- Creates a scheduled maintenance task that runs Tuesday and Friday at 2:00 AM
- Keeps minimal maintenance logs only, not full system or user inventory

Recommended use:
1. Upgrade Windows 11 Home to Pro if RDP hosting is needed
2. Reboot
3. Run this script elevated
4. Set the Blue-Ridge password manually:
       net user Blue-Ridge *
5. Reboot
6. Test SSH and RDP
#>

$ErrorActionPreference = "Continue"

# ------------------------------------------------------------
# Blue Ridge paths and settings
# ------------------------------------------------------------

$BRRoot      = "C:\ProgramData\BlueRidge"
$LogDir      = "$BRRoot\Logs"
$MaintScript = "$BRRoot\br-maintenance.ps1"
$SetupLog    = "$LogDir\setup.log"
$TaskName    = "Blue Ridge Twice Weekly Maintenance"
$BRUser      = "Blue-Ridge"

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

function Add-MemberSafely {
    param(
        [string]$Group,
        [string]$Member
    )

    if ([string]::IsNullOrWhiteSpace($Member)) {
        return
    }

    try {
        Add-LocalGroupMember -Group $Group -Member $Member -ErrorAction Stop
        Write-BRLog "Added $Member to $Group."
    } catch {
        Write-BRLog "$Member may already be in $Group or could not be added. $($_.Exception.Message)"
    }
}

function Ensure-FirewallRule {
    param(
        [string]$Name,
        [string]$DisplayName,
        [int]$Port
    )

    try {
        $ExistingRule = Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue

        if (-not $ExistingRule) {
            New-NetFirewallRule `
                -Name $Name `
                -DisplayName $DisplayName `
                -Enabled True `
                -Direction Inbound `
                -Protocol TCP `
                -Action Allow `
                -LocalPort $Port | Out-Null

            Write-BRLog "Created firewall rule: $DisplayName on TCP $Port."
        } else {
            Enable-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue
            Write-BRLog "Firewall rule already exists and was enabled: $DisplayName."
        }
    } catch {
        Write-BRLog "Firewall rule issue for $DisplayName : $($_.Exception.Message)"
    }
}

if (-not (Test-IsAdmin)) {
    Write-Host "Run this from PowerShell as Administrator."
    exit 1
}

Write-BRLog "=== Blue Ridge Windows 11 Standard Maintenance Baseline started ==="

# ------------------------------------------------------------
# Create Blue-Ridge local admin user
# ------------------------------------------------------------

Write-BRLog "Checking local admin account: $BRUser"

$existingUser = Get-LocalUser -Name $BRUser -ErrorAction SilentlyContinue

if (-not $existingUser) {
    Write-BRLog "Creating local user $BRUser with no password. Password must be set manually."
    try {
        New-LocalUser `
            -Name $BRUser `
            -NoPassword `
            -Description "Blue Ridge Systems local admin account" `
            -ErrorAction Stop

        Write-BRLog "$BRUser created."
    } catch {
        Write-BRLog "Could not create $BRUser : $($_.Exception.Message)"
    }
} else {
    Write-BRLog "$BRUser already exists. Skipping user creation."
}

Add-MemberSafely -Group "Administrators" -Member $BRUser

try {
    Set-LocalUser -Name $BRUser -PasswordNeverExpires $true
    Write-BRLog "Password never expires set for $BRUser."
} catch {
    Write-BRLog "Could not set password-never-expires for $BRUser : $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Detect current user and add both users to Remote Desktop Users
# ------------------------------------------------------------

Write-BRLog "Detecting current console user."

$CurrentUserFull = (Get-CimInstance Win32_ComputerSystem).UserName
$CurrentUserShort = $null

if ($CurrentUserFull) {
    $CurrentUserShort = $CurrentUserFull.Split('\')[-1]
    Write-BRLog "Detected current user: $CurrentUserFull"
} else {
    Write-BRLog "Could not detect current console user."
}

Add-MemberSafely -Group "Remote Desktop Users" -Member $BRUser

if ($CurrentUserFull) {
    Add-MemberSafely -Group "Remote Desktop Users" -Member $CurrentUserFull
} elseif ($CurrentUserShort) {
    Add-MemberSafely -Group "Remote Desktop Users" -Member $CurrentUserShort
}

# ------------------------------------------------------------
# Enable Remote Desktop
# ------------------------------------------------------------

Write-BRLog "Enabling Remote Desktop."

try {
    Set-ItemProperty `
        -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
        -Name "fDenyTSConnections" `
        -Value 0

    Set-ItemProperty `
        -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" `
        -Name "UserAuthentication" `
        -Value 1

    Set-Service -Name TermService -StartupType Automatic
    Start-Service -Name TermService -ErrorAction SilentlyContinue

    Write-BRLog "Remote Desktop enabled with Network Level Authentication."
} catch {
    Write-BRLog "Remote Desktop configuration issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Firewall rules for RDP
# ------------------------------------------------------------

Write-BRLog "Configuring firewall for RDP."

try {
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
    Ensure-FirewallRule -Name "BlueRidge-Allow-RDP-3389" -DisplayName "Blue Ridge Allow RDP 3389" -Port 3389
} catch {
    Write-BRLog "RDP firewall configuration issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Install OpenSSH Server only if missing
# ------------------------------------------------------------

Write-BRLog "Checking OpenSSH Server optional feature."

try {
    $sshCap = Get-WindowsCapability -Online | Where-Object { $_.Name -like "OpenSSH.Server*" }

    if ($sshCap -and $sshCap.State -eq "Installed") {
        Write-BRLog "OpenSSH Server is already installed. Skipping install."
    } else {
        Write-BRLog "OpenSSH Server not installed. Installing optional feature."
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        Write-BRLog "OpenSSH Server install complete."
    }
} catch {
    Write-BRLog "OpenSSH Server feature check/install issue: $($_.Exception.Message)"
}

Write-BRLog "Configuring sshd service."

try {
    Set-Service -Name sshd -StartupType Automatic
    Start-Service sshd -ErrorAction SilentlyContinue
    Write-BRLog "sshd enabled and started."
} catch {
    Write-BRLog "sshd configuration issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Firewall rules for SSH
# ------------------------------------------------------------

Write-BRLog "Configuring firewall for SSH."

try {
    Ensure-FirewallRule -Name "BlueRidge-Allow-SSH-22" -DisplayName "Blue Ridge Allow SSH 22" -Port 22
    Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Enable-NetFirewallRule
} catch {
    Write-BRLog "SSH firewall configuration issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Power settings
# ------------------------------------------------------------

Write-BRLog "Setting High Performance power behavior where available."

try {
    powercfg /setactive SCHEME_MIN

    powercfg /change standby-timeout-ac 0
    powercfg /change hibernate-timeout-ac 0
    powercfg /change monitor-timeout-ac 30

    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
    powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMAX 100
    powercfg /setactive SCHEME_CURRENT

    Write-BRLog "Power settings adjusted."
} catch {
    Write-BRLog "Power setting issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Microsoft Defender tuning, not disabling
# ------------------------------------------------------------

Write-BRLog "Tuning Microsoft Defender without disabling protection."

try {
    Set-MpPreference -ScanAvgCPULoadFactor 20
    Set-MpPreference -DisableEmailScanning $true
    Set-MpPreference -SubmitSamplesConsent 2
    Set-MpPreference -MAPSReporting 1

    Write-BRLog "Defender preferences adjusted."
} catch {
    Write-BRLog "Defender tuning issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Write recurring maintenance script
# ------------------------------------------------------------

Write-BRLog "Writing maintenance script: $MaintScript"

$MaintenanceContent = @'
$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\maintenance.log"

New-Item -ItemType Directory -Force -Path $BRRoot, $LogDir | Out-Null

function Write-BRLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    $line = "[$stamp] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Clear-FolderContents {
    param([string]$Path)

    if (Test-Path $Path) {
        Write-BRLog "Cleaning: $Path"

        try {
            Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-BRLog "Could not fully clean $Path : $($_.Exception.Message)"
        }
    }
}

function Clear-ChromiumCachesForBrowser {
    param(
        [string]$BrowserName,
        [string]$UserDataRoot
    )

    if (-not (Test-Path $UserDataRoot)) {
        return
    }

    Write-BRLog "Cleaning cache for $BrowserName under $UserDataRoot"

    $ProfileDirs = Get-ChildItem -Path $UserDataRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq "Default" -or
            $_.Name -like "Profile *" -or
            $_.Name -eq "Guest Profile"
        }

    foreach ($ProfileDir in $ProfileDirs) {
        $ProfilePath = $ProfileDir.FullName

        $CachePaths = @(
            "$ProfilePath\Cache",
            "$ProfilePath\Code Cache",
            "$ProfilePath\GPUCache",
            "$ProfilePath\Service Worker\CacheStorage",
            "$ProfilePath\Service Worker\ScriptCache",
            "$ProfilePath\Media Cache",
            "$ProfilePath\ShaderCache",
            "$ProfilePath\GrShaderCache",
            "$ProfilePath\DawnCache"
        )

        foreach ($Path in $CachePaths) {
            Clear-FolderContents -Path $Path
        }
    }

    Clear-FolderContents -Path "$UserDataRoot\Crashpad\reports"
    Clear-FolderContents -Path "$UserDataRoot\ShaderCache"
    Clear-FolderContents -Path "$UserDataRoot\GrShaderCache"
}

function Clear-BrowserCaches {
    Write-BRLog "Cleaning Edge and Chrome cache areas while preserving user browser data."

    $UserProfiles = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @("Public", "Default", "Default User", "All Users") -and
            $_.FullName -notlike "*Windows*"
        }

    foreach ($Profile in $UserProfiles) {
        $UserRoot = $Profile.FullName

        Clear-ChromiumCachesForBrowser `
            -BrowserName "Microsoft Edge" `
            -UserDataRoot "$UserRoot\AppData\Local\Microsoft\Edge\User Data"

        Clear-ChromiumCachesForBrowser `
            -BrowserName "Google Chrome" `
            -UserDataRoot "$UserRoot\AppData\Local\Google\Chrome\User Data"

        Clear-FolderContents -Path "$UserRoot\AppData\Local\Temp"
    }
}

function Configure-CleanMgrSageSet11 {
    Write-BRLog "Configuring Disk Cleanup sageset 11."

    $VolumeCaches = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

    $Targets = @(
        "Active Setup Temp Folders",
        "BranchCache",
        "Content Indexer Cleaner",
        "D3D Shader Cache",
        "Delivery Optimization Files",
        "Diagnostic Data Viewer database files",
        "Downloaded Program Files",
        "Internet Cache Files",
        "Language Pack",
        "Old ChkDsk Files",
        "Previous Installations",
        "Recycle Bin",
        "RetailDemo Offline Content",
        "Setup Log Files",
        "System error memory dump files",
        "System error minidump files",
        "Temporary Files",
        "Temporary Setup Files",
        "Thumbnail Cache",
        "Update Cleanup",
        "Upgrade Discarded Files",
        "User file versions",
        "Windows Defender",
        "Windows Error Reporting Files",
        "Windows ESD installation files",
        "Windows Upgrade Log Files"
    )

    foreach ($Target in $Targets) {
        $Path = Join-Path $VolumeCaches $Target

        if (Test-Path $Path) {
            try {
                New-ItemProperty `
                    -Path $Path `
                    -Name "StateFlags0011" `
                    -PropertyType DWord `
                    -Value 2 `
                    -Force | Out-Null
            } catch {
                Write-BRLog "Could not set cleanmgr flag for $Target : $($_.Exception.Message)"
            }
        }
    }
}

Write-BRLog "=== Blue Ridge maintenance started ==="

Write-BRLog "Stopping Edge and Chrome so cache cleanup can complete."
Get-Process msedge, chrome -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

Write-BRLog "Cleaning Windows temp folders."
Clear-FolderContents -Path "C:\Windows\Temp"
Clear-FolderContents -Path "$env:TEMP"

Clear-BrowserCaches

Write-BRLog "Clearing Recycle Bin."
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
} catch {
    Write-BRLog "Recycle Bin cleanup issue: $($_.Exception.Message)"
}

Configure-CleanMgrSageSet11

Write-BRLog "Running Disk Cleanup sageset 11."
try {
    Start-Process cleanmgr.exe -ArgumentList "/sagerun:11" -Wait -WindowStyle Hidden
} catch {
    Write-BRLog "Disk Cleanup issue: $($_.Exception.Message)"
}

Write-BRLog "Running DISM component cleanup."
try {
    DISM /Online /Cleanup-Image /StartComponentCleanup
} catch {
    Write-BRLog "DISM component cleanup issue: $($_.Exception.Message)"
}

Write-BRLog "Updating Microsoft Defender signatures."
try {
    Update-MpSignature
} catch {
    Write-BRLog "Defender signature update issue: $($_.Exception.Message)"
}

Write-BRLog "Running Microsoft Defender quick scan."
try {
    Start-MpScan -ScanType QuickScan
} catch {
    Write-BRLog "Defender quick scan issue: $($_.Exception.Message)"
}

Write-BRLog "Forcing true defrag on C:."
try {
    Optimize-Volume C -Defrag -Verbose
} catch {
    Write-BRLog "Optimize-Volume defrag issue: $($_.Exception.Message)"
}

Write-BRLog "=== Blue Ridge maintenance completed ==="
'@

Set-Content -Path $MaintScript -Value $MaintenanceContent -Encoding UTF8

# ------------------------------------------------------------
# Run initial cleanup pass now
# ------------------------------------------------------------

Write-BRLog "Running initial maintenance pass now."

try {
    PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File $MaintScript
} catch {
    Write-BRLog "Initial maintenance pass issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Initial deep Windows repair
# ------------------------------------------------------------

Write-BRLog "Running DISM RestoreHealth."

try {
    DISM /Online /Cleanup-Image /RestoreHealth
} catch {
    Write-BRLog "DISM RestoreHealth issue: $($_.Exception.Message)"
}

Write-BRLog "Running SFC scan."

try {
    sfc /scannow
} catch {
    Write-BRLog "SFC issue: $($_.Exception.Message)"
}

Write-BRLog "Running forced true defrag on C:."

try {
    Optimize-Volume C -Defrag -Verbose
} catch {
    Write-BRLog "Forced defrag issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Open Windows Update and Microsoft Store update pages for manual review
# ------------------------------------------------------------

Write-BRLog "Opening Windows Update settings for manual review."

try {
    Start-Process "ms-settings:windowsupdate"
} catch {
    Write-BRLog "Could not open Windows Update settings: $($_.Exception.Message)"
}

Write-BRLog "Opening Microsoft Store updates page for manual review."

try {
    Start-Process "ms-windows-store://downloadsandupdates"
} catch {
    Write-BRLog "Could not open Microsoft Store updates page: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Scheduled task: Tuesday and Friday at 2 AM
# Create only if it does not already exist
# ------------------------------------------------------------

Write-BRLog "Checking scheduled task: $TaskName"

try {
    $ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($ExistingTask) {
        Write-BRLog "Scheduled task already exists. Leaving existing task as-is."
    } else {
        Write-BRLog "Creating scheduled task: $TaskName"

        $Action = New-ScheduledTaskAction `
            -Execute "PowerShell.exe" `
            -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$MaintScript`""

        $Trigger1 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Tuesday -At 2:00AM
        $Trigger2 = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Friday -At 2:00AM

        $Principal = New-ScheduledTaskPrincipal `
            -UserId "SYSTEM" `
            -LogonType ServiceAccount `
            -RunLevel Highest

        $Settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -MultipleInstances IgnoreNew `
            -ExecutionTimeLimit (New-TimeSpan -Hours 4)

        Register-ScheduledTask `
            -TaskName $TaskName `
            -Action $Action `
            -Trigger @($Trigger1, $Trigger2) `
            -Principal $Principal `
            -Settings $Settings | Out-Null

        Write-BRLog "Scheduled task created for Tuesday and Friday at 2:00 AM."
    }
} catch {
    Write-BRLog "Scheduled task issue: $($_.Exception.Message)"
}

# ------------------------------------------------------------
# Final status
# ------------------------------------------------------------

Write-BRLog "Checking final service status."

$sshdStatus = Get-Service sshd -ErrorAction SilentlyContinue
$rdpStatus  = Get-Service TermService -ErrorAction SilentlyContinue

if ($sshdStatus) {
    Write-BRLog "sshd status: $($sshdStatus.Status)"
} else {
    Write-BRLog "sshd service not found."
}

if ($rdpStatus) {
    Write-BRLog "Remote Desktop service status: $($rdpStatus.Status)"
} else {
    Write-BRLog "Remote Desktop service not found."
}

Write-BRLog "=== Blue Ridge Windows 11 Standard Maintenance Baseline completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Standard Maintenance Baseline complete."
Write-Host ""
Write-Host "Scheduled maintenance:"
Write-Host "    Tuesday at 2:00 AM"
Write-Host "    Friday at 2:00 AM"
Write-Host ""
Write-Host "Manual next step:"
Write-Host "    net user Blue-Ridge *"
Write-Host ""
Write-Host "Recommended after password is set:"
Write-Host "    Reboot the PC"
Write-Host "    Run Windows Update manually until fully current"
Write-Host "    Review Microsoft Store updates"
Write-Host "    Test SSH and RDP"
Write-Host ""
Write-Host "Useful checks:"
Write-Host "    Get-Service sshd,TermService"
Write-Host "    Get-NetFirewallRule -DisplayName '*Blue Ridge*'"
Write-Host "    Get-LocalGroupMember 'Administrators'"
Write-Host "    Get-LocalGroupMember 'Remote Desktop Users'"
Write-Host "    Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance'"
Write-Host ""
Write-Host "Minimal logs:"
Write-Host "    C:\ProgramData\BlueRidge\Logs\setup.log"
Write-Host "    C:\ProgramData\BlueRidge\Logs\maintenance.log"
Write-Host "============================================================"
