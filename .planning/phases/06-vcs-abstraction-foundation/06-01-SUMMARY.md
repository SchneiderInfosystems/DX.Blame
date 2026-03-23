---
phase: 06-vcs-abstraction-foundation
plan: 01
subsystem: vcs-abstraction
tags: [delphi, vcs, abstraction, interface, createprocess, pipes]

# Dependency graph
requires: []
provides:
  - TVCSProcess base class with CreateProcess pipe capture logic
  - TBlameLineInfo and TBlameData VCS-neutral types
  - IVCSProvider interface for blame, commit detail, diff, discovery
  - TGitProcess thin subclass pattern
affects: [06-02, 07-git-provider-implementation, 09-mercurial-backend]

# Tech tracking
tech-stack:
  added: []
  patterns: [VCS-neutral base class with Git-specific thin subclass, single provider interface]

key-files:
  created:
    - src/DX.Blame.VCS.Types.pas
    - src/DX.Blame.VCS.Process.pas
    - src/DX.Blame.VCS.Provider.pas
  modified:
    - src/DX.Blame.Git.Types.pas
    - src/DX.Blame.Git.Process.pas
    - src/DX.Blame.Git.Discovery.pas
    - src/DX.Blame.dpk

key-decisions:
  - "TVCSProcess fields made protected (not private) so TGitProcess can expose GitPath property via read access to FExePath"
  - "Single IVCSProvider interface covering all operations (blame, commit detail, diff, discovery, identity) per research recommendation"

patterns-established:
  - "VCS-neutral base types in DX.Blame.VCS.* namespace, Git-specific in DX.Blame.Git.*"
  - "Thin subclass pattern: TGitProcess inherits all logic from TVCSProcess, adds only constructor and property alias"
  - "One-way dependency: VCS.* units never reference Git.* units"

requirements-completed: [VCSA-01, VCSA-02, VCSA-03]

# Metrics
duration: 3min
completed: 2026-03-23
---

# Phase 6 Plan 01: VCS Abstraction Foundation Summary

**VCS-neutral type layer (TBlameLineInfo, TBlameData), TVCSProcess base class with pipe capture, and IVCSProvider interface covering blame/diff/discovery operations**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-23T15:53:39Z
- **Completed:** 2026-03-23T15:56:16Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Extracted VCS-neutral types and timing constants into DX.Blame.VCS.Types, breaking the Git coupling
- Moved all CreateProcess pipe logic from TGitProcess into TVCSProcess base class, eliminating duplication
- Defined IVCSProvider interface with 12 methods covering blame, commit detail, diff, revision navigation, discovery, and identity
- Eliminated 65-line duplicated ExecuteGitSync in Git.Discovery, replaced with 5-line TVCSProcess delegation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create VCS.Types and VCS.Process foundation units** - `91a749b` (feat)
2. **Task 2: Create IVCSProvider interface and update DPK** - `2214197` (feat)

## Files Created/Modified
- `src/DX.Blame.VCS.Types.pas` - VCS-neutral TBlameLineInfo, TBlameData, timing constants
- `src/DX.Blame.VCS.Process.pas` - TVCSProcess base class with all CreateProcess pipe logic
- `src/DX.Blame.VCS.Provider.pas` - IVCSProvider interface definition
- `src/DX.Blame.Git.Types.pas` - Stripped to Git-specific sentinel constants only
- `src/DX.Blame.Git.Process.pas` - Thin TVCSProcess subclass with constructor only
- `src/DX.Blame.Git.Discovery.pas` - ExecuteGitSync replaced with TVCSProcess delegation
- `src/DX.Blame.dpk` - Added three VCS units, updated package description

## Decisions Made
- Made TVCSProcess fields `protected` instead of `private` so TGitProcess can expose a `GitPath` property that reads `FExePath` -- maintains backward compatibility with existing consumer code
- Used a single IVCSProvider interface (not split into IVCSBlame/IVCSDiscovery) per research recommendation for simplicity

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Changed TVCSProcess fields from private to protected**
- **Found during:** Task 1 (Git.Process refactoring)
- **Issue:** TGitProcess needs to expose a GitPath property reading FExePath, but private fields are not accessible in subclasses
- **Fix:** Changed field visibility from `private` to `protected` in TVCSProcess
- **Files modified:** src/DX.Blame.VCS.Process.pas
- **Verification:** TGitProcess compiles with `property GitPath: string read FExePath`
- **Committed in:** 91a749b (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary for correct subclass property access. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- VCS abstraction foundation is complete and ready for Plan 02
- Plan 02 will wire TGitProvider implementing IVCSProvider and update all consumer uses clauses
- Package will not compile until Plan 02 updates consumer units from Git.Types to VCS.Types

## Self-Check: PASSED

- All 3 new files exist on disk
- Both task commits verified (91a749b, 2214197)
- VCS.Types contains TBlameLineInfo
- VCS.Process contains TVCSProcess
- VCS.Provider contains IVCSProvider
- Git.Process is thin subclass of TVCSProcess
- Git.Discovery has no duplicated CreatePipe logic

---
*Phase: 06-vcs-abstraction-foundation*
*Completed: 2026-03-23*
