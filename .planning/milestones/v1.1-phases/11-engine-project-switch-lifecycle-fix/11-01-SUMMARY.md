---
phase: 11-engine-project-switch-lifecycle-fix
plan: 01
subsystem: engine
tags: [timer-lifecycle, project-switch, vcs-diagnostics, memory-leak]

requires:
  - phase: 06-vcs-provider-abstraction
    provides: IVCSProvider interface and TBlameEngine VCS integration
provides:
  - Tracked retry timer lifecycle via FRetryTimers dictionary
  - Per-project VCS diagnostic reset via FVCSNotified reset
affects: []

tech-stack:
  added: []
  patterns:
    - "Dictionary-tracked timer pattern extended to retry timers"

key-files:
  created: []
  modified:
    - src/DX.Blame.Engine.pas

key-decisions:
  - "FRetryTimers follows identical lifecycle pattern to FDebounceTimers for consistency"
  - "Timer removed from FRetryTimers before Free to prevent dangling dictionary entries"

patterns-established:
  - "All TTimer instances in TBlameEngine must be dictionary-tracked for cleanup on project switch"

requirements-completed: [VCSA-05, VCSD-05]

duration: 2min
completed: 2026-03-25
---

# Phase 11 Plan 01: Engine Project-Switch Lifecycle Fix Summary

**FRetryTimers dictionary tracks retry timer lifecycle and FVCSNotified resets per project switch, closing MISS-1 and MISS-2 audit gaps**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-25T22:10:24Z
- **Completed:** 2026-03-25T22:12:06Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Retry timers created in HandleBlameError are now tracked in FRetryTimers dictionary and cleaned up during ClearAllTimers on project switch
- DoRetryBlame removes timer from FRetryTimers before freeing, preventing dangling dictionary entries
- FVCSNotified resets to False on each project switch so new projects get fresh VCS diagnostic messages

## Task Commits

Each task was committed atomically:

1. **Task 1: Track retry timers in FRetryTimers dictionary (MISS-1)** - `fa68cf6` (fix)
2. **Task 2: Reset FVCSNotified on project switch (MISS-2)** - `485298a` (fix)

## Files Created/Modified
- `src/DX.Blame.Engine.pas` - Added FRetryTimers field, lifecycle management in constructor/destructor/HandleBlameError/DoRetryBlame/ClearAllTimers, and FVCSNotified reset in OnProjectSwitch

## Decisions Made
- FRetryTimers follows identical lifecycle pattern to FDebounceTimers (create in constructor, track on use, cleanup in ClearAllTimers, free in destructor) for consistency and maintainability
- Timer is removed from FRetryTimers before calling Free in DoRetryBlame, matching the pattern used in DoRequestBlame for debounce timers

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Build script exits with error due to BPL output directory permissions (`C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\`) but Delphi compiler itself compiles all units without errors. This is a pre-existing environment configuration issue, not a code problem.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Both MISS-1 (retry timer leak) and MISS-2 (FVCSNotified suppression) from the v1.1 milestone audit are resolved
- No further phases planned; this was a gap closure phase

## Self-Check: PASSED

- [x] src/DX.Blame.Engine.pas exists
- [x] Commit fa68cf6 exists (Task 1)
- [x] Commit 485298a exists (Task 2)
- [x] FRetryTimers field declared, created, freed, tracked, removed, cleaned (8 occurrences)
- [x] FVCSNotified := False in OnProjectSwitch (line 402)

---
*Phase: 11-engine-project-switch-lifecycle-fix*
*Completed: 2026-03-25*
