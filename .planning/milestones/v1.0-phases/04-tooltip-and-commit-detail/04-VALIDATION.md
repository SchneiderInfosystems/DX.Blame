---
phase: 4
slug: tooltip-and-commit-detail
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-23
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (latest, via git submodule) |
| **Config file** | tests/DX.Blame.Tests.dpr |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |
| **Full suite command** | Same as quick run (single test project) |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe`
- **After every plan wave:** Run full suite (same command)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-xx | 01 | 1 | TTIP-01 | unit | `DX.Blame.Tests.exe --run=TCommitDetailCacheTests` | ❌ W0 | ⬜ pending |
| 04-01-xx | 01 | 1 | TTIP-01 | manual-only | Manual: requires IDE runtime | N/A | ⬜ pending |
| 04-02-xx | 02 | 1 | TTIP-02 | unit | `DX.Blame.Tests.exe --run=TDiffFormatterTests` | ❌ W0 | ⬜ pending |
| 04-02-xx | 02 | 1 | TTIP-02 | unit | `DX.Blame.Tests.exe --run=TSettingsTests` | ✅ | ⬜ pending |
| 04-02-xx | 02 | 1 | TTIP-02 | unit | `DX.Blame.Tests.exe --run=TCommitDetailTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/DX.Blame.Tests.CommitDetail.pas` — stubs for TTIP-01/TTIP-02 commit detail cache and git command construction
- [ ] `tests/DX.Blame.Tests.DiffFormatter.pas` — stubs for TTIP-02 RTF line coloring logic
- [ ] Extend `tests/DX.Blame.Tests.Settings.pas` — covers DiffDialog Width/Height persistence

*Existing infrastructure covers test framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Popup shows correct fields for uncommitted line | TTIP-01 | Requires IDE runtime with loaded blame data | 1. Open blamed file 2. Click uncommitted line annotation 3. Verify "Not committed yet" message |
| Full message fetch via git log format | TTIP-01 | Requires git repo context | 1. Click annotation 2. Verify full commit message displays correctly |
| Click-to-copy hash | TTIP-01 | Requires IDE runtime + clipboard | 1. Click short hash in popup 2. Verify full SHA in clipboard |
| Diff dialog shows colored diff | TTIP-02 | Requires IDE runtime + git repo | 1. Click "Show Diff" 2. Verify green/red coloring on additions/deletions |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
