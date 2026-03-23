# Phase 4: Tooltip and Commit Detail - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Users get full commit context by clicking the blame annotation and can drill into the complete diff without leaving the IDE. This phase adds a click-triggered popup panel with commit info and a modal diff detail dialog. Hover-based tooltips are not used — interaction is explicit click-based.

</domain>

<decisions>
## Implementation Decisions

### Popup trigger & dismissal
- Click on the rendered blame annotation text opens a custom VCL popup panel (not hover, not system hint)
- Panel dismisses on click outside or Escape key
- Clicking a different annotation while popup is open replaces the content in-place (no close-then-reopen flicker)
- Uncommitted lines: clicking shows a "Not committed yet" message panel — no hash, no diff button

### Popup content & layout
- Short commit hash (7-char) — clickable to copy full 40-char SHA to clipboard with brief visual feedback
- Author name, email, full absolute date/time
- Full multi-line commit message (not just first-line Summary)
- "Show Diff" action button to open commit detail dialog (TTIP-02)
- Panel adapts colors to current IDE theme (dark popup for dark theme, light for light) — consistent with annotation color theming from Phase 3

### Commit detail dialog
- Modal VCL dialog showing full diff output
- Plain text with color coding: green for additions, red for deletions (unified diff format)
- Full commit header at top (hash, author, date, full message) above the diff
- Default scope: current file only, with toggle/button to expand to full commit diff (all files)
- Resizable dialog, starting at reasonable default size (e.g. 800x600)
- Dialog size persisted in INI file (same settings.ini from Phase 3)

### Full message & diff retrieval
- Lazy fetch + cache: full commit message and diff output fetched on first click/request, cached per commit hash
- All git fetches (git log for full message, git show for diff) run async in background thread with loading indicator
- Commit detail cache cleared together with blame cache on project switch — keeps lifecycle simple
- Reuse TGitProcess pattern from Navigation.pas for git calls

### Claude's Discretion
- Exact VCL popup panel implementation (TCustomForm descendant, borderless form, etc.)
- Click detection on annotation area (coordinate math in EditorMouseDown vs hit-testing)
- Loading indicator design (spinner, "Loading..." text, etc.)
- Clipboard copy visual feedback mechanism
- Color coding implementation for diff (TRichEdit RTF, custom paint, etc.)
- INI keys for dialog size persistence
- Toggle UI for current-file vs full-commit diff scope

</decisions>

<specifics>
## Specific Ideas

- GitLens-style commit popup card is the reference — clean, informative, non-intrusive
- Click-to-copy hash is a small but high-value UX detail for developers who need to reference commits
- "Show Diff" button should feel like a natural next step, not hidden
- The blocker in STATE.md about hover mechanism is resolved: we're using click, not hover — EditorMouseDown in INTACodeEditorEvents370 provides the hook with coordinate info

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TDXBlameRenderer` (DX.Blame.Renderer.pas): Already implements INTACodeEditorEvents370 with EditorMouseDown(var Handled) — Phase 4 adds click detection logic here
- `TBlameLineInfo` (DX.Blame.Git.Types.pas): Has CommitHash, Author, AuthorMail, AuthorTime, Summary, IsUncommitted — popup reads all fields
- `TGitProcess` (DX.Blame.Git.Process.pas): Async git execution — reuse for git log and git show calls
- `GetFileAtCommit` (DX.Blame.Navigation.pas): Uses git show pattern — diff retrieval follows same approach
- `TFormDXBlameSettings` (DX.Blame.Settings.Form.pas): Existing modal dialog pattern — diff detail dialog follows same VCL modal structure
- `DeriveAnnotationColor` (DX.Blame.Formatter.pas): Theme color derivation — popup can reuse for theme adaptation
- `BlameSettings` (DX.Blame.Settings.pas): INI persistence — extend for dialog size

### Established Patterns
- Async git execution with TThread.Queue delivery to main thread (Phase 2 pattern)
- Modal dialog creation: Create, ShowModal, Free (Settings.Form.pas pattern)
- Editor popup menu hook via FindEditorPopupMenu + OnPopup chaining (Navigation.pas)
- File keying by LowerCase(AFileName) for cache lookups
- OTA service access via Supports(BorlandIDEServices, IXxxServices, LServices)

### Integration Points
- `TDXBlameRenderer.EditorMouseDown` (INTACodeEditorEvents370): Click detection entry point — needs coordinate-to-annotation hit test
- `TBlameCache`: Read blame data to identify which commit the clicked line belongs to
- `PaintLine` context: Knows the annotation X position and rect — needed for hit testing
- `Registration.pas` finalization: Must clean up popup panel and commit detail cache on unload

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-tooltip-and-commit-detail*
*Context gathered: 2026-03-23*
