<p align="center">
  <img src="assets/blue-ridge-systems-consulting-logo.svg" alt="Blue Ridge Systems Consulting Logo" width="160" />
</p>

# Blue Ridge Windows Maintenance

A practical Windows administration toolkit from **Blue Ridge Systems** for field support, small business workstations, student laptops, and general Windows maintenance work.

This repository focuses on safe, inspectable PowerShell scripts that help diagnose and resolve common Windows support issues without immediately jumping to destructive repairs, profile rebuilds, app removals, service disabling, or full system resets.

## Purpose

The scripts are designed for administrators who need repeatable first-pass diagnostics and repair tools. The emphasis is on conservative maintenance, clear prompts, local logging, preserving user data, and separating diagnosis from remediation.

## Goals

- Provide PowerShell scripts that can be reviewed before use
- Diagnose first and repair second
- Favor safe first-pass repair steps before deeper remediation
- Preserve user files, browser data, Outlook data, Windows profiles, and business or school applications
- Keep Windows Update, Microsoft Defender, and core Windows services enabled
- Avoid unnecessary app removal, service disabling, profile deletion, or domain rejoin work
- Keep logs simple and local under `C:\ProgramData\BlueRidge\Logs`

## Repository layout

```text
scripts/
├── diagnostics/
├── domain/
├── repair/
├── restore/
├── security/
└── existing workstation maintenance tools
```

## Script catalog

### Core workstation tools

| Script | Purpose |
|---|---|
| `scripts/blue-ridge-win11-standard-maintenance.ps1` | Windows 11 baseline maintenance, repair, remote access setup, Defender tuning, cache cleanup, DISM/SFC, and scheduled maintenance |
| `scripts/blue-ridge-windows-update-enforcer-install.ps1` | Monthly Windows Update enforcement using built-in Windows Update components |
| `scripts/blue-ridge-startup-app-checker.ps1` | Review-based startup app audit and disable workflow |
| `scripts/blue-ridge-print-queue-cleaner.ps1` | Safe print queue cleanup before deeper printer repair |
| `scripts/blue-ridge-network-fuzz-buster.ps1` | DNS, NetBIOS, ARP, Winsock, TCP/IP, proxy, Kerberos, and saved credential cleanup workflow |
| `scripts/blue-ridge-outlook-teams-soft-reset.ps1` | Safe first-pass Outlook, Teams, and Microsoft 365 desktop app repair helper |
| `scripts/blue-ridge-host-domain-trust-repair.ps1` | Host-side domain secure-channel repair from the affected workstation |
| `scripts/blue-ridge-dc-domain-trust-repair.ps1` | DC-side domain trust repair orchestration over PowerShell Remoting |

### Diagnostics

| Script | Purpose |
|---|---|
| `scripts/diagnostics/blue-ridge-windows-health-report.ps1` | Read-only system health bundle with HTML, text, JSON, and recent-event CSV output |
| `scripts/diagnostics/blue-ridge-pending-reboot-check.ps1` | Fast pending-reboot detection with optional JSON and RMM exit codes |
| `scripts/domain/blue-ridge-domain-trust-diagnostics.ps1` | Domain join, secure channel, DNS, DC discovery, time, Kerberos, Group Policy, SYSVOL, and NETLOGON diagnostics |
| `scripts/security/blue-ridge-defender-health-check.ps1` | Defender protection, signature, scan, exclusion, service, and recent-threat review |

### Repair and restore

| Script | Purpose |
|---|---|
| `scripts/repair/blue-ridge-windows-update-reset.ps1` | Conservative Windows Update component reset with service-state capture and renamed cache folders |
| `scripts/restore/blue-ridge-startup-app-restore.ps1` | Restores startup registry entries, moved Startup-folder files, and disabled startup scheduled tasks |

## Requirements

- Windows 10 or Windows 11 for most workstation scripts
- Windows PowerShell 5.1 or newer
- Administrator rights for scripts that change system state
- Domain scripts require a domain-joined environment
- DC-side domain trust repair requires WinRM/PowerShell Remoting to the target workstation
- Microsoft 365/Office update functions require Click-to-Run Office when using `OfficeC2RClient.exe`

