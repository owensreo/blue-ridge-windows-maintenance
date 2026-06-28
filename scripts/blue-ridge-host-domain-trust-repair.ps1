#requires -RunAsAdministrator
<#
Blue Ridge Host Domain Trust Repair

Purpose:
- Run locally on the affected domain-joined workstation
- Test whether the computer's domain secure channel is healthy
- Repair the computer trust relationship without unjoining/rejoining the domain
- Prompt for the domain repair username directly in PowerShell
- Prompt securely for that user's password
- Restart Netlogon
- Purge Kerberos tickets
- Run gpupdate
- Recommend reboot after repair

Use case:
- User appears to have fallen off the domain
- Trust relationship errors
- Domain login weirdness
- Group Policy not applying
- Network resources acting like the machine is no longer trusted

Does not:
- Remove the computer from the domain
- Rejoin the computer to the domain
- Reset user passwords
- Force user logout
- Delete user profiles
- Delete cached domain logon data
- Delete Credential Manager entries
- Change local administrator passwords
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\host-domain-trust-repair.log"

New-Item -ItemType Directory -Force -Path $BRRoot, $LogDir | Out-Null

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

function Invoke-BRCommand {
    param(
        [string]$Label,
        [scriptblock]$Command
    )

    Write-BRLog "Starting: $Label"

    try {
        & $Command 2>&1 | ForEach-Object {
            if ($_ -ne $null -and $_.ToString().Trim() -ne "") {
                Write-BRLog "    $($_.ToString())"
            }
        }

        Write-BRLog "Completed: $Label"
    } catch {
        Write-BRLog "Failed: $Label : $($_.Exception.Message)"
    }
}

function Get-ComputerDomainInfo {
    try {
        $cs = Get-CimInstance Win32_ComputerSystem

        return [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            PartOfDomain = $cs.PartOfDomain
            Domain = $cs.Domain
            Workgroup = $cs.Workgroup
            CurrentUser = $cs.UserName
        }
    } catch {
        Write-BRLog "Could not read computer domain info: $($_.Exception.Message)"
        return $null
    }
}

function Show-DomainInfo {
    param($DomainInfo)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Domain trust repair target"
    Write-Host "============================================================"

    if ($DomainInfo) {
        $DomainInfo | Format-List
    } else {
        Write-Host "Could not read domain information."
    }
}

function Test-SecureChannelSafe {
    param([string]$DomainController = $null)

    try {
        if ([string]::IsNullOrWhiteSpace($DomainController)) {
            return Test-ComputerSecureChannel -Verbose
        } else {
            return Test-ComputerSecureChannel -Server $DomainController -Verbose
        }
    } catch {
        Write-BRLog "Secure channel test failed to run: $($_.Exception.Message)"
        return $false
    }
}

function Repair-SecureChannel {
    param(
        [pscredential]$Credential,
        [string]$DomainController = $null
    )

    try {
        if ([string]::IsNullOrWhiteSpace($DomainController)) {
            Test-ComputerSecureChannel -Repair -Credential $Credential -Verbose
        } else {
            Test-ComputerSecureChannel -Repair -Credential $Credential -Server $DomainController -Verbose
        }

        return $true
    } catch {
        Write-BRLog "Secure channel repair failed: $($_.Exception.Message)"
        return $false
    }
}

Write-BRLog "=== Blue Ridge Host Domain Trust Repair started ==="

$domainInfo = Get-ComputerDomainInfo
Show-DomainInfo -DomainInfo $domainInfo

if (-not $domainInfo -or -not $domainInfo.PartOfDomain) {
    Write-BRLog "This computer does not appear to be domain joined. Exiting."
    Write-Host ""
    Write-Host "This computer does not appear to be joined to a domain."
    Write-Host "This script repairs existing domain trust. It does not join a workgroup computer to a domain."
    exit 1
}

Write-Host ""
Write-Host "This script repairs the computer trust relationship with the domain."
Write-Host "It does not remove or rejoin the computer."
Write-Host "It does not reset the user's password."
Write-Host ""

$dcChoice = Read-Host "Optional: enter a domain controller name to target, or press Enter to auto-select"

if ([string]::IsNullOrWhiteSpace($dcChoice)) {
    $dcChoice = $null
    Write-BRLog "No domain controller specified. Windows will auto-select a DC."
} else {
    Write-BRLog "Domain controller specified: $dcChoice"
}

Write-Host ""
Write-Host "Testing current secure channel."
Write-Host ""

$beforeHealthy = Test-SecureChannelSafe -DomainController $dcChoice
Write-BRLog "Secure channel healthy before repair: $beforeHealthy"

