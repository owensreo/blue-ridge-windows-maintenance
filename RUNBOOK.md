# Blue Ridge Windows Maintenance Runbook

Practical notes for running the scripts in this repository.

## Basic workflow

1. Clone or download the repository.
2. Review the script you plan to use.
3. Open an elevated Windows terminal.
4. Run the reviewed script from the local `scripts` folder.
5. Follow the prompts shown by the script.
6. Review the terminal output.
7. Check the matching log under `C:\ProgramData\BlueRidge\Logs`.
8. Reboot when the script recommends it.
9. Re-test the original issue.

## Local working folder

Most scripts use:

```text
C:\ProgramData\BlueRidge
```

Most logs are stored in:

```text
C:\ProgramData\BlueRidge\Logs
```

## Run pattern

Run scripts only after reviewing them.

From a local repository copy, use the script in the `scripts` folder.

From a prepared machine, copy the reviewed script to `C:\ProgramData\BlueRidge` and run the local copy from there.

Use the execution policy and script-running standards approved for the environment you are supporting. Do not run unreviewed scripts directly from the internet.

## Script names

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

## Notes

- The README explains what each script does.
- Each script prints its own prompts and guardrails while running.
- Logs are intentionally simple and local.
- Use the least invasive script that matches the issue.
- Reboot when recommended before escalating to deeper repair.

## Public use note

This runbook is intended for administrators. Review code before running it and test in a non-critical environment when changing behavior.
