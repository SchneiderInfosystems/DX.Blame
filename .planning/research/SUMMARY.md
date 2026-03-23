# Project Research Summary

**Project:** DX.Blame v1.1 — Mercurial Support Addition
**Domain:** Delphi IDE Plugin — VCS blame annotations (Mercurial extension to existing Git-only plugin)
**Researched:** 2026-03-23
**Confidence:** HIGH

## Executive Summary

DX.Blame v1.1 is a targeted feature extension to an existing, validated v1.0 codebase. The task is not to build a new product but to introduce a VCS abstraction layer that enables Mercurial blame support alongside the existing Git implementation. The recommended approach is interface-based: introduce `IVCSProvider`, extract the four Git-specific units behind it, implement a parallel set of Mercurial units, and wire the engine to dispatch through the interface. Seven units require modification, seven new units are needed, and seven existing units remain entirely unchanged.

The CLI integration strategy is direct and well-proven. Mercurial's template engine (`-T`) produces machine-parseable output for `hg annotate`, giving structured per-line blame data equivalent to what Git's `--line-porcelain` provides. All other operations (`hg log`, `hg diff -c`, `hg cat`, `hg root`) map cleanly to their Git counterparts. The existing `TGitProcess` (CreateProcess wrapper) is already functionally generic and can be refactored into a shared `TVCSProcess` base class with zero changes to its pipe capture, encoding, or cancellation logic. TortoiseHg ships its own `hg.exe`, so executable discovery must check TortoiseHg installation paths in addition to the system PATH.

The primary risk is the Git-to-abstraction refactoring step: extracting `IVCSProvider` from the existing concrete Git code touches working production logic. This must be done incrementally, with the Git backend verified through the new interface before any Mercurial code is introduced. Secondary risks are parser correctness (Mercurial's annotate output is structurally different from Git's porcelain) and the dual-VCS detection edge case (repos that contain both `.git` and `.hg`). Both are well-understood and preventable with unit tests and a per-project preference store.

## Key Findings

### Recommended Stack

The existing CreateProcess-based execution model requires no changes. The only stack additions are: (1) `hg.exe` (Mercurial 3.8+ for template annotate support, 4.6+ recommended), found via PATH then TortoiseHg installation directories; and (2) optional `thg.exe` for GUI-only "Open in TortoiseHg" actions. No new Delphi libraries are needed — all Mercurial operations are CLI-driven with the same pipe-based stdout capture already in use.

**Core technologies:**
- `hg annotate -T "{lines % ...}"`: Per-line blame data — template system produces structured, reliably parseable output using `{node}`, `{user|emailuser}`, `{date|hgdate}`, `{lineno}`, `{line}` keywords.
- `hg log -r HASH -T "{node}\n{user}\n{date|hgdate}\n{desc}"`: Commit details — four-field newline-separated format, directly equivalent to `git log -1 --format=%B`.
- `hg diff -c HASH FILE` / `hg export HASH`: File and full commit diffs — unified diff format, identical to Git output structure.
- `hg cat -r HASH FILE`: File content at revision — equivalent of `git show HASH:FILE`.
- `hg root`: Repository root detection — equivalent of `git rev-parse --show-toplevel`.
- `TVCSProcess` (refactored from `TGitProcess`): Generic CreateProcess wrapper — zero logic changes, only constructor parameterization.

**Critical version requirement:** Mercurial 3.8+ for `{lines % "..."}` template operator in annotate. Target 4.6+ for full template reliability.

### Expected Features

The feature scope is feature-parity with Git blame, plus a small set of Mercurial-specific enhancements.

**Must have (table stakes):**
- Inline blame annotations via `hg annotate` — core feature parity; users switching from Git blame expect identical UX.
- Click-popup commit details (hash, author, date, message) — existing UX pattern users expect.
- RTF diff dialog (file-scoped and full commit) — existing UX pattern users expect.
- Revision navigation via `hg cat` — existing UX pattern users expect.
- VCS auto-detection (`.hg` directory walk + `hg root` verification) — transparent, no user configuration required.
- `hg.exe` discovery (PATH + TortoiseHg paths) — plugin must find the executable automatically.
- Cache integration — `TBlameData`/`TBlameLineInfo` are already VCS-neutral; no cache changes needed.

**Should have (differentiators):**
- TortoiseHg context menu integration ("Open in TortoiseHg Annotate/Log") — value for the majority of Mercurial-on-Windows users.
- Per-project VCS preference with persistence — required for dual-VCS repos; stored in settings INI keyed by project path.
- Settings dialog VCS dropdown (Auto / Git / Mercurial) — explicit override for edge cases.
- Dual-VCS status indicator in IDE Messages — transparency for the user about which backend is active.

