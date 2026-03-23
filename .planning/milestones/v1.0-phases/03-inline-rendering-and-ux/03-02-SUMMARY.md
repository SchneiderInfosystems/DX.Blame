---
phase: 03-inline-rendering-and-ux
plan: 02
subsystem: renderer, keybinding, menu
tags: [inta-editor-events, keyboard-binding, inline-painting]

requires:
  - phase: 03-inline-rendering-and-ux
    plan: 01
    provides: TDXBlameSettings, FormatBlameAnnotation, DeriveAnnotationColor
provides:
  - TDXBlameRenderer INTACodeEditorEvents implementation for inline blame painting
  - TDXBlameKeyBinding IOTAKeyboardBinding for Ctrl+Alt+B toggle
  - Tools > DX Blame menu with Enable Blame toggle and Settings entry
affects: [03-03-settings-dialog]

tech-stack:
  added: [ToolsAPI.Editor, INTACodeEditorEvents, INTACodeEditorEvents370, IOTAKeyboardBinding]
  patterns: [editor-events-notifier, partial-keyboard-binding, canvas-state-save-restore]

key-files:
  created:
    - src/DX.Blame.Renderer.pas
    - src/DX.Blame.KeyBinding.pas
  modified:
    - src/DX.Blame.Engine.pas
    - src/DX.Blame.Registration.pas
    - src/DX.Blame.dpk

key-decisions:
  - "EditorSetCaretPos Y is view-relative (screen row), not logical line — always read from EditView.CursorPos.Line in PaintLine"
  - "AllowedEvents includes cevPaintLineEvents + cevKeyboardEvents for reliable caret tracking"
  - "Tools menu found via FindComponent('ToolsMenu') with caption fallback for cross-version compatibility"
  - "Menu items created without Name property to avoid IDE component name collisions across install cycles"
  - "BlameAlreadyOpenFiles iterates IOTAModuleServices.Modules on package load since ofnFileOpened doesn't fire for pre-existing files"

patterns-established:
  - "Renderer: plsEndPaint stage, after event only, save/restore canvas state"
  - "Caret tracking: read EditView.CursorPos.Line per paint call, not from EditorSetCaretPos Y"
  - "Thread safety: UnregisterThread called from Execute before TThread.Queue to prevent FreeOnTerminate race"

requirements-completed: [BLAME-01, UX-01, UX-02, CONF-02]

duration: manual-testing-session
completed: 2026-03-20
---

# Phase 3 Plan 02: Blame Renderer, Toggle & Keybinding Summary

**TDXBlameRenderer paints inline blame annotations via INTACodeEditorEvents; TDXBlameKeyBinding provides Ctrl+Alt+B toggle; Tools menu provides Enable Blame and Settings entries**

## Self-Check: PASSED

All must-haves verified during manual IDE testing:
- Annotation text appears after current line in italic muted color
- Toggle via menu and Ctrl+Alt+B works with immediate visual update
- Uncommitted lines show "Not committed yet"
- Annotation follows cursor correctly across lines
