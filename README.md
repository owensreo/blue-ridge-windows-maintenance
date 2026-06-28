# Blue Ridge Windows Maintenance

Practical Windows maintenance scripts for field work, student laptops, home PCs, and small business workstations.

This repository is intended to be a clean, reusable toolbox for Blue Ridge Systems style Windows maintenance: safe first, useful always, and aggressive only when the person running it knows exactly why.

## Scripts

### `scripts/blue-ridge-win11-standard-maintenance.ps1`

A Windows 11 standard maintenance baseline designed for student, home, and light business PCs.

It is intentionally not a registry cleaner, debloater, service killer, or app removal script. The goal is to clean and repair Windows without breaking school software, exam tools, business apps, scanners, printers, Etsy or seller tools, VPN clients, weird class software, or anything else that may depend on Windows services behaving normally.

### `scripts/blue-ridge-windows-update-enforcer-install.ps1`

A monthly Windows Update enforcement installer.

It writes a local update runner to `C:\ProgramData\BlueRidge\br-windows-update-enforcer.ps1`, creates a scheduled task for the **3rd Sunday of every month at 2:00 AM**, installs pending Windows software updates, retries failed updates one time, ignores anything still failing after the retry, and forces a reboot after updates install or a pending reboot is detected.

### `scripts/blue-ridge-startup-app-checker.ps1`

A conservative startup app review tool.

It finds common startup items, writes them to a reviewable CSV, opens the CSV in Notepad, lets the admin mark `Y` or `N` in a `Disable` column, then requires a final `DISABLE` confirmation before making changes. It does not disable Windows services.

### `scripts/blue-ridge-print-queue-cleaner.ps1`

A safe Windows-side print queue cleanup utility.

It clears stuck print jobs, restarts the Print Spooler, clears the spool folder, and shows printer/queue status before and after cleanup. It is meant to be run before power-cycling printers or doing deeper driver/port repair.

### `scripts/blue-ridge-network-fuzz-buster.ps1`

A safe first-pass Windows network cleanup utility.

It flushes DNS, clears NetBIOS and ARP cache, resets Winsock, resets TCP/IP, offers DHCP release/renew, offers WinHTTP proxy reset, offers Kerberos ticket purge, and offers review-based saved credential cleanup for the current Windows user.

### `scripts/blue-ridge-outlook-teams-soft-reset.ps1`

A safe first-pass Microsoft Outlook, Microsoft Teams, and Office repair helper.

It closes Outlook, Teams, and Office apps, clears classic/new Teams cache, clears safe Outlook cache areas, resets the classic Outlook navigation pane, offers an Excel wake-up launch, offers a Microsoft Office Click-to-Run update, offers Office Quick Repair, offers Outlook safe mode, and offers optional Office identity cache reset.

It does **not** delete PST files, OST files by default, Outlook profiles, mail accounts, calendar entries, contacts, Teams installs, Office installs, or force the user onto new Outlook.

### `scripts/blue-ridge-host-domain-trust-repair.ps1`

A host-side domain secure-channel repair tool.

Run this locally on the affected domain-joined workstation. It tests and repairs the computer trust relationship with the domain using `Test-ComputerSecureChannel -Repair`, prompts for a domain repair username in PowerShell, securely prompts for the password, restarts Netlogon, purges Kerberos tickets, runs `gpupdate /force`, and offers a reboot.

### `scripts/blue-ridge-dc-domain-trust-repair.ps1`

A DC-side domain trust repair orchestrator.

Run this from a domain controller or admin workstation with AD/RSAT tools. It asks for the target computer, verifies the AD computer object when the Active Directory module is available, checks WinRM, then remotely runs the secure-channel repair on the affected workstation. This can avoid walking to the workstation or doing a full domain rejoin when PowerShell Remoting still works.

## Standard maintenance baseline: what it does

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

## Standard maintenance baseline: what it does not do

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

## Windows Update enforcer

