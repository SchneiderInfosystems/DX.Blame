# Architecture Patterns

**Domain:** VCS abstraction layer for Delphi IDE blame plugin (Mercurial integration into existing Git architecture)
**Researched:** 2026-03-23

## Recommended Architecture

### Strategy: Interface-Based VCS Provider with Minimal Refactoring

The existing codebase has 18 production units with Git-specific coupling concentrated in 4 units (`DX.Blame.Git.Types`, `DX.Blame.Git.Blame`, `DX.Blame.Git.Process`, `DX.Blame.Git.Discovery`). The remaining 14 units consume Git types but are otherwise VCS-agnostic in their logic. The recommended approach introduces a VCS provider interface that the engine dispatches to, while promoting the existing `TBlameLineInfo` and `TBlameData` to VCS-neutral shared types.

```
                    DX.Blame.VCS.Types (shared data contracts)
                           |
                    DX.Blame.VCS.Provider (IVCSProvider interface)
                         /    \
        DX.Blame.Git.Provider   DX.Blame.Hg.Provider
              |                       |
     DX.Blame.Git.Process     DX.Blame.Hg.Process
     DX.Blame.Git.Blame       DX.Blame.Hg.Blame
     DX.Blame.Git.Discovery   DX.Blame.Hg.Discovery
                         \    /
                    DX.Blame.VCS.Discovery (auto-detection, .git/.hg)
                           |
                    DX.Blame.Engine (dispatches via IVCSProvider)
                           |
              [Cache, Renderer, Popup, Diff, Navigation, etc.]
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `DX.Blame.VCS.Types` | VCS-neutral data contracts (`TBlameLineInfo`, `TBlameData`, constants) | All units that currently use `DX.Blame.Git.Types` |
| `DX.Blame.VCS.Provider` | `IVCSProvider` interface definition | Engine, providers |
| `DX.Blame.VCS.Discovery` | Auto-detect `.git`/`.hg`, find executables, select provider | Engine |
| `DX.Blame.Git.Provider` | `IVCSProvider` implementation delegating to Git sub-units | Engine (via interface) |
| `DX.Blame.Git.Process` | **Unchanged** -- CreateProcess wrapper for `git.exe` | Git.Provider, Git.Discovery |
| `DX.Blame.Git.Blame` | **Unchanged** -- porcelain parser | Git.Provider |
| `DX.Blame.Git.Discovery` | **Minor change** -- extract reusable parts to VCS.Discovery | VCS.Discovery |
| `DX.Blame.Hg.Provider` | `IVCSProvider` implementation delegating to Hg sub-units | Engine (via interface) |
| `DX.Blame.Hg.Process` | CreateProcess wrapper for `hg.exe` (adapted from Git.Process) | Hg.Provider, Hg.Discovery |
| `DX.Blame.Hg.Blame` | Parser for `hg annotate --template` output | Hg.Provider |
| `DX.Blame.Hg.Discovery` | Find `hg.exe` (PATH + common locations) | VCS.Discovery |
| `DX.Blame.Engine` | **Modified** -- uses `IVCSProvider` instead of direct Git calls | VCS.Provider, Cache |
| `DX.Blame.Settings` | **Extended** -- VCS preference per project | Settings.Form |
| `DX.Blame.Cache` | **Unchanged** -- already VCS-agnostic (keyed by file path) | Engine |
| `DX.Blame.Renderer` | **Minimal change** -- uses renamed from `DX.Blame.Git.Types` to `DX.Blame.VCS.Types` | Engine, Cache, Formatter |
| `DX.Blame.Formatter` | **Minimal change** -- uses renamed types unit | Renderer, Navigation |
| `DX.Blame.CommitDetail` | **Modified** -- uses `IVCSProvider` for fetches | Popup, Diff.Form |
| `DX.Blame.Navigation` | **Modified** -- uses `IVCSProvider` for file-at-revision | Renderer context menu |
| `DX.Blame.Popup` | **Minimal change** -- uses renamed types unit | Renderer |
| `DX.Blame.Diff.Form` | **Minimal change** -- uses renamed types unit | Popup |

### Data Flow

**Initialization (project open / switch):**
1. `Engine.Initialize(ProjectPath)` calls `VCS.Discovery.DetectVCS(ProjectPath)`
2. `VCS.Discovery` walks parent dirs for `.git`/`.hg`, checks executable availability
3. If both found: check `Settings.VCSPreference` for this project; if unset, prompt user
4. Returns configured `IVCSProvider` instance (or nil if no VCS)
5. Engine stores provider reference for blame/detail/navigation dispatch

**Blame request:**
1. Engine calls `FProvider.ExecuteBlame(FileName)` -- returns raw output string + exit code
2. Engine calls `FProvider.ParseBlame(RawOutput)` -- returns `TArray<TBlameLineInfo>`
3. Engine wraps in `TBlameData`, stores in Cache
4. Renderer paints from Cache (unchanged logic)

**Commit detail fetch:**
1. `CommitDetail` thread calls `FProvider.FetchCommitMessage(Hash)` for full message
2. Calls `FProvider.FetchFileDiff(Hash, RelPath)` for file-specific diff
3. Calls `FProvider.FetchFullDiff(Hash)` for full commit diff
4. All three return strings, parsed identically to current flow

**Navigation (file at revision):**
1. `Navigation` calls `FProvider.GetFileAtRevision(Hash, RelPath)` -- returns file content string
2. Writes to temp file, opens in IDE (unchanged logic)

## IVCSProvider Interface Definition

```pascal
type
  /// <summary>
  /// Abstraction for version control system operations.
  /// Implemented by Git and Mercurial providers.
  /// </summary>
  IVCSProvider = interface
    ['{GUID}']
    /// <summary>Display name for UI/logging ("Git" or "Mercurial").</summary>
    function GetDisplayName: string;

    /// <summary>Finds the VCS executable. Returns empty string if not found.</summary>
    function FindExecutable: string;

    /// <summary>Finds the repository root for the given path. Returns empty string if not a repo.</summary>
    function FindRepoRoot(const APath: string): string;

    /// <summary>
    /// Executes blame for a file. Returns exit code.
    /// AOutput receives raw CLI output. AProcessHandle for cancellation.
    /// </summary>
    function ExecuteBlame(const ARepoRoot, AFileName: string;
      out AOutput: string; var AProcessHandle: THandle): Integer;

    /// <summary>Parses raw blame output into normalized TBlameLineInfo array.</summary>
    procedure ParseBlame(const AOutput: string; var ALines: TArray<TBlameLineInfo>);

    /// <summary>Fetches full commit message for the given hash/changeset.</summary>
    function FetchCommitMessage(const ARepoRoot, AHash: string): string;

    /// <summary>Fetches file-specific diff for a commit.</summary>
    function FetchFileDiff(const ARepoRoot, AHash, ARelPath: string): string;

    /// <summary>Fetches full commit diff.</summary>
    function FetchFullDiff(const ARepoRoot, AHash: string): string;

    /// <summary>Retrieves file content at a specific revision.</summary>
    function GetFileAtRevision(const ARepoRoot, AHash, ARelPath: string): string;

    /// <summary>Cancels a running process by handle.</summary>
    procedure CancelProcess(var AProcessHandle: THandle);

    /// <summary>Clears any cached discovery data (executable path, repo root).</summary>
    procedure ClearDiscoveryCache;
  end;
