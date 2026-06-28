#requires -RunAsAdministrator
<#
Blue Ridge Print Queue Cleaner

Purpose:
- Clear stuck print jobs
- Clear spooler-side print queue files
- Restart Print Spooler cleanly
- Show printer and queue status before and after
- Avoid removing printers, drivers, ports, or vendor utilities

Use case:
- Run before power-cycling the printer
- Run when jobs are stuck, errored, paused, or not leaving the queue

Does not:
- Delete printers
- Delete printer drivers
- Delete printer ports
- Reset TCP/IP printer ports
- Remove vendor printer utilities
- Change default printer
#>

$ErrorActionPreference = "Continue"

$BRRoot = "C:\ProgramData\BlueRidge"
$LogDir = "$BRRoot\Logs"
$LogFile = "$LogDir\print-queue-cleaner.log"

New-Item -ItemType Directory -Force -Path $BRRoot, $LogDir | Out-Null

function Write-BRLog {
    param([string]$Message)

    $stamp = Get-Date -Format "yyyy-MM-dd hh:mm:ss tt"
    $line = "[$stamp] $Message"

    Write-Host $line
    Add-Content -Path $LogFile -Value $line
}

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Run this from PowerShell as Administrator."
    exit 1
}

function Show-PrinterStatus {
    param([string]$Label)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "$Label"
    Write-Host "============================================================"

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue |
            Select-Object Name, PrinterStatus, JobCount, Type, DriverName, PortName, Shared, Published

        if ($printers) {
            $printers | Format-Table -AutoSize
        } else {
            Write-Host "No printers found by Get-Printer."
        }
    } catch {
        Write-BRLog "Could not show printer status: $($_.Exception.Message)"
    }
}

function Show-PrintJobs {
    param([string]$Label)

    Write-Host ""
    Write-Host "============================================================"
    Write-Host "$Label"
    Write-Host "============================================================"

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue

        foreach ($printer in $printers) {
            $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue

            if ($jobs) {
                Write-Host ""
                Write-Host "Printer: $($printer.Name)"
                $jobs |
                    Select-Object PrinterName, ID, DocumentName, UserName, JobStatus, SubmittedTime, Size |
                    Format-Table -AutoSize
            }
        }
    } catch {
        Write-BRLog "Could not show print jobs: $($_.Exception.Message)"
    }
}

function Stop-PrintSpooler {
    Write-BRLog "Stopping Print Spooler."

    try {
        Stop-Service -Name Spooler -Force -ErrorAction Stop
        Write-BRLog "Print Spooler stopped."
    } catch {
        Write-BRLog "Could not stop Print Spooler cleanly: $($_.Exception.Message)"
    }
}

function Start-PrintSpooler {
    Write-BRLog "Starting Print Spooler."

    try {
        Start-Service -Name Spooler -ErrorAction Stop
        Set-Service -Name Spooler -StartupType Automatic
        Write-BRLog "Print Spooler started and set to Automatic."
    } catch {
        Write-BRLog "Could not start Print Spooler: $($_.Exception.Message)"
    }
}

function Clear-SpoolFolder {
    $spoolPath = "$env:SystemRoot\System32\spool\PRINTERS"

    Write-BRLog "Clearing spool folder: $spoolPath"

    if (-not (Test-Path $spoolPath)) {
        Write-BRLog "Spool folder not found: $spoolPath"
        return
    }

    try {
        Get-ChildItem -Path $spoolPath -Force -ErrorAction SilentlyContinue |
            Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

        Write-BRLog "Spool folder cleared."
    } catch {
        Write-BRLog "Could not fully clear spool folder: $($_.Exception.Message)"
    }
}

function Clear-PrintJobsPowerShell {
    Write-BRLog "Attempting to clear print jobs using PowerShell print commands."

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue

        foreach ($printer in $printers) {
            $jobs = Get-PrintJob -PrinterName $printer.Name -ErrorAction SilentlyContinue

            foreach ($job in $jobs) {
                try {
                    Write-BRLog "Removing print job ID $($job.ID) from printer $($printer.Name): $($job.DocumentName)"
                    Remove-PrintJob -PrinterName $printer.Name -ID $job.ID -ErrorAction Stop
                } catch {
                    Write-BRLog "Could not remove job ID $($job.ID) from $($printer.Name): $($_.Exception.Message)"
                }
            }
        }
    } catch {
        Write-BRLog "PowerShell print job cleanup issue: $($_.Exception.Message)"
    }
}

function Resume-PausedPrinters {
    Write-BRLog "Checking for paused printers."

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue

        foreach ($printer in $printers) {
            try {
                if ($printer.PrinterStatus -eq "Paused") {
                    Write-BRLog "Printer appears paused. Attempting to resume: $($printer.Name)"
                    Resume-Printer -Name $printer.Name -ErrorAction SilentlyContinue
                }
            } catch {
                Write-BRLog "Could not resume printer $($printer.Name): $($_.Exception.Message)"
            }
        }
    } catch {
        Write-BRLog "Paused printer check issue: $($_.Exception.Message)"
    }
}

function Clear-PrinterErrorStates {
    Write-BRLog "Checking printer queues for obvious error/paused/offline states."

    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue

        foreach ($printer in $printers) {
            Write-BRLog "Printer found: $($printer.Name) | Status: $($printer.PrinterStatus) | Jobs: $($printer.JobCount)"
        }
    } catch {
        Write-BRLog "Printer status check issue: $($_.Exception.Message)"
    }
}

Write-BRLog "=== Blue Ridge Print Queue Cleaner started ==="

Show-PrinterStatus -Label "Printer status before cleanup"
Show-PrintJobs -Label "Print jobs before cleanup"

Clear-PrintJobsPowerShell

Stop-PrintSpooler
Start-Sleep -Seconds 3

Clear-SpoolFolder

Start-Sleep -Seconds 2
Start-PrintSpooler

Start-Sleep -Seconds 3
Resume-PausedPrinters
Clear-PrinterErrorStates

Show-PrinterStatus -Label "Printer status after cleanup"
Show-PrintJobs -Label "Print jobs after cleanup"

Write-BRLog "=== Blue Ridge Print Queue Cleaner completed ==="

Write-Host ""
Write-Host "============================================================"
Write-Host "Blue Ridge Print Queue Cleaner completed."
Write-Host ""
Write-Host "What it did:"
Write-Host "    Cleared print jobs"
Write-Host "    Restarted Print Spooler"
Write-Host "    Cleared spool folder"
Write-Host "    Checked printer status"
Write-Host ""
Write-Host "What it did NOT do:"
Write-Host "    Did not delete printers"
Write-Host "    Did not delete drivers"
Write-Host "    Did not delete ports"
Write-Host "    Did not change default printer"
Write-Host ""
Write-Host "Log:"
Write-Host "    $LogFile"
Write-Host "============================================================"
