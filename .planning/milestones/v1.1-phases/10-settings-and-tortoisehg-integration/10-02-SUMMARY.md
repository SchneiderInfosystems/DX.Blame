---
phase: 10-settings-and-tortoisehg-integration
plan: 02
subsystem: vcs-integration
tags: [tortoisehg, mercurial, context-menu, shellexecute, thg]

requires:
  - phase: 08-vcs-discovery
    provides: "Hg.Discovery with FindHgExecutable and cached hg.exe path"
  - phase: 09-mercurial-provider
    provides: "THgProvider with GetDisplayName returning 'Mercurial'"
provides:
  - "FindThgExecutable function deriving thg.exe from hg.exe path"
  - "TortoiseHg Annotate and Log context menu items in editor popup"
affects: []

tech-stack:
  added: []
  patterns: ["fire-and-forget ShellExecute for external tool launch", "conditional menu items based on active VCS provider"]

key-files:
  created: []
  modified:
    - src/DX.Blame.Hg.Discovery.pas
    - src/DX.Blame.Navigation.pas

key-decisions:
  - "Derive thg.exe from hg.exe path (same directory) rather than separate registry/PATH lookup"
  - "Recreate TortoiseHg menu items on every popup event for correct Git/Hg switching"

patterns-established:
  - "Provider-conditional menu items: check GetDisplayName on each popup, not cached"
  - "LaunchThg helper for fire-and-forget external tool launch via ShellExecute"

requirements-completed: [SETT-02, SETT-03]

duration: 3min
completed: 2026-03-24
---

# Phase 10 Plan 02: TortoiseHg Context Menu Integration Summary

**TortoiseHg Annotate and Log context menu items with provider-conditional visibility and fire-and-forget ShellExecute launch**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-24T19:23:19Z
- **Completed:** 2026-03-24T19:26:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- FindThgExecutable function derives thg.exe path from cached hg.exe location
- Editor context menu shows "Open in TortoiseHg Annotate" and "Open in TortoiseHg Log" for Mercurial projects
- Items automatically hidden when Git is active or thg.exe is not installed

## Task Commits

Each task was committed atomically:

1. **Task 1: Add FindThgExecutable to Hg.Discovery** - `f299855` (feat)
2. **Task 2: Add TortoiseHg context menu items to Navigation** - `75ecaec` (feat)

## Files Created/Modified
- `src/DX.Blame.Hg.Discovery.pas` - Added FindThgExecutable deriving thg.exe from hg.exe path
- `src/DX.Blame.Navigation.pas` - Added TortoiseHg Annotate/Log menu items, LaunchThg helper, click handlers

## Decisions Made
- Derive thg.exe from hg.exe path (same TortoiseHg directory) -- avoids separate registry/PATH lookup since both executables always coexist
- Recreate TortoiseHg menu items on every popup event -- matches existing pattern and ensures correct behavior when switching between Git/Hg projects

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Build script plan referenced `DX.Blame.Engine.dpk` but actual project file is `DX.Blame.dproj` -- used correct path for verification
- Group project test target fails due to missing DUnitX submodule (pre-existing, unrelated)

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- TortoiseHg integration complete for Mercurial projects
- All SETT-02 and SETT-03 requirements fulfilled

---
*Phase: 10-settings-and-tortoisehg-integration*
*Completed: 2026-03-24*
