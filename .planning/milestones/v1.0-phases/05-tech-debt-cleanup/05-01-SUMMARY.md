---
phase: 05-tech-debt-cleanup
plan: 01
subsystem: rendering, registration
tags: [ToolsAPI, INTACodeEditorServices, theme-aware, circular-dependency, dead-code]

# Dependency graph
requires:
  - phase: 03-inline-rendering-and-ux
    provides: DeriveAnnotationColor stub and formatter infrastructure
  - phase: 04-tooltip-and-commit-detail
    provides: Popup panel with OnShowDiffClick property to remove
provides:
  - Theme-aware DeriveAnnotationColor using INTACodeEditorServices midpoint blend
  - One-way dependency from Registration to KeyBinding (no circular reference)
  - Clean TDXBlamePopup without orphaned OnShowDiffClick
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Callback decoupling: OnBlameToggled TProc variable in KeyBinding interface, assigned by Registration"
    - "Theme-aware color: midpoint blend between editor background and 128 per channel"

key-files:
  created: []
  modified:
    - src/DX.Blame.Formatter.pas
    - src/DX.Blame.KeyBinding.pas
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.Popup.pas

key-decisions:
  - "Midpoint blend (channel + 128) / 2 produces muted gray that adapts to both light and dark themes"
  - "OnBlameToggled exposed as interface-level TProc var so Registration can assign it without KeyBinding knowing about Registration"

patterns-established:
  - "Callback decoupling pattern: expose TProc var in lower-level unit interface, assign in higher-level unit"

requirements-completed: [CONF-02]

# Metrics
duration: 2min
completed: 2026-03-23
---

# Phase 5 Plan 1: Tech Debt Cleanup Summary

**Theme-aware annotation color via INTACodeEditorServices midpoint blend, circular dependency broken with OnBlameToggled callback, orphaned OnShowDiffClick removed**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-23T12:02:16Z
- **Completed:** 2026-03-23T12:04:41Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- DeriveAnnotationColor now queries the IDE editor background and blends each RGB channel toward 128, producing a muted gray that adapts to any theme (clGray fallback preserved for test runner)
- Circular dependency between KeyBinding and Registration broken: KeyBinding no longer references Registration, uses OnBlameToggled callback instead
- Orphaned OnShowDiffClick field, property, and call removed from TDXBlamePopup
- GetAnnotationClickableLength doc updated to explicitly state "author name span"
- Registration.pas finalization guards confirmed correct (already >= 0)

## Task Commits

Each task was committed atomically:

1. **Task 1: Theme-aware DeriveAnnotationColor and mechanical cleanups** - `fca26fd` (feat)
2. **Task 2: Break circular dependency between KeyBinding and Registration** - `87686bd` (refactor)

## Files Created/Modified
- `src/DX.Blame.Formatter.pas` - Theme-aware DeriveAnnotationColor with INTACodeEditorServices, updated doc comment
- `src/DX.Blame.KeyBinding.pas` - Removed Registration dependency, added OnBlameToggled callback var
- `src/DX.Blame.Registration.pas` - Wires OnBlameToggled := SyncEnableBlameCheckmark after RegisterKeyBinding
- `src/DX.Blame.Popup.pas` - Removed orphaned FOnShowDiffClick field, property, and call

## Decisions Made
- Midpoint blend formula (channel + 128) / 2 chosen for muted gray that works on both light (produces ~191) and dark (produces ~79) backgrounds
- OnBlameToggled declared as interface-level var (not implementation) so Registration.pas can assign it

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- BPL output directory (C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\) not writable, but this is a system permission issue unrelated to code changes. Compilation of all source files succeeded with no errors.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All tech debt items from v1.0 milestone audit are resolved
- Codebase is clean for future development (v2 features)

## Self-Check: PASSED

All 4 modified files exist. Both task commits (fca26fd, 87686bd) verified in git log.

---
*Phase: 05-tech-debt-cleanup*
*Completed: 2026-03-23*
