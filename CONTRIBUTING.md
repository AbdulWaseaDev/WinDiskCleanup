# Contributing

Contributions are welcome — bug fixes, new cleanup steps, and improvements to existing ones.

## Getting Started

1. Fork the repo and clone it locally
2. Create a branch: `git checkout -b feature/my-cleanup-step`
3. Make your changes
4. Test on a real Windows machine (see below)
5. Open a pull request

## Testing Your Change

Always test with `-DryRun` first:

```powershell
.\WinDiskCleanup.ps1 -DryRun
```

Then run the full cleanup and verify the HTML report on your Desktop looks correct.

## Guidelines

- **Auto-detect everything** — never assume a tool is installed. Wrap each step in a check and skip silently if the tool is missing.
- **No hardcoded paths** — use auto-detection or expose a `$Config_*` variable in `cleanup-config.ps1`.
- **Respect `-DryRun`** — every deletion must be gated on `$DryRun -eq $false`.
- **Update CHANGELOG.md** — add your change under a new version heading.
- **One step per PR** — keeps reviews focused and history clean.

## Reporting Bugs

Open an issue using the **Bug Report** template. Include your Windows version, PowerShell version, and the relevant section from the Desktop report file.

## Suggesting Features

Open an issue using the **Feature Request** template. Explain what gets cleaned, why it matters for developers, and roughly how much space it typically wastes.
