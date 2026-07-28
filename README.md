<p align="center">
  <img src="assets/blue-ridge-systems-consulting-logo.svg" alt="Blue Ridge Systems Consulting Logo" width="160" />
</p>

# Blue Ridge Windows Maintenance

A practical Windows administration toolkit from **Blue Ridge Systems** for field support, small-business workstations, student laptops, Windows Server, Microsoft 365, domain environments, and repeatable repair work.

The guiding rule is simple:

> Diagnose first. Repair second. Verify the result. Preserve the user's data.

These scripts favor conservative, inspectable PowerShell workflows instead of destructive resets, random service disabling, registry-cleaner folklore, profile deletion, app removal, or immediate domain rejoin work.

## Repository layout

```text
scripts/
├── baseline/       Business workstation preparation
├── diagnostics/    Read-only workstation and service diagnostics
├── domain/         Domain trust, DNS, Group Policy, and AD-facing tools
├── repair/         Focused state-changing repair workflows
├── restore/        Rollback helpers
├── security/       Defender, BitLocker, admin, and certificate checks
├── server/         Windows Server and installed-role health checks
└── core scripts    Existing maintenance and first-pass repair tools
```

## Requirements

- Windows PowerShell 5.1 or newer
- Windows 10, Windows 11, or Windows Server as appropriate
- Administrator rights for scripts that inspect protected state or make changes
- Domain tools require a domain environment
- Server role commands require the relevant Windows Server modules and installed roles
- Review every script before using it on customer or production systems

## Core workstation tools

| Script | Purpose |
|---|---|
| `scripts/blue-ridge-win11-standard-maintenance.ps1` | Windows 11 baseline maintenance, safe cleanup, DISM/SFC, Defender, remote access, and scheduled maintenance |
| `scripts/blue-ridge-windows-update-enforcer-install.ps1` | Monthly update enforcement using built-in Windows Update components |
| `scripts/blue-ridge-startup-app-checker.ps1` | Review-first startup audit and disable workflow |
| `scripts/blue-ridge-print-queue-cleaner.ps1` | Safe print queue and spool-folder cleanup |
| `scripts/blue-ridge-network-fuzz-buster.ps1` | Conservative DNS, NetBIOS, ARP, Winsock, TCP/IP, proxy, Kerberos, and credential cleanup |
| `scripts/blue-ridge-outlook-teams-soft-reset.ps1` | Safe first-pass Outlook, Teams, and Microsoft 365 desktop repair |
| `scripts/blue-ridge-host-domain-trust-repair.ps1` | Host-side secure-channel repair |
| `scripts/blue-ridge-dc-domain-trust-repair.ps1` | DC/admin-side trust repair over PowerShell Remoting |

## Diagnostics

| Script | Purpose |
|---|---|
| `scripts/diagnostics/blue-ridge-windows-health-report.ps1` | Full read-only workstation health bundle |
| `scripts/diagnostics/blue-ridge-pending-reboot-check.ps1` | Pending-reboot detection with JSON and RMM exit-code support |
| `scripts/diagnostics/blue-ridge-battery-health-report.ps1` | Battery capacity, health percentage, cycle count, power plan, and sleep-state report |
| `scripts/diagnostics/blue-ridge-office-profile-diagnostics.ps1` | Outlook profiles, PST/OST inventory, Office channel/build, Teams/Office cache state, and recent events |
| `scripts/diagnostics/blue-ridge-rdp-openssh-diagnostics.ps1` | RDP, OpenSSH, WinRM-related services, listeners, firewall, NLA, config, and events |
| `scripts/diagnostics/blue-ridge-event-log-triage.ps1` | Recent System/Application warnings and errors grouped into useful patterns |
| `scripts/diagnostics/blue-ridge-disk-space-investigator.ps1` | Volume status, largest files, and optional user-profile size analysis |
| `scripts/diagnostics/blue-ridge-user-profile-health-check.ps1` | Local profile path, load state, size, NTUSER.DAT, and temporary-profile indicators |
| `scripts/diagnostics/blue-ridge-windows-activation-check.ps1` | Windows licensing state, channel, partial key, grace state, and expiration output |
| `scripts/diagnostics/blue-ridge-smb-share-diagnostics.ps1` | SMB shares, sessions, open files, services, configuration, and optional TCP 445 test |
| `scripts/diagnostics/blue-ridge-dns-client-diagnostics.ps1` | DNS servers, client state, cache, lookups, domain SRV records, DC discovery, and DNS events |

