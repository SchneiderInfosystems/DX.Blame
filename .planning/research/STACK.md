# Technology Stack

**Project:** DX.Blame v1.1 (Mercurial Support Addition)
**Researched:** 2026-03-23

## Scope

This document covers ONLY the stack additions needed for Mercurial (hg) support. The existing validated stack (OTA, INTACodeEditorEvents, Git CLI via CreateProcess) is unchanged and NOT re-documented here.

## Recommended Stack Additions

### Mercurial CLI Integration

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `hg annotate` | Mercurial 5.0+ | Per-line blame data | Direct equivalent of `git blame`. Template support enables machine-parseable output. | HIGH |
| `hg log` | Mercurial 5.0+ | Commit details (message, author, date) | Template engine provides structured output. `-r REV` for single revision queries. | HIGH |
| `hg diff -c REV` | Mercurial 5.0+ | Commit diff (full and file-specific) | `-c REV` shows changes relative to parent, equivalent to `git show REV`. | HIGH |
| `hg cat -r REV FILE` | Mercurial 5.0+ | File content at revision | Equivalent of `git show REV:FILE`. Used for revision navigation. | HIGH |

### TortoiseHg (Optional GUI Integration)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| `thg annotate FILE` | TortoiseHg 6.5+ | Opens TortoiseHg annotate dialog | GUI alternative for users who prefer visual annotation. NOT used for data extraction. | HIGH |
| `thg log FILE` | TortoiseHg 6.5+ | Opens TortoiseHg workbench filtered to file | Convenience launch from context menu. NOT used for data extraction. | HIGH |

### VCS Abstraction Layer (New Delphi Units)

| Component | Purpose | Why |
|-----------|---------|-----|
| `IVCSProvider` interface | Abstract blame/log/diff/cat operations | Decouples engine from VCS-specific CLI commands. Enables Git and Hg backends behind same interface. |
| `TVCSProcess` (renamed from `TGitProcess`) | Generic CreateProcess wrapper | Existing `TGitProcess` is already VCS-agnostic in implementation -- just rename and parameterize. |
| `TVCSKind` enum | `vcsGit`, `vcsHg`, `vcsNone` | Discovery result type. Used throughout for branching logic. |

## Exact CLI Commands

### 1. Blame / Annotate

**Command:**
```
hg annotate -c -u -d -n FILE
```

**Flags explained:**
- `-c` (--changeset): Output the 12-char short changeset hash instead of revision number. **Critical** -- we need the hash for commit detail lookups.
- `-u` (--user): Output the author name.
- `-d` (--date): Output the commit date.
- `-n` (--number): Output the revision number. Must be explicitly included because `-c`, `-u`, and `-d` suppress it.

**Default output format (human-readable, space-separated columns):**
```
 abc123def456 John Doe <john@example.com> Thu Jan 15 10:30:00 2026 +0100  42: line content here
```

Each line follows: `<changeset> <user> <date> <revnum>: <content>`

**Why NOT use `-T` (template) for annotate:**
The template-based annotate (`hg annotate -T '{lines % ...}'`) is more complex to parse and less widely tested across Mercurial versions. The default column-based output with `-c -u -d` flags is stable, well-documented, and sufficient. The column format is consistent and parseable with simple string splitting at the colon delimiter.

**Preferred alternative -- template-based (more reliable parsing):**
```
hg annotate -T "{lines % \"{node|short} {rev} {user|emailuser} {date|hgdate} {line}\"}" FILE
```

**Template output format:**
```
abc123def456 42 john 1705312200 0 line content here
```

