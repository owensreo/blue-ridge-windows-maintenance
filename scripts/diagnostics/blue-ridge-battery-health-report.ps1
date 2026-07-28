#requires -Version 5.1
[CmdletBinding()]param()
Set-StrictMode -Version Latest;$ErrorActionPreference='Stop'
$root='C:\ProgramData\BlueRidge\BatteryReports';$logDir='C:\ProgramData\BlueRidge\Logs';New-Item -ItemType Directory -Force -Path $root,$logDir|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$dir=Join-Path $root "battery-$env:COMPUTERNAME-$stamp";New-Item -ItemType Directory -Force -Path $dir|Out-Null
Start-Transcript -Path (Join-Path $logDir 'battery-health-report.log') -Append|Out-Null
try{
 $html=Join-Path $dir 'battery-report.html';powercfg /batteryreport /output $html|Out-Null
 $bats=Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
 $static=Get-CimInstance -Namespace root\wmi -Class BatteryStaticData -ErrorAction SilentlyContinue
 $full=Get-CimInstance -Namespace root\wmi -Class BatteryFullChargedCapacity -ErrorAction SilentlyContinue
 $cycles=Get-CimInstance -Namespace root\wmi -Class BatteryCycleCount -ErrorAction SilentlyContinue
 $rows=@();foreach($s in $static){$f=$full|Where InstanceName -eq $s.InstanceName|Select -First 1;$c=$cycles|Where InstanceName -eq $s.InstanceName|Select -First 1;$design=[double]$s.DesignedCapacity;$fc=if($f){[double]$f.FullChargedCapacity}else{$null};$health=if($design -gt 0 -and $null -ne $fc){[math]::Round(($fc/$design)*100,1)}else{$null};$rows+=[pscustomobject]@{Instance=$s.InstanceName;Manufacturer=$s.ManufactureName;Serial=$s.SerialNumber;DesignCapacitymWh=$design;FullChargeCapacitymWh=$fc;HealthPercent=$health;CycleCount=if($c){$c.CycleCount}else{$null}}}
 $rows|Export-Csv (Join-Path $dir 'battery-summary.csv') -NoTypeInformation -Encoding UTF8
 powercfg /getactivescheme|Out-File (Join-Path $dir 'active-power-plan.txt');powercfg /availablesleepstates|Out-File (Join-Path $dir 'sleep-states.txt')
 $rows|Format-Table -AutoSize|Out-String|Set-Content (Join-Path $dir 'summary.txt')
 Write-Host "Battery report bundle: $dir" -ForegroundColor Green
 if(-not $bats -and -not $rows){Write-Warning 'No battery was detected; this may be a desktop or VM.'}
}finally{Stop-Transcript|Out-Null}