The monthly Windows Update enforcer:

- Uses built-in Windows Update COM objects
- Starts/checks Windows Update related services: `wuauserv`, `bits`, `cryptsvc`, and `msiserver`
- Searches for pending Windows software updates
- Does not intentionally pull driver updates
- Accepts update EULAs when required
- Downloads and installs pending software updates
- Retries once if updates fail
- Ignores updates that still fail after the second pass
- Checks common pending-reboot registry locations
- Forces a reboot in 60 seconds if updates installed or a reboot is pending
- Creates a scheduled task named `Blue Ridge Monthly Windows Update Enforcer`
- Schedules that task for the 3rd Sunday of every month at `2:00 AM`
- Runs the scheduled task as `SYSTEM` with highest privileges

It intentionally does not disable Windows Update services, reset Windows Update components, delete SoftwareDistribution, install third-party modules, require PSWindowsUpdate, intentionally install driver updates, loop forever, or force a reboot if nothing installed and no reboot is pending.

## Startup App Checker

Startup App Checker finds common startup items, exports them to `C:\ProgramData\BlueRidge\StartupAppChecker\startup-review.csv`, opens the CSV in Notepad, and lets the admin mark `Y` or `N` in the `Disable` column. It requires `DISABLE` before changing anything.

It checks:

- Common `Run` and `RunOnce` registry locations
- Current-user and all-users Startup folders
- Non-Microsoft scheduled tasks with Logon or Startup triggers

It intentionally does not disable services, drivers, applications, security products by name, browser extensions, or Store app background permissions.

## Print Queue Cleaner

Print Queue Cleaner is a safe first-pass print cleanup tool. It:

- Shows printer status before cleanup
- Shows visible print jobs before cleanup
- Attempts to remove print jobs using PowerShell print commands
- Stops the Print Spooler
- Clears `C:\Windows\System32\spool\PRINTERS`
- Starts the Print Spooler again
- Sets the Print Spooler startup type to Automatic
- Attempts to resume paused printers
- Shows printer status after cleanup
- Shows any remaining print jobs after cleanup
- Logs to `C:\ProgramData\BlueRidge\Logs\print-queue-cleaner.log`

It intentionally does not delete printers, drivers, ports, vendor utilities, or default printer settings.

## Network Fuzz Buster

Network Fuzz Buster is a safe first-pass network cleanup tool. It:

- Shows a network snapshot before cleanup
- Flushes DNS with `Clear-DnsClientCache`
- Flushes DNS with `ipconfig /flushdns`
- Clears NetBIOS name cache with `nbtstat -R`
- Refreshes NetBIOS registrations with `nbtstat -RR`
- Clears ARP cache
- Resets Winsock
- Resets the TCP/IP stack
- Writes a TCP/IP reset log to `C:\ProgramData\BlueRidge\NetworkFuzzBuster\tcpip-reset.log`
- Offers DHCP release/renew
- Offers WinHTTP proxy reset
- Offers Kerberos ticket purge for the current logon session
- Offers review-based saved credential cleanup through a CSV
- Recommends reboot after Winsock and TCP/IP reset

Saved credentials are per-user. If this script is run as `Blue-Ridge`, it reviews credentials visible to `Blue-Ridge`. To review the affected user's saved Credential Manager entries, run it from that user's Windows session and elevate from there.

It intentionally does not delete adapters, VPN clients, Wi-Fi profiles, user profiles, certificates, passwords, cached domain logon secrets, or domain join.

## Outlook Teams Soft Reset

Outlook Teams Soft Reset is a safe first-pass Microsoft 365 desktop app repair helper for classic Outlook, Teams, and Office update weirdness.

It:

