# Blue Ridge Windows Maintenance

[![Aikido Security Audit Report](https://app.aikido.dev/assets/badges/label-only-light-theme.svg)](https://app.aikido.dev/audit-report/external/WUuAYeTGe5MdKOz7TJTyBMJl/request)

A practical Windows administration toolkit from **Blue Ridge Systems** for field support, small business workstations, student laptops, and general Windows maintenance work.

This repository focuses on safe, inspectable PowerShell scripts that help resolve common Windows support issues without immediately jumping to destructive repairs, profile rebuilds, app removals, or full system resets.

## Purpose

The scripts in this repository are designed for administrators who need repeatable first-pass repair tools for common Windows problems. The emphasis is on conservative maintenance, clear prompts, local logging, and preserving user data.

## Goals

- Provide PowerShell scripts that can be reviewed before use
- Favor safe first-pass repair steps before deeper remediation
- Preserve user files, browser data, Outlook data, Windows profiles, and business or school applications
- Keep Windows Update, Microsoft Defender, and core Windows services enabled
- Avoid unnecessary app removal, service disabling, profile deletion, or domain rejoin work
- Keep logs simple and local under `C:\ProgramData\BlueRidge\Logs`

## Script catalog

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

## Requirements

- Windows 10 or Windows 11 for most workstation scripts
- Windows PowerShell 5.1 or newer
- Administrator rights
- Domain scripts require a domain-joined environment
- DC-side domain trust repair requires WinRM/PowerShell Remoting to the target workstation
- Microsoft 365/Office update functions require Click-to-Run Office when using `OfficeC2RClient.exe`

## Usage

Review each script before running it. These tools are intended for administrators who understand the effects of the commands they execute.

Recommended approach:

1. Clone or download this repository.
2. Review the script you plan to use.
3. Copy the script to the target machine when appropriate.
4. Run from an elevated PowerShell session.
5. Review the terminal output and the log file under `C:\ProgramData\BlueRidge\Logs`.
6. Reboot when a script recommends it.

For practical field notes, see [`RUNBOOK.md`](RUNBOOK.md).

## Script details

### Windows 11 Standard Maintenance

`blue-ridge-win11-standard-maintenance.ps1` is a general baseline script for Windows 11 support work.

It can:

- Prepare a local support account named `Blue-Ridge`
- Configure support access for RDP and OpenSSH where appropriate
- Apply conservative power and Defender performance settings
- Clean Windows temp, user temp, browser cache, and Recycle Bin
- Preserve browser profiles, passwords, history, bookmarks, and extensions
- Run Disk Cleanup, DISM component cleanup, Defender signature update, Defender quick scan, DISM RestoreHealth, and SFC
- Create a scheduled task for twice-weekly maintenance

It intentionally does not remove applications, disable Windows Update, disable Defender, delete user files, reset networking, scrape browsing history, or create a full user activity report.

### Monthly Windows Update Enforcer

`blue-ridge-windows-update-enforcer-install.ps1` installs a monthly update task.

It uses built-in Windows Update components, starts required update services, searches for pending software updates, installs updates, retries once after failures, checks common pending-reboot locations, and reboots only when updates installed or a reboot is already pending.

It intentionally does not reset Windows Update components, delete `SoftwareDistribution`, require third-party modules, intentionally install driver updates, or retry forever.

### Startup App Checker

`blue-ridge-startup-app-checker.ps1` provides a review-first startup item workflow.

It finds common Run/RunOnce registry entries, Startup folder items, and non-Microsoft scheduled tasks with Logon or Startup triggers. It exports findings to a CSV, opens the CSV in Notepad, and only disables items that the admin marks after a final confirmation.

It intentionally does not disable services, drivers, applications, security products by name, browser extensions, or Store app background permissions.

### Print Queue Cleaner

`blue-ridge-print-queue-cleaner.ps1` is a safe first-pass print repair tool.

It shows printer state, removes visible print jobs, stops the Print Spooler, clears the spool folder, restarts the spooler, sets the spooler to Automatic, and attempts to resume paused printers.

It intentionally does not delete printers, drivers, ports, vendor printer utilities, or default printer settings.

### Network Fuzz Buster

`blue-ridge-network-fuzz-buster.ps1` is a conservative network cleanup tool.

It can flush DNS, clear NetBIOS cache, refresh NetBIOS registrations, clear ARP cache, reset Winsock, reset TCP/IP, offer DHCP release/renew, offer WinHTTP proxy reset, offer Kerberos ticket purge, and offer review-based saved credential cleanup.

It intentionally does not delete network adapters, VPN clients, Wi-Fi profiles, user profiles, certificates, passwords, cached domain logon secrets, or domain join.

Saved credentials are per-user. To review a specific user's saved Credential Manager entries, run the script from that user's Windows session and elevate from there.

### Outlook Teams Soft Reset

`blue-ridge-outlook-teams-soft-reset.ps1` is a safe first-pass Microsoft 365 desktop repair helper for classic Outlook, Teams, and Office update issues.

It can close Outlook, Teams, and Office applications, clear classic and new Teams cache, clear Outlook RoamCache, clear Outlook temporary attachment cache, clear Office file cache, run classic Outlook `/resetnavpane`, offer an Excel launch to wake Office update components, offer `OfficeC2RClient.exe /update user`, open the Office Quick Repair applet, launch Outlook safe mode, and optionally move Office identity cache folders to backup.

It intentionally does not delete PST files, delete OST files by default, delete Outlook profiles, remove mail accounts, remove calendar entries, remove contacts, force new Outlook, uninstall Teams, uninstall Office, reset user passwords, or delete Credential Manager entries by default.

The Office identity cache reset is optional because it may sign the user out of Office, Outlook, Teams, OneDrive, or Microsoft 365 applications.

### Domain Trust Repair

This repository includes two secure-channel repair workflows.

#### Host-side repair

`blue-ridge-host-domain-trust-repair.ps1` runs locally on the affected domain-joined workstation.

It confirms the machine is domain joined, tests the secure channel, prompts for a domain repair username, securely prompts for the password, runs secure-channel repair, restarts Netlogon, purges Kerberos tickets, runs Group Policy update, and offers a reboot.

#### DC-side repair

`blue-ridge-dc-domain-trust-repair.ps1` runs from a domain controller or admin workstation.

It prompts for the target computer, loads the Active Directory module when available, verifies the AD computer object when possible, checks reachability, checks WinRM/PowerShell Remoting, then remotely runs the secure-channel repair on the target workstation.

The DC-side version requires WinRM/PowerShell Remoting. If the trust is too broken for remote access, use the host-side version locally on the affected PC.

The domain trust scripts intentionally do not unjoin the domain, rejoin the domain, blindly reset the AD computer account, reset user passwords, force logout, delete user profiles, delete cached domain logon data, delete Credential Manager entries, or change local administrator passwords.

## Scheduled tasks

The standard maintenance script creates a twice-weekly maintenance task.

The monthly update enforcer creates a monthly Windows Update task.

All other scripts are interactive/manual tools and do not create scheduled tasks.

## Logs and local files

Common log and review paths:

```text
C:\ProgramData\BlueRidge\Logs\setup.log
C:\ProgramData\BlueRidge\Logs\maintenance.log
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer-setup.log
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer.log
C:\ProgramData\BlueRidge\Logs\startup-app-checker.log
C:\ProgramData\BlueRidge\Logs\print-queue-cleaner.log
C:\ProgramData\BlueRidge\Logs\network-fuzz-buster.log
C:\ProgramData\BlueRidge\Logs\outlook-teams-soft-reset.log
C:\ProgramData\BlueRidge\Logs\host-domain-trust-repair.log
C:\ProgramData\BlueRidge\Logs\dc-domain-trust-repair.log
C:\ProgramData\BlueRidge\StartupAppChecker\startup-review.csv
C:\ProgramData\BlueRidge\StartupAppChecker\DisabledStartupItems\
C:\ProgramData\BlueRidge\NetworkFuzzBuster\credential-review.csv
C:\ProgramData\BlueRidge\NetworkFuzzBuster\tcpip-reset.log
C:\ProgramData\BlueRidge\OutlookTeamsSoftReset\Backups\
```

Logs are intentionally simple. They record script actions and errors. They are not intended to collect user activity, browser history, personal files, or full system inventory data.

## Recommended support workflow

For a typical Windows workstation support visit:

1. Review the device state and confirm user impact.
2. Run the least invasive script that matches the issue.
3. Confirm what the script will and will not change.
4. Run from an elevated PowerShell session.
5. Review the script output and local log.
6. Reboot when the script recommends it.
7. Escalate to deeper repair only when the safe first-pass workflow does not resolve the issue.

## Safety principles

This repository favors maintenance that is clear, conservative, and practical:

- Repair Windows before blaming hardware
- Clean safe cache locations without touching user data
- Preserve school and business software compatibility
- Keep Microsoft Defender enabled
- Keep Windows Update available
- Avoid disabling services unless there is a named problem
- Separate normal maintenance from forced update/reboot behavior
- Make startup changes reviewable and admin-confirmed
- Keep printer repair safe before moving to driver, port, or vendor-tool work
- Keep network repair safe before moving to adapter removal, VPN repair, domain repair, or profile work
- Fix Microsoft 365 desktop issues without destroying Outlook data or forcing new Outlook
- Repair domain trust before doing a full unjoin/rejoin cycle

## Roadmap ideas

Possible future additions:

- Business workstation baseline
- Deep repair mode
- Windows Update reset utility
- Startup app restore helper
- Battery health report
- Deep printer repair helper
- Deep network repair helper
- Domain trust diagnostics helper
- Outlook profile rebuild helper
- Defender offline scan launcher
- Student laptop tune-up variant

## Disclaimer

Review scripts before running them on customer or production machines. Test in a virtual machine or non-critical environment when changing behavior. This repository is intended for administrators who understand the effects of the PowerShell commands they run.

## Security

This public repository is regularly scanned by **Aikido Security** for vulnerabilities.