```

## Mercurial CLI Command Mapping

The following maps each Git command used in v1.0 to its Mercurial equivalent:

| Operation | Git Command (v1.0) | Mercurial Equivalent |
|-----------|--------------------|-----------------------|
| Blame | `git blame --line-porcelain -- <file>` | `hg annotate --template "{node}\n{user}\n{date\|hgdate}\n{desc\|firstline}\n{lineno}\n" <file>` |
| Repo root | `git rev-parse --show-toplevel` | `hg root` |
| Full commit message | `git log -1 --format=%B <hash>` | `hg log -r <hash> --template "{desc}"` |
| File diff | `git show <hash> -- <file>` | `hg diff -c <hash> <file>` |
| Full diff | `git show <hash>` | `hg log -r <hash> -p --template "{desc}\n\n"` or `hg export <hash>` |
| File at revision | `git show <hash>:<relpath>` | `hg cat -r <hash> <file>` |
| Executable search | `git.exe` in PATH | `hg.exe` in PATH + common install locations (TortoiseHg) |

### Mercurial Annotate Template Design

The key design decision is the `hg annotate --template` format. Mercurial's template engine allows structured output that is easy to parse:

```
hg annotate --template "{node|short}\t{user}\t{date|hgdate}\t{desc|firstline}\t{lineno}\t{line}" <file>
```

However, `{line}` already includes a newline, making tab-delimited per-line parsing straightforward. For maximum reliability (handling tabs in commit messages), use a multi-line format with sentinel separators:

```
hg annotate --template "{node}\n{user}\n{date|hgdate}\n{desc|firstline}\n" <file>
```

This outputs a 4-line block per blame line, followed by the source line. The parser reads in fixed-size blocks.

**Important:** Mercurial uses revision-local integer IDs alongside global 40-char node hashes. Always use `{node}` (full hash) for consistency with the existing `TBlameLineInfo.CommitHash` field. The `{date|hgdate}` filter outputs `<unix-timestamp> <tz-offset>`, directly parseable like Git's `author-time`.

### Uncommitted Lines in Mercurial

Mercurial annotate marks working-copy changes differently than Git. Lines from the working directory that are not committed show the parent changeset, not an all-zeros hash. To detect uncommitted changes, either:
- Use `hg annotate --include-resolve` (not available in all versions)
- Compare annotate output against `hg status` to detect modified files

For v1.1, the pragmatic approach is to not distinguish uncommitted lines in Mercurial (annotate always shows the last committed state), matching `hg annotate` standard behavior. This is functionally equivalent since the plugin already skips blame when `Buffer.IsModified`.

## Units Classification: New vs Modified vs Unchanged

### New Units (7)

| Unit | Purpose | Depends On |
|------|---------|-----------|
| `DX.Blame.VCS.Types` | VCS-neutral `TBlameLineInfo`, `TBlameData`, constants | RTL only |
| `DX.Blame.VCS.Provider` | `IVCSProvider` interface definition | `DX.Blame.VCS.Types` |
| `DX.Blame.VCS.Discovery` | Auto-detect VCS, instantiate correct provider | `VCS.Provider`, `Git.Provider`, `Hg.Provider` |
| `DX.Blame.Hg.Provider` | `IVCSProvider` implementation for Mercurial | `VCS.Provider`, `Hg.Process`, `Hg.Blame`, `Hg.Discovery` |
| `DX.Blame.Hg.Process` | CreateProcess wrapper for `hg.exe` | RTL, WinAPI |
| `DX.Blame.Hg.Blame` | Parser for `hg annotate --template` output | `VCS.Types` |
| `DX.Blame.Hg.Discovery` | Find `hg.exe` on PATH and common locations | RTL |

### Modified Units (7)

| Unit | Change Description | Effort |
|------|--------------------|--------|
| `DX.Blame.Engine` | Replace direct `Git.Discovery`/`Git.Process`/`Git.Blame` calls with `IVCSProvider` dispatch. Replace `FGitPath`/`FGitAvailable` with `FProvider: IVCSProvider`/`FVCSAvailable`. | **Medium** -- core refactoring |
| `DX.Blame.CommitDetail` | Replace `TGitProcess`+`FindGitExecutable` calls with `IVCSProvider` methods | **Medium** -- thread needs provider ref |
| `DX.Blame.Navigation` | Replace `GetFileAtCommit` (uses `TGitProcess`) with `IVCSProvider.GetFileAtRevision` | **Low** -- single function replacement |
| `DX.Blame.Settings` | Add `VCSPreference: TDXBlameVCSPreference` (Auto/Git/Mercurial) with INI persistence | **Low** -- add one enum + 2 lines in Load/Save |
| `DX.Blame.Settings.Form` | Add VCS preference dropdown to settings dialog | **Low** -- one TComboBox |
| `DX.Blame.Registration` | Update `Initialize` to use VCS discovery; minor log message changes | **Low** -- 3-4 lines |
| `DX.Blame.Git.Discovery` | Extract `FindGitRepoRoot` directory-walking logic to shared helper; keep Git-specific parts | **Low** -- refactor to delegate |

### Renamed/Moved Type (1 logical change, many files touched)

| Change | Files Affected |
|--------|---------------|
| `DX.Blame.Git.Types` renamed to `DX.Blame.VCS.Types` | All 14 units that `use DX.Blame.Git.Types` |

This is a mechanical rename. The types themselves (`TBlameLineInfo`, `TBlameData`, constants) are already VCS-neutral in structure. Only the unit name changes.

### Unchanged Units (7)

| Unit | Why Unchanged |
|------|--------------|
| `DX.Blame.Cache` | Already VCS-agnostic (keyed by file path, stores `TBlameData`) |
| `DX.Blame.Renderer` | Only consumes `TBlameLineInfo` from cache; no VCS calls |
| `DX.Blame.Popup` | Only displays data from `TBlameLineInfo`; no VCS calls |
| `DX.Blame.Diff.Form` | Only displays diff strings; no VCS calls |
| `DX.Blame.KeyBinding` | Toggle logic only; no VCS coupling |
| `DX.Blame.IDE.Notifier` | Delegates to Engine; no direct VCS calls |
| `DX.Blame.Version` | Version constants only |

(Note: Popup, Diff.Form, Renderer, Formatter need the `uses` clause updated from `DX.Blame.Git.Types` to `DX.Blame.VCS.Types` -- this is a mechanical rename, not a logic change.)

## Patterns to Follow

### Pattern 1: Provider Factory via Discovery

**What:** A single `DetectVCS` function returns the appropriate `IVCSProvider` based on directory structure and user preference.

**When:** During `Engine.Initialize` and `Engine.OnProjectSwitch`.

**Example:**
```pascal
function DetectVCS(const AProjectPath: string;
  APreference: TDXBlameVCSPreference): IVCSProvider;
