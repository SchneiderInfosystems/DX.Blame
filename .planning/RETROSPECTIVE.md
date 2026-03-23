# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — DX.Blame: Inline Git Blame for Delphi IDE

**Shipped:** 2026-03-23
**Phases:** 5 | **Plans:** 11 | **Timeline:** 7 days

### What Was Built
- Design-time BPL package with full OTA lifecycle (wizard, splash, about box, menu)
- Async git blame engine with porcelain parser and thread-safe per-file cache
- Inline blame annotations with configurable formatting and theme-aware coloring
- Click-triggered popup with commit details and modal RTF diff dialog
- 28 unit tests covering parser, formatter, cache, and diff coloring

### What Worked
- Coarse phase granularity (5 phases for full plugin) kept planning overhead low
- Async-first architecture avoided all IDE blocking issues from the start
- Click-based popup (instead of hover tooltip) was simpler to implement and more reliable in OTA
- Pre-compiling .rc to .res with BRCC32 solved Delphi 13 RLINK32 compatibility immediately
- Thread-safe cache with TObjectDictionary + TCriticalSection was straightforward and correct

### What Was Inefficient
- Phase 4-02 SUMMARY documented phantom GetAnnotationHashLength feature that never existed in code — documentation divergence went unnoticed until audit
- Double CleanupPopup call (Registration + Renderer finalization) — redundant safety that could have been caught during Phase 4 review
- ROADMAP.md Phase 3 success criterion stale text survived through completion — should have been caught during phase verification

### Patterns Established
- OnBlameToggled TProc callback pattern for decoupling circular unit dependencies
- Midpoint blend formula `(channel + 128) / 2` for theme-aware annotation colors
- Unit-level dictionaries (GAnnotationXByRow, GLineByRow) for annotation hit-test data
- {$LIBSUFFIX AUTO} in DPK for automatic compiler version suffix across Delphi 11-13
- STRONGLINKTYPES ON + explicit RegisterTestFixture for reliable DUnitX discovery

### Key Lessons
1. Click-based interaction is more reliable than hover in Delphi OTA — EditorMouseDown gives precise coordinates; hover detection is fragile
2. Delphi 13 introduced stricter compiler rules (initialization before finalization) — always test newest compiler version first
3. Documentation divergence accumulates silently — SUMMARY files should be verified against actual code, not just plan completion

### Cost Observations
- Model mix: quality profile (opus-heavy)
- Average plan execution: 8min across 11 plans
- Total execution time: ~0.8 hours for 11 plans
- Notable: Phase 5 (tech debt) completed in 2min — focused cleanup phases are efficient

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 7 days | 5 | Initial milestone — established all patterns |

### Cumulative Quality

| Milestone | Tests | Audit Score | Tech Debt Items |
|-----------|-------|-------------|-----------------|
| v1.0 | 28 | 14/14 requirements | 6 non-blocking |

### Top Lessons (Verified Across Milestones)

1. Async-first architecture prevents IDE responsiveness issues
2. Click-based UX is more reliable than hover in OTA context
3. Documentation should be verified against code, not just plan status