- `{node|short}`: 12-char hex hash (equivalent to Git's short hash)
- `{rev}`: Integer revision number
- `{user|emailuser}`: Username portion only (strips email)
- `{date|hgdate}`: Unix timestamp + timezone offset (e.g., `1705312200 -3600`)
- `{line}`: Actual line content

**Recommendation: Use template-based output.** The `{date|hgdate}` filter gives Unix timestamps identical to what `git blame --porcelain` provides (`author-time`), making the parser nearly identical. The `{node|short}` gives a consistent 12-char hash. This is the most reliable approach for machine parsing.

**Final recommended command:**
```
hg annotate -T "{lines % \"{node} {rev} {user|emailuser} {date|hgdate}\t{line}\"}" FILE
```

Using `{node}` (full 40-char hash) instead of `{node|short}` for consistency with Git's 40-char hashes. The TAB character (`\t`) before `{line}` provides an unambiguous delimiter between metadata and content -- same strategy as `git blame --porcelain` using TAB for content lines.

**Uncommitted lines:** Mercurial annotate does NOT show uncommitted working-directory changes. It only annotates committed content. This is different from `git blame` which shows uncommitted lines with the all-zero hash. For DX.Blame this is acceptable -- the existing Git behavior already marks uncommitted lines as "Not committed yet", and for Hg we simply will not have them (the annotation covers only committed state).

### 2. Commit Details (Full Message)

**Command:**
```
hg log -r HASH -T "{node}\n{user}\n{date|hgdate}\n{desc}"
```

**Output format:**
```
abc123def456789...  (40-char node)
John Doe <john@example.com>
1705312200 -3600
Full commit message
possibly multi-line
```

**Why this template:** Four fields separated by newlines. The first three are single-line, the description takes the remainder. Simple to parse with `Split([#10])` -- take lines [0..2] as metadata, join the rest as description.

**Equivalent Git command it replaces:**
```
git log -1 --format=%B HASH
```

### 3. File-Specific Diff

**Command:**
```
hg diff -c HASH FILE
```

**Flags explained:**
- `-c HASH` (--change): Show changes introduced by this changeset (diff against parent). This is the Mercurial equivalent of `git show HASH -- FILE`.

**Output format:** Standard unified diff format, identical to `git show` diff output. No special parsing changes needed.

**Equivalent Git command it replaces:**
```
git show HASH -- "FILE"
```

### 4. Full Commit Diff

**Command:**
```
hg diff -c HASH
```

Without a file argument, shows the full changeset diff. Equivalent to `git show HASH`.

**Alternative with commit header:**
```
hg export HASH
```

`hg export` includes the commit message header (Author, Date, Subject) followed by the unified diff. This is more informative for the diff dialog and mirrors `git show` output more closely.

**Recommendation: Use `hg export HASH`** because it includes commit metadata in the output header, matching what `git show` provides and what the diff dialog already displays.

### 5. File Content at Revision (Navigation)

**Command:**
```
hg cat -r HASH FILE
```

**Output:** Raw file content at that revision, written to stdout.

**Equivalent Git command it replaces:**
```
git show HASH:FILE
```

### 6. Repository Root Detection

**Command:**
```
hg root
```

**Output:** Single line with absolute path to repository root.

**Equivalent Git command it replaces:**
```
git rev-parse --show-toplevel
```

### 7. Executable Discovery

**Search order for `hg.exe`:**
1. System PATH (`hg.exe`)
2. `C:\Program Files\Mercurial\hg.exe`
3. `C:\Program Files\TortoiseHg\hg.exe` (TortoiseHg bundles hg)
4. `%LOCALAPPDATA%\Programs\TortoiseHg\hg.exe`

**Search order for `thg.exe` (optional, GUI only):**
1. System PATH (`thg.exe`)
2. `C:\Program Files\TortoiseHg\thg.exe`
3. `%LOCALAPPDATA%\Programs\TortoiseHg\thg.exe`

**Important:** TortoiseHg ships its own bundled Mercurial. If `hg.exe` is not found in PATH but TortoiseHg is installed, `hg.exe` will be available in the TortoiseHg installation directory.

### 8. Repository Detection

**Filesystem check:** Walk parent directories looking for `.hg` directory (same pattern as `.git` detection).

**Verification command:**
```
hg root
```

Run from candidate directory. Exit code 0 = valid Hg repo. Output = repo root path.

## Command-to-Git Mapping Summary

| Git Command | Mercurial Equivalent | Notes |
|-------------|---------------------|-------|
| `git blame --line-porcelain -- FILE` | `hg annotate -T "{lines % \"{node} {rev} ...\"}" FILE` | Template provides structured output |
| `git log -1 --format=%B HASH` | `hg log -r HASH -T "{node}\n{user}\n{date\|hgdate}\n{desc}"` | Template for structured output |
| `git show HASH -- FILE` | `hg diff -c HASH FILE` | `-c` = changes in changeset |
| `git show HASH` | `hg export HASH` | Includes commit header + diff |
| `git show HASH:FILE` | `hg cat -r HASH FILE` | Raw file content at revision |
| `git rev-parse --show-toplevel` | `hg root` | Repo root path |

## What NOT to Add

| Rejected Approach | Why |
|-------------------|-----|
| libhg / Python bindings | Mercurial is Python-based; calling Python from Delphi adds massive complexity. CLI is simpler, faster, no dependency management. |
| `hg serve` (built-in web server) | Overkill for blame data. HTTP overhead, port management, process lifecycle -- all unnecessary. |
| Direct `.hg` directory parsing | Internal format is undocumented and version-dependent. CLI is the stable interface. |
| `thg` for data extraction | TortoiseHg is a GUI tool. Its commands launch windows, not stdout streams. Only use for "open in TortoiseHg" user actions. |
| `hg annotate --json` | JSON output is NOT a built-in option for annotate. Template output is the correct approach. |

## Integration with Existing Shell Execution

The existing `TGitProcess` class is already a generic CreateProcess wrapper. The only Git-specific aspect is the constructor parameter name (`AGitPath`). For v1.1:

1. **Rename to `TVCSProcess`** (or keep `TGitProcess` and create `THgProcess` as a thin alias -- but renaming is cleaner).
2. The `Execute` / `ExecuteAsync` / `CancelProcess` methods work identically for `hg.exe`.
3. The pipe-based stdout capture, `CREATE_NO_WINDOW`, `SW_HIDE`, and handle cleanup are all VCS-agnostic.
4. The 5-second `WaitForSingleObject` timeout is appropriate for Mercurial as well.

**Zero changes needed to the process execution logic itself.** Only the path parameter and command arguments change.

## Encoding Considerations

- Mercurial outputs UTF-8 by default on modern versions (5.0+).
- The existing `TEncoding.UTF8.GetString` in `TGitProcess.ExecuteAsync` works for both Git and Hg output.
- Template output with `{date|hgdate}` uses ASCII-only characters (digits and minus sign), so no encoding issues.

## Mercurial Version Compatibility

| Feature | Minimum Version | Notes |
|---------|----------------|-------|
| `hg annotate -T` (template) | Mercurial 3.8+ | Template support for annotate added in 3.8 |
| `{date\|hgdate}` filter | Mercurial 1.0+ | Available since early versions |
| `{node}` keyword | Mercurial 1.0+ | Core template keyword |
| `hg diff -c` | Mercurial 1.4+ | Change flag for single-changeset diff |
| `hg export` | Mercurial 0.9+ | Core command |
| `hg cat -r` | Mercurial 0.9+ | Core command |
| `hg root` | Mercurial 0.9+ | Core command |

**Target minimum: Mercurial 3.8+** for template-based annotate. This covers all actively maintained installations. The latest stable Mercurial is 6.8 (2024).

## TortoiseHg Version Notes

- TortoiseHg 6.9 released 2025-01-16 (latest as of research date)
- TortoiseHg bundles its own Mercurial installation
- `thg annotate FILE` opens the annotate dialog (GUI)
- `thg log FILE` opens the workbench filtered to file (GUI)
- These are fire-and-forget GUI launches, not data extraction commands

## Sources

- [hg annotate documentation](https://repo.mercurial-scm.org/hg/help/annotate) - Official command reference (HIGH confidence)
- [hg log documentation](https://repo.mercurial-scm.org/hg/help/log) - Official command reference (HIGH confidence)
- [Mercurial templates reference](https://repo.mercurial-scm.org/hg/help/templates) - Official template keywords and filters (HIGH confidence)
- [hg diff documentation](https://repo.mercurial-scm.org/hg/help/diff) - Official diff command reference (HIGH confidence)
- [Replicating git show in Mercurial](https://slaptijack.com/software/git-show-in-hg.html) - `hg export` as git show equivalent (MEDIUM confidence)
- [TortoiseHg documentation](https://tortoisehg.readthedocs.io/en/latest/) - thg command reference (HIGH confidence)
- [Mercurial template customization](https://book.mercurial-scm.org/read/template.html) - Template syntax and filters (HIGH confidence)
