#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]param()
Set-StrictMode -Version Latest;$ErrorActionPreference='Continue'
$root='C:\ProgramData\BlueRidge\SecurityReports';$logs='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logs|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$out=Join-Path $root "bitlocker-readiness-$env:COMPUTERNAME-$stamp.json";Start-Transcript -Path (Join-Path $logs 'bitlocker-readiness.log') -Append|Out-Null
try{
 $tpm=Get-Tpm -ErrorAction SilentlyContinue;$secureBoot=try{Confirm-SecureBootUEFI}catch{$null};$vols=Get-BitLockerVolume -ErrorAction SilentlyContinue
 $system=Get-Volume -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue
 $systemBitLocker=$vols|Where-Object MountPoint -eq $env:SystemDrive|Select-Object -First 1
 $tpmPresent=if($tpm){$tpm.TpmPresent}else{$false};$tpmReady=if($tpm){$tpm.TpmReady}else{$false};$tpmEnabled=if($tpm){$tpm.TpmEnabled}else{$false}
 $result=[pscustomobject]@{Computer=$env:COMPUTERNAME;TpmPresent=$tpmPresent;TpmReady=$tpmReady;TpmEnabled=$tpmEnabled;SecureBoot=$secureBoot;SystemDrive=$env:SystemDrive;FileSystem=if($system){$system.FileSystem}else{$null};HealthStatus=if($system){$system.HealthStatus}else{$null};ProtectionStatus=if($systemBitLocker){$systemBitLocker.ProtectionStatus}else{$null};VolumeStatus=if($systemBitLocker){$systemBitLocker.VolumeStatus}else{$null};EncryptionPercentage=if($systemBitLocker){$systemBitLocker.EncryptionPercentage}else{$null};RecoveryPasswordProtectorPresent=[bool]($systemBitLocker -and ($systemBitLocker.KeyProtector|Where-Object KeyProtectorType -eq 'RecoveryPassword'));Recommendation=if($tpmReady -and $secureBoot -ne $false){'Hardware appears ready. Confirm recovery-key escrow before enabling BitLocker.'}else{'Review TPM, UEFI, and Secure Boot status before enabling BitLocker.'}}
 $result|ConvertTo-Json -Depth 5|Set-Content $out -Encoding UTF8;$result|Format-List;Write-Host "Report: $out" -ForegroundColor Green
 Write-Warning 'This script does not enable BitLocker or create protectors.'
}finally{Stop-Transcript|Out-Null}