- Selects the affected local user profile
- Closes Outlook, Teams, Excel, Word, PowerPoint, OneNote, Publisher, Visio, Access, and related Office helpers
- Clears classic Teams cache when present
- Clears new Teams cache when present
- Clears Outlook RoamCache
- Clears Outlook temporary attachment cache
- Clears Office file cache
- Runs classic Outlook `/resetnavpane` when Outlook is found
- Offers to launch Excel briefly to wake Office update plumbing
- Offers to force Microsoft Office Click-to-Run update with `OfficeC2RClient.exe /update user`
- Offers to open the Office Quick Repair applet
- Offers to launch classic Outlook in safe mode
- Offers optional Office identity cache reset by moving identity/cache folders to backup
- Logs to `C:\ProgramData\BlueRidge\Logs\outlook-teams-soft-reset.log`
- Stores optional moved identity/cache backups under `C:\ProgramData\BlueRidge\OutlookTeamsSoftReset\Backups`

It intentionally does not:

- Delete PST files
- Delete OST files by default
- Delete Outlook profiles
- Remove mail accounts
- Remove calendar entries
- Remove contacts
- Force new Outlook
- Uninstall Teams
- Uninstall Office
- Reset user passwords
- Delete Credential Manager entries by default

The Office identity cache reset is optional because it may sign the user out of Office, Outlook, Teams, OneDrive, or Microsoft 365 apps. Use it when sign-in/token weirdness is the suspected problem.

## Domain Trust Repair tools

### Host-side repair

Use `blue-ridge-host-domain-trust-repair.ps1` when you are at the affected workstation or connected to it through RDP/remote support.

It:

- Confirms the machine is domain joined
- Tests the domain secure channel
- Prompts for a domain repair username directly in PowerShell
- Securely prompts for that account's password
- Runs secure-channel repair from the host
- Restarts Netlogon
- Purges Kerberos tickets for the current session
- Runs `gpupdate /force`
- Offers a reboot

### DC-side repair

Use `blue-ridge-dc-domain-trust-repair.ps1` when you are on a domain controller or admin workstation and want to repair a target workstation remotely.

It:

- Prompts for the target computer name
- Loads the Active Directory module when available
- Verifies the AD computer object when possible
- Checks basic reachability
- Checks WinRM/PowerShell Remoting
- Prompts for a domain repair username directly in PowerShell
- Securely prompts for that account's password
- Remotely runs the secure-channel repair on the target workstation
- Restarts Netlogon on the target workstation
- Purges Kerberos tickets on the target workstation
- Runs `gpupdate /force` on the target workstation
- Offers to reboot the target workstation

The DC-side version requires WinRM/PowerShell Remoting to work. If the trust is too broken for remote access, use the host-side version locally on the affected PC.

### Domain Trust Repair: what these scripts do not do

- Do not unjoin the domain
- Do not rejoin the domain
- Do not blindly reset the AD computer account
- Do not reset user passwords
- Do not force user logout
- Do not delete user profiles
- Do not delete cached domain logon data
- Do not delete Credential Manager entries
- Do not change local administrator passwords

They repair the machine secure channel. They are not identity demolition tools.

## Recommended field workflow

For a Windows 11 Home machine that needs RDP support:

1. Upgrade Windows 11 Home to Windows 11 Pro.
2. Reboot.
3. Open PowerShell as Administrator.
4. Run the standard maintenance script.
5. Set the `Blue-Ridge` password manually.
6. Reboot again.
7. Run Windows Update manually until fully current.
8. Review Microsoft Store updates.
9. Test SSH and RDP.
10. Install the monthly Windows Update enforcer if the machine should continue receiving forced monthly update/reboot maintenance.
11. Run Startup App Checker if startup items need manual review.
12. Run Print Queue Cleaner when print jobs are stuck before power-cycling printers.
13. Run Network Fuzz Buster when DNS, DHCP, proxy, TCP/IP, Winsock, or saved credential weirdness is suspected.
14. Run Outlook Teams Soft Reset when Outlook, Teams, or Office desktop apps will not open, loop, hang, or need an update/quick repair nudge.
15. Use the host-side or DC-side Domain Trust Repair scripts when a domain-joined machine appears to have lost its trust relationship.

