# Phase 2: Blame Data Pipeline - Research

**Researched:** 2026-03-19
**Domain:** Git blame CLI integration, OTA editor notifiers, async process execution, thread-safe caching
**Confidence:** HIGH

## Summary

Phase 2 builds the entire data pipeline: detecting git, running `git blame --line-porcelain` asynchronously via `CreateProcess` with pipe redirection, parsing the porcelain output into structured records, and storing results in a thread-safe per-file cache. The pipeline hooks into the IDE via OTA notifiers (IOTAIDENotifier for file open/close, IOTAModuleNotifier for file save) and delivers results to the main thread via `TThread.Queue`.

The technical domain is well-understood. Git blame porcelain format is stable and documented. Delphi's OTA notifier system has established patterns from GExperts and community plugins. CreateProcess pipe capture is a solved problem with clear patterns. Thread safety via `TCriticalSection` is straightforward for this use case (dictionary-style cache with infrequent writes).

**Primary recommendation:** Use `--line-porcelain` (not `--porcelain`) for simpler parsing -- every line gets full commit metadata, eliminating the need for a commit info lookup table during parsing. The slight bandwidth overhead is negligible for source files.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Git Discovery:** Search system PATH first, then check common install locations (C:\Program Files\Git\cmd, etc.). Repo detection: filesystem walk for .git folder first, verify with `git rev-parse --show-toplevel`. Detection runs once on project open; cached until project switch.
- **Missing Git:** Show one-time non-modal notification (IDE Messages window), disable blame features silently -- menu stays greyed out.
- **Untracked files:** Silent skip -- no annotation, no message.
- **Blame failure on tracked files:** Log to IDE Messages window.
- **Uncommitted lines:** Show as "Not committed yet" (distinct annotation).
- **Error retry:** Retry once after ~2-3s delay for transient git lock issues; if retry fails, log and give up.
- **Cache eviction:** Invalidate on file save (triggers re-blame), remove from cache when tab is closed.
- **No max cache size:** Cache grows proportional to open tabs, tab close keeps it bounded.
- **Save debounce:** ~500ms debounce to avoid rapid re-blames during Save All or fast Ctrl+S.
- **Clear entire cache on project switch.**
- **Blame scope:** Entire file at once (not visible lines) -- one git process per file.
- **Triggers:** File open and file save only -- no periodic timer, no focus-based re-blame.
- **Large files (1000+ lines):** Same async behavior, no special handling.
- **Cancellation:** Terminate in-progress git process and discard results if tab is closed before blame finishes.

### Claude's Discretion
- Exact threading implementation (TThread subclass, anonymous thread, etc.)
- CreateProcess pipe reading strategy and buffer management
- Porcelain parser internal structure and data types
- Thread-safe cache implementation details (TCriticalSection, TMonitor, etc.)
- Exact notification mechanism from background thread to main thread
- Git path search order for common install locations

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BLAME-02 | Plugin erkennt automatisch ob das aktuelle Projekt in einem Git-Repository liegt | Git discovery pattern: .git folder walk + `git rev-parse --show-toplevel` verification; git.exe PATH search + common install locations |
| BLAME-03 | Blame wird beim Oeffnen einer Datei automatisch asynchron ausgefuehrt | IOTAIDENotifier.FileNotification with ofnFileOpened; TThread subclass for async execution |
| BLAME-04 | Git blame wird per CLI (`git blame --porcelain`) in einem Hintergrund-Thread ausgefuehrt | CreateProcess + anonymous pipe pattern; `--line-porcelain` flag; TThread subclass with cancellation |
| BLAME-05 | Blame-Ergebnisse werden pro Datei im Speicher gecacht | TDictionary<string, TBlameData> with TCriticalSection guard; TBlameLineInfo record for per-line data |
| BLAME-06 | Cache wird bei Datei-Save invalidiert und Blame automatisch neu ausgefuehrt | IOTAModuleNotifier.AfterSave or IOTAIDENotifier.FileNotification; 500ms debounce timer; cache invalidation + re-trigger |
</phase_requirements>

## Standard Stack

