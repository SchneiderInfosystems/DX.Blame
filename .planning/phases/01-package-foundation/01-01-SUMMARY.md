---
phase: 01-package-foundation
plan: 01
subsystem: infra
tags: [delphi, ota, bpl, design-time-package, toolsapi]

# Dependency graph
requires: []
provides:
  - "Compilable DX.Blame.bpl design-time package for Delphi 13"
  - "OTA registration: wizard, splash screen, about box, Tools menu"
  - "Version constants unit (cDXBlameVersion, cDXBlameName, etc.)"
  - "Build infrastructure with DelphiBuildDPROJ.ps1"
  - "Project group (DX.Blame.groupproj)"
affects: [02-data-pipeline, 03-rendering-ux, 04-tooltip-detail]

# Tech tracking
tech-stack:
  added: [ToolsAPI, designide, DelphiBuildDPROJ.ps1, BRCC32]
  patterns: [OTA-wizard-registration, splash-in-initialization, reverse-order-finalization, single-registration-unit]

key-files:
  created:
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.Version.pas
    - src/DX.Blame.dpk
    - src/DX.Blame.dproj
    - res/DX.Blame.Splash.rc
    - res/DX.Blame.Splash.res
    - res/DX.Blame.SplashIcon.bmp
    - build/DelphiBuildDPROJ.ps1
    - DX.Blame.groupproj
  modified:
    - .gitignore
    - .gitattributes

key-decisions:
  - "Pre-compile .rc to .res with BRCC32 -32 and reference .res in DPK (avoids RLINK32 16-bit resource error)"
  - "Add .gitignore exception for res/*.res to track compiled resource files"
  - "Use AddPluginBitmap (not AddProductBitmap) for splash screen per QC 42320"

patterns-established:
  - "OTA lifecycle in single unit: DX.Blame.Registration.pas handles wizard, splash, about, menu"
  - "Splash registered in initialization section, about/wizard/menu in Register procedure"
  - "Finalization cleanup in reverse order: menu, wizard, about"
  - "All .pas files UTF-8 with BOM and CRLF line endings"
  - "Resource files kept in res/ directory, compiled .res tracked in git"

requirements-completed: [UX-04]

# Metrics
duration: 9min
completed: 2026-03-19
---

# Phase 1 Plan 01: Package Foundation Summary

**Design-time BPL with OTA wizard, splash screen, about box, and disabled Tools menu -- compiles for Delphi 13 via DelphiBuildDPROJ.ps1**

## Performance

- **Duration:** 9 min
- **Started:** 2026-03-19T00:46:59Z
- **Completed:** 2026-03-19T00:56:29Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments
- Complete project scaffold with .gitignore, .gitattributes, build script, and project group
- DX.Blame.bpl compiles successfully for Delphi 13 (Win32) producing 38KB BPL
- OTA registration unit with wizard, splash screen (initialization), about box, and Tools menu
- Clean finalization with reverse-order removal of menu items, wizard, and about box entry

## Task Commits

Each task was committed atomically:

1. **Task 1: Create project scaffold and build infrastructure** - `a30e9bd` (feat)
2. **Task 2: Implement OTA registration with wizard, splash, about, and menu** - `c3b48e5` (feat)

**Plan metadata:** (pending) (docs: complete plan)

## Files Created/Modified
- `src/DX.Blame.Registration.pas` - Central OTA lifecycle: wizard, splash, about, menu registration and cleanup
- `src/DX.Blame.Version.pas` - Version constants (1.0.0.0) and plugin metadata
- `src/DX.Blame.dpk` - Design-time package source requiring rtl, vcl, designide
- `src/DX.Blame.dproj` - Project file with correct output paths and version info
- `res/DX.Blame.Splash.rc` - Resource script referencing splash bitmap
- `res/DX.Blame.Splash.res` - Compiled resource (32-bit, via BRCC32)
- `res/DX.Blame.SplashIcon.bmp` - Placeholder 24x24 bitmap (user provides final artwork)
- `build/DelphiBuildDPROJ.ps1` - Universal build script from omonien/DelphiStandards
- `DX.Blame.groupproj` - Project group containing DX.Blame package
- `.gitignore` - Delphi-optimized with exception for res/*.res
- `.gitattributes` - Delphi-optimized encoding and line ending rules

## Decisions Made
- Pre-compile .rc to .res with BRCC32 and reference the compiled .res in DPK, because Delphi's MSBuild targets use BRCC32 internally which produces resources that RLINK32 rejects as "Unsupported 16bit resource" when referenced as .rc
- Added .gitignore exception `!res/*.res` to track compiled resource files needed for build
- Used AddPluginBitmap (not AddProductBitmap) for splash screen per known QC 42320 bug

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed resource compilation failure (RLINK32 16-bit resource error)**
- **Found during:** Task 2 (compilation verification)
- **Issue:** `{$R '..\res\DX.Blame.res.rc'}` in DPK caused "Unsupported 16bit resource" error from RLINK32
- **Fix:** Pre-compiled .rc to .res using BRCC32 -32, renamed files to DX.Blame.Splash.rc/.res, changed DPK to reference compiled .res
- **Files modified:** src/DX.Blame.dpk, res/DX.Blame.Splash.rc, res/DX.Blame.Splash.res
- **Verification:** BPL compiles successfully
- **Committed in:** c3b48e5 (Task 2 commit)

**2. [Rule 3 - Blocking] Added .gitignore exception for compiled resource files**
- **Found during:** Task 2 (git commit)
- **Issue:** Standard Delphi .gitignore ignores all *.res files, preventing the compiled splash resource from being tracked
- **Fix:** Added `!res/*.res` exception to .gitignore
- **Files modified:** .gitignore
- **Verification:** git add res/DX.Blame.Splash.res succeeds
- **Committed in:** c3b48e5 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both fixes necessary for successful compilation and version control. No scope creep.

## Issues Encountered
- Python3 not directly available on this Windows system (Windows Store alias redirect); used Node.js for file creation with UTF-8 BOM + CRLF encoding
- PowerShell execution policy blocked script execution; resolved with `-ExecutionPolicy Bypass` flag

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- BPL shell compiles and is ready for IDE installation testing (manual: Component > Install Packages)
- Plan 02 (DUnitX test infrastructure) can proceed immediately
- All future phases build on this Registration unit for notifier and service registration

## Self-Check: PASSED

- All 11 created files verified present
- Both task commits (a30e9bd, c3b48e5) verified in git log
- DX.Blame.bpl (38KB) verified in build/Win32/Debug/

---
*Phase: 01-package-foundation*
*Completed: 2026-03-19*
