# Blue Ridge Windows Maintenance Runbook

Practical field notes for running the Blue Ridge Windows Maintenance scripts after reviewing them.

The README is the public overview. This runbook is the practical admin guide: how to choose the right script, what to check before running it, what to expect while it runs, and where to look afterward.

## Core rule

Use the least invasive tool that matches the issue.

The scripts in this repo are meant to fix common Windows problems without jumping straight to profile rebuilds, Office reinstalls, printer driver removal, network adapter removal, domain rejoin, or full Windows reset.

## Standard field workflow

1. Confirm the user's actual problem.
2. Pick the script that most closely matches the problem.
3. Review the script before running it.
4. Open an elevated Windows terminal.
5. Run the reviewed script from a local repository copy or from a reviewed copy under `C:\ProgramData\BlueRidge`.
6. Read the script prompts before confirming anything.
7. Let the script finish.
8. Review the terminal output.
9. Review the matching log under `C:\ProgramData\BlueRidge\Logs`.
10. Reboot when the script recommends it.
11. Re-test the original issue.
12. Escalate only if the first-pass repair did not resolve the issue.

## Standard local paths

Most scripts use this local working folder:

```text
C:\ProgramData\BlueRidge
```

Most logs are stored here:

```text
C:\ProgramData\BlueRidge\Logs
```

Some scripts also create review or backup folders under `C:\ProgramData\BlueRidge`.

## Running scripts locally

Preferred pattern:

1. Clone or download the repository.
2. Review the script in the `scripts` folder.
3. Run the reviewed script from the local repository copy.

Alternate field pattern:

1. Copy the reviewed script to `C:\ProgramData\BlueRidge`.
2. Run that local copy from an elevated Windows terminal.
3. Keep the log with the machine for later review.

Use the script-running and execution policy standards approved for the environment you are supporting. Do not run unreviewed scripts directly from the internet.

## PowerShell-friendly local run parameters