### Core
| Library/API | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| ToolsAPI (designide) | Delphi 11.3+ | OTA notifiers for file events | Only way to hook IDE file open/save/close events |
| Winapi.Windows (CreateProcess) | Win32 API | Execute git.exe and capture stdout | Standard Delphi pattern for CLI process execution |
| System.Generics.Collections | RTL | TDictionary for cache, TList for line data | Built-in, no external dependency |
| System.SyncObjs | RTL | TCriticalSection for thread-safe cache | Lightweight, well-tested, simple lock |
| System.Classes (TThread) | RTL | Background blame execution | Standard Delphi threading primitive |

### Supporting
| Library/API | Version | Purpose | When to Use |
|-------------|---------|---------|-------------|
| System.IOUtils (TPath, TDirectory) | RTL | .git folder detection, path operations | Git repo discovery walk |
| System.DateUtils | RTL | Unix timestamp to TDateTime conversion | Parsing author-time from porcelain output |
| Vcl.ExtCtrls (TTimer) | VCL | Debounce timer for save re-blame | 500ms debounce on file save |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TCriticalSection | TMonitor | TMonitor has overhead for simple lock patterns; TCriticalSection is faster for single-lock scenarios |
| TThread subclass | TTask (PPL) | TTask cannot be cancelled/terminated; we need to kill git process on tab close |
| --line-porcelain | --porcelain | --porcelain is more bandwidth-efficient but requires stateful parser to track commit info across lines |

## Architecture Patterns

### Recommended Unit Structure
```
src/
  DX.Blame.Git.Discovery.pas    -- Git executable finder + repo detection
  DX.Blame.Git.Process.pas      -- CreateProcess wrapper for git commands
  DX.Blame.Git.Blame.pas        -- Porcelain parser + blame data types
  DX.Blame.Cache.pas             -- Thread-safe per-file blame cache
  DX.Blame.IDE.Notifier.pas     -- OTA notifiers (file open/save/close)
  DX.Blame.Engine.pas           -- Orchestrator: ties notifiers to blame execution
```

### Pattern 1: Git Discovery (BLAME-02)
**What:** Find git.exe on the system, then detect whether the current project is in a git repo.
**When to use:** On project open (once), cached until project switch.

```pascal
// Step 1: Find git.exe
function FindGitExecutable: string;
// Search order:
// 1. System PATH (use FileSearch or iterate GetEnvironmentVariable('PATH'))
// 2. C:\Program Files\Git\cmd\git.exe
// 3. C:\Program Files (x86)\Git\cmd\git.exe
// 4. User-specific locations

// Step 2: Detect .git folder by walking parents
function FindGitRepoRoot(const APath: string): string;
var
  LDir: string;
begin
  LDir := APath;
  while LDir <> '' do
  begin
    if TDirectory.Exists(TPath.Combine(LDir, '.git')) then
      Exit(LDir);
    var LParent := TDirectory.GetParent(LDir);
    if LParent = LDir then
      Break; // root reached
    LDir := LParent;
  end;
  Result := ''; // not in a git repo
end;

// Step 3: Verify with git rev-parse --show-toplevel
// Run synchronously (fast, <100ms) -- only on project open
```

### Pattern 2: Async Blame Execution (BLAME-03, BLAME-04)
**What:** Run `git blame --line-porcelain <file>` in a background thread with pipe capture.
**When to use:** On file open, on file save (after debounce).

```pascal
TBlameThread = class(TThread)
private
  FFileName: string;
  FRepoRoot: string;
  FGitPath: string;
  FProcessHandle: THandle;
  FCancelled: Boolean;
  FOnComplete: TProc<string, TBlameData>; // filename -> parsed data
protected
  procedure Execute; override;
public
  procedure Cancel; // sets FCancelled, terminates process
end;

// CreateProcess setup:
// - CREATE_NO_WINDOW flag (no console flash)
// - STARTF_USESTDHANDLES for pipe redirection
// - Working directory = repo root
// - Command: git blame --line-porcelain -- "<relative-path>"
// - Close write end of pipe after CreateProcess
// - Read loop: ReadFile until ERROR_BROKEN_PIPE
// - Check FCancelled between reads for responsive cancellation
```

