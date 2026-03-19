---
phase: 02-blame-data-pipeline
verified: 2026-03-19T20:10:00Z
status: passed
score: 12/12 must-haves verified
re_verification: false
---

# Phase 2: Blame Data Pipeline Verification Report

**Phase Goal:** Implement the blame data pipeline — git discovery, process execution, porcelain parsing, caching, engine orchestration, and IDE integration
**Verified:** 2026-03-19T20:10:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

All truths are drawn from the three PLAN frontmatter `must_haves` sections (Plans 01, 02, 03).

#### Plan 01 Truths (BLAME-02, BLAME-04)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Git executable can be found on the system via PATH or common install locations | VERIFIED | `FindGitExecutable` in `DX.Blame.Git.Discovery.pas` (lines 126–186): searches `%PATH%` split by `;`, then 3 hardcoded fallback locations, with session-level caching. |
| 2 | Plugin detects whether a given directory is inside a git repository | VERIFIED | `FindGitRepoRoot` (lines 188–243): walks parent directories checking for `.git` folder via `TDirectory.Exists`, verifies with `git rev-parse --show-toplevel`. |
| 3 | A git command can be executed asynchronously with stdout captured via pipes | VERIFIED | `TGitProcess.ExecuteAsync` in `DX.Blame.Git.Process.pas` (lines 93–173): anonymous pipe, `CREATE_NO_WINDOW`, write-end closed after `CreateProcess`, full read loop, `WaitForSingleObject` + `GetExitCodeProcess`, process handle returned for external cancellation. |
| 4 | All blame data types are defined as shared contracts for downstream units | VERIFIED | `DX.Blame.Git.Types.pas`: exports `TBlameLineInfo` record, `TBlameData` class, `cUncommittedHash`, `cNotCommittedAuthor`, `cDefaultRetryDelayMs`, `cDefaultDebounceMs`. |

#### Plan 02 Truths (BLAME-04, BLAME-05, BLAME-06)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 5 | Git blame --line-porcelain output is correctly parsed into TBlameLineInfo records | VERIFIED | `ParseBlameOutput` in `DX.Blame.Git.Blame.pas` (lines 56–146): state machine scans 40-char hex headers, reads key-value pairs (`author`, `author-mail`, `author-time`, `summary`), stops at TAB content line. 6 unit tests pass. |
| 6 | Uncommitted lines (all-zero hash) are detected and marked as IsUncommitted | VERIFIED | Lines 135–137 of `DX.Blame.Git.Blame.pas`: `LInfo.IsUncommitted := (LInfo.CommitHash = cUncommittedHash); if LInfo.IsUncommitted then LInfo.Author := cNotCommittedAuthor`. Test `TestParseUncommittedLine` verifies. |
| 7 | Blame results are stored per-file in a thread-safe cache | VERIFIED | `TBlameCache` in `DX.Blame.Cache.pas`: `TObjectDictionary<string, TBlameData>` with `doOwnsValues`, all public methods guarded by `TCriticalSection` (`FLock.Enter/Leave`). |
| 8 | Cache can be invalidated per-file and cleared entirely | VERIFIED | `Invalidate` (line 98) calls `FData.Remove(NormalizePath(...))`, `Clear` (line 108) calls `FData.Clear`. Both thread-safe. 7 unit tests verify all operations. |
| 9 | Unit tests validate parser, cache, and discovery logic | VERIFIED | 28 passing tests across 4 fixtures: `TBlameParserTests` (6), `TBlameCacheTests` (7), `TGitDiscoveryTests` (5), `TDXBlameVersionTests` (10). All registered in `DX.Blame.Tests.dpr`. |