When a reviewed script has been copied to `C:\ProgramData\BlueRidge`, this is the standard field run pattern:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
& "C:\ProgramData\BlueRidge\<script-name>.ps1"
```

Notes:

- `-Scope Process` keeps the execution policy change limited to the current PowerShell session.
- `-Force` keeps the command from stopping for an execution policy confirmation prompt.
- Replace `<script-name>` with the actual script file name.
- Run from an elevated PowerShell session.
- Review the script before running it.

## Script index

```text
blue-ridge-win11-standard-maintenance.ps1
blue-ridge-windows-update-enforcer-install.ps1
blue-ridge-startup-app-checker.ps1
blue-ridge-print-queue-cleaner.ps1
blue-ridge-network-fuzz-buster.ps1
blue-ridge-outlook-teams-soft-reset.ps1
blue-ridge-host-domain-trust-repair.ps1
blue-ridge-dc-domain-trust-repair.ps1
```

## Choosing the right script

| Problem | Start here |
|---|---|
| General Windows tune-up, temp cleanup, DISM/SFC, Defender update | Windows 11 Standard Maintenance |
| Need a predictable monthly Windows Update pass | Monthly Windows Update Enforcer |
| Too many startup apps or slow login | Startup App Checker |
| Stuck print jobs or jammed spooler | Print Queue Cleaner |
| DNS, proxy, network cache, Winsock, TCP/IP, or saved credential weirdness | Network Fuzz Buster |
| Outlook, Teams, or Office desktop apps will not open or need an Office update nudge | Outlook Teams Soft Reset |
| Workstation appears to have lost domain trust and you are on that workstation | Host Domain Trust Repair |
| Workstation appears to have lost domain trust and you are on a DC/admin workstation with remote access | DC Domain Trust Repair |

## Windows 11 Standard Maintenance

Script:

```text
scripts\blue-ridge-win11-standard-maintenance.ps1
```

Use when:

- A Windows 11 machine needs a conservative tune-up.
- Remote support access needs to be prepared.
- Windows needs temp cleanup, Defender update, DISM, and SFC checks.
- A student, home, or small business PC needs a safe first-pass maintenance baseline.

Before running:

- Confirm the machine is Windows 11.
- Confirm the user is okay with maintenance, cleanup, and possible reboot.
- Confirm whether RDP or SSH support access is desired.
- Close unnecessary user applications.

During the run:

- Watch for prompts related to account setup, scheduled task setup, or reboot.
- Let long-running repair steps finish.
- Do not interrupt DISM or SFC unless the machine is clearly frozen.

After running:

- Set the `Blue-Ridge` account password manually if the script created or prepared that account.
- Confirm RDP or SSH only if those features were intended.
- Review the logs.
- Reboot if recommended.
- Re-test the original issue.

Logs:

```text
C:\ProgramData\BlueRidge\Logs\setup.log
C:\ProgramData\BlueRidge\Logs\maintenance.log
```

## Monthly Windows Update Enforcer

Script:

```text
scripts\blue-ridge-windows-update-enforcer-install.ps1
```

Use when:

- A machine should receive a predictable monthly update pass.
- You want Windows Update handled by built-in Windows components.
- A user or small business machine needs regular maintenance without daily nagging.

Before running:

- Confirm the machine can reboot during the configured maintenance window.
- Confirm the user understands updates may require restart.
- Confirm this is appropriate for the device's role.

During the run:

- The installer creates the local update runner and scheduled task.
- The update runner handles pending software updates and reboot logic.

After running:

- Confirm the scheduled task exists.
- Review setup log.
- Confirm the configured maintenance window is acceptable.

Logs:

```text
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer-setup.log
C:\ProgramData\BlueRidge\Logs\windows-update-enforcer.log
```

## Startup App Checker

Script:

```text
scripts\blue-ridge-startup-app-checker.ps1
```

Use when:

- The machine is slow after login.
- Too many applications launch at startup.
- The user complains about popups or background apps.
- You want a review-based startup cleanup instead of an automatic debloater.

Before running:

- Ask the user what applications must keep starting automatically.
- Avoid disabling security, backup, VPN, printer, scanner, or business-critical tools unless you are sure.
- Remember that this is a review tool, not a blind cleanup tool.

During the run:

- The script creates a CSV for review.
- Mark only items you actually want disabled.
- Save and close the CSV before returning to the terminal.
- The script requires a final confirmation before disabling selected items.

After running:

- Reboot or sign out/sign in to test login behavior.
- Confirm required apps still launch.
- Review the disabled items folder if something needs to be restored manually.

Files:

```text
C:\ProgramData\BlueRidge\StartupAppChecker\startup-review.csv
C:\ProgramData\BlueRidge\StartupAppChecker\DisabledStartupItems\
C:\ProgramData\BlueRidge\Logs\startup-app-checker.log
```

## Print Queue Cleaner

Script:

```text
scripts\blue-ridge-print-queue-cleaner.ps1
```

Use when:

- Print jobs are stuck.
- A printer queue will not clear.
- The print spooler needs a safe reset.
- You want a first-pass print fix before touching drivers or printer ports.

Before running:

- Ask whether any print jobs are important and should be recreated later.
- Confirm the user understands stuck jobs may be cleared.
- Avoid changing drivers, ports, or printer defaults unless this first pass fails.

During the run:

- The script shows printer and queue state before cleanup.
- It clears stuck jobs and restarts the spooler.
- It shows printer and queue state afterward.

After running:

- Print a test page or test from the affected app.
- If printing still fails, move to driver, port, network printer, or vendor utility troubleshooting.

Log:

```text
C:\ProgramData\BlueRidge\Logs\print-queue-cleaner.log
```

## Network Fuzz Buster

Script:

```text
scripts\blue-ridge-network-fuzz-buster.ps1
```

Use when:

- DNS resolution is unreliable.
- Network paths feel stale.
- DHCP or proxy state is suspicious.
- Windows networking behaves strangely after VPN or Wi-Fi changes.
- Saved credentials may be contributing to access problems.
- A safe network cleanup is preferred before deeper adapter or VPN repair.

Before running:

- Ask what network resources are failing.
- Check whether the user is on VPN, Wi-Fi, Ethernet, or a captive portal.
- Confirm whether the affected user is the one currently signed in.
- Remember that saved credentials are per-user.

During the run:

- The script shows a network snapshot before cleanup.
- It offers several optional cleanup steps.
- Credential cleanup is review-based and should be handled carefully.

After running:

- Reboot if Winsock or TCP/IP reset was performed.
- Re-test DNS, mapped drives, websites, VPN, printers, or application access.
- If the issue remains, move to adapter, VPN, firewall, router, DNS server, or domain-specific troubleshooting.

Files:

```text
C:\ProgramData\BlueRidge\NetworkFuzzBuster\credential-review.csv
C:\ProgramData\BlueRidge\NetworkFuzzBuster\tcpip-reset.log
C:\ProgramData\BlueRidge\Logs\network-fuzz-buster.log
```

## Outlook Teams Soft Reset

Script:

```text
scripts\blue-ridge-outlook-teams-soft-reset.ps1
```

Use when:

- Classic Outlook will not open.
- Outlook opens in safe mode but behaves badly normally.
- Teams will not open, loops, or behaves stale.
- Office apps need an update nudge.
- Office Quick Repair may be appropriate.
- You want to avoid forcing a user onto new Outlook.

Before running:

- Confirm whether the user uses classic Outlook or new Outlook.
- Close Office apps when possible.
- Ask whether Outlook has PST files or special local archives.
- Confirm the user understands that optional identity reset may require signing back into Microsoft 365 apps.

During the run:

- Select the affected local user profile.
- Confirm the soft reset when prompted.
- Use the Excel wake-up option when Office update behavior appears stuck.
- Use the Office update option when Click-to-Run Office is detected.
- Use Office repair when update/cache cleanup does not resolve the issue.
- Use identity reset only when sign-in or token state appears to be the problem.

After running:

- Try classic Outlook again.
- Try Teams again.
- Confirm mail, calendar, and Teams sign-in behavior.
- If identity reset was used, expect Microsoft 365 sign-in prompts.
- If Outlook still fails, consider add-ins, profile repair, Office repair, or mailbox/account-specific troubleshooting.

Guardrails:

- Does not delete PST files.
- Does not delete OST files by default.
- Does not delete Outlook profiles.
- Does not remove mail accounts.
- Does not remove calendar entries.
- Does not force new Outlook.
- Does not uninstall Teams.
- Does not uninstall Office.

Files:

```text
C:\ProgramData\BlueRidge\Logs\outlook-teams-soft-reset.log
C:\ProgramData\BlueRidge\OutlookTeamsSoftReset\Backups\
```

## Host Domain Trust Repair

Script:

```text
scripts\blue-ridge-host-domain-trust-repair.ps1
```

Use when:

- You are at the affected domain-joined workstation.
- You are connected to the affected workstation through remote support.
- The workstation appears to have lost domain trust.
- You want to repair the secure channel before considering a full domain unjoin/rejoin.

Before running:

- Confirm the machine is supposed to be domain joined.
- Confirm the machine can reach the corporate network or VPN.
- Confirm DNS and time are reasonable.
- Have an appropriate domain repair credential available.

During the run:

- Review the detected domain information.
- Optionally specify a domain controller if needed.
- Enter the repair username when prompted.
- Confirm the repair only when you are ready.

After running:

- Reboot when the repair verifies healthy.
- Have the user test domain login and access to domain resources.
- If repair does not verify, check network path, DNS, time sync, account status, and whether a full rejoin is required.

Log:

```text
C:\ProgramData\BlueRidge\Logs\host-domain-trust-repair.log
```

## DC Domain Trust Repair

Script:

```text
scripts\blue-ridge-dc-domain-trust-repair.ps1
```

Use when:

- You are on a domain controller or admin workstation.
- The target workstation is online and reachable.
- Remote PowerShell access is available.
- You want to repair the target workstation trust remotely before sending someone to the machine.

Before running:

- Confirm the target computer name.
- Confirm the computer object exists in Active Directory.
- Confirm the target workstation is reachable.
- Confirm remote access is expected to work.
- Have an appropriate repair credential available.

During the run:

- Enter the target computer name.
- Review the AD computer object details if shown.
- Confirm the selected domain controller.
- Enter the repair username when prompted.
- Confirm the repair only when you are ready.

After running:

- Reboot the target workstation if the repair verifies healthy and a reboot is acceptable.
- Ask the user to test sign-in and access to domain resources.
- If remote repair fails, use the host-side version locally on the affected PC.

Log:

```text
C:\ProgramData\BlueRidge\Logs\dc-domain-trust-repair.log
```

## Quick after-checks

After any script:

- Check whether the original symptom is fixed.
- Check the matching log file.
- Reboot when recommended.
- Ask the user to test the exact app, printer, network path, mailbox, or login that failed.
- Do not escalate until the original symptom has been re-tested.

## Escalation ladder

1. Use the safest matching script first.
2. Reboot if recommended.
3. Re-test the original problem.
4. Move to deeper repair only if the safe first-pass tool does not resolve the issue.
5. Avoid profile rebuilds, domain rejoin, Office reinstall, adapter removal, printer driver rebuilds, or Windows reset until lighter repair steps fail.

## Public use note

This runbook is intended for administrators. Review code before running it and test in a non-critical environment when changing behavior.