**Defer (v2+):**
- Statusbar display mode — orthogonal to VCS abstraction; already tracked as future feature.
- Annotation X-position configuration — orthogonal; already tracked as future feature.
- Further VCS backends (SVN, etc.) — interface is extensible but out of scope for v1.1.

### Architecture Approach

The architecture follows a Strategy pattern: `IVCSProvider` is the interface, `TGitProvider` and `THgProvider` are concrete implementations, and `DX.Blame.VCS.Discovery` is the factory that selects and instantiates the correct provider based on directory structure and user preference. `DX.Blame.Engine` holds an `IVCSProvider` reference and dispatches all VCS operations through it. The 14 units outside the four Git-specific ones are already VCS-neutral in logic and require only a `uses` clause rename from `DX.Blame.Git.Types` to `DX.Blame.VCS.Types`.

**Major components:**
1. `DX.Blame.VCS.Types` — VCS-neutral shared data contracts (`TBlameLineInfo`, `TBlameData`); mechanical rename of existing `DX.Blame.Git.Types`, zero structural changes to the types themselves.
2. `DX.Blame.VCS.Provider` — `IVCSProvider` interface definition; the central abstraction contract with 10 methods covering blame, commit details, diff, file-at-revision, and discovery.
3. `DX.Blame.VCS.Discovery` — provider factory: walks for `.git`/`.hg`, resolves dual-VCS conflict via per-project preference, instantiates the correct provider.
4. `DX.Blame.VCS.Process` — shared `TVCSProcess` base class (DRY refactor from `TGitProcess`); both providers use it with different executable paths.
5. `DX.Blame.Git.Provider` — thin wrapper delegating to existing Git sub-units; Git behavior completely unchanged.
6. `DX.Blame.Hg.Provider` + `Hg.Process` + `Hg.Blame` + `Hg.Discovery` — complete Mercurial implementation; parallel structure to Git sub-units.
7. `DX.Blame.Engine` (modified) — replaces direct Git calls with `IVCSProvider` dispatch; `FGitPath`/`FGitAvailable` replaced by `FProvider: IVCSProvider`.

### Critical Pitfalls

1. **Assuming hg annotate output matches git blame porcelain** — Use Mercurial's template system (`-T`) with a custom delimiter format. Write a dedicated Hg parser; do not adapt the Git porcelain parser. Verify with unit tests against known output covering multiple changesets.

2. **Using Mercurial revision numbers instead of node hashes** — Revision numbers are local to a clone and shift on pull. Always use `{node}` (full 40-char hash) as the canonical identifier in `TBlameLineInfo.CommitHash`. Revision numbers for display only, never as internal keys or cache keys.

3. **Leaking Git assumptions into the VCS interface** — Design `IVCSProvider` from both implementations simultaneously. Audit for hardcoded `7` (Git short hash length), `0000...` uncommitted sentinel, and Git-specific command strings. Provide `ShortHashLength` or `ShortHash()` via the interface; Git returns 7 chars, Mercurial returns 12.

4. **hg annotate not showing uncommitted lines** — Unlike Git, Mercurial annotate always reflects last committed state. Accept this behavioral difference. Expose `SupportsUncommittedBlame: Boolean` via the interface so the renderer can adapt its visual treatment.

5. **Dual-VCS detection race and cache collision on VCS switch** — Check for both `.git` and `.hg` simultaneously; prompt once per project when both found; persist choice. On VCS preference change, clear the blame cache and re-trigger annotations on open files.

## Implications for Roadmap

Based on research, the suggested phase structure follows the architectural build order in ARCHITECTURE.md, respecting strict dependency ordering to minimize regression risk.

### Phase 1: Shared Types Rename and Process Abstraction

**Rationale:** Everything depends on `DX.Blame.VCS.Types`. This is a mechanical rename with zero logic risk, but it must compile cleanly before any other work proceeds. Simultaneously extract `TVCSProcess` from `TGitProcess` to establish the DRY foundation for both providers.
**Delivers:** Renamed `DX.Blame.VCS.Types` unit, updated `uses` clauses in all 14 dependent units, new `DX.Blame.VCS.Process` base class, `DX.Blame.Git.Process` refactored to delegate.
**Addresses:** Cache integration (types remain structurally unchanged), DRY process wrapper.
**Avoids:** Pitfall 3 (Git-type leakage) — establishing VCS-neutral types from the start prevents retrofitting.