### Pattern 3: Porcelain Parser (BLAME-04)
**What:** Parse `--line-porcelain` output into structured records.
**When to use:** After git blame process completes.

```pascal
TBlameLineInfo = record
  CommitHash: string;    // 40-char SHA-1 (all zeros = uncommitted)
  Author: string;        // author name
  AuthorMail: string;    // <email>
  AuthorTime: TDateTime; // converted from Unix timestamp
  Summary: string;       // first line of commit message
  OriginalLine: Integer; // line in original file
  FinalLine: Integer;    // line in current file
  IsUncommitted: Boolean; // True when hash = 0000...
end;

TBlameData = class
  Lines: TArray<TBlameLineInfo>;  // indexed by final line number (1-based)
  FileName: string;
  Timestamp: TDateTime;  // when blame was executed
end;

// Parser state machine:
// 1. Read header: <hash> <orig-line> <final-line> [<num-lines>]
// 2. Read key-value pairs until TAB-prefixed content line
// 3. TAB line = actual source content (skip, we don't need it)
// 4. Repeat from step 1
//
// Uncommitted detection: hash = '0000000000000000000000000000000000000000'
//   -> set IsUncommitted := True, Author := 'Not committed yet'
```

### Pattern 4: Thread-Safe Cache (BLAME-05)
**What:** Per-file blame data storage, safe for concurrent read/write.
**When to use:** Always -- cache is the single source of truth for blame data.

```pascal
TBlameCache = class
private
  FLock: TCriticalSection;
  FData: TDictionary<string, TBlameData>;  // key = lowercase full path
public
  procedure Store(const AFileName: string; AData: TBlameData);
  function TryGet(const AFileName: string; out AData: TBlameData): Boolean;
  procedure Invalidate(const AFileName: string);
  procedure Clear; // on project switch
end;

// Lock strategy: single TCriticalSection guarding all dictionary operations.
// Low contention: writes happen only when blame completes or cache invalidates.
// Reads happen on main thread (rendering), writes happen from Queue callback.
// Keep lock duration minimal -- just the dictionary operation.
```

### Pattern 5: OTA Notifier Integration (BLAME-03, BLAME-06)
**What:** Hook into IDE file events to trigger blame and manage cache.
**When to use:** Plugin lifecycle.

```pascal
// IOTAIDENotifier for file open/close events
TDXBlameIDENotifier = class(TNotifierObject, IOTAIDENotifier)
  procedure FileNotification(NotifyCode: TOTAFileNotification;
    const FileName: string; var Cancel: Boolean);
  // ofnFileOpened -> trigger blame
  // ofnFileClosing -> cancel pending blame, remove from cache
  procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
  procedure AfterCompile(Succeeded: Boolean);
end;

// Registration pattern:
// GNotifierIndex := (BorlandIDEServices as IOTAServices).AddNotifier(LNotifier);
// Cleanup: (BorlandIDEServices as IOTAServices).RemoveNotifier(GNotifierIndex);

// For save detection, IOTAIDENotifier does NOT fire ofnFileSaved.
// Two approaches:
// A) Use IOTAModuleNotifier.AfterSave per module (complex: per-file notifier)
// B) Use INTAEditServicesNotifier (if available)
// Recommended: IOTAModuleNotifier approach for reliable save detection.
// Alternative: Watch for ofnFileOpened after save (some IDE versions re-fire).
// Safest: Implement IOTAModuleNotifier, attach to each opened module.
```

