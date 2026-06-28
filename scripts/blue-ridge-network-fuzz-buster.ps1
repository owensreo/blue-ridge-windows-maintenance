#requires -RunAsAdministrator
<#
Blue Ridge Network Fuzz Buster

Purpose:
- Clear common Windows networking cache problems
- Flush DNS cache
- Reset TCP/IP and Winsock
- Clear DNS, NetBIOS, and ARP cache
- Optionally release/renew DHCP
- Optionally reset WinHTTP proxy
- Optionally purge Kerberos tickets
- Optionally review and clear saved Credential Manager entries

Designed as a safe first-pass network cleanup tool.

Does not:
- Delete network adapters
- Delete VPN clients
- Delete Wi-Fi profiles
- Remove printer ports
- Change passwords
- Reset user passwords
- Force logout
- Remove domain join
- Delete Windows user profiles
- Delete certificates
- Touch DPAPI keys
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$ToolRoot = "$BRRoot\NetworkFuzzBuster"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\network-fuzz-buster.log"
$CredReviewCsv = "$ToolRoot\credential-review.csv"
$TcpIpResetLog = "$ToolRoot\tcpip-reset.log"

New-Item -ItemType Directory -Force -Path $BRRoot, $ToolRoot, $LogDir | Out-Null

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

function Show-NetworkSnapshot {
    param([string]$Label)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "$Label"
    Write-Host "============================================================"

    try {
        Write-Host ""
        Write-Host "IP addresses:"
        Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Select-Object InterfaceAlias, IPv4Address, IPv6Address, IPv4DefaultGateway, DNSServer |
            Format-List

        Write-Host ""
        Write-Host "DNS client cache sample:"
        Get-DnsClientCache -ErrorAction SilentlyContinue |
            Select-Object -First 15 Entry, Name, Type, Data |
            Format-Table -AutoSize

        Write-Host ""
        Write-Host "Active adapters:"
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress |
            Format-Table -AutoSize
    } catch {
        Write-BRLog "Could not show network snapshot: $($_.Exception.Message)"
    }
}

function Clear-NetworkCaches {
    Write-BRLog "Clearing DNS, NetBIOS, and ARP cache."

    Invoke-BRCommand -Label "Clear PowerShell DNS client cache" -Command {
        Clear-DnsClientCache
    }

    Invoke-BRCommand -Label "ipconfig /flushdns" -Command {
        ipconfig.exe /flushdns
    }

    Invoke-BRCommand -Label "Clear NetBIOS name cache" -Command {
        nbtstat.exe -R
    }

    Invoke-BRCommand -Label "Refresh NetBIOS name registrations" -Command {
        nbtstat.exe -RR
    }

    Invoke-BRCommand -Label "Clear ARP cache" -Command {
        netsh.exe interface ip delete arpcache
    }
}

function Reset-NetworkStack {
    Write-BRLog "Resetting Winsock and TCP/IP stack. A reboot is recommended after this."

    Invoke-BRCommand -Label "Reset Winsock catalog" -Command {
        netsh.exe winsock reset
    }

    Invoke-BRCommand -Label "Reset TCP/IP stack" -Command {
        netsh.exe int ip reset "$TcpIpResetLog"
    }
}

function Optional-DhcpRenew {
    Write-Host ""
    $choice = Read-Host "Release and renew DHCP lease now? This may briefly drop network access. Type Y to do it"

    if ($choice -match '^(Y|y|Yes|YES|yes)$') {
        Write-BRLog "Admin chose DHCP release/renew."

        Invoke-BRCommand -Label "ipconfig /release" -Command {
            ipconfig.exe /release
        }

        Start-Sleep -Seconds 3

        Invoke-BRCommand -Label "ipconfig /renew" -Command {
            ipconfig.exe /renew
        }
    } else {
        Write-BRLog "Admin skipped DHCP release/renew."
    }
}

