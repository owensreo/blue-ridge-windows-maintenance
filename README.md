# Blue Ridge Windows Maintenance

Practical Windows maintenance scripts for field work, student laptops, home PCs, and small business workstations.

This repository is intended to be a clean, reusable toolbox for Blue Ridge Systems style Windows maintenance: safe first, useful always, and aggressive only when the person running it knows exactly why.

## Current script

### `scripts/blue-ridge-win11-standard-maintenance.ps1`

A Windows 11 standard maintenance baseline designed for student, home, and light business PCs.

It is intentionally not a registry cleaner, debloater, service killer, or app removal script. The goal is to clean and repair Windows without breaking school software, exam tools, business apps, scanners, printers, Etsy or seller tools, VPN clients, weird class software, or anything else that may depend on Windows services behaving normally.

## What it does

The standard maintenance script:

- Creates a local admin account named `Blue-Ridge`
- Adds `Blue-Ridge` to the local Administrators group
- Adds `Blue-Ridge` and the current logged-in user to `Remote Desktop Users`
- Enables Remote Desktop with Network Level Authentication
- Opens firewall access for RDP on TCP `3389`
- Installs OpenSSH Server only if it is not already installed
- Enables and starts the `sshd` service
- Opens firewall access for SSH on TCP `22`
- Sets High Performance power behavior where available
- Adjusts Microsoft Defender to be less performance-heavy without disabling protection
- Cleans Windows temp folders
- Cleans user temp folders
- Cleans Microsoft Edge and Google Chrome cache areas across local profiles
- Preserves browser bookmarks, passwords, history, extensions, preferences, and profiles
- Clears the Recycle Bin
- Runs Disk Cleanup using sageset/sagerun `11`
- Runs DISM component cleanup
- Updates Microsoft Defender signatures
- Runs a Microsoft Defender quick scan
- Runs `DISM /Online /Cleanup-Image /RestoreHealth`
- Runs `sfc /scannow`
- Forces a true defrag on `C:`
- Opens Windows Update settings for manual review
- Opens Microsoft Store updates for manual review
- Creates a scheduled task that runs maintenance Tuesday and Friday at `2:00 AM`
- Keeps minimal logs in `C:\ProgramData\BlueRidge\Logs`

## What it does not do

This script intentionally does not:

- Delete user documents
- Delete the Downloads folder
- Delete Desktop files
- Delete browser bookmarks
- Delete browser passwords
- Delete browser history
- Delete browser extensions
- Delete full browser profiles
- Remove installed applications
- Disable Windows Update
- Disable Microsoft Defender
- Disable arbitrary Windows services
- Change driver packages
- Reset networking
- Reset Windows Update components
- Create a full system inventory report
- Log user activity
- Scrape browser history

That restraint is the point. This is a safe baseline, not a scorched-earth repair pass.

## Recommended field workflow

For a Windows 11 Home machine that needs RDP support:

1. Upgrade Windows 11 Home to Windows 11 Pro.
2. Reboot.
3. Open PowerShell as Administrator.
4. Run the script.
5. Set the `Blue-Ridge` password manually.
6. Reboot again.
7. Run Windows Update manually until fully current.
8. Review Microsoft Store updates.
9. Test SSH and RDP.

## Install/run from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad:

```powershell
notepad "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
```

Paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
```

After the script finishes, set the password manually:

```powershell
net user Blue-Ridge *
```

Optional: hide the maintenance folder after setup:

```powershell
attrib +h "C:\ProgramData\BlueRidge"
```

## Quick download from GitHub

From an elevated PowerShell session:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-win11-standard-maintenance.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
```

Then:

```powershell
net user Blue-Ridge *
```

## Scheduled maintenance

The script creates this scheduled task:

```text
Blue Ridge Twice Weekly Maintenance
```

Schedule:

```text
Tuesday at 2:00 AM
Friday at 2:00 AM
```

The scheduled task runs:

```text
C:\ProgramData\BlueRidge\br-maintenance.ps1
```

The installer checks whether the task already exists. If it does, the script leaves the existing task alone instead of recreating it every time.

## Logs

Minimal logs are stored here:

```text
C:\ProgramData\BlueRidge\Logs\setup.log
C:\ProgramData\BlueRidge\Logs\maintenance.log
```

The logs are intentionally simple. They record maintenance actions and errors. They do not collect a full system inventory or user activity.

## Useful verification commands

Check SSH and RDP services:

```powershell
Get-Service sshd,TermService
```

Check Blue Ridge firewall rules:

```powershell
Get-NetFirewallRule -DisplayName '*Blue Ridge*'
```

Check local groups:

```powershell
Get-LocalGroupMember 'Administrators'
Get-LocalGroupMember 'Remote Desktop Users'
```

Check the scheduled task:

```powershell
Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance'
(Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance').Triggers
```

Test SSH:

```powershell
ssh Blue-Ridge@<laptop-ip>
```

Test RDP:

```powershell
mstsc /v:<laptop-ip>
```

## Design philosophy

This repo favors maintenance that is defensible, boring, and useful:

- Repair Windows before blaming the hardware
- Clean safe cache locations without touching user data
- Preserve school and business software compatibility
- Keep Microsoft Defender enabled
- Keep Windows Update available
- Avoid disabling services unless there is a named problem
- Create repeatable maintenance that other admins can inspect and extend

More aggressive scripts can be added later for power users, lab machines, or deep-repair situations. Those should live as separate scripts so the standard baseline stays safe.

## Roadmap ideas

Possible future scripts:

- Business workstation baseline
- Deep repair mode
- Windows Update reset utility
- Startup app audit report
- Battery health report
- Printer cleanup helper
- Network stack repair helper
- Defender offline scan launcher
- Student laptop tune-up variant

## Disclaimer

Review scripts before running them on customer machines. Test in a VM or non-critical machine when changing behavior. This repository is intended for administrators who understand the effects of the commands they run.
