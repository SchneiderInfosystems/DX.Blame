---
phase: 02-blame-data-pipeline
plan: 01
subsystem: git-integration
tags: [createprocess, pipe-capture, git-discovery, blame-types, win32-api]

# Dependency graph
requires:
  - phase: 01-package-foundation
    provides: DPK package structure with OTA registration
provides:
  - TBlameLineInfo record and TBlameData class for blame pipeline contracts
  - FindGitExecutable and FindGitRepoRoot for git detection
  - TGitProcess wrapper for safe CreateProcess with pipe capture
affects: [02-blame-data-pipeline]

# Tech tracking
tech-stack:
  added: [Winapi.Windows/CreateProcess, System.IOUtils, System.Classes/TBytesStream]
  patterns: [anonymous-pipe-capture, parent-directory-walk, session-cached-discovery]

key-files:
  created:
    - src/DX.Blame.Git.Types.pas
    - src/DX.Blame.Git.Discovery.pas
    - src/DX.Blame.Git.Process.pas
  modified:
    - src/DX.Blame.dpk

key-decisions:
  - "Discovery unit includes internal ExecuteGitSync for rev-parse verification, avoiding circular dependency on TGitProcess"
  - "TGitProcess.Execute delegates to ExecuteAsync then closes the handle, keeping a single implementation path"
  - "Qualified System.SysUtils.GetEnvironmentVariable to avoid ambiguity with Winapi.Windows overload"

patterns-established:
  - "Pipe capture pattern: CreatePipe, close write end after CreateProcess, read loop, then WaitForSingleObject"
  - "Session-cached discovery: unit-level vars with ClearDiscoveryCache for project switch"
  - "Handle cleanup: all 5 handles (read pipe, write pipe, process, thread, security attrs) in try/finally"

requirements-completed: [BLAME-02, BLAME-04]

# Metrics
duration: 3min
completed: 2026-03-19
---

# Phase 2 Plan 01: Git Foundation Units Summary

**Blame data types, git discovery with PATH + common locations, and CreateProcess pipe wrapper with cancellation support**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-19T19:22:23Z
- **Completed:** 2026-03-19T19:25:53Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- TBlameLineInfo record and TBlameData class define shared contracts for the entire blame pipeline
- FindGitExecutable searches PATH then 3 common install locations with session caching
- FindGitRepoRoot walks parent directories for .git folder then verifies via git rev-parse
- TGitProcess wraps CreateProcess with anonymous pipe capture, cancellation, and full handle cleanup

## Task Commits

Each task was committed atomically:

1. **Task 1: Create shared blame data types unit** - `8321d64` (feat)
2. **Task 2: Create git discovery unit** - `b96a875` (feat)
3. **Task 3: Create git process wrapper unit** - `9eef5af` (feat)

## Files Created/Modified
- `src/DX.Blame.Git.Types.pas` - TBlameLineInfo record, TBlameData class, pipeline constants
- `src/DX.Blame.Git.Discovery.pas` - Git executable finder and repo root detection with caching
- `src/DX.Blame.Git.Process.pas` - Safe CreateProcess wrapper with pipe capture and cancellation
- `src/DX.Blame.dpk` - Added all three new units to contains clause

## Decisions Made
- Discovery unit has its own internal ExecuteGitSync function rather than depending on TGitProcess, avoiding a circular unit dependency while keeping rev-parse verification inline
- TGitProcess.Execute is a thin wrapper over ExecuteAsync that closes the process handle, ensuring a single code path for the CreateProcess logic
- Qualified GetEnvironmentVariable calls with System.SysUtils prefix to resolve ambiguity with Winapi.Windows overload

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added System.Classes to Discovery unit uses clause**
- **Found during:** Task 2 (Git discovery unit)
- **Issue:** TBytesStream is declared in System.Classes, which was missing from the uses clause
- **Fix:** Added System.Classes to the implementation uses clause
- **Files modified:** src/DX.Blame.Git.Discovery.pas
- **Verification:** Build succeeded after fix
- **Committed in:** b96a875 (Task 2 commit)

**2. [Rule 1 - Bug] Qualified GetEnvironmentVariable to avoid ambiguity**
- **Found during:** Task 2 (Git discovery unit)
- **Issue:** Both System.SysUtils and Winapi.Windows export GetEnvironmentVariable with different signatures
- **Fix:** Qualified all calls as System.SysUtils.GetEnvironmentVariable
- **Files modified:** src/DX.Blame.Git.Discovery.pas
- **Verification:** Build succeeded after fix
- **Committed in:** b96a875 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both fixes necessary for compilation. No scope creep.

## Issues Encountered
- PowerShell execution policy blocked the build script; resolved by using `-ExecutionPolicy Bypass` flag

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All three foundation units compile and are registered in the DPK
- Ready for Plan 02 (porcelain parser) and Plan 03 (cache, notifiers, engine) to build on these types and utilities
- TGitProcess is ready to be used by the blame thread for async git blame execution

---
*Phase: 02-blame-data-pipeline*
*Completed: 2026-03-19*