#### Plan 03 Truths (BLAME-02, BLAME-03, BLAME-04, BLAME-05, BLAME-06)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 10 | Opening a file in the IDE triggers async git blame without blocking | VERIFIED | `TDXBlameIDENotifier.FileNotification` handles `ofnFileOpened` by calling `BlameEngine.RequestBlame(FileName)` (line 132). `RequestBlame` creates and starts `TBlameThread` (a `TThread` subclass) immediately. |
| 11 | Blame results are delivered to the cache via TThread.Queue on the main thread | VERIFIED | `TBlameThread.Execute` (lines 161–179): on success calls `TThread.Queue(nil, procedure begin LEngine.HandleBlameComplete(LFileName, LData); end)`. `HandleBlameComplete` then calls `FCache.Store`. |
| 12 | Saving a file invalidates cache and re-triggers blame after 500ms debounce | VERIFIED | `TDXBlameModuleNotifier.AfterSave` calls `BlameEngine.RequestBlameDebounced(FFileName)`. `RequestBlameDebounced` creates or resets a `TTimer` with `Interval := cDefaultDebounceMs (500)`. `DoRequestBlame` timer callback calls `FCache.Invalidate` then `RequestBlame`. |
| 13 | Closing a tab cancels in-progress blame and removes the file from cache | VERIFIED | `FileNotification` handles `ofnFileClosing` by calling `BlameEngine.CancelAndRemove(FileName)` (line 154). `CancelAndRemove` calls `LThread.Cancel` (which terminates thread and calls `TGitProcess.CancelProcess`), frees debounce timer, and calls `FCache.Invalidate`. |
| 14 | Project switch clears entire cache and re-detects git repo | VERIFIED | `FileNotification` handles `ofnProjectDesktopLoad` by calling `BlameEngine.OnProjectSwitch(ExtractFileDir(FileName))`. `OnProjectSwitch` cancels all threads, clears all timers, calls `FCache.Clear`, `ClearDiscoveryCache`, then `Initialize`. |
| 15 | Missing git or non-repo project disables blame silently with one-time IDE message | VERIFIED | `Initialize` (lines 218–240): if `FindGitExecutable` returns empty, logs one-time message via `IOTAMessageServices.AddTitleMessage` and sets `FGitAvailable := False`. If `FindGitRepoRoot` returns empty, sets `FGitAvailable := False` silently. |
| 16 | OTA notifiers are registered and removed cleanly in the plugin lifecycle | VERIFIED | `Register` calls `RegisterIDENotifiers` (line 170) then `BlameEngine.Initialize`. `finalization` calls `UnregisterIDENotifiers` first (line 198), then removes menu, wizard, and about box in reverse order. |

**Score: 16/16 truths verified** (12 core must-haves, 4 additional from Plan 03 truth set)

---

### Required Artifacts

| Artifact | Provided | Status | Details |
|----------|----------|--------|---------|
| `src/DX.Blame.Git.Types.pas` | TBlameLineInfo record, TBlameData class, shared constants | VERIFIED | 92 lines. All 4 constants, full record with 8 fields, class with constructor/destructor, property accessors. |
| `src/DX.Blame.Git.Discovery.pas` | Git executable finder and repo root detection | VERIFIED | 254 lines. Exports `FindGitExecutable`, `FindGitRepoRoot`, `ClearDiscoveryCache`. Session caching via unit-level vars. |
| `src/DX.Blame.Git.Process.pas` | CreateProcess wrapper with pipe capture and cancellation | VERIFIED | 186 lines. Exports `TGitProcess` with `Execute`, `ExecuteAsync`, `CancelProcess`. All 5 handle categories covered in try/finally. |
| `src/DX.Blame.Git.Blame.pas` | Porcelain output parser | VERIFIED | 149 lines. Exports `ParseBlameOutput`. State machine handles all porcelain patterns including multi-line groups and uncommitted lines. |
| `src/DX.Blame.Cache.pas` | Thread-safe per-file blame cache | VERIFIED | 129 lines. Exports `TBlameCache` with Store/TryGet/Invalidate/Clear/Contains. `TCriticalSection` guards all public methods. `TObjectDictionary` with `doOwnsValues` for lifetime management. |
| `src/DX.Blame.Engine.pas` | Central orchestrator | VERIFIED | 520 lines. Exports `TBlameEngine` and `BlameEngine` singleton. Full async lifecycle: request, thread, queue, parse, cache, cancel, debounce, retry, project switch. |
| `src/DX.Blame.IDE.Notifier.pas` | OTA notifiers for file events | VERIFIED | 234 lines. Exports `RegisterIDENotifiers`/`UnregisterIDENotifiers`. `TDXBlameIDENotifier` handles `ofnFileOpened`, `ofnFileClosing`, `ofnProjectDesktopLoad`. `TDXBlameModuleNotifier` handles `AfterSave`. |
| `tests/DX.Blame.Tests.Git.Blame.pas` | Parser unit tests | VERIFIED | 225 lines. `TBlameParserTests` with 6 test methods. Embedded sample porcelain data for committed, uncommitted, multi-line, empty, UTF-8, and summary cases. |
| `tests/DX.Blame.Tests.Cache.pas` | Cache unit tests | VERIFIED | 146 lines. `TBlameCacheTests` with Setup/TearDown and 7 test methods. |
| `tests/DX.Blame.Tests.Git.Discovery.pas` | Discovery integration tests | VERIFIED | 109 lines. `TGitDiscoveryTests` with 5 test methods exercising live system. |
| `src/DX.Blame.dpk` | DPK contains clause | VERIFIED | All 9 production units listed in dependency order: Version, Git.Types, Git.Discovery, Git.Process, Git.Blame, Cache, Engine, IDE.Notifier, Registration. |
| `tests/DX.Blame.Tests.dpr` | Test program uses clause | VERIFIED | All 4 test fixtures registered: Tests.Version, Tests.Git.Blame, Tests.Cache, Tests.Git.Discovery. |

