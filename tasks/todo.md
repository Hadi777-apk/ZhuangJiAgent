# WPF Refactor Task Plan

## Phase 0 - Baseline Analysis

Status: completed on 2026-07-04.

### Repository Safety

- [x] Confirmed active repository: `C:\Users\hardy777\Downloads\AI\AI开发环境初始化工具\AI-Environment`.
- [x] Confirmed previous working tree was clean before refactor setup.
- [x] Created and switched to branch `feature/wpf-refactor`.
- [x] Checked tracked files in runtime directories. Large runtime artifacts are not tracked.
- [x] Confirmed `.gitignore` excludes runtime payload/output directories: `installers/`, `downloads/`, `cache/`, `logs/`, `reports/`, `backups/`, `skills/`.
- [x] Added .NET/WPF build output exclusions: `bin/`, `obj/`, `.vs/`, `TestResults/`, `*.user`, `*.suo`.

### Existing Files To Preserve

- `install.ps1` remains the authoritative migration reference for detection, install, update, download, backup, restore, safe upgrade, install-location preview, and command preview behavior.
- `gui.ps1` remains the current PowerShell WPF GUI reference until the new WPF app reaches feature parity.
- `Run.bat`, `Run-GUI.bat`, and `Run-GUI.vbs` remain unchanged during early phases.
- `config.json`, `update-config.json`, and `sources/allowlist.json` remain the real configuration inputs. The new model layer must adapt to their current schema first, not assume a redesigned manifest.
- Runtime directories remain external data and must not be embedded into the WPF binary.

### Configuration Shape

`config.json` currently contains:

- `settings.productName`, `settings.version`, `settings.installTimeoutMinutes`.
- `settings.installLocationPolicy` with default install root, free-space thresholds, preview behavior, and custom-directory policy.
- `apps[]` entries with install metadata:
  - display name and installer file name
  - installer type such as `exe`, `msi`, or `none`
  - required/target version fields
  - command, registry, AppX, process, shortcut, and path detection hints
  - silent and fallback install arguments
  - installability flags
  - custom install directory support and risk notes
  - safety flags such as manual confirmation and online-stub/network requirements

`update-config.json` currently contains:

- read-only update agent settings.
- disabled-by-default download/upgrade behavior.
- official source requirement and timeout settings.
- `apps[]` update metadata:
  - category and detection method list
  - official source type
  - source locator fields such as official page, GitHub repo, winget id, and installer file name
  - auto-download and auto-upgrade flags
  - config paths, backup policy, upgrade policy, risk level, and notes

`sources/allowlist.json` currently contains:

- `allowedDomains[]` for download source validation.
- notes explaining that only direct URL and GitHub release sources use the allowlist; winget, official page, and manual sources do not participate in automatic download.

Sensitive handling rule: reports should describe URL/path fields by purpose unless the exact value is necessary for implementation.

### Script Function Migration Map

`install.ps1` migration targets:

- Core models:
  - app configuration entries
  - update configuration entries
  - environment snapshots
  - install, update, download, backup, restore, and safe-upgrade result models
- `IManifestService` / catalog loading:
  - `Load-Config`
  - `Load-UpdateConfig`
  - conversion helpers such as string-array and boolean config parsing
- `IEnvironmentDetectionService`:
  - `Get-SystemInfo`
  - `Test-Admin`
  - app detection functions using command, registry, AppX, process, shortcut, path, and file version checks
- `IInstallerExecutionService`:
  - installer readiness checks
  - installer process execution
  - path refresh behavior after install
- `IReportService`:
  - check, install, update, download, backup, restore, safe-upgrade, install-location, and command-preview report generation
- `IAllowlistService` / download safety:
  - allowlist loading
  - URL allow checks
  - official-source gating
- `IDownloadService` later phase:
  - download directory initialization
  - GitHub release asset resolution
  - installer download, signature/hash inspection, and download result reporting
- `IBackupRestoreService` later phase:
  - backup source expansion
  - exclusion checks
  - safe copy and manifest generation
  - restore preview and restore execution
- `ISafeUpgradeService` later phase:
  - current version detection
  - installer backup
  - config backup
  - preview, confirmation, installer invocation, post-upgrade verification
- `IInstallLocationService` or `IDiskSpaceCalculatorService`:
  - install location policy
  - drive space inspection
  - custom root validation
  - per-app install location plan and preview reporting

`gui.ps1` migration targets:

- WPF App shell:
  - navigation button and page switching behavior
  - shared status surface
- Views/ViewModels:
  - environment check page from `Build-Check` and `Do-Check`
  - install preview/software selection page from `Build-Preview` and `Do-Preview`
  - install execution page from `Build-Install`
  - update check page behavior maps into later report/update surfaces, not the five-step MVP unless explicitly pulled in
  - config backup/restore page behavior maps into later Services and optional UI, not the five-step MVP unless explicitly pulled in

### UI Reference Notes

The supplied HTML reference is usable for workflow and layout only. Do not copy its final visual style.

Carry forward these ideas:

- five-step linear wizard
- left-side navigation or equivalent stepper
- global status strip for admin/offline/system health
- environment detection before software selection
- software list grouped by status and recommendation
- path configuration as a required pre-install step
- install progress page with overall progress, per-package status, and terminal-style log
- completion report with success, skip, failure, retry, log, and next-action surfaces

### UAC / Elevation Decision

Early WPF phases must not set `requireAdministrator` in the app manifest.

Reason:

- Existing `Run.bat`, `Run-GUI.bat`, and `Run-GUI.vbs` already handle elevation.
- Duplicating elevation in the WPF manifest before launcher replacement can cause inconsistent behavior or repeated UAC prompts.
- The WPF app should detect/admin-status-display first, then final elevation ownership should be decided during the launcher replacement phase.

Phase 8 will decide one of two strategies:

- keep external launcher elevation, or
- move elevation ownership into the WPF app manifest and replace launchers accordingly.

### Planned Implementation Phases

- [x] Phase 1: Create `DevEnvInit.sln`, `DevEnvInit.Core`, models, service interfaces, and `InstallSessionState`.
- [x] Phase 2: Create `DevEnvInit.Services` with minimal implementations for manifest loading, SHA256 verification, disk-space calculation, allowlist validation, and stubbed archive/install services.
- [x] Phase 3: Create `DevEnvInit.App` WPF shell with Microsoft.Extensions.DependencyInjection, five-step navigation, shared status strip, and empty pages.
- [x] Phase 4: Wire environment detection and software selection to real configuration data.
- [ ] Phase 5: Wire path configuration and disk-space estimates. No command preview area.
- [ ] Phase 6: Wire install progress with dry-run or mock execution first. Extraction logs only; install phase shows progress.
- [ ] Phase 7: Wire completion report generation and report display.
- [ ] Phase 8: Decide launcher/elevation ownership, update docs, run final review and verification.

## Review

Phase 0 changed only project safety/planning artifacts:

- `.gitignore` was updated to prevent future .NET/WPF build output from entering Git.
- `tasks/todo.md` was added to capture the baseline, migration map, UAC decision, and staged execution plan.

No business logic, installer behavior, configuration schema, or existing launcher behavior was changed.
