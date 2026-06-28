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

This script is intentionally separate from the standard maintenance baseline because Windows Update can require reboots, dependency ordering, and multiple passes.

### `scripts/blue-ridge-startup-app-checker.ps1`

A conservative startup app review tool.

It finds common startup items, writes them to a reviewable CSV, opens the CSV in Notepad, lets the admin mark `Y` or `N` in a `Disable` column, then requires a final `DISABLE` confirmation before making changes.

It does not disable Windows services. That is deliberate.

### `scripts/blue-ridge-print-queue-cleaner.ps1`

A safe Windows-side print queue cleanup utility.

It clears stuck print jobs, restarts the Print Spooler, clears the spool folder, and shows printer/queue status before and after cleanup. It is meant to be run before power-cycling printers or doing deeper driver/port repair.

It does not delete printers, drivers, ports, vendor utilities, or change the default printer.

### `scripts/blue-ridge-network-fuzz-buster.ps1`

A safe first-pass Windows network cleanup utility.

It flushes DNS, clears NetBIOS and ARP cache, resets Winsock, resets TCP/IP, offers DHCP release/renew, offers WinHTTP proxy reset, offers Kerberos ticket purge, and offers review-based saved credential cleanup for the current Windows user.

It does not delete adapters, VPN clients, Wi-Fi profiles, user profiles, certificates, passwords, or domain join.

## Standard maintenance baseline: what it does

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

## Standard maintenance baseline: what it does not do

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

## Windows Update enforcer: what it does

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

## Windows Update enforcer: what it does not do

The update enforcer intentionally does not:

- Disable Windows Update services
- Reset Windows Update components
- Delete SoftwareDistribution
- Install third-party modules
- Require PSWindowsUpdate
- Intentionally install driver updates
- Loop forever until every update succeeds
- Keep retrying failures beyond the second attempt
- Force a reboot if no updates installed and no reboot is pending

## Startup App Checker: what it does

The Startup App Checker:

- Finds startup registry entries under common `Run` and `RunOnce` locations
- Finds current-user and all-users Startup folder items
- Finds non-Microsoft scheduled tasks with Logon or Startup triggers
- Exports findings to `C:\ProgramData\BlueRidge\StartupAppChecker\startup-review.csv`
- Opens the CSV in Notepad for manual review
- Lets the admin mark `Y` or `N` in the `Disable` column
- Requires the admin to type `DISABLE` before it changes anything
- Backs up registry startup entries before removing them
- Moves Startup folder items to a Blue Ridge disabled-items folder
- Disables selected scheduled tasks
- Keeps a simple log at `C:\ProgramData\BlueRidge\Logs\startup-app-checker.log`

## Startup App Checker: what it does not do

The Startup App Checker intentionally does not:

- Disable Windows services
- Disable drivers
- Remove applications
- Delete application files
- Disable security products by name
- Disable browser extensions
- Change Store app background permissions
- Guess what should be disabled automatically

It is an audit-and-confirm tool, not an automatic debloater.

## Startup App Checker workflow

1. Run the script from an elevated PowerShell window.
2. The script creates and opens `startup-review.csv` in Notepad.
3. In the `Disable` column, put `Y` beside items to disable.
4. Leave `N` beside items to keep.
5. Save and close Notepad.
6. Return to PowerShell and press Enter.
7. Review the list of items marked for disable.
8. Type `DISABLE` to confirm.
9. The script disables only the selected items.

## Print Queue Cleaner: what it does

The Print Queue Cleaner:

- Shows printer status before cleanup
- Shows any visible print jobs before cleanup
- Attempts to remove print jobs using PowerShell print commands
- Stops the Print Spooler
- Clears `C:\Windows\System32\spool\PRINTERS`
- Starts the Print Spooler again
- Sets the Print Spooler startup type to Automatic
- Attempts to resume paused printers
- Shows printer status after cleanup
- Shows any remaining print jobs after cleanup
- Keeps a simple log at `C:\ProgramData\BlueRidge\Logs\print-queue-cleaner.log`

## Print Queue Cleaner: what it does not do

The Print Queue Cleaner intentionally does not:

- Delete printers
- Delete printer drivers
- Delete printer ports
- Reset TCP/IP printer ports
- Remove vendor printer utilities
- Change the default printer
- Attempt deep driver repair
- Attempt WSD/TCP port surgery

It is a safe first-pass print cleanup tool, not a deep printer rebuild script.

## Network Fuzz Buster: what it does

The Network Fuzz Buster:

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
- Shows a network snapshot after cleanup
- Recommends reboot after Winsock and TCP/IP reset
- Offers a final `REBOOT` prompt
- Keeps a simple log at `C:\ProgramData\BlueRidge\Logs\network-fuzz-buster.log`

## Network Fuzz Buster: credential cleanup notes

