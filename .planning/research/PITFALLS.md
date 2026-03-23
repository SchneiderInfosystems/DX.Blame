# Domain Pitfalls

**Domain:** Adding Mercurial Blame Support to Existing Git-Only Delphi IDE Plugin
**Researched:** 2026-03-23

This document focuses exclusively on pitfalls when adding Mercurial (hg) support alongside existing Git support. The v1.0 pitfalls (OTA notifiers, CreateProcess pipes, PaintLine performance, etc.) remain valid and are not repeated here.

## Critical Pitfalls

Mistakes that cause rewrites, broken parsing, or incorrect blame data.

### Pitfall 1: Assuming hg annotate Output Matches git blame --porcelain

**What goes wrong:** Developer writes a Mercurial parser that expects output structured like Git's porcelain format -- header lines with 40-char hashes, key-value metadata pairs, TAB-prefixed content lines. Mercurial's default `hg annotate` output looks nothing like this: it produces `<user> <rev>: <line content>` with no structured metadata.
**Why it happens:** The existing parser is a state machine built for Git's well-defined porcelain format. It is natural to assume Mercurial has an equivalent machine-parseable mode.
**Consequences:** Parser produces garbage data or zero results. Blame annotations show wrong authors, wrong dates, or nothing at all.
**Prevention:** Use Mercurial's template system to produce a custom, machine-parseable output format. Example command:
```
hg annotate -T "{lines % \"{node|short}|{user|emailuser}|{date|hgdate}|{rev}|{line}\"}" <file>
```
The `{lines % "..."}` operator iterates over annotated lines with sub-keywords `{node}`, `{user}`, `{date}`, `{rev}`, `{line}`, `{lineno}`, `{path}`. Design a delimiter-based format (pipe or TAB) and write a dedicated parser for it. Do NOT try to adapt the Git porcelain parser.
**Detection:** Unit test: parse a known hg annotate output with 10+ lines from different changesets. Verify author, date, hash, and line number for each.

### Pitfall 2: Using Revision Numbers Instead of Node Hashes

**What goes wrong:** Mercurial exposes local revision numbers (incrementing integers like `42`, `43`) alongside changeset node hashes (40-char hex like Git SHA-1). Developer uses revision numbers as identifiers in cache keys, commit detail lookups, or display.
**Why it happens:** Mercurial's default annotate output shows revision numbers (e.g., `user 42: line content`). They look simpler than full hashes. Git developers are unfamiliar with this dual-identity system.
**Consequences:** Revision numbers are LOCAL to a repository clone. They change when pulling from other repos. Cache lookups break across clone boundaries. Comparing blame data between team members becomes impossible. Worse: using `hg log -r 42` after a pull might reference a different changeset than expected.
**Prevention:** Always use the full node hash (`{node}`) or short node hash (`{node|short}`, 12 chars) as the canonical identifier. Store node hashes in TBlameLineInfo.CommitHash. Use revision numbers only for display if the user requests it (like `rev 42`), never as internal keys.
**Detection:** Run `hg annotate` on a file, pull new changesets, run again. If revision numbers shifted, any rev-number-based cache would be stale.

### Pitfall 3: Leaking Git Assumptions Into the VCS Abstraction

**What goes wrong:** The VCS interface is designed around Git semantics. Mercurial's behavioral differences cause impedance mismatches: different hash lengths (12-char short vs 7-char), different command structures for diffs and commit details, different path separator expectations, no staging area concept.
**Why it happens:** Natural tendency to make the abstraction a thin wrapper around the existing Git implementation, then "adapt" Mercurial to fit.
**Consequences:** The abstraction either leaks Git-isms (forcing Mercurial into awkward patterns) or requires constant special-casing that defeats the purpose of abstraction. Eventually leads to rewrite of the interface.
**Prevention:** Design the VCS interface from BOTH implementations simultaneously. Key differences to account for:

| Concern | Git | Mercurial |
|---------|-----|-----------|
| Short hash length | 7 chars | 12 chars |
| Uncommitted sentinel | 40 zeros | No standard sentinel -- annotate does not show uncommitted lines by default |
| Blame command | `git blame --line-porcelain` | `hg annotate -T "{lines % ...}"` |
| File at revision | `git show <hash>:<path>` | `hg cat -r <node> <file>` |
| Commit message | `git log -1 --format=%B <hash>` | `hg log -r <node> -T "{desc}"` |
| File diff | `git show <hash> -- <file>` | `hg diff -c <node> <file>` or `hg log -p -r <node> <file>` |
| Full diff | `git show <hash>` | `hg log -p -r <node>` |
| Repo root | `git rev-parse --show-toplevel` | `hg root` |
| Repo detection | `.git` directory | `.hg` directory |

