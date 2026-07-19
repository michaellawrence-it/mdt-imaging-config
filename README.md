# mdt-imaging-config

Zero-touch Windows deployment with Microsoft Deployment Toolkit — the configuration that eliminated manual laptop setup at a 100+ employee healthcare organization.

## Problem
Every new workstation was a half-day of manual work: install Windows, join the domain, install a dozen applications one by one, set power/network policy, configure printers. Multiply by a hiring wave (the org grew 65→120) and imaging became the single biggest time sink in device lifecycle — and no two machines came out quite the same.

## Approach
An MDT deployment share on a Hyper-V VM drives the whole build over PXE/USB boot:

```
Boot into WinPE ──► Bootstrap.ini (connects to the deployment share, skips the welcome wizard)
        │
        ▼
CustomSettings.ini
  · OS install + locale/timezone pre-answered
  · Domain join with machine-object OU placement
  · Computer naming convention enforced
        │
        ▼
Task sequence
  · OS + drivers injected per model
  · Roles/features via ZTI PowerShell steps
  · Install-Apps.ps1 — the post-image payload (below)
        │
        ▼
Domain-joined, fully-loaded machine. Zero clicks after boot.
```

**[`Scripts/Install-Apps.ps1`](Scripts/Install-Apps.ps1)** does the heavy lifting after the OS lands:
- **System policy first:** disables sleep/hibernation/lid-close power traps that break overnight patching, enables .NET 3.5 for legacy line-of-business apps
- **Network-aware:** detects Ethernet; only stages the corporate Wi-Fi profile (no forced connection) when the machine is wireless
- **Sequential, logged installs** of the full corporate stack — PDF reader, browser (enterprise MSI), Office via ODT, endpoint protection, Citrix Workspace, VPN client, OneDrive machine-wide, Zoom, secure-email plugin — each with silent-install switches and exit-code logging
- **Point-and-Print registry policy** imported so printer deployment works under modern Windows hardening

## Result
- Manual laptop setup: **eliminated** — image, boot, hand to the user
- Setup time per machine: ~half a day → **~45 unattended minutes**
- Every machine identical: same apps, same power policy, same security baseline
- Scaled through a 65→120 headcount hiring wave without adding IT staff

## Stack
Microsoft Deployment Toolkit · WinPE · PowerShell · Windows ADK · Hyper-V

> Configs are sanitized: domain, credentials, OU paths, and machine-name prefixes are placeholders. **Note:** MDT stores deployment credentials in plaintext in `Bootstrap.ini`/`CustomSettings.ini` by design — mitigate with a least-privilege, join-only service account, which is what the placeholders represent.