var
  LHasGit, LHasHg: Boolean;
begin
  Result := nil;
  LHasGit := DirectoryExists(FindVCSRoot(AProjectPath, '.git'));
  LHasHg := DirectoryExists(FindVCSRoot(AProjectPath, '.hg'));

  case APreference of
    vcsAuto:
      begin
        if LHasGit and LHasHg then
          // Both present: prompt user or use last-saved preference
          Result := PromptVCSChoice(AProjectPath)
        else if LHasGit then
          Result := TGitProvider.Create
        else if LHasHg then
          Result := THgProvider.Create;
      end;
    vcsGit:
      if LHasGit then Result := TGitProvider.Create;
    vcsMercurial:
      if LHasHg then Result := THgProvider.Create;
  end;
end;
```

### Pattern 2: Reuse TGitProcess Pattern for THgProcess

**What:** `THgProcess` mirrors `TGitProcess` exactly -- CreateProcess wrapper with pipe capture, sync/async execution, and cancellation.

**When:** All Mercurial CLI operations.

**Example:**
```pascal
type
  THgProcess = class
  private
    FHgPath: string;
    FWorkDir: string;
  public
    constructor Create(const AHgPath, AWorkDir: string);
    function Execute(const AArgs: string; out AOutput: string): Integer;
    function ExecuteAsync(const AArgs: string; out AOutput: string;
      var AProcessHandle: THandle): Integer;
    class procedure CancelProcess(var AProcessHandle: THandle);
  end;
