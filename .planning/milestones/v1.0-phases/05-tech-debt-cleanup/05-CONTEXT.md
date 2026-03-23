# Phase 5: Tech Debt Cleanup - Context

**Gathered:** 2026-03-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix latent bugs, implement IDE theme-aware annotation color, break circular unit dependency, and clean up dead code and stale documentation. This is a gap-closure phase addressing tech debt from the v1.0 milestone audit. No new capabilities — only improving existing code quality and correctness.

</domain>

<decisions>
## Implementation Decisions

### Theme Color Blending (DeriveAnnotationColor)
- Use INTACodeEditorServices to get the editor background color instead of hardcoded clGray
- Blending algorithm: midpoint blend toward gray — blend editor background 50% toward mid-gray (128,128,128)
- Light themes produce a darker muted gray, dark themes produce a lighter muted gray
- Color re-derived on each paint call (live update) — annotation color changes instantly when user switches IDE theme
- Fallback to clGray remains for non-IDE context (test runner, no BorlandIDEServices)

### Circular Dependency Resolution
- Break the circular dependency between DX.Blame.KeyBinding and DX.Blame.Registration
- Approach: move RegisterKeyBinding/UnregisterKeyBinding procedures out of KeyBinding.pas into Registration.pas (or a shared unit) so KeyBinding no longer references Registration
- KeyBinding.pas currently uses Registration only for SyncEnableBlameCheckmark — eliminate that reference

### Claude's Discretion
- Exact unit restructuring for the circular dependency fix (which procedures move where)
- Registration.pas finalization guard fix (>= 0 instead of > 0) — mechanical
- OnShowDiffClick property removal from TDXBlamePopup — mechanical dead code removal
- GetAnnotationClickableLength documentation update — mechanical
- TTIP-02 traceability table update — mechanical

</decisions>

<specifics>
## Specific Ideas

- Phase 3 CONTEXT established: "color auto-adapts from IDE theme by default — light theme gets muted gray, dark theme gets dim gray" — this phase implements that promise
- The existing DeriveAnnotationColor comment says: "The renderer (Plan 02) will override this with INTACodeEditorServices.Options.BackgroundColor[atWhiteSpace] blending" — follow this guidance
- Live update means no caching of derived color — call DeriveAnnotationColor fresh in PaintLine each time

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DeriveAnnotationColor` (DX.Blame.Formatter.pas:148): Current clGray fallback — needs INTACodeEditorServices integration
- `TDXBlameRenderer.PaintLine` (DX.Blame.Renderer.pas:306): Already calls DeriveAnnotationColor — no wiring change needed
- `SyncEnableBlameCheckmark` (DX.Blame.Registration.pas:25): The only reason KeyBinding references Registration

### Established Patterns
- OTA service access via `Supports(BorlandIDEServices, IXxxServices, LServices)` — use for INTACodeEditorServices
- Fallback pattern: check if service is available, return sensible default if not (used throughout codebase)

### Integration Points
- `DX.Blame.Formatter.pas`: DeriveAnnotationColor implementation change
- `DX.Blame.KeyBinding.pas` implementation uses: Registration (line 58) — this reference must be eliminated
- `DX.Blame.Registration.pas` implementation uses: KeyBinding (line 39) — this reference stays (Registration orchestrates lifecycle)
- `DX.Blame.Popup.pas`: OnShowDiffClick field and property removal
- `DX.Blame.Registration.pas` finalization (line 322, 327): Guard conditions to verify

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-tech-debt-cleanup*
*Context gathered: 2026-03-23*