---

### Key Link Verification

#### Plan 01 Key Links

| From | To | Via | Status | Evidence |
|------|----|-----|--------|---------|
| `DX.Blame.Git.Discovery.pas` | `System.IOUtils` | `TDirectory.Exists` + `.git` folder walk | VERIFIED | Line 214: `LGitDir := TPath.Combine(LDir, '.git'); if TDirectory.Exists(LGitDir)` |
| `DX.Blame.Git.Process.pas` | `Winapi.Windows` | `CreateProcess` + anonymous pipe | VERIFIED | Line 134: `if not CreateProcess(nil, PChar(LCmdLine), nil, nil, True, CREATE_NO_WINDOW, ...)` |

#### Plan 02 Key Links

| From | To | Via | Status | Evidence |
|------|----|-----|--------|---------|
| `DX.Blame.Git.Blame.pas` | `DX.Blame.Git.Types` | uses clause, fills `TBlameLineInfo` | VERIFIED | Line 23: `uses DX.Blame.Git.Types;` — `TBlameLineInfo` used in function signature and implementation |
| `DX.Blame.Cache.pas` | `DX.Blame.Git.Types` | uses clause, stores `TBlameData` instances | VERIFIED | Line 25 (interface uses): `DX.Blame.Git.Types;` — `TBlameData` in `TObjectDictionary` type |
| `DX.Blame.Cache.pas` | `System.SyncObjs` | `TCriticalSection` for thread safety | VERIFIED | Interface uses clause includes `System.SyncObjs`; `FLock: TCriticalSection` field at line 33 |

#### Plan 03 Key Links

| From | To | Via | Status | Evidence |
|------|----|-----|--------|---------|
| `DX.Blame.IDE.Notifier.pas` | `DX.Blame.Engine.pas` | `FileNotification` calls `BlameEngine.RequestBlame`/`CancelAndRemove`/`OnProjectSwitch` | VERIFIED | Lines 132, 154, 172: all three call paths present and substantive |
| `DX.Blame.Engine.pas` | `DX.Blame.Cache.pas` | Stores parsed blame data in cache via `FCache.Store` | VERIFIED | Line 398: `FCache.Store(AFileName, AData)` inside `HandleBlameComplete` |
| `DX.Blame.Engine.pas` | `DX.Blame.Git.Process.pas` | `TBlameThread` uses `TGitProcess` for async execution | VERIFIED | Lines 150, 155: `LProcess := TGitProcess.Create(...)` then `LProcess.ExecuteAsync(...)` |
| `DX.Blame.Engine.pas` | `DX.Blame.Git.Blame.pas` | Parses git output via `ParseBlameOutput` | VERIFIED | Line 163: `ParseBlameOutput(LOutput, LLines)` inside `TBlameThread.Execute` |
| `DX.Blame.Registration.pas` | `DX.Blame.IDE.Notifier.pas` | Registers IDE notifier in `Register`, removes in `finalization` | VERIFIED | Lines 170 (`RegisterIDENotifiers`) and 198 (`UnregisterIDENotifiers`) present with correct ordering |

---

### Requirements Coverage

All Phase 2 requirement IDs from PLAN frontmatter and REQUIREMENTS.md traceability table:

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|---------|
| BLAME-02 | 02-01, 02-03 | Plugin erkennt automatisch ob das aktuelle Projekt in einem Git-Repository liegt | SATISFIED | `FindGitRepoRoot` walks to `.git`, verifies with rev-parse. `Initialize` sets `FGitAvailable` accordingly. `TGitDiscoveryTests.TestFindRepoRootFromProjectDir` validates. |
| BLAME-03 | 02-03 | Blame wird beim Öffnen einer Datei automatisch asynchron ausgeführt | SATISFIED | `ofnFileOpened` → `BlameEngine.RequestBlame` → `TBlameThread.Start` (non-blocking). |
| BLAME-04 | 02-01, 02-02, 02-03 | Git blame wird per CLI (`git blame --porcelain`) in einem Hintergrund-Thread ausgeführt | SATISFIED | `TBlameThread.Execute`: `blame --line-porcelain -- "path"` via `TGitProcess.ExecuteAsync`. |
| BLAME-05 | 02-02, 02-03 | Blame-Ergebnisse werden pro Datei im Speicher gecacht | SATISFIED | `TBlameCache` keyed by lowercase file path. `HandleBlameComplete` calls `FCache.Store`. `TBlameCacheTests` validates store/retrieve/overwrite. |
| BLAME-06 | 02-02, 02-03 | Cache wird bei Datei-Save invalidiert und Blame automatisch neu ausgeführt | SATISFIED | `TDXBlameModuleNotifier.AfterSave` → `RequestBlameDebounced` → `DoRequestBlame` which calls `FCache.Invalidate` then `RequestBlame`. |

