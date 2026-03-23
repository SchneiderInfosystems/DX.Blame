# Phase 3: Inline Rendering and UX - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Users see blame annotations inline at the end of the current code line and can toggle, configure, and navigate blame. This phase enables the disabled menu placeholders from Phase 1, consumes blame data from Phase 2's TBlameEngine/TBlameCache, and adds the visual rendering layer plus all UX controls. Tooltip and commit detail views are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Annotation Text Format
- Default format: "Author, relative time" (e.g. "John Doe, 3 months ago")
- Configurable elements: Show Author (on/off), Date Format (relative/absolute), Show Summary (on/off)
- When summary enabled: "John Doe, 3 months ago • Fix null check"
- Max length: configurable with truncation and ellipsis (e.g. 80 chars default) — full text available in tooltip (Phase 4)
- Uncommitted lines: show "Not committed yet" — no author, no time, just the sentinel text

### Rendering & Color
- Custom paint on editor canvas — hook into OTA/NTA editor paint mechanism to draw text after the last character of the line
- Font: same monospace font as the editor code, but italic style
- Color auto-adapts from IDE theme by default — light theme gets muted gray, dark theme gets dim gray
- User can override with a fixed custom color in settings (CONF-02)
- Display scope: configurable — default is current (caret) line only, user can switch to all lines in settings

### Toggle & Hotkey UX
- Blame enabled by default on first install — it should just work
- "Enable Blame" menu item under Tools > DX Blame becomes a working toggle (checkbox style)
- Toggle state persists across IDE restarts
- All settings (toggle state, format options, color, display scope) persisted in INI file: %APPDATA%\DX.Blame\settings.ini
- Default hotkey: Ctrl+Alt+B for toggle blame on/off
- Hotkey is configurable in settings
- "Settings..." menu item opens a configuration dialog for all CONF-01/CONF-02 options

### Parent Commit Navigation (UX-03)
- Trigger: both context menu on annotation ("Previous Revision") AND a dedicated hotkey
- Action: opens the file at the parent commit in a new read-only editor tab with full blame annotations
- The parent revision tab title should indicate it's a historical view (e.g. "filename.pas @ abc1234")
- Navigation is chainable — user can navigate to parent from a parent revision tab, each opens a new tab
- To go back: simply close the parent revision tab — no breadcrumb or history stack needed
- Uncommitted lines: "Previous Revision" not available (no parent commit for uncommitted work)

### Claude's Discretion
- Exact OTA/NTA interface for editor canvas painting (INTACustomEditorView, editor subclassing, etc.)
- Theme color derivation algorithm (how to compute muted color from editor background)
- INI file structure and section naming
- Settings dialog layout and component choices
- Hotkey registration mechanism (IOTAKeyboardBinding vs other OTA approach)
- How to create a read-only editor view for parent revision content
- Context menu attachment mechanism for the annotation area

</decisions>

<specifics>
## Specific Ideas

- GitLens is the reference for inline blame UX — "Author, time ago" at end of current line is the gold standard
- "Not committed yet" text matches the Phase 2 sentinel constant `cNotCommittedAuthor` — keep consistent
- The existing `TBlameEngine.HandleBlameComplete` has a placeholder comment `// Phase 3 will add: notify UI to repaint` — this is the integration hook
- Menu items "Enable Blame" and "Settings..." already exist as disabled TMenuItem in Registration.pas — Phase 3 enables and wires them

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `TBlameEngine` (DX.Blame.Engine.pas): Singleton orchestrator with `RequestBlame`, `HandleBlameComplete` callback — Phase 3 hooks into the completion callback
- `TBlameCache` (DX.Blame.Cache.pas): Thread-safe per-file cache — Phase 3 reads from cache for rendering
- `TBlameLineInfo` (DX.Blame.Git.Types.pas): Per-line data record with Author, AuthorTime, CommitHash, Summary, IsUncommitted — all fields needed for annotation text
- `TBlameData` (DX.Blame.Git.Types.pas): File-level container with Lines array — Phase 3 iterates this for rendering
- Menu items `DXBlameEnableItem` and `DXBlameSettingsItem` (Registration.pas): Created disabled in Phase 1, Phase 3 enables and adds OnClick handlers

### Established Patterns
- OTA service access via `Supports(BorlandIDEServices, IXxxServices, LServices)` pattern
- Notification delivery from background threads via `TThread.Queue` (main thread callback)
- File keying by `LowerCase(AFileName)` throughout the engine and cache
- IDE message logging via `IOTAMessageServices.AddTitleMessage`

### Integration Points
- `TBlameEngine.HandleBlameComplete`: needs to fire a UI repaint notification (comment placeholder exists)
- `TDXBlameIDENotifier.FileNotification`: already handles file open/close — Phase 3 may need to attach editor-specific notifiers here
- `Registration.pas` finalization: cleanup order must include new Phase 3 resources (rendering, settings)
- `CreateToolsMenu` in Registration.pas: menu items need OnClick handlers wired in Phase 3

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-inline-rendering-and-ux*
*Context gathered: 2026-03-19*
