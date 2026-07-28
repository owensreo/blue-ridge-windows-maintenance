#requires -RunAsAdministrator
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([string]$PrinterName,[switch]$RestartSpooler,[switch]$ClearQueue,[switch]$TestPorts,[switch]$ExportDrivers)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\ProgramData\BlueRidge\PrinterRepair';$logDir='C:\ProgramData\BlueRidge\Logs'
New-Item -ItemType Directory -Force -Path $root,$logDir|Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss';$log=Join-Path $logDir 'deep-printer-repair.log';Start-Transcript -Path $log -Append|Out-Null
function Info($m){Write-Host "[*] $m" -ForegroundColor Cyan};function Ok($m){Write-Host "[+] $m" -ForegroundColor Green};function Warn($m){Write-Host "[!] $m" -ForegroundColor Yellow}
try{
 $printers=Get-Printer -ErrorAction Stop;if($PrinterName){$printers=$printers|Where-Object Name -eq $PrinterName;if(-not $printers){throw "Printer not found: $PrinterName"}}
 $report=$printers|ForEach-Object{ $p=$_;$port=Get-PrinterPort -Name $p.PortName -ErrorAction SilentlyContinue;[pscustomobject]@{Name=$p.Name;Driver=$p.DriverName;Port=$p.PortName;Type=$p.Type;Shared=$p.Shared;Published=$p.Published;PrinterStatus=$p.PrinterStatus;WorkOffline=$p.WorkOffline;PortHost=if($port){$port.PrinterHostAddress}else{$null};Protocol=if($port){$port.Protocol}else{$null}}}
 $csv=Join-Path $root "printer-report-$stamp.csv";$report|Export-Csv $csv -NoTypeInformation -Encoding UTF8;Info "Report: $csv"
 if($ExportDrivers){$driverCsv=Join-Path $root "printer-drivers-$stamp.csv";Get-PrinterDriver|Select Name,Manufacturer,MajorVersion,InfPath,DriverPath,ConfigFile,DataFile|Export-Csv $driverCsv -NoTypeInformation -Encoding UTF8;Ok "Driver inventory: $driverCsv"}
 if($ClearQueue){foreach($p in $printers){if($PSCmdlet.ShouldProcess($p.Name,'Remove visible print jobs')){Get-PrintJob -PrinterName $p.Name -ErrorAction SilentlyContinue|Remove-PrintJob -ErrorAction SilentlyContinue;Ok "Cleared visible jobs for $($p.Name)"}}}
 if($RestartSpooler){if($PSCmdlet.ShouldProcess('Print Spooler','Restart service')){Restart-Service Spooler -Force;Set-Service Spooler -StartupType Automatic;Ok 'Print Spooler restarted and set Automatic'}}
 if($TestPorts){foreach($row in $report|Where-Object PortHost){$hostName=[string]$row.PortHost;Info "Testing $($row.Name) at $hostName";if(Test-Connection $hostName -Count 1 -Quiet -ErrorAction SilentlyContinue){Ok 'ICMP reachable'}else{Warn 'ICMP not reachable'};foreach($port in 9100,515,631){$t=Test-NetConnection $hostName -Port $port -WarningAction SilentlyContinue;Write-Host ("  TCP {0}: {1}" -f $port,$t.TcpTestSucceeded)}}}
 Warn 'This helper does not delete printers, ports, or drivers automatically. Use the report to identify stale objects before removal.'
}finally{Stop-Transcript|Out-Null}
