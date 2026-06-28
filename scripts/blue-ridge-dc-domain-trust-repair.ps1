#requires -RunAsAdministrator
<#
Blue Ridge DC Domain Trust Repair

Purpose:
- Run from a domain controller or admin workstation with RSAT/AD tools
- Ask for a target computer name
- Ask for a domain repair username
- Remotely run a secure-channel repair on the target computer
- Avoid unjoining/rejoining the computer from the domain
- Avoid resetting the AD computer account blindly

Requirements:
- Target computer must be online
- Target computer must be reachable by DNS/name
- PowerShell Remoting / WinRM must work to the target computer
- Credential used must have rights to repair/reset the target computer secure channel

Does not:
- Reset user passwords
- Force user logout
- Delete user profiles
- Delete cached domain logon data
- Remove the computer from the domain
- Rejoin the computer to the domain
- Blindly reset the AD computer account
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\dc-domain-trust-repair.log"

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

function Try-ImportADModule {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-BRLog "ActiveDirectory module loaded."
        return $true
    } catch {
        Write-BRLog "ActiveDirectory module not available: $($_.Exception.Message)"
        return $false
    }
}

function Resolve-TargetComputer {
    param([string]$ComputerName)

    $cleanName = $ComputerName.Trim()

    if ($cleanName -match "\.") {
        $shortName = $cleanName.Split(".")[0]
    } else {
        $shortName = $cleanName
    }

    return $shortName.ToUpper()
}

Write-BRLog "=== Blue Ridge DC Domain Trust Repair started ==="

$adModuleAvailable = Try-ImportADModule

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge DC Domain Trust Repair"
Write-Host "============================================================"
Write-Host ""
Write-Host "This runs from the domain controller, but repairs the trust"
Write-Host "from the target workstation side using PowerShell Remoting."
Write-Host ""
Write-Host "It does NOT blindly reset the AD computer account."
Write-Host "============================================================"
Write-Host ""

$targetInput = Read-Host "Enter target computer name"

if ([string]::IsNullOrWhiteSpace($targetInput)) {
    Write-BRLog "No target computer entered. Exiting."
    Write-Host "No target computer entered. Exiting."
    exit 1
}

$TargetComputer = Resolve-TargetComputer -ComputerName $targetInput

Write-BRLog "Target computer entered: $TargetComputer"

$DomainName = (Get-CimInstance Win32_ComputerSystem).Domain
$DefaultDC = $env:COMPUTERNAME

Write-Host ""
Write-Host "Detected domain:"
Write-Host "    $DomainName"
Write-Host ""
Write-Host "Default domain controller target:"
Write-Host "    $DefaultDC"
Write-Host ""

$dcChoice = Read-Host "Press Enter to use this DC, or enter another domain controller name"

if ([string]::IsNullOrWhiteSpace($dcChoice)) {
    $DomainController = $DefaultDC
} else {
    $DomainController = $dcChoice.Trim()
}

Write-BRLog "Domain controller selected for repair: $DomainController"

if ($adModuleAvailable) {
    Write-BRLog "Checking AD computer object."

    try {
        $adComputer = Get-ADComputer -Identity $TargetComputer -Properties Enabled, DistinguishedName, LastLogonDate, PasswordLastSet -ErrorAction Stop

        Write-Host ""
        Write-Host "AD computer object found:"
        Write-Host "    Name:            $($adComputer.Name)"
        Write-Host "    Enabled:         $($adComputer.Enabled)"
        Write-Host "    LastLogonDate:   $($adComputer.LastLogonDate)"
        Write-Host "    PasswordLastSet: $($adComputer.PasswordLastSet)"
        Write-Host "    DN:              $($adComputer.DistinguishedName)"
        Write-Host ""

        Write-BRLog "AD computer object found: $($adComputer.DistinguishedName)"
    } catch {
        Write-BRLog "Could not find AD computer object for $TargetComputer : $($_.Exception.Message)"
        Write-Host ""
        Write-Host "Could not find AD computer object for:"
        Write-Host "    $TargetComputer"
        Write-Host ""
        Write-Host "Stopping here so we do not guess."
        exit 1
    }
} else {
    Write-Host ""
    Write-Host "ActiveDirectory module is not available."
    Write-Host "Continuing without AD object lookup."
}

Write-Host ""
Write-Host "Testing basic network reachability to $TargetComputer..."
Write-Host ""

$pingOk = Test-Connection -ComputerName $TargetComputer -Count 2 -Quiet -ErrorAction SilentlyContinue

Write-BRLog "Ping test to $TargetComputer result: $pingOk"

if (-not $pingOk) {
    Write-Host "Ping failed or ICMP is blocked."
    Write-Host "This does not always mean the computer is offline, but WinRM must still work."
    Write-Host ""
}

Write-Host "Testing PowerShell Remoting / WinRM to $TargetComputer..."
Write-Host ""

try {
    Test-WSMan -ComputerName $TargetComputer -ErrorAction Stop | Out-Null
    $wsmanOk = $true
} catch {
    $wsmanOk = $false
    Write-BRLog "WinRM test failed: $($_.Exception.Message)"
}

Write-BRLog "WinRM test to $TargetComputer result: $wsmanOk"