**Detection:** Code review: search for hardcoded `40` (hash length), `7` (short hash), `0000000000...` (uncommitted), `git` in command strings. All must be behind the abstraction.

### Pitfall 4: hg annotate Does Not Show Uncommitted Lines

**What goes wrong:** Git blame shows uncommitted/unstaged changes as lines attributed to the all-zeros hash (`0000000000...`). The existing code handles this with `cUncommittedHash` and `cNotCommittedAuthor`. Developer assumes Mercurial has an equivalent.
**Why it happens:** By default, `hg annotate` annotates the parent of the working directory -- it does not show uncommitted modifications at all. If the file has local changes, the output simply matches the last committed state.
**Consequences:** Line numbers in hg annotate output may not match the editor's current line numbers if the user has unsaved/uncommitted edits. Blame data appears "shifted" -- wrong annotations on wrong lines.
**Prevention:** Accept this as a fundamental difference. Document it. When using Mercurial, blame data always reflects the last committed state. If the file is modified (dirty), either:
1. Show a visual indicator that blame may be stale (same approach as Git for uncommitted lines)
2. Compare file line count from annotate vs current editor line count; if different, mark blame as approximate
The VCS interface should expose a method like `SupportsUncommittedBlame: Boolean` so the renderer can adapt.
**Detection:** Edit a file (add/remove lines) without committing. Check if blame annotations still align correctly with the displayed code.

## Moderate Pitfalls

### Pitfall 5: VCS Detection Race When Both .git and .hg Exist

**What goes wrong:** A project directory contains both `.git` and `.hg` (common when migrating between VCS systems, or using git-hg bridges). The discovery logic finds one before the other based on directory walk order, producing inconsistent behavior.
**Why it happens:** The current `FindGitRepoRoot` walks parent directories looking for `.git`. A naive Mercurial equivalent walks the same path looking for `.hg`. If both exist at the same level, whichever is checked first wins. The result may differ across sessions if code changes.
**Consequences:** Plugin silently uses the wrong VCS. Blame data comes from the wrong history. User sees unfamiliar commit hashes and authors.
**Prevention:** When detecting VCS, check for BOTH `.git` and `.hg` at each directory level. If both are found at the same root:
1. Check project-level stored preference (from Settings)
2. If no preference, prompt user once per project (remember the choice)
3. Store the choice in the plugin settings keyed by project path
The discovery function should return a VCS type enum, not just a root path.
**Detection:** Create a test directory with both `.git` and `.hg`. Open a project in it. Verify the plugin prompts or uses the correct VCS.

### Pitfall 6: TortoiseHg vs Standalone Mercurial Executable Confusion

**What goes wrong:** Developer assumes `hg.exe` is always available at a standard path. On Windows, Mercurial is most commonly installed via TortoiseHg, which places `hg.exe` at `C:\Program Files\TortoiseHg\hg.exe`. But standalone Mercurial installs put it in Python's Scripts folder (e.g., `C:\Python39\Scripts\hg`), or users may have it only in PATH. The `thg` CLI is a GUI launcher (opens annotate dialog, workbench), NOT a command-line tool for capturing output.
**Why it happens:** Git's installation is standardized (Git for Windows). Mercurial's installation landscape on Windows is fragmented.
**Consequences:** Plugin fails to find hg.exe on many systems. Using `thg annotate` opens a GUI window instead of returning parseable output.
**Prevention:** Search order for hg.exe:
1. System PATH
2. `C:\Program Files\TortoiseHg\hg.exe`
3. `C:\Program Files (x86)\TortoiseHg\hg.exe`
4. Python Scripts directories

Never use `thg` for data retrieval. The `thg` CLI is strictly for launching GUI dialogs. All data operations must go through `hg` CLI.
**Detection:** Test on a system with TortoiseHg installed but hg.exe not in PATH. Test on a system with standalone Python-based Mercurial.