function Optional-WinHttpProxyReset {
    Write-Host ""
    Write-Host "Current WinHTTP proxy:"
    netsh.exe winhttp show proxy

    Write-Host ""
    $choice = Read-Host "Reset WinHTTP proxy to direct access? Type Y to reset"

    if ($choice -match '^(Y|y|Yes|YES|yes)$') {
        Write-BRLog "Admin chose WinHTTP proxy reset."

        Invoke-BRCommand -Label "Reset WinHTTP proxy" -Command {
            netsh.exe winhttp reset proxy
        }
    } else {
        Write-BRLog "Admin skipped WinHTTP proxy reset."
    }
}

function Optional-KerberosPurge {
    Write-Host ""
    Write-Host "Kerberos ticket purge note:"
    Write-Host "This clears Kerberos tickets for the current logon session."
    Write-Host "It does not reset passwords and does not log the user out."
    Write-Host "Some network resources may ask for authentication again."

    $choice = Read-Host "Purge Kerberos tickets for this session? Type PURGE to continue"

    if ($choice -eq "PURGE") {
        Write-BRLog "Admin chose Kerberos ticket purge."

        Invoke-BRCommand -Label "klist purge" -Command {
            klist.exe purge
        }
    } else {
        Write-BRLog "Admin skipped Kerberos ticket purge."
    }
}

function Get-CmdKeyCredentials {
    $items = @()

    try {
        $raw = cmdkey.exe /list
        $current = [ordered]@{}

        foreach ($line in $raw) {
            $trimmed = $line.Trim()

            if ($trimmed -match '^Target:\s*(.+)$') {
                if ($current.Target) {
                    $items += [PSCustomObject]@{
                        Clear = "N"
                        Target = $current.Target
                        Type = $current.Type
                        User = $current.User
                        Notes = "Set Clear to Y to delete this saved credential"
                    }
                }

                $current = [ordered]@{}
                $current.Target = $Matches[1].Trim()
                $current.Type = ""
                $current.User = ""
            } elseif ($trimmed -match '^Type:\s*(.+)$') {
                $current.Type = $Matches[1].Trim()
            } elseif ($trimmed -match '^User:\s*(.+)$') {
                $current.User = $Matches[1].Trim()
            }
        }

        if ($current.Target) {
            $items += [PSCustomObject]@{
                Clear = "N"
                Target = $current.Target
                Type = $current.Type
                User = $current.User
                Notes = "Set Clear to Y to delete this saved credential"
            }
        }
    } catch {
        Write-BRLog "Could not read saved credentials with cmdkey: $($_.Exception.Message)"
    }

    return $items
}

