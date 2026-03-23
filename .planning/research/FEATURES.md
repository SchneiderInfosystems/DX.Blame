# Feature Landscape: Mercurial Blame Support (v1.1)

**Domain:** Delphi IDE Plugin -- VCS blame annotations (Mercurial extension)
**Researched:** 2026-03-23
**Confidence:** HIGH (Mercurial CLI is stable and well-documented)

## Table Stakes

Features that must exist for Mercurial support to feel complete. Users who switch from Git blame expect identical UX -- anything missing feels broken.

| Feature | Why Expected | Complexity | Dependencies | Notes |
|---------|--------------|------------|--------------|-------|
| **Inline blame annotations (hg annotate)** | Core feature parity with Git | Medium | VCS abstraction interface | `hg annotate -c -u -d -q` gives changeset + user + date per line. Template system (`-T`) can produce structured output for reliable parsing. |
| **Click-popup commit details** | Existing Git UX pattern users expect | Medium | Blame annotations, hg log | `hg log -r <node> --template "{desc}\n"` for full message. Node hash is 40-char hex like Git SHA-1. |
| **RTF diff dialog (file-scoped and full)** | Existing Git UX pattern users expect | Low | Commit detail fetch | `hg diff -c <node> <file>` for file diff, `hg diff -c <node>` for full diff. Unified diff format, same as Git. |
| **Revision navigation (parent commit)** | Existing Git UX pattern users expect | Medium | hg cat, temp file opening | `hg cat -r <node> <file>` to retrieve file at revision (equivalent of `git show <hash>:<path>`). Parent via `hg log -r "p1(<node>)"`. |
| **VCS auto-detection (.hg directory)** | Users should not have to configure which VCS is in use | Low | Filesystem walk (existing pattern) | Walk parent directories for `.hg/` folder, verify with `hg root`. Identical logic to current `.git` discovery. |
| **hg executable discovery** | Plugin must find hg.exe without manual config | Low | PATH search, common install locations | Same pattern as FindGitExecutable: PATH, `C:\Program Files\TortoiseHg\`, `C:\Program Files (x86)\Mercurial\` |
| **Uncommitted line handling** | Git shows "Not committed yet" for uncommitted lines; Hg must too | Low | Blame parser | Hg annotate shows working directory parent for uncommitted lines. Need to detect and mark as IsUncommitted. |
| **Cache integration** | Blame caching already exists; Hg must use the same pipeline | Low | Existing TBlameCache | TBlameData/TBlameLineInfo are VCS-agnostic records. Hg parser outputs the same types. No cache changes needed. |

## Differentiators

Features that go beyond parity and add genuine value for Mercurial users.

| Feature | Value Proposition | Complexity | Dependencies | Notes |
|---------|-------------------|------------|--------------|-------|
| **TortoiseHg (thg) integration** | Many Hg users have TortoiseHg installed. `thg annotate <file>` opens a rich GUI annotate view. Offering "Open in TortoiseHg" as a context menu option provides a bridge to the full tool. | Low | thg.exe discovery | `thg annotate <file>` launches GUI. Fire-and-forget -- no output parsing needed. |
| **VCS preference with per-project memory** | When both `.git` and `.hg` exist (dual-versioned repos), prompt once and remember the choice per project path in settings.ini. | Medium | Settings persistence, detection logic | Store as `[VCSPreference] <project_path>=git/hg` in INI. Show non-modal prompt on first detection. |
| **Settings dialog VCS section** | Explicit VCS preference override in the existing settings dialog (dropdown: Auto / Git / Hg). | Low | Existing settings form | Add a combobox. "Auto" = detect from directory. "Git"/"Hg" = force. |
| **Dual-VCS status indicator** | Show which VCS backend is active in the IDE messages or status annotation prefix (e.g., "[hg]" prefix on first use). | Low | VCS abstraction | One-time log message to IDE Messages pane: "DX.Blame: Using Mercurial for <project>" |

## Anti-Features

Features to explicitly NOT build. Each would add complexity without proportional value.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **hg command server protocol** | More efficient for multiple operations but adds massive complexity (socket-based IPC, state management). Git backend uses simple CLI calls; Hg should match. | Use `hg` CLI for every operation, same as Git pattern. The annotate call is infrequent (on file open + save). |
| **JSON template output from hg annotate** | Mercurial docs explicitly warn JSON/XML styles are "experimental" and "behavior may change." Fragile for production use. | Parse annotate output with a custom template string using `-T` with simple delimiters (not JSON). |
| **Mercurial bookmarks/branches in popup** | Git popup shows commit hash, author, date, message. Adding Hg-specific concepts (bookmarks, named branches) breaks UX consistency. | Show the same fields as Git: node hash (short), author, date, full message. |
| **hg serve / hgweb integration** | Overkill for blame annotations. Requires running an HTTP server. | Direct CLI calls. |
| **SVN or other VCS support** | PROJECT.md explicitly scopes to Git + Mercurial only. | Keep the VCS interface extensible but do not implement further backends now. |
| **Mercurial revsets in UI** | Revsets are powerful but exposing them in UI adds complexity for a blame tool. | Use revsets internally only (e.g., `p1(node)` for parent navigation). |
| **Automatic hg/thg installation** | Users who use Mercurial already have it installed. Auto-install is out of scope for an IDE plugin. | Log a clear message: "hg.exe not found in PATH" with guidance. |

## Feature Dependencies

```
VCS Abstraction Interface
  |
  +---> Git Backend (refactor existing code behind interface)
  |       |
  |       +---> Existing functionality unchanged
  |
  +---> Hg Backend (new implementation)
  |       |
  |       +---> Hg Discovery (find hg.exe, find .hg repo root)
  |       +---> Hg Annotate Parser (parse hg annotate output -> TBlameLineInfo[])
  |       +---> Hg Commit Detail Fetch (hg log + hg diff -> TCommitDetail)
  |       +---> Hg File Retrieval (hg cat -> temp file for revision nav)
  |
  +---> VCS Detection Logic
          |
          +---> Walk for .git / .hg directories
          +---> Handle dual-VCS case (prompt + remember)
          +---> Settings integration (Auto / Git / Hg preference)