### Pitfall 7: Cache Key Collision Between VCS Types

**What goes wrong:** The existing TBlameCache uses lowercase file path as the key. When switching between Git and Mercurial (e.g., on project switch, or when user changes VCS preference), stale blame data from the previous VCS type is served.
**Why it happens:** The cache has no concept of VCS type. A file path is a file path regardless of which VCS produced the blame data.
**Consequences:** After switching VCS preference (or switching from a Git project to an Hg project), the user sees blame from the wrong VCS until the cache expires or is cleared.
**Prevention:** Two approaches (choose one):
1. **Clear cache on VCS switch:** Already happens in `OnProjectSwitch`. But if the user changes VCS preference for the same project, cache must also clear.
2. **Include VCS type in cache key:** Prefix cache key with `git:` or `hg:`. This is more robust but requires changing TBlameCache.

Approach 1 is simpler and sufficient. Ensure that changing VCS preference in settings triggers a full cache clear + re-blame of open files.
**Detection:** Open a project with both .git and .hg. Use Git blame. Switch preference to Hg. Check if annotations update.

### Pitfall 8: hg annotate Date Format Differences

**What goes wrong:** Git blame porcelain returns `author-time` as a Unix timestamp (seconds since epoch). Mercurial's `{date}` template keyword returns a different format depending on the filter applied. Without a filter, it is an internal float. With `{date|hgdate}` it returns `<unix-timestamp> <timezone-offset>`. With `{date|isodate}` it returns ISO format.
**Why it happens:** Developer assumes timestamps are interchangeable between Git and Mercurial.
**Consequences:** Dates are parsed incorrectly. Relative time display ("3 days ago") shows wildly wrong values. Sorting by date breaks.
**Prevention:** Use `{date|hgdate}` filter in the template, which produces `<unix-timestamp> <tz-offset>` (e.g., `1711234567 -7200`). Parse the Unix timestamp part (first space-separated token) with the same `UnixToDateTime` logic used for Git. The timezone offset is the second token and can be applied for display purposes.
**Detection:** Unit test: parse a known hg annotate output with `{date|hgdate}` dates. Verify the resulting TDateTime matches expected values.

### Pitfall 9: hg diff Output Format Differences

**What goes wrong:** The commit detail dialog parses diff output for RTF coloring. Git's `git show <hash>` produces a combined header + diff. Mercurial's `hg log -p -r <node>` produces a different header format (changeset: X:hash, user:, date:, summary: followed by diff).
**Why it happens:** The existing diff parser and RTF colorizer are tuned for Git's unified diff output format.
**Consequences:** Diff dialog shows garbled output, wrong coloring, or crashes on Mercurial diffs.
**Prevention:** The unified diff format itself (`---`, `+++`, `@@`, `+`, `-` lines) is the same between Git and Mercurial. The difference is in the header/metadata before the diff hunks. The RTF diff colorizer should:
1. Skip/handle VCS-specific header lines gracefully
2. Only colorize the actual diff hunks (lines starting with `+`, `-`, `@@`)
3. Display header lines in a neutral color

Alternatively, use `hg diff -c <node>` which produces a cleaner output with just the unified diff (no log metadata).
**Detection:** Unit test: feed a Mercurial diff output into the RTF colorizer. Verify it produces valid RTF.

### Pitfall 10: Process Execution Encoding Differences

**What goes wrong:** Git for Windows outputs UTF-8 by default. Mercurial on Windows may output in the system's ANSI codepage depending on configuration and version. Non-ASCII author names or commit messages get garbled.
**Why it happens:** The existing code uses `TEncoding.UTF8.GetString` unconditionally for process output.
**Consequences:** Author names with umlauts, accents, or CJK characters display as garbage in blame annotations.
**Prevention:** Set `HGENCODING=utf-8` in the environment when spawning hg processes. This forces Mercurial to use UTF-8 output. Alternatively, pass `--encoding utf-8` as a global hg argument. Then the existing UTF-8 decoding works correctly.
**Detection:** Create a test commit with a non-ASCII author name (e.g., "Muller" with umlaut). Run blame and check the annotation.

## Minor Pitfalls

### Pitfall 11: hg annotate Is Slower Than git blame