```

The implementation is identical to `TGitProcess` -- only the executable path differs. Consider extracting a shared `TVCSProcess` base class to eliminate duplication (DRY).

### Pattern 3: Shared Process Base Class (DRY)

**What:** Extract `TGitProcess` logic into `TVCSProcess` base class. Both `TGitProcess` and `THgProcess` become thin wrappers or direct aliases.

**When:** Since the CreateProcess logic is 100% identical (only the executable path differs), this avoids code duplication.

**Example:**
```pascal
// DX.Blame.VCS.Process
type
  TVCSProcess = class
  private
    FExePath: string;
    FWorkDir: string;
  public
    constructor Create(const AExePath, AWorkDir: string);
    function Execute(const AArgs: string; out AOutput: string): Integer;
    function ExecuteAsync(const AArgs: string; out AOutput: string;
      var AProcessHandle: THandle): Integer;
    class procedure CancelProcess(var AProcessHandle: THandle);
  end;
```

Then `TGitProcess = TVCSProcess` (type alias) and `THgProcess = TVCSProcess`. Or keep the concrete classes as thin constructors that pass the executable name.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Dual-Provider Complexity

**What:** Supporting multiple VCS providers simultaneously for the same project (e.g., blame from Git for file A, Mercurial for file B).

**Why bad:** Massively increases complexity. Cache invalidation, discovery, and engine state would need per-file VCS tracking. The v1.0 architecture assumes one engine state per project.

**Instead:** One provider per project session. User selects when both are present. Switch requires project re-initialization.

### Anti-Pattern 2: Abstract Class Hierarchy Instead of Interface

**What:** Using `TVCSProvider = class(TObject)` with virtual methods instead of `IVCSProvider = interface`.

**Why bad:** In Delphi, interfaces provide automatic reference counting, clean separation, and are idiomatic for plugin-style architectures. Abstract classes require manual lifetime management and tighter coupling.

**Instead:** Use `IVCSProvider` interface. Provider implementations are classes that implement the interface but are managed via interface references.

### Anti-Pattern 3: Modifying TBlameLineInfo for Mercurial Specifics

**What:** Adding Mercurial-specific fields (e.g., `RevisionNumber: Integer`) to `TBlameLineInfo`.

**Why bad:** Pollutes the shared type with VCS-specific concerns. The renderer, formatter, popup, and diff form would need to handle fields that may or may not be populated.

**Instead:** `TBlameLineInfo` stays as-is (already contains exactly the fields needed for display). Mercurial provider maps its data into the same fields. Mercurial revision numbers are not needed for display.

### Anti-Pattern 4: Parsing Output in the Engine

**What:** Moving blame parsing logic into `TBlameEngine` with VCS-specific branches.

**Why bad:** Violates SoC. Engine becomes a god class that knows about both Git porcelain format and Mercurial template format.

**Instead:** Each provider implements `ParseBlame` internally. Engine only calls the interface method.

## VCS Auto-Detection Algorithm

```
1. Walk parent directories from project path
2. For each directory, check:
   a. Does .git/ subdirectory exist?
   b. Does .hg/ subdirectory exist?
