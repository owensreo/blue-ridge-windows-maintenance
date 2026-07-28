#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$ResetWinsock,[switch]$ResetTcpIp,[switch]$ResetAdapters,[switch]$ReleaseRenewDhcp,[switch]$ResetWinHttpProxy,[switch]$RestartComputer)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root='C:\ProgramData\BlueRidge\NetworkRepair';$logDir='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logDir|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$bundle=Join-Path $root "network-before-$stamp";New-Item -ItemType Directory -Force -Path $bundle|Out-Null
Start-Transcript -Path (Join-Path $logDir 'deep-network-repair.log') -Append|Out-Null
function Info($m){Write-Host "[*] $m" -ForegroundColor Cyan};function Ok($m){Write-Host "[+] $m" -ForegroundColor Green};function Warn($m){Write-Host "[!] $m" -ForegroundColor Yellow}
try{
 Get-NetIPConfiguration|Format-List *|Out-File (Join-Path $bundle 'ipconfig.txt');Get-NetRoute|Sort DestinationPrefix,RouteMetric|Export-Csv (Join-Path $bundle 'routes.csv') -NoTypeInformation;Get-DnsClientServerAddress|Export-Csv (Join-Path $bundle 'dns.csv') -NoTypeInformation;Get-NetAdapter|Export-Csv (Join-Path $bundle 'adapters.csv') -NoTypeInformation;netsh winhttp show proxy|Out-File (Join-Path $bundle 'winhttp-proxy.txt');route print|Out-File (Join-Path $bundle 'route-print.txt');ipconfig /all|Out-File (Join-Path $bundle 'ipconfig-all.txt');Ok "Before-state saved: $bundle"
 if($PSCmdlet.ShouldProcess('DNS, NetBIOS, and ARP caches','Clear')){Clear-DnsClientCache;nbtstat -R|Out-Null;nbtstat -RR|Out-Null;arp -d * 2>$null;Ok 'Cleared DNS, NetBIOS, and ARP caches.'}
 if($ResetWinsock -and $PSCmdlet.ShouldProcess('Winsock catalog','Reset')){netsh winsock reset|Out-File (Join-Path $bundle 'winsock-reset.txt');Ok 'Winsock reset requested.'}
 if($ResetTcpIp -and $PSCmdlet.ShouldProcess('TCP/IP stack','Reset')){netsh int ip reset (Join-Path $bundle 'tcpip-reset.txt')|Out-Null;Ok 'TCP/IP reset requested.'}
 if($ResetWinHttpProxy -and $PSCmdlet.ShouldProcess('WinHTTP proxy','Reset to direct')){netsh winhttp reset proxy|Out-Null;Ok 'WinHTTP proxy reset.'}
 if($ReleaseRenewDhcp -and $PSCmdlet.ShouldProcess('DHCP adapters','Release and renew')){ipconfig /release|Out-Null;ipconfig /renew|Out-Null;Ok 'DHCP release/renew completed.'}
 if($ResetAdapters){$active=Get-NetAdapter|Where Status -ne 'Disabled';foreach($a in $active){if($PSCmdlet.ShouldProcess($a.Name,'Disable and enable adapter')){Disable-NetAdapter -Name $a.Name -Confirm:$false;Start-Sleep 2;Enable-NetAdapter -Name $a.Name -Confirm:$false;Ok "Reset adapter: $($a.Name)"}}}
 Warn 'VPN clients, Wi-Fi profiles, certificates, and domain membership were not removed.'
 if($RestartComputer -and $PSCmdlet.ShouldProcess($env:COMPUTERNAME,'Restart computer')){Restart-Computer -Force}else{Info 'A restart is recommended when Winsock, TCP/IP, or adapters were reset.'}
}finally{Stop-Transcript|Out-Null}
