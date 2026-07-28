#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputRoot = 'C:\ProgramData\BlueRidge\DomainTrustDiagnostics'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $OutputRoot "$env:COMPUTERNAME-$stamp"
$logDir = 'C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Path $outDir,$logDir -Force | Out-Null
$log = Join-Path $logDir 'domain-trust-diagnostics.log'
Start-Transcript -Path $log -Append | Out-Null

function Invoke-TextCommand {
    param([string]$File,[string[]]$Arguments)
    try { (& $File @Arguments 2>&1 | Out-String).Trim() } catch { "ERROR: $($_.Exception.Message)" }
}
function Try-Value { param([scriptblock]$Script) try { & $Script } catch { $null } }

try {
    $computer = Get-CimInstance Win32_ComputerSystem
    $partOfDomain = [bool]$computer.PartOfDomain
    $domain = $computer.Domain
    $secureChannel = $null
    $secureError = $null
    if ($partOfDomain) {
        try { $secureChannel = Test-ComputerSecureChannel -ErrorAction Stop } catch { $secureChannel = $false; $secureError = $_.Exception.Message }
    }

    $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object ServerAddresses | Select-Object InterfaceAlias,ServerAddresses
    $timeStatus = Invoke-TextCommand 'w32tm.exe' @('/query','/status')
    $timeSource = Invoke-TextCommand 'w32tm.exe' @('/query','/source')
    $dcDiscovery = if ($partOfDomain) { Invoke-TextCommand 'nltest.exe' @("/dsgetdc:$domain") } else { 'Not domain joined' }
    $secureVerify = if ($partOfDomain) { Invoke-TextCommand 'nltest.exe' @('/sc_verify:' + $domain) } else { 'Not domain joined' }
    $logonServer = $env:LOGONSERVER
    $kerberos = if ($partOfDomain) { Invoke-TextCommand 'klist.exe' @() } else { 'Not domain joined' }
    $gp = if ($partOfDomain) { Invoke-TextCommand 'gpresult.exe' @('/r','/scope','computer') } else { 'Not domain joined' }
    $netlogon = Get-Service Netlogon -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
    $events = Get-WinEvent -FilterHashtable @{LogName=@('System','Microsoft-Windows-GroupPolicy/Operational'); StartTime=(Get-Date).AddDays(-2)} -ErrorAction SilentlyContinue |
        Where-Object { $_.Level -in 1,2 -or $_.ProviderName -match 'NETLOGON|GroupPolicy|Kerberos|Time-Service' } |
        Select-Object TimeCreated,LogName,Id,ProviderName,LevelDisplayName,Message
    $events | Export-Csv (Join-Path $outDir 'domain-events.csv') -NoTypeInformation -Encoding UTF8

    $sysvol = $false
    $netlogonShare = $false
    if ($partOfDomain) {
        $sysvol = Test-Path "\\$domain\SYSVOL"
        $netlogonShare = Test-Path "\\$domain\NETLOGON"
    }

    $recommendation = if (-not $partOfDomain) {
        'This computer is not domain joined.'
    } elseif (-not $secureChannel) {
        if ($dcDiscovery -match 'failed|ERROR') { 'Fix DNS or domain controller discovery before attempting trust repair.' }
        elseif (-not $sysvol -or -not $netlogonShare) { 'Domain resources are unreachable. Fix DNS, routing, or DC availability before trust repair.' }
        else { 'Secure channel is broken. Run the host-side repair locally, or the DC-side repair if WinRM is available.' }
    } elseif ($timeStatus -match 'error|unsynchronized') {
        'Secure channel is healthy, but time synchronization needs attention.'
    } else {
        'No domain trust repair is currently indicated.'
    }

    $report = [ordered]@{
        GeneratedAt = Get-Date
        ComputerName = $env:COMPUTERNAME
        PartOfDomain = $partOfDomain
        Domain = $domain
        SecureChannelHealthy = $secureChannel
        SecureChannelError = $secureError
        LogonServer = $logonServer
        NetlogonService = $netlogon
        DNS = $dns
        SYSVOLReachable = $sysvol
        NETLOGONReachable = $netlogonShare
        TimeSource = $timeSource
        TimeStatus = $timeStatus
        DCDiscovery = $dcDiscovery
        SecureChannelVerification = $secureVerify
        KerberosTickets = $kerberos
        ComputerPolicy = $gp
        RecentEventCount = @($events).Count
        Recommendation = $recommendation
    }

    $report | ConvertTo-Json -Depth 7 | Set-Content (Join-Path $outDir 'domain-trust-report.json') -Encoding UTF8
    $report | Format-List * | Out-String -Width 240 | Set-Content (Join-Path $outDir 'domain-trust-report.txt') -Encoding UTF8
    $report | Format-List *
    Write-Host "Recommendation: $recommendation" -ForegroundColor Cyan
    Write-Host "Report folder: $outDir" -ForegroundColor Green
}
finally { Stop-Transcript | Out-Null }