Saved credentials are per-user. If the script is run as `Blue-Ridge`, it reviews credentials visible to `Blue-Ridge`. To review the affected user's saved Credential Manager entries, run it from that user's Windows session and elevate from there.

Credential cleanup is review-based:

1. Type `REVIEW` when prompted.
2. The script writes `credential-review.csv`.
3. Put `Y` beside saved credentials to clear.
4. Save and close Notepad.
5. Press Enter in PowerShell.
6. Review selected credentials.
7. Type `CLEARCREDS` to confirm deletion.

Kerberos ticket purge is separate. It clears tickets for the current logon session and does not reset passwords or force logout.

## Network Fuzz Buster: what it does not do

The Network Fuzz Buster intentionally does not:

- Delete network adapters
- Delete VPN clients
- Delete Wi-Fi profiles
- Remove printer ports
- Change passwords
- Reset user passwords
- Force logout
- Remove domain join
- Delete Windows user profiles
- Delete certificates
- Touch DPAPI keys
- Delete cached domain logon secrets

It is a network cleanup and cache reset tool, not identity demolition.

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

## Install/run standard maintenance from local copy

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

## Install/run monthly Windows Update enforcer from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad:

```powershell
notepad "C:\ProgramData\BlueRidge\blue-ridge-windows-update-enforcer-install.ps1"
```

Paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-windows-update-enforcer-install.ps1"
```

## Install/run Startup App Checker from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad:

```powershell
notepad "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
```

Paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
```

## Install/run Print Queue Cleaner from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad:

```powershell
notepad "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
```

Paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
```

## Install/run Network Fuzz Buster from local copy

Create the Blue Ridge folder:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\BlueRidge" | Out-Null
```

Open the target file in Notepad:

```powershell
notepad "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
```

Paste the script contents, save, then run from an elevated PowerShell session:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
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

Then:

```powershell
net user Blue-Ridge *
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

## Scheduled tasks

### Standard maintenance

Task name:

```text
Blue Ridge Twice Weekly Maintenance
```

Schedule:

```text
Tuesday at 2:00 AM
Friday at 2:00 AM
```

Runs:

```text
C:\ProgramData\BlueRidge\br-maintenance.ps1
```

The installer checks whether the task already exists. If it does, the script leaves the existing task alone instead of recreating it every time.

### Monthly Windows Update enforcer

Task name:

```text
Blue Ridge Monthly Windows Update Enforcer
```

Schedule:

```text
3rd Sunday of every month at 2:00 AM
```

Runs:

```text
C:\ProgramData\BlueRidge\br-windows-update-enforcer.ps1
```

The installer checks whether the task already exists. If it does, the script leaves the existing task alone.

Startup App Checker, Print Queue Cleaner, and Network Fuzz Buster are interactive/manual tools and do not create scheduled tasks.

## Logs and review files

Minimal logs and review files are stored here:

```text
C:\ProgramData\BlueRidge\Logs\setup.log
C:\ProgramData\BlueRidge\Logs\maintenance.log
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer-setup.log
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer.log
C:\ProgramData\BlueRidge\Logs\startup-app-checker.log
C:\ProgramData\BlueRidge\Logs\print-queue-cleaner.log
C:\ProgramData\BlueRidge\Logs\network-fuzz-buster.log
C:\ProgramData\BlueRidge\StartupAppChecker\startup-review.csv
C:\ProgramData\BlueRidge\StartupAppChecker\DisabledStartupItems\
C:\ProgramData\BlueRidge\NetworkFuzzBuster\credential-review.csv
C:\ProgramData\BlueRidge\NetworkFuzzBuster\tcpip-reset.log
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

Check the standard maintenance task:

```powershell
Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance'
(Get-ScheduledTask 'Blue Ridge Twice Weekly Maintenance').Triggers
```

Check the monthly Windows Update enforcer task:

```powershell
schtasks /Query /TN "Blue Ridge Monthly Windows Update Enforcer" /V /FO LIST
```

Run the monthly Windows Update enforcer manually:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\br-windows-update-enforcer.ps1"
```

Run Startup App Checker manually:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-startup-app-checker.ps1"
```

Run Print Queue Cleaner manually:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-print-queue-cleaner.ps1"
```

Run Network Fuzz Buster manually:

```powershell
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\BlueRidge\blue-ridge-network-fuzz-buster.ps1"
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
- Separate normal maintenance from forced update/reboot behavior
- Make startup changes reviewable and admin-confirmed
- Keep print repair safe before moving to driver, port, or vendor-tool work
- Keep network repair safe before moving to adapter removal, VPN repair, domain repair, or profile work
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
- Defender offline scan launcher
- Student laptop tune-up variant

## Disclaimer

Review scripts before running them on customer machines. Test in a VM or non-critical machine when changing behavior. This repository is intended for administrators who understand the effects of the commands they run.