## Install/run from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad, paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\<script-name>.ps1"
```

For the standard maintenance script, set the password manually after it finishes:

```powershell
net user Blue-Ridge *
```

Optional: hide the maintenance folder after setup:

```powershell
attrib +h "C:\ProgramData\BlueRidge"
```

## Quick download from GitHub

The repository may be private. These raw URLs work when authenticated or when the repository is public.

### Standard maintenance baseline

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-win11-standard-maintenance.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-win11-tuneup.ps1"
```

### Monthly Windows Update enforcer

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-windows-update-enforcer-install.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-windows-update-enforcer-install.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-windows-update-enforcer-install.ps1"
```

### Startup App Checker

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-startup-app-checker.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
```

### Print Queue Cleaner

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-print-queue-cleaner.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
```

### Network Fuzz Buster

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-network-fuzz-buster.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
```

### Outlook Teams Soft Reset

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-outlook-teams-soft-reset.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-outlook-teams-soft-reset.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-outlook-teams-soft-reset.ps1"
```

### Host Domain Trust Repair

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-host-domain-trust-repair.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-host-domain-trust-repair.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-host-domain-trust-repair.ps1"
```

### DC Domain Trust Repair

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/owensreo/blue-ridge-windows-maintenance/main/scripts/blue-ridge-dc-domain-trust-repair.ps1" `
  -OutFile "C:\ProgramData\BlueRidge\blue-ridge-dc-domain-trust-repair.ps1"
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-dc-domain-trust-repair.ps1"
```

## Scheduled tasks

### Standard maintenance

```text
Blue Ridge Twice Weekly Maintenance
Tuesday at 2:00 AM
Friday at 2:00 AM
Runs: C:\ProgramData\BlueRidge\br-maintenance.ps1
```

### Monthly Windows Update enforcer

```text
Blue Ridge Monthly Windows Update Enforcer
3rd Sunday of every month at 2:00 AM
Runs: C:\ProgramData\BlueRidge\br-windows-update-enforcer.ps1
```

Startup App Checker, Print Queue Cleaner, Network Fuzz Buster, Outlook Teams Soft Reset, and the Domain Trust Repair scripts are interactive/manual tools and do not create scheduled tasks.

## Logs and review files

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

The logs are intentionally simple. They record maintenance actions and errors. They do not collect a full system inventory or user activity.

## Useful verification commands

```powershell
Get-Service sshd,TermService
Get-NetFirewallRule -DisplayName '*Blue Ridge*'
Get-LocalGroupMember 'Administrators'
Get-LocalGroupMember 'Remote Desktop Users'
Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance'
schtasks /Query /TN "Blue Ridge Monthly Windows Update Enforcer" /V /FO LIST
```

Run tools manually:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-outlook-teams-soft-reset.ps1"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-host-domain-trust-repair.ps1"
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-dc-domain-trust-repair.ps1"
```

Test SSH/RDP:

```powershell
ssh Blue-Ridge@<laptop-ip>
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
- Separate normal maintenance from forced update/reboot behavior
- Make startup changes reviewable and admin-confirmed
- Keep print repair safe before moving to driver, port, or vendor-tool work
- Keep network repair safe before moving to adapter removal, VPN repair, domain repair, or profile work
- Fix Microsoft 365 desktop weirdness without destroying Outlook data or forcing new Outlook
- Repair domain trust without immediately doing the full unjoin/rejoin dance
- Create repeatable maintenance that other admins can inspect and extend

More aggressive scripts can be added later for power users, lab machines, or deep-repair situations. Those should live as separate scripts so the standard baseline stays safe.

## Roadmap ideas

Possible future scripts:

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

Review scripts before running them on customer machines. Test in a VM or non-critical machine when changing behavior. This repository is intended for administrators who understand the effects of the commands they run.