function Optional-CredentialReview {
    Write-Host ""
    Write-Host "Credential Manager cleanup note:"
    Write-Host "This reviews saved credentials visible to the current Windows user."
    Write-Host "If you run this as Blue-Ridge, you are reviewing Blue-Ridge saved credentials."
    Write-Host "It does not clear another user's Credential Manager vault unless run in that user's session."
    Write-Host "It does not reset passwords or force logout."

    $choice = Read-Host "Review saved credentials with Y/N CSV? Type REVIEW to continue"

    if ($choice -ne "REVIEW") {
        Write-BRLog "Admin skipped saved credential review."
        return
    }

    $creds = Get-CmdKeyCredentials

    if (-not $creds -or $creds.Count -eq 0) {
        Write-BRLog "No saved cmdkey credentials found for current user."
        Write-Host ""
        Write-Host "No saved cmdkey credentials found for the current user."
        return
    }

    $creds |
        Sort-Object Target |
        Export-Csv -Path $CredReviewCsv -NoTypeInformation -Encoding UTF8

    Write-BRLog "Credential review CSV created: $CredReviewCsv"

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "Credential Review"
    Write-Host "============================================================"
    Write-Host ""
    Write-Host "A review file has been created:"
    Write-Host "    $CredReviewCsv"
    Write-Host ""
    Write-Host "In the Clear column, put:"
    Write-Host "    Y = delete that saved credential"
    Write-Host "    N = leave it alone"
    Write-Host ""
    Write-Host "Save and close Notepad when finished."
    Write-Host "Then return to this PowerShell window and press Enter."
    Write-Host "============================================================"
    Write-Host ""

    Start-Process notepad.exe -ArgumentList "`"$CredReviewCsv`"" -Wait

    Read-Host "Press Enter after saving the credential review CSV"

    try {
        $decisions = Import-Csv -Path $CredReviewCsv
    } catch {
        Write-BRLog "Could not read credential review CSV: $($_.Exception.Message)"
        return
    }

    $toClear = $decisions | Where-Object {
        $_.Clear -match '^(Y|y|Yes|YES|yes)$'
    }

    if (-not $toClear -or $toClear.Count -eq 0) {
        Write-BRLog "No credentials were marked for clearing."
        Write-Host ""
        Write-Host "No credentials marked Y. Nothing cleared."
        return
    }

    Write-Host ""
    Write-Host "The following saved credentials were marked for clearing:"
    Write-Host ""

    $toClear |
        Select-Object Target, Type, User |
        Format-Table -AutoSize

    Write-Host ""
    $confirm = Read-Host "Type CLEARCREDS to confirm deleting these saved credentials"

    if ($confirm -ne "CLEARCREDS") {
        Write-BRLog "Admin did not confirm credential clearing."
        Write-Host "No credentials cleared."
        return
    }

    foreach ($cred in $toClear) {
        try {
            Write-BRLog "Deleting saved credential target: $($cred.Target)"
            cmdkey.exe /delete:$($cred.Target) 2>&1 | ForEach-Object {
                Write-BRLog "    $($_.ToString())"
            }
        } catch {
            Write-BRLog "Failed to delete saved credential $($cred.Target): $($_.Exception.Message)"
        }
    }
}

Write-BRLog "=== Blue Ridge Network Fuzz Buster started ==="

Show-NetworkSnapshot -Label "Network snapshot before cleanup"

Clear-NetworkCaches
Reset-NetworkStack

Optional-DhcpRenew
Optional-WinHttpProxyReset
Optional-KerberosPurge
Optional-CredentialReview

Show-NetworkSnapshot -Label "Network snapshot after cleanup"

Write-BRLog "=== Blue Ridge Network Fuzz Buster completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Network Fuzz Buster completed."
Write-Host ""
Write-Host "What it did:"
Write-Host "    Flushed DNS cache"
Write-Host "    Cleared NetBIOS name cache"
Write-Host "    Refreshed NetBIOS registrations"
Write-Host "    Cleared ARP cache"
Write-Host "    Reset Winsock"
Write-Host "    Reset TCP/IP stack"
Write-Host "    Offered DHCP release/renew"
Write-Host "    Offered WinHTTP proxy reset"
Write-Host "    Offered Kerberos ticket purge"
Write-Host "    Offered saved credential review"
Write-Host ""
Write-Host "What it did NOT do:"
Write-Host "    Did not delete adapters"
Write-Host "    Did not delete VPN clients"
Write-Host "    Did not delete Wi-Fi profiles"
Write-Host "    Did not reset passwords"
Write-Host "    Did not force logout"
Write-Host "    Did not remove domain join"
Write-Host "    Did not delete user profiles"
Write-Host ""
Write-Host "Reboot recommended:"
Write-Host "    Winsock and TCP/IP resets are not fully clean until reboot."
Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
Write-Host ""
Write-Host "TCP/IP reset log:"
Write-Host "    $TcpIpResetLog"
Write-Host "============================================================"

$reboot = Read-Host "Reboot now to finish the network reset? Type REBOOT to restart"

if ($reboot -eq "REBOOT") {
    Write-BRLog "Admin chose reboot."
    shutdown.exe /r /t 30 /c "Blue Ridge Network Fuzz Buster completed. Rebooting to finish TCP/IP and Winsock reset."
} else {
    Write-BRLog "Admin skipped reboot."
    Write-Host "Reboot skipped. Please reboot later to finish the TCP/IP and Winsock reset."
}
