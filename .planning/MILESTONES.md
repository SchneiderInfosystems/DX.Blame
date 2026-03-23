# Milestones

## v1.0 DX.Blame: Inline Git Blame for Delphi IDE (Shipped: 2026-03-23)

**Phases completed:** 5 phases, 11 plans
**Timeline:** 7 days (2026-03-17 to 2026-03-23)
**Stats:** 85 commits, 103 files, 4,533 LOC Delphi

**Key accomplishments:**
- Compilable DX.Blame.bpl design-time package with OTA registration (wizard, splash, about box, Tools menu)
- Complete async git blame engine with porcelain parser, thread-safe cache, and 28 unit tests
- Inline blame annotations with configurable formatting, Ctrl+Alt+B toggle, settings dialog, and revision navigation
- Click-triggered popup panel with async commit detail fetch and modal diff dialog with RTF color-coded diffs
- Theme-aware annotation coloring via IDE editor background blending, circular dependency fix, and dead code cleanup

**Tech debt (non-blocking):**
- Placeholder comments in Registration.pas (intentional no-ops)
- DoRetryBlame timer-to-key ordering warning
- ROADMAP.md Phase 3 stale text ("parent commit" vs "annotated commit")
- Phase 4-02 SUMMARY phantom GetAnnotationHashLength documentation
- Double CleanupPopup call in finalization (safe but redundant)

**Audit:** 14/14 requirements, 6/6 E2E flows, all passed

---

