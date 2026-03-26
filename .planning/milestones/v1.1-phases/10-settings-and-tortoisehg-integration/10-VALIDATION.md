---
phase: 10
slug: settings-and-tortoisehg-integration
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-24
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (manual IDE verification — no automated test project for OTA/VCL) |
| **Config file** | none — manual verification only |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk` |
| **Full suite command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.groupproj` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk`
- **After every plan wave:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project DX.Blame.groupproj`
- **Before `/gsd:verify-work`:** Full suite must compile clean
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | SETT-01 | compile + manual | `DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk` | N/A | ⬜ pending |
| 10-01-02 | 01 | 1 | SETT-01 | compile + manual | `DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk` | N/A | ⬜ pending |
| 10-02-01 | 02 | 1 | SETT-02 | compile + manual | `DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk` | N/A | ⬜ pending |
| 10-02-02 | 02 | 1 | SETT-03 | compile + manual | `DelphiBuildDPROJ.ps1 -Project src/DX.Blame.Engine.dpk` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No automated test stubs needed — all verification is compilation + manual IDE testing (consistent with all prior phases).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| VCS preference combo in settings dialog | SETT-01 | Requires running IDE with OTA-registered package | Load package, open Settings, change VCS preference, verify INI persists value, verify discovery respects preference |
| TortoiseHg Annotate context menu | SETT-02 | Requires IDE context menu + external process launch | Open Hg project file, right-click, select "Open in TortoiseHg Annotate", verify thg opens with correct file |
| TortoiseHg Log context menu | SETT-03 | Requires IDE context menu + external process launch | Open Hg project file, right-click, select "Open in TortoiseHg Log", verify thg opens with correct file |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