## Domain tools

| Script | Purpose |
|---|---|
| `scripts/domain/blue-ridge-domain-trust-diagnostics.ps1` | Domain join, secure channel, DNS, DC, time, Kerberos, Group Policy, SYSVOL, and NETLOGON diagnostics |
| `scripts/domain/blue-ridge-gpo-troubleshooting-bundle.ps1` | `gpresult`, policy events, DC discovery, secure channel, time, DNS, and optional `gpupdate` bundle |

## Repair tools

| Script | Purpose |
|---|---|
| `scripts/repair/blue-ridge-windows-update-reset.ps1` | Conservative Windows Update reset with service-state capture and renamed cache folders |
| `scripts/repair/blue-ridge-deep-printer-repair.ps1` | Printer/driver/port inventory, queue cleanup, spooler restart, and TCP printer-port testing |
| `scripts/repair/blue-ridge-deep-network-repair.ps1` | Before-state capture plus optional Winsock, TCP/IP, adapter, DHCP, and WinHTTP repair |
| `scripts/repair/blue-ridge-time-sync-repair.ps1` | Capture and repair Windows Time configuration using domain hierarchy or a named peer |

## Restore tools

| Script | Purpose |
|---|---|
| `scripts/restore/blue-ridge-startup-app-restore.ps1` | Restores backed-up Run entries, moved Startup-folder items, and disabled startup tasks |

## Security tools

| Script | Purpose |
|---|---|
| `scripts/security/blue-ridge-defender-health-check.ps1` | Defender protection, signatures, scans, exclusions, services, and optional repair actions |
| `scripts/security/blue-ridge-local-admin-audit.ps1` | Local Administrators membership and local-account state report |
| `scripts/security/blue-ridge-bitlocker-readiness-check.ps1` | TPM, Secure Boot, volume, protector, and BitLocker readiness report |
| `scripts/security/blue-ridge-certificate-expiration-report.ps1` | Local computer/current-user certificate expiration and private-key report |

## Baseline and server tools

| Script | Purpose |
|---|---|
| `scripts/baseline/blue-ridge-business-workstation-baseline.ps1` | Conservative SMB workstation baseline with before-state capture and optional RDP/OpenSSH/power setup |
| `scripts/server/blue-ridge-server-role-health-report.ps1` | Server roles/features, services, storage, SMB, firewall, time, event logs, and role-aware AD/DNS/DHCP checks |

## Common usage

