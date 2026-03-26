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

## Milestone: v1.1 — Mercurial Support

**Shipped:** 2026-03-26
**Phases:** 6 | **Plans:** 11 | **Timeline:** 3 days

### What Was Built
- IVCSProvider abstraction layer with shared types, process base class, and interface-based dispatch
- Full engine refactor — all 5 consumer units dispatch through IVCSProvider with zero direct Git calls
- Auto-detection of Git/Hg repositories with dual-VCS prompt and per-project persistence
- Complete Mercurial blame at Git parity — annotations, commit details, RTF diffs, revision navigation
- VCS preference setting (Auto/Git/Mercurial) and TortoiseHg Annotate/Log context menu items
- Engine lifecycle fix — FRetryTimers dictionary and FVCSNotified reset on project switch

### What Worked
- Mirror pattern strategy: building THgProvider as an exact structural mirror of TGitProvider kept both implementations consistent and the code reviewable
- Phase-sequential architecture: each phase cleanly built on the previous (abstraction → dispatch → discovery → provider → settings → fix)
- Milestone audit → gap closure cycle: MISS-1 and MISS-2 caught by the v1.1 audit were resolved in Phase 11 within minutes
- Template-based hg annotate parser: pipe-delimited format was clean to parse and completely independent from Git's porcelain parser
- Derive thg.exe from hg.exe path: simple co-location assumption avoided registry/PATH complexity

### What Was Inefficient
- Phases 6 and 7 ROADMAP checkboxes not marked `[x]` despite complete execution — cosmetic tracking gap that persisted until Phase 11
- Some SUMMARY.md files lack `one_liner` frontmatter field — needed manual extraction at milestone completion
- Nyquist VALIDATION.md files for Phases 6-10 created but never populated during execution (feature added mid-milestone)

### Patterns Established
- IVCSProvider interface pattern for multi-backend VCS dispatch
- TVCSDiscovery with nested local functions (ScanForVCS, ResolveChoice, PromptForVCS) for minimal public API
- MD5-hashed project path key for per-project settings persistence
- FRetryTimers/FDebounceTimers parallel dictionary pattern for tracked timer lifecycle
- Conditional context menu injection via provider display name check

### Key Lessons
1. Gap closure phases are highly efficient — Phase 11 (2 tasks, 1 file) took 2 minutes because the research was precise and the fix pattern was established
2. Milestone audits surface bugs that phase-level verification misses — MISS-1 and MISS-2 were cross-phase lifecycle issues invisible at single-phase granularity
3. Template-based CLI output (hg annotate -T) produces cleaner parse targets than format-dependent output — consider this pattern for future CLI integrations

### Cost Observations
- Model mix: quality profile (opus-heavy), sonnet for checkers/verifiers
- Average plan execution: ~3.5min across 11 plans
- Total execution time: ~0.6 hours for 11 plans
- Notable: Entire milestone (6 phases, 11 plans) completed in 3 calendar days

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Timeline | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | 7 days | 5 | Initial milestone — established all patterns |
| v1.1 | 3 days | 6 | Mirror pattern strategy, milestone audit → gap closure cycle |

### Cumulative Quality

| Milestone | Tests | Audit Score | Tech Debt Items |
|-----------|-------|-------------|-----------------|
| v1.0 | 28 | 14/14 requirements | 6 non-blocking |
| v1.1 | 28 (unchanged) | 18/18 requirements | 2 non-blocking |

### Top Lessons (Verified Across Milestones)

1. Async-first architecture prevents IDE responsiveness issues
2. Click-based UX is more reliable than hover in OTA context
3. Documentation should be verified against code, not just plan status
4. Milestone audits catch cross-phase lifecycle bugs that phase-level verification misses
5. Mirror pattern strategy (building new backend as structural clone of existing) keeps implementations consistent
