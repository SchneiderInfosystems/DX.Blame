---
phase: 08-vcs-discovery
plan: 01
subsystem: vcs
tags: [mercurial, hg, discovery, provider, tortoisehg]

requires:
  - phase: 06-vcs-abstraction
    provides: IVCSProvider interface, TVCSProcess base class
provides:
  - FindHgExecutable for locating hg.exe on the system
  - FindHgRepoRoot for detecting Mercurial repository roots
  - THgProvider stub implementing IVCSProvider for Mercurial
affects: [08-02-vcs-orchestrator, 09-hg-blame]

tech-stack:
  added: []
  patterns: [hg-discovery-cache, stub-provider-pattern]

key-files:
  created:
    - src/DX.Blame.Hg.Discovery.pas
    - src/DX.Blame.Hg.Provider.pas
  modified:
    - src/DX.Blame.dpk

key-decisions:
  - "No registry lookup for TortoiseHg — PATH + default dirs cover standard installs (registry key unconfirmed)"
  - "No fallback when hg.exe missing — unlike Git, Mercurial without executable is unusable"
  - "Uncommitted hash uses Mercurial convention ffffffffffff (12 hex f chars)"

patterns-established:
  - "Hg discovery mirrors Git discovery: same cache pattern, same parent-walk strategy"
  - "Stub provider pattern: functional discovery + ENotSupportedException for unimplemented operations"

requirements-completed: [VCSD-01, VCSD-02, VCSD-03]

duration: 3min
completed: 2026-03-24
---

# Phase 8 Plan 1: Mercurial Discovery Infrastructure Summary

**Mercurial executable finder (PATH + TortoiseHg dirs), repo root detection via .hg walk + hg root verification, and stub IVCSProvider with ENotSupportedException for blame operations**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-24T10:48:46Z
- **Completed:** 2026-03-24T10:51:42Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Created DX.Blame.Hg.Discovery with FindHgExecutable searching PATH, TortoiseHg default, and x86 directories
- Created DX.Blame.Hg.Provider stub implementing full IVCSProvider interface with working discovery and ENotSupportedException for blame
- Both units compile cleanly as part of DX.Blame package

## Task Commits

Each task was committed atomically:

1. **Task 1: Create DX.Blame.Hg.Discovery unit** - `6494d19` (feat)
2. **Task 2: Create DX.Blame.Hg.Provider stub** - `b0892bb` (feat)

## Files Created/Modified
- `src/DX.Blame.Hg.Discovery.pas` - Mercurial executable finder and repository root detection with caching
- `src/DX.Blame.Hg.Provider.pas` - Stub IVCSProvider for Mercurial, discovery delegates to Hg.Discovery
- `src/DX.Blame.dpk` - Added both Hg units to package contains clause

## Decisions Made
- Omitted registry lookup for TortoiseHg InstallDir (LOW confidence from research, key may not exist)
- No fallback when hg.exe is not found even if .hg directory exists (Mercurial without executable is unusable per research)
- Used 'ffffffffffff' (12 f's) as Mercurial uncommitted hash convention
- Used 'Not Committed' as uncommitted author to match Git provider behavior

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Build script requires .dproj file not .dpk — used src/DX.Blame.dproj for compilation verification

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Hg discovery and stub provider ready for VCS orchestrator (Plan 02) integration
- THgProvider can be instantiated and used for discovery; blame operations will raise clear exceptions until Phase 9

---
*Phase: 08-vcs-discovery*
*Completed: 2026-03-24*