Run from an elevated Windows PowerShell session when required:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\diagnostics\blue-ridge-windows-health-report.ps1
```

Use `-WhatIf` on supported state-changing scripts before committing changes:

```powershell
.\scripts\repair\blue-ridge-windows-update-reset.ps1 -WhatIf
.\scripts\repair\blue-ridge-deep-network-repair.ps1 -ResetWinsock -ResetTcpIp -WhatIf
```

## Recommended support flow

1. Confirm the actual user impact.
2. Run the full health report or the focused diagnostic.
3. Review the generated report and logs.
4. Run the least invasive repair that matches the evidence.
5. Re-run the diagnostic or otherwise verify the result.
6. Restore a reversible change when needed.
7. Reboot only when recommended.
8. Escalate to destructive work only after the conservative path is exhausted.

## Selected workflows

### Printer trouble

```powershell
.\scripts\blue-ridge-print-queue-cleaner.ps1
.\scripts\repair\blue-ridge-deep-printer-repair.ps1 -TestPorts -ExportDrivers
```

The deep helper does not automatically delete printers, ports, or drivers.

### Network trouble

```powershell
.\scripts\blue-ridge-network-fuzz-buster.ps1
.\scripts\diagnostics\blue-ridge-dns-client-diagnostics.ps1
.\scripts\repair\blue-ridge-deep-network-repair.ps1 -ResetWinsock -ResetTcpIp -WhatIf
```

The repair helper preserves VPN clients, Wi-Fi profiles, certificates, and domain membership.

### Domain/GPO trouble

```powershell
.\scripts\domain\blue-ridge-domain-trust-diagnostics.ps1
.\scripts\domain\blue-ridge-gpo-troubleshooting-bundle.ps1
```

Use the trust repair scripts only after DNS, DC discovery, and time synchronization are healthy.

### Remote access trouble

```powershell
.\scripts\diagnostics\blue-ridge-rdp-openssh-diagnostics.ps1
```

This collects state without enabling services or opening firewall ports.

### Security review

```powershell
.\scripts\security\blue-ridge-defender-health-check.ps1
.\scripts\security\blue-ridge-local-admin-audit.ps1
.\scripts\security\blue-ridge-bitlocker-readiness-check.ps1
.\scripts\security\blue-ridge-certificate-expiration-report.ps1 -WarnDays 90
```

### Windows Server intake

```powershell
.\scripts\server\blue-ridge-server-role-health-report.ps1
```

On a domain controller, the report also runs `dcdiag` and `repadmin`. DNS and DHCP sections are included only when those services are installed.

## Output locations

Scripts write logs and reports under `C:\ProgramData\BlueRidge`.

```text
C:\ProgramData\BlueRidge\Logs\
C:\ProgramData\BlueRidge\HealthReports\
C:\ProgramData\BlueRidge\BatteryReports\
C:\ProgramData\BlueRidge\OfficeDiagnostics\
C:\ProgramData\BlueRidge\RemoteAccessReports\
C:\ProgramData\BlueRidge\EventTriage\
C:\ProgramData\BlueRidge\DiskReports\
C:\ProgramData\BlueRidge\ProfileReports\
C:\ProgramData\BlueRidge\ActivationReports\
C:\ProgramData\BlueRidge\SMBReports\
C:\ProgramData\BlueRidge\DNSReports\
C:\ProgramData\BlueRidge\SecurityReports\
C:\ProgramData\BlueRidge\ServerReports\
C:\ProgramData\BlueRidge\WindowsUpdateReset\
C:\ProgramData\BlueRidge\StartupAppChecker\
```

Logs record administrative actions, errors, and technical state. These tools are not intended to collect browser history, personal documents, message content, or surveillance-style user activity.

## Safety principles

- Diagnose first and repair second
- Keep Microsoft Defender enabled
- Keep Windows Update available
- Preserve user profiles, PST/OST files, browser data, and business applications
- Avoid deleting printers, ports, drivers, adapters, VPN clients, certificates, or domain membership automatically
- Make startup changes reviewable and reversible
- Capture state before deeper repair
- Use `-WhatIf` where supported
- Keep workstation tuning separate from forced update/reboot behavior
- Test state-changing scripts in a VM or non-critical environment first

## Roadmap

The toolbox now covers the previously listed diagnostic, repair, baseline, security, domain, and server ideas. Future work can focus on guided workflows rather than more one-off scripts, including:

- Outlook profile rebuild assistant with explicit PST/OST safeguards
- Student-laptop baseline variant
- BitLocker enablement and recovery-key escrow workflow
- Printer reinstall assistant driven by the deep-printer report
- Unified interactive launcher for the complete toolbox
- Pester tests and ScriptAnalyzer checks for supported scripts

## Branding

This repository includes Blue Ridge Systems Consulting branding assets. See [`BRANDING.md`](BRANDING.md) for logo and brand usage guidance.

## Disclaimer

Review scripts before running them on customer or production machines. Test state-changing behavior in a virtual machine or non-critical environment first. This repository is intended for administrators who understand the effects of the PowerShell commands they run.

## Security

[![Aikido Security Audit Report](https://app.aikido.dev/assets/badges/label-only-light-theme.svg)](https://app.aikido.dev/audit-report/external/WUuAYeTGe5MdKOz7TJTyBMJl/request)

This public repository is regularly scanned by **Aikido Security** for vulnerabilities.