TortoiseHg Integration (independent, additive)
  |
  +---> thg.exe discovery
  +---> Context menu "Open in TortoiseHg"
```

**Critical path:** VCS Abstraction Interface must come first. Everything else depends on it. The Git backend refactor (extracting interface from existing concrete classes) is the riskiest step because it touches working code.

## Mercurial CLI Command Mapping

Mapping each existing Git operation to its Mercurial equivalent:

| Operation | Git Command | Mercurial Command | Notes |
|-----------|-------------|-------------------|-------|
| Blame/Annotate | `git blame --line-porcelain <file>` | `hg annotate -c -u -d -n <file>` or with `-T` template | Hg output is simpler but less structured than porcelain. Use `-T` template for reliable parsing. |
| Commit details | `git log --format=%B -n1 <hash>` | `hg log -r <node> --template "{desc}"` | Node = 40-char hex, same as Git SHA. Short node = 12 chars (vs 7 for Git). |
| File diff | `git show <hash> -- <file>` | `hg diff -c <node> <file>` | Same unified diff format output. |
| Full diff | `git show <hash>` | `hg diff -c <node>` | Or `hg export <node>` for diff with commit header. |
| File at revision | `git show <hash>:<path>` | `hg cat -r <node> <file>` | Direct equivalent. |
| Repo root | `git rev-parse --show-toplevel` | `hg root` | Simpler command in Hg. |
| Executable | `git.exe` | `hg.exe` | Common locations: PATH, TortoiseHg install dir. |
| Parent commit | `git log --format=%H -n1 <hash>^` | `hg log -r "p1(<node>)" --template "{node}"` | Revset `p1()` for first parent. |
| Verify repo | `git rev-parse --show-toplevel` | `hg root` | Exit code 0 = valid repo. |

## Recommended Template for hg annotate

Instead of parsing default output (which varies with flags), use a custom template with unambiguous delimiters:

```
hg annotate -T "{lines % '{node|short}\t{rev}\t{user|emailuser}\t{date|isodate}\t{lineno}\t{line}'}" <file>
```

This produces tab-separated fields per line:
```
a1b2c3d4e5f6	42	john.doe	2026-01-15 14:30 +0100	17	  procedure Foo;
```

For full node hash (needed for commit detail lookup):
```
hg annotate -T "{lines % '{node}\t{rev}\t{user}\t{date|isodate}\t{lineno}\t{line}'}" <file>
```

**Fallback:** If template parsing fails (older Hg versions without template support), fall back to parsing default `hg annotate -c -u -d` output with regex.

## MVP Recommendation

Prioritize in this order:

1. **VCS Abstraction Interface** -- Extract `IVCSProvider` interface from existing Git code. This is the foundation. Git backend must keep working identically after refactor.
2. **Hg Discovery** -- Find hg.exe and .hg repo root. Identical pattern to Git discovery. Quick win that enables testing.
3. **Hg Annotate Parser** -- Parse `hg annotate` output into `TBlameLineInfo[]`. This enables inline annotations (the core feature).
4. **Hg Commit Detail Fetch** -- `hg log` + `hg diff` for popup and diff dialog. Enables click-through UX.
5. **VCS Detection + Preference** -- Auto-detect `.git`/`.hg`, handle dual-VCS, persist preference.
6. **Hg Revision Navigation** -- `hg cat` for file-at-revision. Enables "Previous Revision" context menu.
7. **Settings Dialog Update** -- Add VCS preference dropdown.

**Defer:**
- **TortoiseHg "Open in..." context menu**: Nice-to-have, not blocking. Can ship in a point release.
- **Statusbar display mode** (from future features list): Orthogonal to VCS abstraction, defer to v1.2.
- **Annotation X positioning** (from future features list): Orthogonal, defer to v1.2.

## Key Differences from Git That Affect Implementation

| Aspect | Git | Mercurial | Impact |
|--------|-----|-----------|--------|
| **Hash identifier** | SHA-1, 40 chars, short = 7 chars | SHA-1, 40 chars, short = 12 chars | Display formatting may differ (12 vs 7 in popup) |
| **Blame output** | `--line-porcelain` gives structured key-value pairs | Default output is simpler, template system for structure | Need custom parser, cannot reuse Git porcelain parser |
| **Uncommitted sentinel** | `0000000000000000000000000000000000000000` | Lines show working directory parent revision (no all-zeros sentinel) | Need different detection logic for uncommitted lines |
| **Executable location** | `git.exe` in PATH, Program Files\Git\cmd\ | `hg.exe` in PATH, Program Files\TortoiseHg\ | Different search paths for executable discovery |
| **Repo marker** | `.git/` directory | `.hg/` directory | Trivial change in directory walker |
| **Parent syntax** | `<hash>^` or `<hash>~1` | Revset: `p1(<node>)` | Different CLI syntax for parent navigation |
| **File at revision** | `git show <hash>:<relative-path>` | `hg cat -r <node> <file>` | Simpler in Hg (no colon-path syntax) |

## Sources

- [Mercurial annotate documentation](https://www.mercurial-scm.org/repo/hg/help/annotate)
- [Mercurial template system](https://book.mercurial-scm.org/read/template.html)
- [Mercurial scripting guide](https://www.mercurial-scm.org/help/topics/scripting)
- [Replicating git show in Mercurial](https://slaptijack.com/software/git-show-in-hg.html)
- [TortoiseHg CLI documentation](https://manpages.ubuntu.com/manpages/trusty/man1/thg.1.html)
- [hg root command](https://commandmasters.com/commands/hg-root-common/)
- [Mercurial changeset identifiers](https://www.mercurial-scm.org/wiki/ChangeSet)
- [TortoiseHg documentation](https://tortoisehg.readthedocs.io/en/latest/quick.html)