## Usage

Review each script before running it. These tools are intended for administrators who understand the effects of the commands they execute.

Recommended approach:

1. Clone or download this repository.
2. Review the script you plan to use.
3. Run the least invasive diagnostic that matches the issue.
4. Copy the repair script to the target machine when appropriate.
5. Run state-changing scripts from an elevated PowerShell session.
6. Review terminal output and logs under `C:\ProgramData\BlueRidge\Logs`.
7. Reboot only when the script recommends it.

For practical field notes, see [`RUNBOOK.md`](RUNBOOK.md).

## New diagnostic workflows

### Windows Health Report

`blue-ridge-windows-health-report.ps1` creates a dated report folder under:

```text
C:\ProgramData\BlueRidge\HealthReports\COMPUTERNAME-YYYYMMDD-HHMMSS\
```

It records OS and hardware information, uptime, disks, physical-disk health where available, BitLocker, TPM, Secure Boot, Defender, pending reboot state, failed automatic services, networking, remote-access state, and recent critical/error events.

It is read-only and does not change the computer.

### Pending Reboot Check

Standard output:

```powershell
.\scripts\diagnostics\blue-ridge-pending-reboot-check.ps1
```

JSON output:

```powershell
.\scripts\diagnostics\blue-ridge-pending-reboot-check.ps1 -Json
```

RMM exit-code behavior:

```powershell
.\scripts\diagnostics\blue-ridge-pending-reboot-check.ps1 -RmmExitCodes
```

Exit code `0` means no reboot is pending. Exit code `3010` means a reboot is required.

### Defender Health Check

The default run is diagnostic only:

```powershell
.\scripts\security\blue-ridge-defender-health-check.ps1
```

Optional actions:

```powershell
.\scripts\security\blue-ridge-defender-health-check.ps1 -UpdateSignatures
.\scripts\security\blue-ridge-defender-health-check.ps1 -RunQuickScan
.\scripts\security\blue-ridge-defender-health-check.ps1 -LaunchOfflineScan
```

The offline-scan option warns that Windows will reboot and requires explicit confirmation.

### Domain Trust Diagnostics

Run this before attempting trust repair:

```powershell
.\scripts\domain\blue-ridge-domain-trust-diagnostics.ps1
```

It creates text, JSON, and event-log output and recommends whether to repair trust, fix DNS/DC discovery, correct time synchronization, or take no repair action.

## New repair and restore workflows

### Windows Update Reset

```powershell
.\scripts\repair\blue-ridge-windows-update-reset.ps1
```

Optional deeper checks:

```powershell
.\scripts\repair\blue-ridge-windows-update-reset.ps1 -RunDISM -TriggerScan
```

The script captures current update-service state, attempts a restore point unless skipped, stops update services, renames `SoftwareDistribution` and `catroot2` instead of deleting them, restarts services, and optionally runs DISM and triggers a scan.

It supports PowerShell `-WhatIf` for the state-changing reset operations.

### Startup App Restore

The restore helper reads the backup locations used by `blue-ridge-startup-app-checker.ps1`:

- `HKCU:\Software\BlueRidge\DisabledStartup`
- `HKLM:\Software\BlueRidge\DisabledStartup`
- `C:\ProgramData\BlueRidge\StartupAppChecker\DisabledStartupItems`
- the saved startup review CSV for task and original-path context

Run:

```powershell
.\scripts\restore\blue-ridge-startup-app-restore.ps1
```

It presents available disabled items and requires the administrator to type `RESTORE` before making changes.

## Existing tool highlights

### Windows 11 Standard Maintenance

The standard maintenance script can prepare a local support account, configure RDP and OpenSSH where appropriate, apply conservative power and Defender performance settings, clean safe cache locations, run Disk Cleanup, DISM, SFC, Defender updates/scans, and create twice-weekly scheduled maintenance.

