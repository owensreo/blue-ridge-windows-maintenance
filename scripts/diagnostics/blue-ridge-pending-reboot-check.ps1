#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$RmmExitCodes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$reasons = [System.Collections.Generic.List[string]]::new()

function Test-RegPath { param([string]$Path) return (Test-Path -LiteralPath $Path) }
function Test-RegValue {
    param([string]$Path,[string]$Name)
    try {
        $value = Get-ItemPropertyValue -LiteralPath $Path -Name $Name -ErrorAction Stop
        return ($null -ne $value -and @($value).Count -gt 0)
    } catch { return $false }
}

if (Test-RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
    $reasons.Add('Component Based Servicing')
}
if (Test-RegPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
    $reasons.Add('Windows Update')
}
if (Test-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'PendingFileRenameOperations') {
    $reasons.Add('Pending file rename operations')
}
if (Test-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' 'ComputerName') {
    try {
        $active = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName' 'ComputerName'
        $pending = Get-ItemPropertyValue 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' 'ComputerName'
        if ($active -ne $pending) { $reasons.Add('Computer rename pending') }
    } catch {}
}

try {
    $ccm = Invoke-CimMethod -Namespace 'root\ccm\ClientSDK' -ClassName CCM_ClientUtilities -MethodName DetermineIfRebootPending -ErrorAction Stop
    if ($ccm.RebootPending -or $ccm.IsHardRebootPending) { $reasons.Add('Configuration Manager client') }
} catch {}

$result = [pscustomobject]@{
    ComputerName  = $env:COMPUTERNAME
    CheckedAt     = Get-Date
    PendingReboot = ($reasons.Count -gt 0)
    Reasons       = @($reasons)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 3
} else {
    Write-Host "PendingReboot: $($result.PendingReboot)"
    if ($reasons.Count -gt 0) {
        Write-Host 'Reasons:'
        $reasons | ForEach-Object { Write-Host "- $_" }
    } else {
        Write-Host 'Reasons: none'
    }
}

if ($RmmExitCodes) {
    if ($result.PendingReboot) { exit 3010 }
    exit 0
}
