# DX.Blame

## What This Is

Ein Delphi IDE Plugin (Design-Time Package), das Git-Blame-Informationen inline im Code-Editor anzeigt. Wenn das aktuelle Projekt in einem Git-Repository liegt, wird am Ende der aktuellen Codezeile angezeigt, wer diese Zeile zuletzt bearbeitet hat — vergleichbar mit GitLens in VS Code.

## Core Value

Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Inline Blame-Anzeige am Zeilenende (Autor, relative Zeit)
- [ ] Hover-Tooltip mit Commit-Hash, voller Commit-Message, Datum, Autor
- [ ] Commit-Detail-Ansicht (voller Diff) aus dem Tooltip heraus
- [ ] Git-Repo-Erkennung für das aktuelle Projekt
- [ ] Lazy Blame beim Datei-Öffnen mit Caching
- [ ] Cache-Invalidierung bei Dateiänderungen
- [ ] Toggle per Menü und konfigurierbarem Hotkey
- [ ] Git CLI Integration (git blame Aufruf)
- [ ] Unterstützung für Delphi 11, 12 und 13
- [ ] Design-Time Package (BPL) Installation

### Out of Scope

- libgit2 native Bindings — unnötige Komplexität, git CLI ist zuverlässiger und einfacher
- Gutter-Spalte für Blame — v1 nur inline am Zeilenende
- Blame für nicht-gespeicherte Änderungen — nur committed/staged Code
- Git History Browser — nur Blame, kein vollständiger Git-Client
- Andere VCS (SVN, Mercurial) — nur Git

## Context

- Delphi IDE Plugins nutzen die Open Tools API (OTA/IOTAxx Interfaces)
- Editor-Notifier (IOTAEditorNotifier) für Tab-Wechsel und Änderungen
- INTAEditServicesNotifier für Cursor-Tracking im Editor
- Git blame wird per Shell-Aufruf (`git blame --porcelain`) ausgeführt
- Das Plugin muss die Blame-Ausgabe parsen und zeilenweise cachen
- Inline-Darstellung erfordert Custom Painting im Editor via OTA

## Constraints

- **Tech Stack**: Delphi, Open Tools API — kein externes Framework
- **Git**: Muss im PATH verfügbar sein, keine eingebettete Git-Installation
- **Kompatibilität**: Delphi 11 Alexandria, 12 Athens, 13 — bedingte Kompilierung wo nötig
- **Performance**: Blame darf den IDE-Workflow nicht blockieren — asynchrone Ausführung erforderlich

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Inline am Zeilenende statt Gutter | Wie GitLens — vertrautes UX-Pattern, weniger invasiv | — Pending |
| Git CLI statt libgit2 | Einfacher, zuverlässiger, weniger Abhängigkeiten | — Pending |
| Design-Time Package statt DLL Expert | Standard für IDE-Plugins, einfachere Installation | — Pending |
| Lazy + Cache Strategie | Ganze Datei beim Öffnen blamen, dann aus Cache — guter Kompromiss | — Pending |
| Delphi 11+ Support | Breite Nutzerbasis, OTA-Interfaces stabil seit 11 | — Pending |

---
*Last updated: 2026-03-17 after initialization*
