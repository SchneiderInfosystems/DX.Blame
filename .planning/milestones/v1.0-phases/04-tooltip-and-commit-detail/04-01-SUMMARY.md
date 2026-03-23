---
phase: 04-tooltip-and-commit-detail
plan: 01
subsystem: ui
tags: [vcl, popup, clipboard, theme, async, git]

# Dependency graph
requires:
  - phase: 03-inline-rendering-and-ux
    provides: TDXBlameRenderer with PaintLine and INTACodeEditorEvents370
  - phase: 02-blame-data-pipeline
    provides: TBlameEngine, TBlameCache, TGitProcess, TBlameLineInfo
provides:
  - TCommitDetailCache with thread-safe cache keyed by commit hash
  - TCommitDetailThread for async git log/show fetch
  - TDXBlamePopup borderless form with theme adaptation
  - Click detection in renderer via annotation hit-testing
affects: [04-tooltip-and-commit-detail]

# Tech tracking
tech-stack:
  added: []
  patterns: [borderless TCustomForm popup with CM_DEACTIVATE dismissal, per-row annotation hit-test dictionary, async commit detail fetch thread]

key-files:
  created:
    - src/DX.Blame.CommitDetail.pas
    - src/DX.Blame.Popup.pas
  modified:
    - src/DX.Blame.Renderer.pas
    - src/DX.Blame.Engine.pas
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.dpk

key-decisions:
  - "Unit-level dictionaries for annotation hit-test data (GAnnotationXByRow, GLineByRow) instead of instance fields, since TDXBlameRenderer is reference-counted TNotifierObject"
  - "TCommitDetailThread dedicated thread class following TBlameThread pattern instead of TProc callback to avoid Delphi generic anonymous method issues"
  - "Popup stored as unit-level var GPopup in Renderer.pas with CleanupPopup exported for Registration finalization"

patterns-established:
  - "Borderless popup: TCustomForm with WS_POPUP|WS_BORDER, WS_EX_TOOLWINDOW, CM_DEACTIVATE for click-outside dismissal"
  - "Annotation hit-testing: store per-row annotation X and logical line during PaintLine, look up in EditorMouseDown"

requirements-completed: [TTIP-01]

# Metrics
duration: 6min
completed: 2026-03-23
---

# Phase 4 Plan 01: Blame Popup Panel Summary

**Click-triggered borderless popup with commit hash copy, theme-adaptive colors, and async full message fetch via TCommitDetailCache**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-23T09:18:46Z
- **Completed:** 2026-03-23T09:25:07Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- TCommitDetailCache with thread-safe dictionary and TCommitDetailThread for async git log/show
- TDXBlamePopup borderless form with hash copy to clipboard, "Copied!" feedback, dark/light theme adaptation
- Per-row annotation hit-test in renderer for precise click detection on annotation area
- CommitDetailCache cleared on project switch alongside blame cache

## Task Commits

Each task was committed atomically:

1. **Task 1: Commit detail cache and popup panel units** - `9dda6de` (feat)
2. **Task 2: Click detection in renderer and lifecycle wiring** - `c16a5b3` (feat)

## Files Created/Modified
- `src/DX.Blame.CommitDetail.pas` - TCommitDetail record, TCommitDetailCache singleton, TCommitDetailThread async fetch
- `src/DX.Blame.Popup.pas` - TDXBlamePopup borderless form with theme colors, hash copy, Escape/click-outside dismissal
- `src/DX.Blame.Renderer.pas` - Annotation hit-test dictionaries, EditorMouseDown click detection, popup management
- `src/DX.Blame.Engine.pas` - CommitDetailCache.Clear in OnProjectSwitch
- `src/DX.Blame.Registration.pas` - CleanupPopup call in finalization
- `src/DX.Blame.dpk` - Added CommitDetail and Popup units to contains clause

## Decisions Made
- Used unit-level dictionaries (GAnnotationXByRow, GLineByRow) for hit-test data because TDXBlameRenderer is a TNotifierObject (reference-counted, no normal destructor)
- Used TCommitDetailThread dedicated thread class instead of TProc callback (consistent with TBlameThread pattern, avoids Delphi generic anonymous method issues)
- Popup stored as unit-level var GPopup with explicit CleanupPopup procedure for deterministic cleanup in Registration finalization
- Hide popup on editor scroll and tab switch to prevent stale positioning

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed unused FDetail field from TCommitDetailThread**
- **Found during:** Task 1 (compilation verification)
- **Issue:** TCommitDetailThread had an FDetail field that was never used (thread uses local variables instead)
- **Fix:** Removed the unused field to eliminate H2219 hint warning
- **Files modified:** src/DX.Blame.CommitDetail.pas
- **Verification:** Clean build with no warnings
- **Committed in:** 9dda6de (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor cleanup. No scope creep.

## Issues Encountered
- Win32 build fails with BPL output path permission error (C:\Users\Public\Documents\Embarcadero -- pre-existing issue). Win64 builds successfully. Not caused by our changes.
- Test project build fails with missing DX.Blame.Version unit (search path issue, pre-existing). Not caused by our changes.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Popup panel is ready for Plan 02 to wire the "Show Diff" button to a modal diff dialog
- FOnShowDiffClick event on TDXBlamePopup is prepared but unassigned (Plan 02 will connect it)
- TCommitDetail.FileDiff and FullDiff fields are populated by the async thread, ready for diff display

---
*Phase: 04-tooltip-and-commit-detail*
*Completed: 2026-03-23*
