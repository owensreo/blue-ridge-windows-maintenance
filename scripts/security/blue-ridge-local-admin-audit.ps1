#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding()]param()
Set-StrictMode -Version Latest;$ErrorActionPreference='Continue'
$root='C:\ProgramData\BlueRidge\SecurityReports';$logs='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logs|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$out=Join-Path $root "local-admin-audit-$env:COMPUTERNAME-$stamp.csv";Start-Transcript -Path (Join-Path $logs 'local-admin-audit.log') -Append|Out-Null
try{
 $members=Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop
 $rows=foreach($m in $members){$local=$null;if($m.PrincipalSource -eq 'Local'){$n=($m.Name -split '\\')[-1];$local=Get-LocalUser -Name $n -ErrorAction SilentlyContinue};[pscustomobject]@{Computer=$env:COMPUTERNAME;Name=$m.Name;ObjectClass=$m.ObjectClass;PrincipalSource=$m.PrincipalSource;Enabled=$local.Enabled;LastLogon=$local.LastLogon;PasswordLastSet=$local.PasswordLastSet;PasswordExpires=$local.PasswordExpires;Description=$local.Description}}
 $rows|Export-Csv $out -NoTypeInformation -Encoding UTF8;$rows|Format-Table -AutoSize;Write-Host "Audit saved: $out" -ForegroundColor Green
 Write-Warning 'Nested domain-group membership is not expanded automatically; review domain groups in Active Directory.'
}finally{Stop-Transcript|Out-Null}