if (-not $wsmanOk) {
    Write-Host ""
    Write-Host "PowerShell Remoting is not reachable on $TargetComputer."
    Write-Host ""
    Write-Host "This DC-side script needs WinRM/PowerShell Remoting to repair the trust remotely."
    Write-Host "If WinRM is not available, run the host-side version locally on the affected PC."
    Write-Host ""
    exit 1
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
Write-Host "Ready to repair domain trust."
Write-Host ""
Write-Host "Target computer:"
Write-Host "    $TargetComputer"
Write-Host ""
Write-Host "Domain controller:"
Write-Host "    $DomainController"
Write-Host ""
Write-Host "Credential:"
Write-Host "    $domainUser"
Write-Host ""
Write-Host "This will remotely run secure-channel repair on the target computer."
Write-Host ""

$confirm = Read-Host "Type REPAIRTRUST to continue"

if ($confirm -ne "REPAIRTRUST") {
    Write-BRLog "Admin did not confirm repair. Exiting."
    Write-Host "No changes made."
    exit 0
}

$remoteScript = {
    param(
        [string]$RepairDC,
        [pscredential]$RepairCredential
    )

    $result = [ordered]@{}

    $cs = Get-CimInstance Win32_ComputerSystem

    $result.ComputerName = $env:COMPUTERNAME
    $result.Domain = $cs.Domain
    $result.PartOfDomain = $cs.PartOfDomain
    $result.CurrentUser = $cs.UserName

    if (-not $cs.PartOfDomain) {
        $result.BeforeHealthy = $false
        $result.RepairAttempted = $false
        $result.AfterHealthy = $false
        $result.Message = "Target computer is not domain joined."
        return [PSCustomObject]$result
    }

    try {
        $before = Test-ComputerSecureChannel -Server $RepairDC -Verbose
    } catch {
        $before = $false
        $result.BeforeTestError = $_.Exception.Message
    }

    $result.BeforeHealthy = $before

    try {
        Test-ComputerSecureChannel -Repair -Server $RepairDC -Credential $RepairCredential -Verbose
        $result.RepairAttempted = $true
    } catch {
        $result.RepairAttempted = $false
        $result.RepairError = $_.Exception.Message
    }

    Start-Sleep -Seconds 3

    try {
        Restart-Service Netlogon -Force -ErrorAction Stop
        $result.NetlogonRestarted = $true
    } catch {
        $result.NetlogonRestarted = $false
        $result.NetlogonError = $_.Exception.Message
    }

    Start-Sleep -Seconds 3

    try {
        $after = Test-ComputerSecureChannel -Server $RepairDC -Verbose
    } catch {
        $after = $false
        $result.AfterTestError = $_.Exception.Message
    }

    $result.AfterHealthy = $after

    try {
        klist.exe purge | Out-Null
        $result.KerberosPurged = $true
    } catch {
        $result.KerberosPurged = $false
        $result.KerberosError = $_.Exception.Message
    }

    try {
        gpupdate.exe /force | Out-Null
        $result.GpupdateRan = $true
    } catch {
        $result.GpupdateRan = $false
        $result.GpupdateError = $_.Exception.Message
    }

    return [PSCustomObject]$result
}

Write-BRLog "Invoking remote trust repair on $TargetComputer."

try {
    $repairResult = Invoke-Command `
        -ComputerName $TargetComputer `
        -Credential $cred `
        -ScriptBlock $remoteScript `
        -ArgumentList $DomainController, $cred `
        -ErrorAction Stop
} catch {
    Write-BRLog "Remote repair failed: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Remote repair failed:"
    Write-Host "    $($_.Exception.Message)"
    Write-Host ""
    Write-Host "If the secure channel is too broken for remoting, run the host-side script locally."
    exit 1
}

Write-BRLog "Remote repair completed."

Write-Host ""
Write-Host "============================================================"
Write-Host "Domain trust repair result"
Write-Host "============================================================"
$repairResult | Format-List
Write-Host "============================================================"

Write-BRLog "Repair result: $($repairResult | Out-String)"

if ($repairResult.AfterHealthy -eq $true) {
    Write-Host ""
    Write-Host "Trust appears healthy after repair."
    Write-Host ""

    $reboot = Read-Host "Reboot target computer now? Type REBOOT to restart $TargetComputer"

    if ($reboot -eq "REBOOT") {
        Write-BRLog "Admin chose remote reboot for $TargetComputer."

        try {
            Restart-Computer -ComputerName $TargetComputer -Credential $cred -Force -ErrorAction Stop
            Write-BRLog "Remote reboot command sent to $TargetComputer."
            Write-Host "Remote reboot command sent."
        } catch {
            Write-BRLog "Remote reboot failed: $($_.Exception.Message)"
            Write-Host "Remote reboot failed:"
            Write-Host "    $($_.Exception.Message)"
        }
    } else {
        Write-BRLog "Admin skipped remote reboot."
        Write-Host "Reboot skipped. A reboot is still recommended."
    }
} else {
    Write-Host ""
    Write-Host "The trust repair did not verify cleanly."
    Write-Host ""
    Write-Host "Next checks:"
    Write-Host "    DNS resolution"
    Write-Host "    VPN/network path to DC"
    Write-Host "    Time sync"
    Write-Host "    Disabled computer account"
    Write-Host "    Duplicate computer account"
    Write-Host "    Whether WinRM is working under a cached/admin credential"
    Write-Host "    Full domain rejoin if repair cannot complete"
    Write-BRLog "Trust repair did not verify cleanly."
}

Write-BRLog "=== Blue Ridge DC Domain Trust Repair completed ==="

Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
