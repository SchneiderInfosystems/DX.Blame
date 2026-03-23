---
phase: 3
slug: inline-rendering-and-ux
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | DUnitX (existing in project) |
| **Config file** | tests/DX.Blame.Tests.dpr |
| **Quick run command** | `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe` |
| **Full suite command** | Same as quick run (single test project) |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `powershell -File build/DelphiBuildDPROJ.ps1 -Project tests/DX.Blame.Tests.dproj -Config Debug -Platform Win32 && build\Win32\Debug\DX.Blame.Tests.exe`
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | BLAME-01 | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Formatter` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | CONF-01 | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Settings` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | CONF-02 | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Formatter` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | BLAME-01 | unit | `DX.Blame.Tests.exe --run DX.Blame.Tests.Formatter` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 1 | UX-01 | manual-only | N/A — requires running IDE | N/A | ⬜ pending |
| 03-03-02 | 03 | 1 | UX-02 | manual-only | N/A — requires running IDE | N/A | ⬜ pending |
| 03-04-01 | 04 | 2 | UX-03 | manual-only | N/A — requires running IDE | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/DX.Blame.Tests.Formatter.pas` — stubs for BLAME-01 annotation formatting, relative time, truncation, and CONF-02 theme color derivation
- [ ] `tests/DX.Blame.Tests.Settings.pas` — stubs for CONF-01 settings read/write round-trip
- [ ] Update `tests/DX.Blame.Tests.dpr` to include new test units

*Wave 0 creates test stubs that will be filled during execution.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Menu toggle on/off | UX-01 | Requires running IDE with plugin loaded | 1. Open IDE with DX.Blame installed 2. Open a Git-tracked file 3. Toggle via View menu 4. Verify annotation appears/disappears |
| Hotkey toggle | UX-02 | Requires running IDE keyboard binding | 1. Open IDE 2. Press Ctrl+Alt+B 3. Verify blame toggles 4. Check hotkey appears in IDE keymap |
| Parent revision navigation | UX-03 | Requires running IDE + git repo with history | 1. Open file with multiple revisions 2. Trigger "Previous Revision" 3. Verify new tab opens with parent blame |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