if ($beforeHealthy -eq $true) {
    Write-Host ""
    Write-Host "Secure channel already appears healthy."
    Write-Host ""

    $continue = Read-Host "Run repair anyway? Type REPAIR to continue"

    if ($continue -ne "REPAIR") {
        Write-BRLog "Secure channel healthy and admin skipped repair."
        Write-Host "No repair performed."
        exit 0
    }
}

Write-Host ""
Write-Host "Enter the domain repair username."
Write-Host "Use one of these formats:"
Write-Host "    DOMAIN\username"
Write-Host "    username@domain.com"
Write-Host ""

$domainUser = Read-Host "Enter domain repair username"

if ([string]::IsNullOrWhiteSpace($domainUser)) {
    Write-BRLog "No domain repair username entered. Exiting."
    Write-Host "No username entered. Exiting."
    exit 1
}

Write-BRLog "Domain repair username entered: $domainUser"

$cred = Get-Credential -UserName $domainUser -Message "Enter password for domain trust repair"

if (-not $cred) {
    Write-BRLog "No credential provided. Exiting."
    Write-Host "No credential provided. Exiting."
    exit 1
}

Write-Host ""
Write-Host "Ready to repair the domain trust relationship for:"
Write-Host "    Computer: $($domainInfo.ComputerName)"
Write-Host "    Domain:   $($domainInfo.Domain)"
Write-Host "    Using:    $domainUser"
Write-Host ""

$confirm = Read-Host "Type REPAIRTRUST to repair the domain trust relationship"

if ($confirm -ne "REPAIRTRUST") {
    Write-BRLog "Admin did not confirm trust repair."
    Write-Host "No changes made."
    exit 0
}

Write-BRLog "Repairing secure channel."

$repairResult = Repair-SecureChannel -Credential $cred -DomainController $dcChoice
Write-BRLog "Secure channel repair command completed: $repairResult"

Start-Sleep -Seconds 3

Write-BRLog "Restarting Netlogon service."

Invoke-BRCommand -Label "Restart Netlogon" -Command {
    Restart-Service Netlogon -Force
}

Start-Sleep -Seconds 3

Write-BRLog "Testing secure channel after repair."

$afterHealthy = Test-SecureChannelSafe -DomainController $dcChoice
Write-BRLog "Secure channel healthy after repair: $afterHealthy"

Write-BRLog "Purging Kerberos tickets for current session."

Invoke-BRCommand -Label "klist purge" -Command {
    klist.exe purge
}

Write-BRLog "Running gpupdate."

Invoke-BRCommand -Label "gpupdate /force" -Command {
    gpupdate.exe /force
}

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Host Domain Trust Repair completed."
Write-Host ""
Write-Host "Before repair secure channel healthy:"
Write-Host "    $beforeHealthy"
Write-Host ""
Write-Host "After repair secure channel healthy:"
Write-Host "    $afterHealthy"
Write-Host ""
Write-Host "What it did:"
Write-Host "    Tested domain secure channel"
Write-Host "    Repaired secure channel if confirmed"
Write-Host "    Restarted Netlogon"
Write-Host "    Purged Kerberos tickets for current session"
Write-Host "    Ran gpupdate /force"
Write-Host ""
Write-Host "What it did NOT do:"
Write-Host "    Did not unjoin the domain"
Write-Host "    Did not rejoin the domain"
Write-Host "    Did not reset user passwords"
Write-Host "    Did not force logout"
Write-Host "    Did not delete user profiles"
Write-Host "    Did not delete cached domain logon data"
Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
Write-Host "============================================================"

if ($afterHealthy -eq $true) {
    Write-Host ""
    $reboot = Read-Host "Trust appears healthy. Reboot now to finish cleanup? Type REBOOT to restart"

    if ($reboot -eq "REBOOT") {
        Write-BRLog "Admin chose reboot after successful trust repair."
        shutdown.exe /r /t 30 /c "Blue Ridge Host Domain Trust Repair completed. Rebooting to finish domain trust cleanup."
    } else {
        Write-BRLog "Admin skipped reboot after successful trust repair."
        Write-Host "Reboot skipped. A reboot is still recommended."
    }
} else {
    Write-Host ""
    Write-Host "The trust repair did not verify cleanly."
    Write-Host "Next steps may include checking VPN/domain controller reachability, DNS, time sync, or doing a full domain rejoin."
    Write-BRLog "Trust repair did not verify cleanly."
}

Write-BRLog "=== Blue Ridge Host Domain Trust Repair completed ==="