3. Record first .git root and first .hg root found
4. Apply preference:
   - Auto + only one found -> use that one
   - Auto + both found -> prompt user (with "remember for this project" checkbox)
   - Explicit Git/Mercurial -> use that if available, else disabled
5. Verify chosen VCS:
   - Git: run `git rev-parse --show-toplevel` (existing logic)
   - Hg: run `hg root` (equivalent verification)
6. If executable not found -> log warning, disable blame
```

## Suggested Build Order

The build order respects dependencies and enables incremental testing:

| Phase | Units | Rationale |
|-------|-------|-----------|
| **1. Shared types** | Rename `DX.Blame.Git.Types` to `DX.Blame.VCS.Types`; update all `uses` clauses | Foundation -- everything depends on this. Mechanical change, zero logic risk. Must compile cleanly before proceeding. |
| **2. Process abstraction** | Create `DX.Blame.VCS.Process` (extract from `DX.Blame.Git.Process`); refactor `DX.Blame.Git.Process` to delegate | DRY foundation for both providers. Existing Git tests still pass. |
| **3. Interface + Git provider** | Create `DX.Blame.VCS.Provider` (interface); create `DX.Blame.Git.Provider` (wraps existing Git units) | Interface exists; Git keeps working through the new interface. No behavior change yet. |
| **4. Engine refactoring** | Modify `DX.Blame.Engine` to use `IVCSProvider` instead of direct Git calls | Critical refactoring. After this, Git blame works through the interface. Full regression test point. |
| **5. CommitDetail + Navigation** | Modify `DX.Blame.CommitDetail` and `DX.Blame.Navigation` to use `IVCSProvider` | Complete the VCS abstraction in all units that make CLI calls. |
| **6. VCS Discovery** | Create `DX.Blame.VCS.Discovery` (auto-detect .git/.hg) | Independent of Hg implementation. Can detect both repos even before Hg provider exists. |
| **7. Mercurial provider** | Create `DX.Blame.Hg.Discovery`, `DX.Blame.Hg.Process`, `DX.Blame.Hg.Blame`, `DX.Blame.Hg.Provider` | New functionality. All Hg-specific code in one batch. |
| **8. Settings + UI** | Extend `DX.Blame.Settings` and `DX.Blame.Settings.Form` for VCS preference | Settings depend on discovery knowing about both providers. |
| **9. Integration** | Wire VCS.Discovery into Engine.Initialize; handle dual-VCS prompt | Final assembly and end-to-end testing. |

## Scalability Considerations

| Concern | Current (Git only) | After v1.1 (Git + Hg) | Future (SVN etc.) |
|---------|-------------------|----------------------|-------------------|
| Adding a VCS | N/A | New provider class + discovery entry | Same pattern -- implement IVCSProvider |
| Process overhead | One executable type | Two executable types, same CreateProcess wrapper | Same pattern |
| Cache complexity | Single provider assumed | Single provider per project session | Unchanged |
| Settings complexity | None | One enum preference + per-project memory | Add enum value |
| Unit count | 18 units | ~25 units (+7 new) | +4 per new VCS |

## Sources

- Existing codebase analysis (18 production units in `Y:/DX.Blame/src/`)
- [Mercurial annotate help](https://www.mercurial-scm.org/repo/hg/help/annotate) -- template keywords, output format
- [Mercurial template documentation](https://book.mercurial-scm.org/read/template.html) -- `{node}`, `{user}`, `{date|hgdate}`, `{desc|firstline}`
- [hg root command](https://mercurial-scm.org/help/commands/root) -- repository root detection
- [hg cat command](https://mercurial-scm.org/help/commands/cat) -- file at revision (`hg cat -r <rev> <file>`)
- [Replicating git show in Mercurial](https://slaptijack.com/software/git-show-in-hg/) -- `hg diff -c <hash>` for commit diffs, `hg export` for full details
- [Mercurial hg log](https://www.mercurial-scm.org/help/commands/log.html) -- `hg log -r <hash> --template` for commit messages
- [Git vs Mercurial command mapping](https://hyperpolyglot.org/version-control) -- comprehensive command equivalence table