### Anti-Patterns to Avoid
- **Blocking the main thread with WaitForSingleObject:** Never wait for git process on the main thread. Always use TThread.
- **Using Synchronize instead of Queue:** Synchronize blocks the background thread. Use Queue for fire-and-forget result delivery.
- **Forgetting to close pipe write handle after CreateProcess:** Causes ReadFile to never return ERROR_BROKEN_PIPE -- deadlock.
- **Not terminating the git process on cancel:** TerminateProcess is required; just setting a flag and waiting is insufficient for a long-running git blame on a large file.
- **Lowercase path normalization:** Always lowercase file paths before cache lookup -- IDE may return paths with inconsistent casing.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Unix timestamp to TDateTime | Manual division/offset math | `UnixToDateTime()` from System.DateUtils | Handles UTC correctly, no off-by-one errors |
| Path parent walking | Manual string splitting | `TDirectory.GetParent()` / `TPath.GetDirectoryName()` | Handles UNC paths, trailing separators, root detection |
| Process creation boilerplate | Inline CreateProcess each time | Single `TGitProcess` wrapper class | Pipe setup, handle cleanup, error handling are error-prone |
| Thread-safe singleton access | Double-checked locking | Class var with initialization in `initialization` section | Delphi's unit initialization is single-threaded, safe by design |

**Key insight:** The CreateProcess + pipe pattern has at least 5 handle cleanup points (read pipe, write pipe, process handle, thread handle, security attributes). A wrapper class with try/finally is essential to prevent handle leaks.

## Common Pitfalls

### Pitfall 1: Pipe Deadlock
**What goes wrong:** Git blame output exceeds pipe buffer (~4KB default), git blocks waiting for pipe to drain, ReadFile never gets called because code is waiting for process to exit first.
**Why it happens:** Calling `WaitForSingleObject(ProcessHandle, INFINITE)` before reading the pipe.
**How to avoid:** Read the pipe in a loop first, then wait for process exit. Or read in the background thread while the process runs.
**Warning signs:** Plugin hangs when opening files with many lines.

### Pitfall 2: Handle Leak on Exception
**What goes wrong:** CreateProcess fails or ReadFile raises an exception, leaving pipe handles and process handles open.
**Why it happens:** Missing try/finally around the 5+ handles involved.
**How to avoid:** Wrap all handle creation in try/finally with CloseHandle in finally blocks. Use a helper class.
**Warning signs:** Handle count in Task Manager growing over time.

### Pitfall 3: Race Condition on Rapid Save
**What goes wrong:** User hits Ctrl+S rapidly. Multiple blame threads spawn for the same file, results arrive out of order, cache contains stale data from the first blame.
**Why it happens:** No debounce, no cancellation of previous blame.
**How to avoid:** 500ms debounce timer. Cancel previous blame thread before starting new one. Use a generation counter or timestamp to discard stale results.
**Warning signs:** Blame annotations briefly flicker or show wrong data after save.

### Pitfall 4: OTA Notifier Not Removed
**What goes wrong:** BPL unload crashes the IDE because the notifier is still registered.
**Why it happens:** Notifier index not stored, or RemoveNotifier not called in finalization.
**How to avoid:** Store notifier index in a unit-level var, remove in finalization section (same pattern as Phase 1 wizard cleanup).
**Warning signs:** Access violation on IDE shutdown or package uninstall.

### Pitfall 5: Git Process Orphaned After Cancel
**What goes wrong:** Tab closed while blame runs. Thread is freed but git.exe keeps running.
**Why it happens:** Thread.Terminate only sets the Terminated flag; it doesn't kill the child process.
**How to avoid:** Call `TerminateProcess(FProcessHandle, 1)` in the Cancel method, then wait briefly for thread to finish. Close the pipe read handle to unblock ReadFile.
**Warning signs:** Multiple git.exe processes accumulating in Task Manager.

### Pitfall 6: Encoding Issues in Git Output
**What goes wrong:** Author names with non-ASCII characters (umlauts, CJK) are garbled.
**Why it happens:** Git outputs UTF-8, but ReadFile gives raw bytes. Converting with wrong codepage.
**How to avoid:** Always decode pipe output as UTF-8. Use `TEncoding.UTF8.GetString(LBytes)` or read into a `TStringStream` with UTF-8 encoding.
**Warning signs:** German/international author names display incorrectly.

### Pitfall 7: File Path Mismatch Between IDE and Git
**What goes wrong:** IDE provides full path `C:\Projects\MyApp\src\Unit1.pas`, but git blame expects relative path from repo root.
**Why it happens:** Not converting IDE absolute path to git-relative path.
**How to avoid:** Compute relative path: `ExtractRelativePath(RepoRoot + '\', IDEFullPath)`. Use forward slashes for git.
**Warning signs:** Git blame returns "no such path" error.

