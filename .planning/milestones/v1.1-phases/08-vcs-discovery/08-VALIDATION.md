---
phase: 8
slug: vcs-discovery
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (Git submodule under /libs) |
| **Config file** | tests/ directory |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.Engine.dpk`
- **After every plan wave:** Full package build + manual IDE load test
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 8-01-01 | 01 | 1 | VCSD-01 | unit | Build ScanForVCS with mock directories | ❌ W0 | ⬜ pending |
| 8-01-02 | 01 | 1 | VCSD-02 | unit | Test FindHgExecutable with manipulated PATH | ❌ W0 | ⬜ pending |
| 8-01-03 | 01 | 1 | VCSD-03 | manual | Requires real hg repo - manual verification | N/A | ⬜ pending |
| 8-01-04 | 01 | 1 | VCSD-04 | unit | Test persistence read/write in INI | ❌ W0 | ⬜ pending |
| 8-01-05 | 01 | 1 | VCSD-05 | manual | Requires running IDE plugin | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Unit tests for Hg discovery are deferred — hg.exe/repo availability varies by machine
- [ ] Compilation verification is the primary automated gate for this phase
- [ ] Manual testing with real Git and Hg repos required for VCSD-01, VCSD-03, VCSD-05

*Primary automated validation: package compilation succeeds.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| hg root verification | VCSD-03 | Requires real Mercurial repo on disk | 1. Create temp hg repo, 2. Open project pointing to it, 3. Verify `hg root` is called and repo activates |
| IDE Messages logging | VCSD-05 | Requires running IDE plugin in Delphi | 1. Open project in Git repo, 2. Check Messages pane shows "Git repository detected", 3. Repeat for Hg repo |
| Dual-VCS prompt | VCSD-04 | Requires both .git and .hg in same directory tree | 1. Create project with both, 2. Verify dialog appears, 3. Select choice, reopen, verify no re-prompt |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
