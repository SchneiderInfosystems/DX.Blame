---
phase: 7
slug: engine-vcs-dispatch
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (Git submodule under libs/) |
| **Config file** | tests/DX.Blame.Tests.dproj |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Compile all affected units via DelphiBuildDPROJ.ps1
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-XX-01 | 01 | 1 | VCSA-05 | compile | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj` | Yes | ⬜ pending |
| 07-XX-02 | 01 | 1 | VCSA-05 | smoke | Run existing test suite | Yes | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.* No new test files needed — the primary verification is compilation success and uses-clause inspection. Runtime behavior is validated by existing tests continuing to pass.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Engine uses no direct Git calls; all operations route through IVCSProvider | VCSA-05 | Code structure check (no direct Git imports), not runtime behavior | Compile all units and verify no Git-specific units in consumer uses clauses |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
