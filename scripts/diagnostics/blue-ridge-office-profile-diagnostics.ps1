#requires -Version 5.1
[CmdletBinding()]param()
Set-StrictMode -Version Latest;$ErrorActionPreference='Continue'
$root='C:\ProgramData\BlueRidge\OfficeDiagnostics';$logDir='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logDir|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$dir=Join-Path $root "office-$env:COMPUTERNAME-$stamp";New-Item -ItemType Directory -Force -Path $dir|Out-Null
Start-Transcript -Path (Join-Path $logDir 'office-profile-diagnostics.log') -Append|Out-Null
try{
 $c2r='HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration';if(Test-Path $c2r){Get-ItemProperty $c2r|Select VersionToReport,ClientVersionToReport,UpdateChannel,CDNBaseUrl,Platform,ProductReleaseIds|Export-Csv (Join-Path $dir 'click-to-run.csv') -NoTypeInformation}
 $profiles=@();$profileRoots=@('HKCU:\Software\Microsoft\Office\16.0\Outlook\Profiles','HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles');foreach($r in $profileRoots){if(Test-Path $r){Get-ChildItem $r|ForEach-Object{$profiles+=[pscustomobject]@{RegistryRoot=$r;Profile=$_.PSChildName}}}};$profiles|Export-Csv (Join-Path $dir 'outlook-profiles.csv') -NoTypeInformation
 $dataFiles=Get-ChildItem "$env:USERPROFILE\Documents\Outlook Files","$env:LOCALAPPDATA\Microsoft\Outlook" -Recurse -File -Include *.pst,*.ost -ErrorAction SilentlyContinue|Select FullName,Length,LastWriteTime; $dataFiles|Export-Csv (Join-Path $dir 'outlook-data-files.csv') -NoTypeInformation
 $paths=@("$env:APPDATA\Microsoft\Teams","$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe","$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache","$env:LOCALAPPDATA\Microsoft\Outlook\RoamCache","$env:LOCALAPPDATA\Microsoft\OneAuth","$env:LOCALAPPDATA\Microsoft\IdentityCache");$paths|ForEach-Object{[pscustomobject]@{Path=$_;Exists=Test-Path $_;SizeMB=if(Test-Path $_){[math]::Round(((Get-ChildItem $_ -Recurse -File -ErrorAction SilentlyContinue|Measure Length -Sum).Sum/1MB),2)}else{0}}}|Export-Csv (Join-Path $dir 'cache-and-identity-paths.csv') -NoTypeInformation
 Get-Process OUTLOOK,ms-teams,Teams,WINWORD,EXCEL,ONENOTE,OneDrive -ErrorAction SilentlyContinue|Select Name,Id,Path,StartTime|Export-Csv (Join-Path $dir 'running-office-processes.csv') -NoTypeInformation
 Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue|Where-Object ProviderName -match 'Outlook|Office|Teams|ClickToRun'|Select -First 200 TimeCreated,ProviderName,Id,LevelDisplayName,Message|Export-Csv (Join-Path $dir 'recent-office-events.csv') -NoTypeInformation
 Write-Host "Office diagnostic bundle: $dir" -ForegroundColor Green;Write-Warning 'This script does not delete profiles, PST/OST files, credentials, or identity caches.'
}finally{Stop-Transcript|Out-Null}