## Code Examples

### CreateProcess Pipe Pattern (verified from Win32 API docs + Delphi community)
```pascal
function ExecuteGitCommand(const AGitPath, AWorkDir, AArgs: string;
  out AOutput: string; AProcessHandle: PHandle = nil): Integer;
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LBuffer: TBytes;
  LBytesRead: DWORD;
  LStream: TBytesStream;
  LExitCode: DWORD;
  LCmdLine: string;
begin
  Result := -1;
  AOutput := '';

  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  if not CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
    Exit;
  try
    // Prevent read handle from being inherited
    SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);

    FillChar(LSI, SizeOf(LSI), 0);
    LSI.cb := SizeOf(LSI);
    LSI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LSI.hStdOutput := LWritePipe;
    LSI.hStdError := LWritePipe;
    LSI.wShowWindow := SW_HIDE;

    LCmdLine := Format('"%s" %s', [AGitPath, AArgs]);

    if not CreateProcess(nil, PChar(LCmdLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(AWorkDir), LSI, LPI) then
      Exit;
    try
      // Close write end -- critical to avoid deadlock
      CloseHandle(LWritePipe);
      LWritePipe := 0;

      // Expose process handle for cancellation if requested
      if AProcessHandle <> nil then
        AProcessHandle^ := LPI.hProcess;

      // Read all output
      LStream := TBytesStream.Create;
      try
        SetLength(LBuffer, 4096);
        while ReadFile(LReadPipe, LBuffer[0], Length(LBuffer), LBytesRead, nil)
          and (LBytesRead > 0) do
          LStream.WriteBuffer(LBuffer[0], LBytesRead);

        AOutput := TEncoding.UTF8.GetString(LStream.Bytes, 0, LStream.Size);
      finally
        LStream.Free;
      end;

      WaitForSingleObject(LPI.hProcess, 5000);
      GetExitCodeProcess(LPI.hProcess, LExitCode);
      Result := LExitCode;
    finally
      CloseHandle(LPI.hThread);
      // Don't close hProcess here if exposed for cancellation
      if (AProcessHandle = nil) or (AProcessHandle^ <> LPI.hProcess) then
        CloseHandle(LPI.hProcess);
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    CloseHandle(LReadPipe);
  end;
end;
```

### Porcelain Parser Pattern
```pascal
// Verified against actual git blame --line-porcelain output from this repo.
// Format per line entry:
//   <40-char-hash> <orig-line> <final-line> [<group-count>]
//   author <name>
//   author-mail <<email>>
//   author-time <unix-timestamp>
//   author-tz <timezone>
//   committer <name>
//   committer-mail <<email>>
//   committer-time <unix-timestamp>
//   committer-tz <timezone>
//   summary <commit message first line>
//   [previous <hash> <filename>]    -- optional
//   filename <path>
//   \t<actual line content>

// Uncommitted lines have:
//   hash = 0000000000000000000000000000000000000000
//   author = "Not Committed Yet"
//   author-mail = "<not.committed.yet>"

const
  cUncommittedHash = '0000000000000000000000000000000000000000';

procedure ParseBlameOutput(const AOutput: string; var ALines: TArray<TBlameLineInfo>);
var
  LTextLines: TArray<string>;
  i: Integer;
  LInfo: TBlameLineInfo;
  LLineList: TList<TBlameLineInfo>;
begin
  LTextLines := AOutput.Split([#10]);
  LLineList := TList<TBlameLineInfo>.Create;
  try
    i := 0;
    while i < Length(LTextLines) do
    begin
      // Header line: hash orig-line final-line [count]
      if (Length(LTextLines[i]) >= 40) and (LTextLines[i][1] in ['0'..'9','a'..'f']) then
      begin
        FillChar(LInfo, SizeOf(LInfo), 0);
        // Parse header...
        LInfo.CommitHash := Copy(LTextLines[i], 1, 40);
        LInfo.IsUncommitted := (LInfo.CommitHash = cUncommittedHash);
        // Parse remaining parts for line numbers...
        Inc(i);
        // Read key-value pairs until TAB-prefixed content line
        while (i < Length(LTextLines)) and
              (Length(LTextLines[i]) > 0) and
              (LTextLines[i][1] <> #9) do
        begin
          if LTextLines[i].StartsWith('author ') then
            LInfo.Author := Copy(LTextLines[i], 8, MaxInt)
          else if LTextLines[i].StartsWith('author-mail ') then
            LInfo.AuthorMail := Copy(LTextLines[i], 13, MaxInt)
          else if LTextLines[i].StartsWith('author-time ') then
            LInfo.AuthorTime := UnixToDateTime(StrToInt64(Copy(LTextLines[i], 13, MaxInt)))
          else if LTextLines[i].StartsWith('summary ') then
            LInfo.Summary := Copy(LTextLines[i], 9, MaxInt);
          Inc(i);
        end;
        // Skip TAB-prefixed content line
        if (i < Length(LTextLines)) and (Length(LTextLines[i]) > 0)
          and (LTextLines[i][1] = #9) then
          Inc(i);

        LLineList.Add(LInfo);
      end
      else
        Inc(i);
    end;
    ALines := LLineList.ToArray;
  finally
    LLineList.Free;
  end;
end;
```