### Phase 2: VCS Interface and Git Provider Wrapper

**Rationale:** The interface must exist before the engine can be refactored, and the Git provider wrapper proves the interface is correct without changing any observable behavior. This is the safety net before the highest-risk phase.
**Delivers:** `DX.Blame.VCS.Provider` (interface), `DX.Blame.Git.Provider` (wraps existing Git units). Git blame continues working identically, now routed through the interface.
**Implements:** `IVCSProvider` interface with all 10 methods defined in ARCHITECTURE.md.
**Avoids:** Pitfall 3 (interface designed for both implementations, not just Git semantics).

### Phase 3: Engine and CommitDetail Refactoring

**Rationale:** This is the highest-risk phase — modifying the production engine to dispatch via `IVCSProvider`. Isolated into its own phase for focused regression testing. CommitDetail and Navigation are included because they are the remaining units with direct Git CLI calls.
**Delivers:** `DX.Blame.Engine` using `IVCSProvider`, `DX.Blame.CommitDetail` and `DX.Blame.Navigation` updated to dispatch through provider. Full Git blame regression test point — all existing functionality verified through the new abstraction before any Mercurial code exists.
**Avoids:** Pitfall 3 (Engine becomes a god class with VCS-specific branches if not refactored now).

### Phase 4: VCS Discovery

**Rationale:** Discovery is independent of the Mercurial provider implementation and can be built and tested in isolation. Building it before Phase 5 also validates the dual-VCS conflict handling logic separately from the annotation parsing logic.
**Delivers:** `DX.Blame.VCS.Discovery` with auto-detection, dual-VCS conflict resolution with user prompt, per-project preference persistence, `hg.exe` and `thg.exe` search paths.
**Addresses:** Per-project VCS preference, dual-VCS status indicator.
**Avoids:** Pitfall 5 (dual-VCS race condition), Pitfall 6 (TortoiseHg vs standalone hg.exe confusion), Pitfall 7 (cache collision on VCS switch).

### Phase 5: Mercurial Provider Implementation

**Rationale:** All foundational work is complete. This phase adds Mercurial as a pure net-new implementation with no risk to existing Git functionality.
**Delivers:** `DX.Blame.Hg.Discovery`, `DX.Blame.Hg.Process`, `DX.Blame.Hg.Blame`, `DX.Blame.Hg.Provider`. Full Mercurial blame, commit details, diff, and revision navigation at feature parity with Git.
**Uses:** `hg annotate -T` template command, `hg log -r HASH -T`, `hg diff -c`, `hg export`, `hg cat -r`, `hg root` — exact command strings documented in STACK.md.
**Avoids:** Pitfall 1 (output format — custom template parser), Pitfall 2 (node hashes only), Pitfall 4 (uncommitted lines — accept and document), Pitfall 8 (date format — use `{date|hgdate}`), Pitfall 10 (encoding — set `HGENCODING=utf-8` in process environment).

### Phase 6: Settings, UI, and TortoiseHg Integration

**Rationale:** UI changes are always last — they depend on all provider logic being stable. Settings expose the VCS preference that Discovery already handles internally. TortoiseHg context menu is additive and the lowest-risk change in the entire project.
**Delivers:** Settings VCS dropdown (Auto/Git/Mercurial), `DX.Blame.Settings` VCS preference persistence, optional "Open in TortoiseHg Annotate/Log" context menu items.
**Addresses:** Settings dialog VCS section differentiator, TortoiseHg integration differentiator.
**Avoids:** Pitfall 6 (thg vs hg confusion — context menu uses thg for GUI launch only, never for data retrieval).

### Phase Ordering Rationale

- Types rename is the unconditional first step — 14 units have a compile-time dependency on it.
- Interface definition must precede engine refactoring so the engine has a type to reference.
- The Git provider wrapper proves the interface is correct before any engine changes are made.
- Engine refactoring must complete before the Mercurial provider exists — the engine must be provider-agnostic to accept a new concrete implementation.
- Discovery is independent of the Hg provider but must precede engine wiring in Phase 3 (even if not fully wired yet).
- Settings and UI always follow stable provider contracts to avoid churn.

### Research Flags

Phases with standard patterns (no additional research needed):
- **Phase 1 (Types rename + Process abstraction):** Purely mechanical; Delphi unit rename and interface extraction are well-understood.
- **Phase 2 (Interface + Git wrapper):** Standard Delphi interface/implementation pattern.
- **Phase 3 (Engine refactoring):** Well-understood refactoring with detailed design in ARCHITECTURE.md.
- **Phase 6 (Settings + TortoiseHg):** Standard settings form extension plus fire-and-forget process launch.