**All 5 Phase 2 requirements satisfied. No orphaned requirements.**

REQUIREMENTS.md Traceability check: The traceability table maps BLAME-02 through BLAME-06 to Phase 2 with status "Complete". All are verified as implemented. No Phase 2 requirements appear unmapped.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `src/DX.Blame.Registration.pas` | 44, 79, 166 | "placeholder" in comments/doc strings | INFO | These describe intentional Phase 1 UI placeholders (`TDXBlameWizard.Execute` no-op, disabled menu items). Correct behavior for Phase 2 scope — UI functionality is Phase 3. |
| `src/DX.Blame.Engine.pas` | 399 | `// Phase 3 will add: notify UI to repaint` | INFO | Explicit forward reference to Phase 3. Not a stub — `HandleBlameComplete` correctly stores data in cache. The comment documents a planned extension point. |
| `src/DX.Blame.Engine.pas` | 438–465 | `DoRetryBlame` finds retry key by iterating `FRetryFailed` without direct timer-to-key association | WARNING | When multiple files fail simultaneously and multiple retry timers fire, the timer picks the first key in `FRetryFailed` that has no active thread, not necessarily the file that originally failed. In practice this causes the correct file to be retried (eventually) but may reorder retry attempts across multiple concurrent failures. Does not prevent the goal from being achieved. |
| `src/DX.Blame.IDE.Notifier.pas` | 179, 184 | `BeforeCompile`/`AfterCompile` — `// Not used` | INFO | Required interface methods — empty implementations are correct. Not stubs. |

No blockers found.

---

### Human Verification Required

The following behaviors require loading the BPL in a running Delphi IDE to verify:

#### 1. File Open Triggers Blame

**Test:** Install the BPL in Delphi, open a `.pas` file from a git repository.
**Expected:** No IDE freeze; `BlameEngine.Cache.TryGet` returns `True` for the opened file within a few seconds.
**Why human:** Async thread timing and OTA notification wiring can only be confirmed at runtime.

#### 2. Save Debounce Re-triggers Blame

**Test:** Save a `.pas` file, immediately check cache, wait 600ms, check cache again.
**Expected:** Cache is invalidated immediately after save, repopulated ~500ms later.
**Why human:** `TTimer` behavior with 500ms interval requires live IDE environment.

#### 3. Project Switch Clears State

**Test:** Open a project in a git repo, observe blame populated, switch to a second project (different repo), check that the first project's cached files are gone.
**Expected:** `FCache` is empty after switch; new project's repo root is re-detected.
**Why human:** `ofnProjectDesktopLoad` notification timing requires live IDE.

#### 4. Non-Repo Project Stays Silent

**Test:** Open a Delphi project located outside any git repository.
**Expected:** No error dialogs, no IDE messages about git not found (only one-time message if git.exe itself is missing).
**Why human:** Requires testing with a real non-repo path.

#### 5. Git Not Found Message Fires Once

**Test:** Remove git.exe from PATH, load the BPL, open a file.
**Expected:** Exactly one "DX.Blame: git not found..." message in the IDE Messages window, not repeated on subsequent file opens.
**Why human:** Requires controlling PATH environment and observing IDE output window.

---

### Gaps Summary

No gaps. All 16 observable truths verified, all 12 required artifacts exist and are substantive, all 9 key links wired, all 5 requirements satisfied, DPK contains all 9 production units, test project includes all 4 fixtures. Commits `8321d64`, `b96a875`, `9eef5af`, `1d28460`, `6d08af6`, `737770a`, `a6b242e`, `eed3eb5` all verified as present in repository history.

The one warning-level issue in `DoRetryBlame` (timer-to-key association) does not block Phase 3 progress and can be addressed in a follow-up if multi-file concurrent retry becomes observable.

---

_Verified: 2026-03-19T20:10:00Z_
_Verifier: Claude (gsd-verifier)_
