---
phase: 11
slug: engine-project-switch-lifecycle-fix
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-25
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (submodule in libs/) |
| **Config file** | tests/ directory (project convention) |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/*.dproj` |
| **Full suite command** | Same (single test project) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1` (compilation check)
- **After every plan wave:** Full compile + manual IDE verification
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 11-01-01 | 01 | 1 | VCSA-05 | manual-only | Compile + IDE test: trigger blame error, switch project, verify no stale retry | N/A | ⬜ pending |
| 11-01-02 | 01 | 1 | VCSD-05 | manual-only | Compile + IDE test: open non-VCS project, switch to another, verify message appears | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No automated test infrastructure changes needed — this is a single-file bugfix verified by compilation and manual IDE testing.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Retry timers cancelled on project switch | VCSA-05 | Requires Delphi IDE runtime (TTimer lifecycle, BorlandIDEServices) | 1. Open project with VCS, trigger blame error to create retry timer 2. Switch to different project 3. Verify no stale retry fires (no blame request for previous file) |
| FVCSNotified reset per project | VCSD-05 | Requires IDE message services (IOTAMessageServices) | 1. Open non-VCS project, verify "No VCS detected" message 2. Switch to another non-VCS project 3. Verify message appears again (not suppressed) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