**What goes wrong:** `hg annotate` on large files can be significantly slower than `git blame`, especially with templates. The existing timeout (5000ms in WaitForSingleObject) may not be sufficient.
**Prevention:** Monitor execution time. Consider increasing the timeout for Mercurial operations, or making it configurable. The async architecture already handles this well -- the user just waits longer for annotations to appear.

### Pitfall 12: Mercurial's File at Revision Command Differs

**What goes wrong:** Navigation uses `git show <hash>:<path>` to retrieve file content at a revision. The equivalent Mercurial command is `hg cat -r <node> <file>`, which uses different argument syntax.
**Prevention:** The VCS interface must abstract `GetFileAtRevision(hash, path)` so the Navigation unit calls through the interface, not directly to Git.

### Pitfall 13: Short Hash Display Length Inconsistency

**What goes wrong:** The existing code uses `Copy(ACommitHash, 1, 7)` for display (e.g., in temp file names, context menu). Mercurial's conventional short hash is 12 characters. Showing only 7 chars of an hg node may not be unique.
**Prevention:** The VCS interface should provide a `ShortHashLength` property or a `ShortHash(full)` method. Git returns 7, Mercurial returns 12. All display code uses this instead of hardcoded `7`.

### Pitfall 14: hg root vs git rev-parse --show-toplevel Path Format

**What goes wrong:** `hg root` returns the repository root path. On Windows with network drives, the path format may differ from `git rev-parse --show-toplevel` (which can return UNC paths). The existing code already works around this for Git by using the `.git` directory location instead of the rev-parse output.
**Prevention:** Apply the same strategy for Mercurial: walk parent directories looking for `.hg`, then verify with `hg root`. Use the filesystem path (from `.hg` location) as the canonical root, not the `hg root` output, to avoid UNC/mapped-drive mismatches.

### Pitfall 15: Mercurial Version Compatibility

**What goes wrong:** The template system (`{lines % "..."}` for annotate) was refined in Mercurial 4.6+. Older installations may not support all template keywords or filters.
**Prevention:** On first detection of hg.exe, run `hg --version` and parse the version number. Log a warning if below 4.6. Consider a minimum supported version and document it.

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| VCS abstraction interface design | Pitfall 3 (Git assumptions leak) | Design interface from both implementations. Review for hardcoded Git values. |
| VCS discovery / detection | Pitfall 5 (both .git and .hg), Pitfall 6 (finding hg.exe) | Check both dirs. Search multiple hg.exe paths. Prompt when ambiguous. |
| hg annotate parsing | Pitfall 1 (output format), Pitfall 2 (rev numbers vs hashes), Pitfall 8 (dates) | Custom template output. Use node hashes. Use hgdate filter. Unit tests. |
| Uncommitted line handling | Pitfall 4 (no uncommitted in hg annotate) | Accept difference. Expose via interface. Adapt renderer. |
| Commit detail / diff display | Pitfall 9 (diff format), Pitfall 12 (file at revision) | Use hg diff -c. Abstract GetFileAtRevision. Test RTF colorizer. |
| Cache management | Pitfall 7 (VCS type collision) | Clear cache on VCS preference change. |
| Process execution | Pitfall 10 (encoding), Pitfall 11 (speed) | Set HGENCODING=utf-8. Increase timeout. |
| Display / UX | Pitfall 13 (short hash length) | Abstract short hash length in VCS interface. |
| Settings & preferences | Pitfall 5 (dual VCS preference) | Store per-project VCS choice. UI for selection. |

## Sources

- [Mercurial hg annotate documentation](https://repo.mercurial-scm.org/hg/help/annotate) -- Official annotate command reference
- [Mercurial GitConcepts wiki](https://wiki.mercurial-scm.org/GitConcepts) -- Git-to-Mercurial concept mapping
- [Mercurial template system](https://book.mercurial-scm.org/read/template.html) -- Template keywords, filters, and operators
- [Mercurial FAQ/TechnicalDetails](https://www.mercurial-scm.org/wiki/FAQ/TechnicalDetails) -- Revision numbers vs node hashes
- [TortoiseHg documentation](https://tortoisehg.readthedocs.io/en/latest/) -- thg CLI is GUI-only, hg.exe for data
- [Mercurial Windows installation](https://www.mercurial-scm.org/wiki/WindowsInstall) -- Installation paths on Windows
- [hg root command](https://commandmasters.com/commands/hg-root-common/) -- Repository root detection