Phases that warrant pre-implementation review before coding:
- **Phase 5 (Mercurial provider — annotate parser specifically):** The template format and parser state machine are the most novel element in this project. Review PITFALLS.md Pitfalls 1, 2, 4, 8, and 10 before writing the parser. Prototype the template command against a real Mercurial repository to validate output format before writing the parser.
- **Phase 4 (VCS Discovery — dual-VCS conflict UX):** The prompt-and-persist pattern for dual-VCS projects has no existing precedent in the codebase. The UX interaction model (modal dialog vs non-modal notification vs IDE Messages action) must be decided before coding the discovery module.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All CLI commands sourced from official Mercurial documentation. Exact command strings and template keywords verified. No experimental APIs. |
| Features | HIGH | Feature scope is clearly bounded by Git blame parity. Mercurial CLI is mature and stable. All operations have confirmed equivalents. |
| Architecture | HIGH | Based on direct analysis of the existing 18-unit codebase. Interface contract covers both providers. Dependency ordering validated against the unit graph. |
| Pitfalls | HIGH | 15 specific pitfalls identified with concrete prevention strategies and detection tests. Mercurial/Git behavioral differences are thoroughly documented by the Mercurial project itself. |

**Overall confidence:** HIGH

### Gaps to Address

- **Mercurial 3.8 vs 4.6 template compatibility:** Research indicates the `{lines % "..."}` operator was refined in 4.6. During Phase 5 implementation, test against Mercurial 3.8 specifically. If the template fails, either raise the minimum supported version to 4.6 (document this) or implement a fallback parser for default `hg annotate -c -u -d` output.

- **Dual-VCS prompt UX design:** The requirement is clear (prompt once, persist choice) but the exact UI pattern is unspecified. Decide between modal dialog, non-modal notification bar, or IDE Messages pane action before Phase 4 implementation to avoid retrofitting the discovery module's callback interface.

- **Short hash display convention in v1.0:** ARCHITECTURE.md recommends abstracting `ShortHashLength` in `IVCSProvider`. Confirm whether the popup, context menu, and temp file naming in v1.0 already use a helper or hardcode `Copy(hash, 1, 7)`. If hardcoded, this needs to be addressed in Phase 2 (interface design) not Phase 5.

- **hg annotate timeout baseline:** PITFALLS.md notes Mercurial annotate is slower than `git blame`. The existing 5000ms `WaitForSingleObject` timeout may be insufficient on large repositories. Establish a realistic timeout during Phase 5 testing on representative large files before shipping.

## Sources

### Primary (HIGH confidence)
- [hg annotate documentation](https://repo.mercurial-scm.org/hg/help/annotate) — annotate flags, template operator `{lines % "..."}`, field keywords `{node}`, `{user}`, `{date}`, `{line}`, `{lineno}`
- [Mercurial templates reference](https://repo.mercurial-scm.org/hg/help/templates) — all template keywords and filters including `{node}`, `{date|hgdate}`, `{user|emailuser}`
- [hg log documentation](https://repo.mercurial-scm.org/hg/help/log) — `-r`, `-T`, `-p` flags, structured commit output
- [hg diff documentation](https://repo.mercurial-scm.org/hg/help/diff) — `-c` (change) flag for single-changeset diff
- [TortoiseHg documentation](https://tortoisehg.readthedocs.io/en/latest/) — thg CLI is GUI-launch only; `hg.exe` bundled in TortoiseHg installation directory
- [Mercurial template customization book](https://book.mercurial-scm.org/read/template.html) — template syntax, filter reference, `{lines % "..."}` operator
- Existing DX.Blame v1.0 codebase (18 production units in `y:/DX.Blame/src/`) — architecture analysis basis

### Secondary (MEDIUM confidence)
- [Replicating git show in Mercurial](https://slaptijack.com/software/git-show-in-hg.html) — `hg export` as `git show` equivalent
- [Git vs Mercurial command mapping (hyperpolyglot)](https://hyperpolyglot.org/version-control) — comprehensive command equivalence table
- [Mercurial GitConcepts wiki](https://wiki.mercurial-scm.org/GitConcepts) — Git-to-Mercurial concept mapping and behavioral differences

### Tertiary (LOW confidence)
- None — all key findings confirmed with primary or secondary sources.

---
*Research completed: 2026-03-23*
*Ready for roadmap: yes*