### OTA Notifier Registration Pattern
```pascal
// Source: Established OTA pattern from GExperts, DGH OTA Template

// Register in initialization or Register procedure:
var
  GIDENotifierIndex: Integer = -1;

procedure RegisterIDENotifier;
var
  LServices: IOTAServices;
begin
  if Supports(BorlandIDEServices, IOTAServices, LServices) then
    GIDENotifierIndex := LServices.AddNotifier(TDXBlameIDENotifier.Create);
end;

// Cleanup in finalization:
procedure UnregisterIDENotifier;
var
  LServices: IOTAServices;
begin
  if (GIDENotifierIndex >= 0) and Assigned(BorlandIDEServices) then
    if Supports(BorlandIDEServices, IOTAServices, LServices) then
      LServices.RemoveNotifier(GIDENotifierIndex);
end;

// FileNotification handler:
procedure TDXBlameIDENotifier.FileNotification(
  NotifyCode: TOTAFileNotification;
  const FileName: string; var Cancel: Boolean);
begin
  case NotifyCode of
    ofnFileOpened:
      BlameEngine.RequestBlame(FileName);
    ofnFileClosing:
      BlameEngine.CancelAndRemove(FileName);
  end;
end;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TThread.Synchronize | TThread.Queue / ForceQueue | Delphi XE+ | Non-blocking result delivery to main thread |
| TRTLCriticalSection (record) | TCriticalSection (class) | Delphi XE+ | Auto-initialization, easier lifecycle |
| ShellExecute for CLI | CreateProcess + pipes | Always preferred | Capture stdout; ShellExecute cannot redirect output |
| git blame (default format) | git blame --line-porcelain | Git 1.8.4+ | Machine-readable output, stable format |
| IOTAIDENotifier (legacy) | IOTAIDENotifier + IOTAModuleNotifier | Delphi 5+ | Module notifier gives reliable AfterSave |

**Deprecated/outdated:**
- `TThread.Suspend`/`TThread.Resume`: Deprecated since Delphi XE. Use `TEvent` or `TThread.Start` instead.
- `AnsiString` for pipe reading: Use `TBytes` + `TEncoding.UTF8` for correct Unicode handling.

## Open Questions

1. **Save detection reliability across Delphi versions**
   - What we know: `IOTAIDENotifier.FileNotification` fires `ofnFileOpened` and `ofnFileClosing` reliably. There is no `ofnFileSaved` constant.
   - What's unclear: Whether `IOTAModuleNotifier.AfterSave` fires reliably in Delphi 13. Some forum posts mention quirks in older versions.
   - Recommendation: Implement `IOTAModuleNotifier.AfterSave` as primary save detection. If it proves unreliable, fall back to polling file modification time. Test in target Delphi version during implementation.

2. **Project switch detection**
   - What we know: Need to clear cache on project switch. `ofnProjectDesktopLoad` fires when a project is loaded.
   - What's unclear: Exact sequence of notifications when switching projects in a project group.
   - Recommendation: Listen for `ofnProjectDesktopLoad` to trigger cache clear and re-detect git repo. Also consider `IOTAIDENotifier80.AfterCompile` project parameter changes.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (via git submodule in libs/DUnitX) |
| Config file | tests/DX.Blame.Tests.dproj |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Platform Win64 -Config Debug && build\Win64\Debug\DX.Blame.Tests.exe` |
| Full suite command | Same as quick run (single test project) |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BLAME-02 | Git repo detection by .git folder walk | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-02 | Git executable discovery on PATH | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-03 | Async blame completes without blocking | integration | Manual (IDE) | No - manual only |
| BLAME-04 | Porcelain output parsed correctly | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-04 | Uncommitted lines detected (all-zero hash) | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-05 | Cache stores and retrieves blame data | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-05 | Cache is thread-safe under concurrent access | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |
| BLAME-06 | Cache invalidation removes stale data | unit | `build\Win64\Debug\DX.Blame.Tests.exe` | No - Wave 0 |