It intentionally does not remove applications, disable Windows Update, disable Defender, delete user files, reset networking, scrape browsing history, or create a full user activity report.

### Startup App Checker

The checker finds Run/RunOnce registry entries, Startup-folder items, and non-Microsoft scheduled tasks with Logon or Startup triggers. It exports findings to CSV and disables only items explicitly marked and confirmed by the administrator.

### Print Queue Cleaner

The print tool removes visible jobs, safely resets the spool folder, restores the Print Spooler to Automatic, and attempts to resume paused printers. It does not delete printers, drivers, ports, vendor tools, or default-printer settings.

### Network Fuzz Buster

The network tool can flush DNS, clear NetBIOS and ARP caches, reset Winsock/TCP-IP, and optionally handle DHCP, WinHTTP proxy, Kerberos tickets, and review-based saved credentials. It does not delete adapters, VPN clients, Wi-Fi profiles, certificates, cached domain logons, or domain membership.

### Outlook Teams Soft Reset

The Microsoft 365 helper performs safe first-pass cache and launch repairs while preserving PST files, OST files by default, Outlook profiles, accounts, calendar entries, contacts, Teams, Office, and credentials.

### Domain Trust Repair

The host-side and DC-side repair scripts attempt secure-channel repair without automatically unjoining/rejoining the domain, deleting profiles, clearing cached domain logons, or changing local administrator credentials.

## Logs and local files

Common paths include:

```text
C:\ProgramData\BlueRidge\Logs\
C:\ProgramData\BlueRidge\HealthReports\
C:\ProgramData\BlueRidge\DomainTrustDiagnostics\
C:\ProgramData\BlueRidge\WindowsUpdateReset\
C:\ProgramData\BlueRidge\StartupAppChecker\
C:\ProgramData\BlueRidge\OutlookTeamsSoftReset\Backups\
```

Logs record script actions and errors. They are not intended to collect user activity, browser history, personal files, or a surveillance-style system inventory.

## Recommended support workflow

1. Confirm the user impact and current symptoms.
2. Run the Windows Health Report or the focused diagnostic for the issue.
3. Review the report before changing the machine.
4. Run the least invasive repair tool.
5. Review console output and local logs.
6. Re-run the diagnostic or otherwise verify the repair.
7. Reboot when recommended.
8. Escalate to deeper repair only when the conservative workflow does not resolve the issue.

## Safety principles

- Diagnose first and repair second
- Repair Windows before blaming hardware
- Clean safe cache locations without touching user data
- Preserve school and business software compatibility
- Keep Microsoft Defender enabled
- Keep Windows Update available
- Avoid disabling services unless there is a named problem
- Separate normal maintenance from forced update/reboot behavior
- Make startup changes reviewable, confirmed, and reversible
- Keep printer repair safe before driver, port, or vendor-tool work
- Keep network repair safe before adapter removal, VPN repair, domain repair, or profile work
- Fix Microsoft 365 desktop issues without destroying Outlook data or forcing new Outlook
- Diagnose domain trust before repairing it
- Repair domain trust before doing a full unjoin/rejoin cycle

## Roadmap ideas

- Business workstation baseline
- Deep repair mode
- Battery health report
- Deep printer repair helper
- Deep network repair helper
- Outlook profile diagnostics and guided rebuild helper
- Student laptop tune-up variant
- BitLocker readiness and recovery-key workflow
- RDP, WinRM, and OpenSSH diagnostics bundle

## Branding

This repository includes Blue Ridge Systems Consulting branding assets. See [`BRANDING.md`](BRANDING.md) for logo and brand usage guidance.

## Disclaimer

Review scripts before running them on customer or production machines. Test in a virtual machine or non-critical environment when changing behavior. This repository is intended for administrators who understand the effects of the PowerShell commands they run.

## Security

[![Aikido Security Audit Report](https://app.aikido.dev/assets/badges/label-only-light-theme.svg)](https://app.aikido.dev/audit-report/external/WUuAYeTGe5MdKOz7TJTyBMJl/request)

This public repository is regularly scanned by **Aikido Security** for vulnerabilities.
