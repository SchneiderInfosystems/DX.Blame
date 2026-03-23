---
phase: 04-tooltip-and-commit-detail
plan: 02
subsystem: ui
tags: [vcl, richedit, diff, modal-dialog, theme, ini-persistence]

# Dependency graph
requires:
  - phase: 04-tooltip-and-commit-detail
    provides: TCommitDetailCache, TDXBlamePopup, TCommitDetailThread, click detection
provides:
  - TFormDXBlameDiff modal dialog with RTF color-coded unified diff display
  - GetDiffLineColor pure function for diff line coloring
  - DiffDialog size persistence in INI settings
  - Short hash hotlink in annotations (underlined, always visible)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: [RTF diff coloring via TRichEdit SelAttributes, two-part annotation rendering with underline hotlink]

key-files:
  created:
    - src/DX.Blame.Diff.Form.pas
    - src/DX.Blame.Diff.Form.dfm
    - tests/DX.Blame.Tests.CommitDetail.pas
    - tests/DX.Blame.Tests.DiffFormatter.pas
  modified:
    - src/DX.Blame.Formatter.pas
    - src/DX.Blame.Renderer.pas
    - src/DX.Blame.Settings.pas
    - src/DX.Blame.Popup.pas
    - src/DX.Blame.dpk
    - tests/DX.Blame.Tests.Settings.pas
    - tests/DX.Blame.Tests.Formatter.pas
    - tests/DX.Blame.Tests.dpr
    - tests/DX.Blame.Tests.dproj

key-decisions:
  - "FormatBlameAnnotation always prefixes 7-char short hash for committed lines, making annotations visually clickable"
  - "Two-part rendering in PaintLine: hash drawn with [fsUnderline, fsItalic], rest with [fsItalic] only"
  - "GetAnnotationHashLength returns 9 (7 hash + 2 spaces) for committed, 0 for uncommitted -- decouples formatting from rendering"

patterns-established:
  - "Annotation hotlink: hash prefix always visible and underlined to signal clickability"
  - "Two-part TextOut: split annotation into styled segments using TextWidth for positioning"

requirements-completed: [TTIP-02]

# Metrics
duration: 4min
completed: 2026-03-23
---

# Phase 4 Plan 02: Modal Diff Dialog Summary

**Modal diff dialog with RTF color-coded unified diff, scope toggle, size persistence, and always-visible underlined hash hotlink in annotations**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-23T09:43:20Z
- **Completed:** 2026-03-23T09:47:12Z
- **Tasks:** 2 (Task 1 from previous session, Task 2 fix from user feedback)
- **Files modified:** 13

## Accomplishments
- TFormDXBlameDiff modal dialog with RTF color-coded diff display (green additions, red deletions, blue hunk headers)
- GetDiffLineColor pure function with dark/light theme support and correct +++ / --- exclusion
- DiffDialog size persistence via INI settings (DiffDialogWidth/Height)
- Annotation text now always shows 7-char short hash, underlined as visual hotlink indicator
- Two-part rendering: underlined hash prefix + italic remainder in PaintLine
- Unit tests for CommitDetailCache CRUD, diff line coloring, settings persistence, and hash prefix formatting

## Task Commits

Each task was committed atomically:

1. **Task 1: Diff dialog form with RTF coloring and size persistence** - `95f5ffe` (feat)
2. **Task 2: Show short hash as underlined hotlink in annotations** - `5900359` (fix, user feedback)

## Files Created/Modified
- `src/DX.Blame.Diff.Form.pas` - TFormDXBlameDiff modal dialog with TRichEdit diff display, scope toggle, theme adaptation
- `src/DX.Blame.Diff.Form.dfm` - DFM layout for diff dialog (header panel, toolbar, RichEdit)
- `src/DX.Blame.Formatter.pas` - FormatBlameAnnotation now prefixes short hash; added GetAnnotationHashLength
- `src/DX.Blame.Renderer.pas` - Two-part annotation rendering with underlined hash hotlink
- `src/DX.Blame.Settings.pas` - DiffDialogWidth/Height properties with INI persistence
- `src/DX.Blame.Popup.pas` - Wired Show Diff button to TFormDXBlameDiff.ShowDiff
- `src/DX.Blame.dpk` - Added DX.Blame.Diff.Form to contains clause
- `tests/DX.Blame.Tests.CommitDetail.pas` - TCommitDetailCacheTests (Store/TryGet/Clear)
- `tests/DX.Blame.Tests.DiffFormatter.pas` - TDiffFormatterTests (color assignment for all line types)
- `tests/DX.Blame.Tests.Settings.pas` - DiffDialog size default and round-trip tests
- `tests/DX.Blame.Tests.Formatter.pas` - Hash prefix and GetAnnotationHashLength tests
- `tests/DX.Blame.Tests.dpr` - Added new test unit registrations
- `tests/DX.Blame.Tests.dproj` - Updated search paths for new test units

## Decisions Made
- Always show 7-char short hash in annotation text to signal clickability (user feedback)
- Use [fsUnderline, fsItalic] for hash and [fsItalic] for rest -- two TextOut calls with TextWidth positioning
- GetAnnotationHashLength returns 9 for committed (7 hash + 2 spaces), 0 for uncommitted -- clean separation between formatter and renderer

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added underlined hash hotlink to annotations per user feedback**
- **Found during:** Task 2 (user verification reported annotations not visibly clickable)
- **Issue:** Users could not tell annotations were clickable -- no visual affordance
- **Fix:** FormatBlameAnnotation now prefixes short hash; renderer draws it underlined
- **Files modified:** src/DX.Blame.Formatter.pas, src/DX.Blame.Renderer.pas, tests/DX.Blame.Tests.Formatter.pas
- **Verification:** Package and tests compile, 63/64 tests pass (1 pre-existing environment failure)
- **Committed in:** 5900359

---

**Total deviations:** 1 auto-fixed (1 bug -- missing visual affordance)
**Impact on plan:** Essential UX fix based on user testing. No scope creep.

## Issues Encountered
- TSettingsTests.TestDefaultValues fails on this machine due to existing INI file with ShowSummary=True overriding default. Pre-existing environment-dependent issue, not caused by our changes.
- Win32 build path permission issue (pre-existing). Win64 builds successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 4 is now complete. All planned features delivered: popup, diff dialog, hash hotlink.
- All v1 requirements are satisfied.
- The project is ready for final verification and release.

---
*Phase: 04-tooltip-and-commit-detail*
*Completed: 2026-03-23*