### Sampling Rate
- **Per task commit:** `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Platform Win64 -Config Debug && build\Win64\Debug\DX.Blame.Tests.exe`
- **Per wave merge:** Same command (single test project)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/DX.Blame.Tests.Git.Discovery.pas` -- covers BLAME-02 (git finder, repo detection with mock filesystem)
- [ ] `tests/DX.Blame.Tests.Git.Blame.pas` -- covers BLAME-04 (porcelain parser with sample output strings)
- [ ] `tests/DX.Blame.Tests.Cache.pas` -- covers BLAME-05, BLAME-06 (cache store/get/invalidate/clear)
- [ ] Update `tests/DX.Blame.Tests.dpr` uses clause to include new test units
- [ ] Update `tests/DX.Blame.Tests.dproj` to reference new test unit files

## Sources

### Primary (HIGH confidence)
- [Git official docs - git-blame](https://git-scm.com/docs/git-blame) -- porcelain format specification, --line-porcelain option
- [Microsoft Learn - CreateProcess with redirected I/O](https://learn.microsoft.com/en-us/windows/win32/procthread/creating-a-child-process-with-redirected-input-and-output) -- pipe pattern reference
- Actual `git blame --line-porcelain` output from this repository -- verified format, uncommitted line representation

### Secondary (MEDIUM confidence)
- [Embarcadero OTAPI-Docs](https://github.com/Embarcadero/OTAPI-Docs/blob/main/The%20Delphi%20IDE%20Open%20Tools%20API%20-%20Version%201.2.md) -- IOTAIDENotifier, TOTAFileNotification, IOTAModuleNotifier
- [Dave's Development Blog - OTA Notifiers](https://www.davidghoyle.co.uk/WordPress/?p=1272) -- FileNotification constants, notifier lifecycle
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) -- notifier registration patterns
- [RAD Studio API Docs - TThread.Queue](https://docwiki.embarcadero.com/Libraries/Sydney/en/System.Classes.TThread.Queue) -- Queue vs Synchronize vs ForceQueue semantics
- [GitHub Gist - ExecAndCapture](https://gist.github.com/hotsoft-desenv2/bed7a75bbe19f19b163d2059fe85c57e) -- CreateProcess pipe pattern for Delphi

### Tertiary (LOW confidence)
- [DelphiTools - TMonitor vs TCriticalSection](https://www.delphitools.info/2013/06/06/tmonitor-vs-trtlcriticalsection/) -- performance comparison (2013, may not reflect modern Delphi)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- all RTL/VCL/ToolsAPI, no third-party dependencies
- Architecture: HIGH -- patterns well-established in Delphi plugin ecosystem
- Pitfalls: HIGH -- verified against real git blame output and known CreateProcess issues
- OTA save detection: MEDIUM -- IOTAModuleNotifier.AfterSave behavior may vary across Delphi versions

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable domain, unlikely to change)
