#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]param()
Set-StrictMode -Version Latest;$ErrorActionPreference='Continue'
$root='C:\ProgramData\BlueRidge\SecurityReports';$logs='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logs|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$out=Join-Path $root "bitlocker-readiness-$env:COMPUTERNAME-$stamp.json";Start-Transcript -Path (Join-Path $logs 'bitlocker-readiness.log') -Append|Out-Null
try{
 $tpm=Get-Tpm -ErrorAction SilentlyContinue;$secureBoot=try{Confirm-SecureBootUEFI}catch{$null};$vols=Get-BitLockerVolume -ErrorAction SilentlyContinue
 $system=Get-Volume -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
 $result=[pscustomobject]@{Computer=$env:COMPUTERNAME;TpmPresent=$tpm.TpmPresent;TpmReady=$tpm.TpmReady;TpmEnabled=$tpm.TpmEnabled;SecureBoot=$secureBoot;SystemDrive=$env:SystemDrive;FileSystem=$system.FileSystem;HealthStatus=$system.HealthStatus;ProtectionStatus=($vols|Where MountPoint -eq $env:SystemDrive).ProtectionStatus;VolumeStatus=($vols|Where MountPoint -eq $env:SystemDrive).VolumeStatus;EncryptionPercentage=($vols|Where MountPoint -eq $env:SystemDrive).EncryptionPercentage;RecoveryPasswordProtectorPresent=[bool](($vols|Where MountPoint -eq $env:SystemDrive).KeyProtector|Where KeyProtectorType -eq 'RecoveryPassword');Recommendation=if($tpm.TpmReady -and $secureBoot -ne $false){'Hardware appears ready. Confirm recovery-key escrow before enabling BitLocker.'}else{'Review TPM, UEFI, and Secure Boot status before enabling BitLocker.'}}
 $result|ConvertTo-Json -Depth 5|Set-Content $out -Encoding UTF8;$result|Format-List;Write-Host "Report: $out" -ForegroundColor Green
 Write-Warning 'This script does not enable BitLocker or create protectors.'
}finally{Stop-Transcript|Out-Null}
