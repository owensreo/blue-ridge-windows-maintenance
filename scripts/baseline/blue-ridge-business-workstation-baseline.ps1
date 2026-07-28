#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([switch]$EnableRdp,[switch]$InstallOpenSSH,[switch]$CreateRestorePoint,[switch]$ApplyPowerSettings)
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root='C:\ProgramData\BlueRidge\Baseline';$logs='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logs|Out-Null;$s=Get-Date -Format yyyyMMdd-HHmmss;$backup=Join-Path $root "before-$s";New-Item -ItemType Directory -Force -Path $backup|Out-Null;Start-Transcript -Path (Join-Path $logs 'business-workstation-baseline.log') -Append|Out-Null
function Ok($m){Write-Host "[+] $m" -ForegroundColor Green};function Info($m){Write-Host "[*] $m" -ForegroundColor Cyan}
try{
 $os=Get-CimInstance Win32_OperatingSystem;if(-not $os -or $os.ProductType -ne 1){throw 'This baseline supports Windows workstations only.'}
 Get-ComputerInfo|Select WindowsProductName,WindowsVersion,OsBuildNumber,CsName,CsDomain|ConvertTo-Json|Set-Content (Join-Path $backup computer.json);Get-NetFirewallProfile|Export-Csv (Join-Path $backup firewall.csv) -NoTypeInformation;Get-Service wuauserv,bits,WinDefend,TermService,sshd -ErrorAction SilentlyContinue|Export-Csv (Join-Path $backup services.csv) -NoTypeInformation;powercfg /getactivescheme|Out-File (Join-Path $backup power-plan.txt)
 if($CreateRestorePoint -and $PSCmdlet.ShouldProcess($env:SystemDrive,'Create a system restore point')){try{Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue;Checkpoint-Computer -Description 'Before Blue Ridge Business Baseline' -RestorePointType MODIFY_SETTINGS;Ok 'Restore point created'}catch{Write-Warning $_}}
 if($PSCmdlet.ShouldProcess('Windows Update services','Set startup type to Manual')){Set-Service wuauserv -StartupType Manual;Set-Service bits -StartupType Manual;Ok 'Windows Update services preserved.'}
 if((Get-Command Set-MpPreference -ErrorAction SilentlyContinue) -and $PSCmdlet.ShouldProcess('Microsoft Defender','Set scan CPU cap to 20%')){Set-MpPreference -ScanAvgCPULoadFactor 20;Ok 'Defender scan CPU cap set to 20%.'}
 if($PSCmdlet.ShouldProcess('Windows CloudContent policy','Disable consumer features')){New-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Force|Out-Null;New-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' DisableWindowsConsumerFeatures -PropertyType DWord -Value 1 -Force|Out-Null}
 if($ApplyPowerSettings -and $PSCmdlet.ShouldProcess('AC power plan','Set monitor timeout to 20 minutes and disable standby')){powercfg /change monitor-timeout-ac 20;powercfg /change standby-timeout-ac 0;Ok 'Business AC power defaults applied.'}
 if($EnableRdp -and $PSCmdlet.ShouldProcess('Remote Desktop','Enable RDP and firewall rules')){Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' fDenyTSConnections 0;Enable-NetFirewallRule -DisplayGroup 'Remote Desktop';Ok 'RDP enabled.'}
 if($InstallOpenSSH -and $PSCmdlet.ShouldProcess('OpenSSH Server','Install, enable, and start')){$cap=Get-WindowsCapability -Online|Where Name -like 'OpenSSH.Server*'|Select-Object -First 1;if(-not $cap){throw 'OpenSSH Server capability was not found.'};if($cap.State -ne 'Installed'){Add-WindowsCapability -Online -Name $cap.Name|Out-Null};Set-Service sshd -StartupType Automatic;Start-Service sshd;Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue|Enable-NetFirewallRule;Ok 'OpenSSH Server ready.'}
 Info "Before-state: $backup";Write-Warning 'This baseline does not remove applications, disable Defender, disable Windows Update, or create user accounts.'
}finally{Stop-Transcript|Out-Null}
