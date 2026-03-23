# DX.Blame

## What This Is

Ein Delphi IDE Plugin (Design-Time Package), das Git-Blame-Informationen inline im Code-Editor anzeigt. Wenn das aktuelle Projekt in einem Git-Repository liegt, wird am Ende der aktuellen Codezeile angezeigt, wer diese Zeile zuletzt bearbeitet hat — vergleichbar mit GitLens in VS Code. Klick auf die Annotation zeigt Commit-Details mit farbcodiertem Diff.

## Core Value

Der Entwickler sieht auf einen Blick, wer eine Codezeile zuletzt geändert hat und wann, ohne die IDE verlassen zu müssen.

## Requirements

### Validated

- ✓ Inline Blame-Anzeige am Zeilenende (Autor, relative Zeit) — v1.0
- ✓ Klick-Popup mit Commit-Hash, voller Commit-Message, Datum, Autor — v1.0
- ✓ Commit-Detail-Ansicht (voller Diff) aus dem Popup heraus — v1.0
- ✓ Git-Repo-Erkennung für das aktuelle Projekt — v1.0
- ✓ Lazy Blame beim Datei-Öffnen mit Caching — v1.0
- ✓ Cache-Invalidierung bei Dateiänderungen — v1.0
- ✓ Toggle per Menü und konfigurierbarem Hotkey (Ctrl+Alt+B) — v1.0
- ✓ Git CLI Integration (git blame --porcelain) — v1.0
- ✓ Unterstützung für Delphi 11, 12 und 13 — v1.0
- ✓ Design-Time Package (BPL) Installation — v1.0
- ✓ Konfigurierbare Anzeige (Autor, Datumsformat, Max-Länge, Farbe) — v1.0
- ✓ Theme-aware Annotation-Farbe (automatische Ableitung aus IDE-Theme) — v1.0
- ✓ Navigation zur annotierten Revision per Kontextmenü — v1.0
- ✓ RTF-farbcodierter Diff-Dialog mit Scope-Toggle und Größenpersistenz — v1.0

### Active

(None — next milestone requirements to be defined via `/gsd:new-milestone`)

### Out of Scope

- libgit2 native Bindings — unnötige Komplexität, git CLI ist zuverlässiger und einfacher
- Blame für nicht-gespeicherte Änderungen — nur committed/staged Code
- Git History Browser — nur Blame, kein vollständiger Git-Client
- Andere VCS (SVN, Mercurial) — nur Git
- Real-time Blame bei jedem Tastendruck — Performance-Killer, sinnlos für uncommitted Änderungen

## Context

Shipped v1.0 with 4,533 LOC Delphi across 17 production units.
Tech stack: Delphi, Open Tools API, git CLI.
Architecture: OTA plugin with async blame engine, thread-safe cache, INTACodeEditorEvents renderer.

- Editor-Notifier (IOTAEditorNotifier) für Tab-Wechsel und Änderungen
- INTAEditServicesNotifier für Cursor-Tracking im Editor
- Git blame wird per Shell-Aufruf (`git blame --porcelain`) ausgeführt
- Click-based popup (not hover) for commit details — EditorMouseDown detection
- Modal diff dialog with RTF coloring and DPI-aware scaling

## Constraints

- **Tech Stack**: Delphi, Open Tools API — kein externes Framework
- **Git**: Muss im PATH verfügbar sein, keine eingebettete Git-Installation
- **Kompatibilität**: Delphi 11 Alexandria, 12 Athens, 13 — bedingte Kompilierung wo nötig
- **Performance**: Blame darf den IDE-Workflow nicht blockieren — asynchrone Ausführung erforderlich

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Inline am Zeilenende statt Gutter | Wie GitLens — vertrautes UX-Pattern, weniger invasiv | ✓ Good — works well, users see annotation naturally |
| Git CLI statt libgit2 | Einfacher, zuverlässiger, weniger Abhängigkeiten | ✓ Good — reliable, no DLL distribution needed |
| Design-Time Package statt DLL Expert | Standard für IDE-Plugins, einfachere Installation | ✓ Good — standard install via Component > Install Packages |
| Lazy + Cache Strategie | Ganze Datei beim Öffnen blamen, dann aus Cache — guter Kompromiss | ✓ Good — no perceptible delay, cache invalidation on save works |
| Delphi 11+ Support | Breite Nutzerbasis, OTA-Interfaces stabil seit 11 | ✓ Good — {$LIBSUFFIX AUTO} handles version suffixes |
| Click-Popup statt Hover-Tooltip | Hover-Detection in OTA nicht zuverlässig machbar | ✓ Good — click on author name triggers popup, feels natural |
| Pre-compile .rc to .res with BRCC32 | Avoids RLINK32 16-bit resource error in Delphi 13 | ✓ Good — solved cross-version resource compilation |
| Midpoint blend for annotation color | (channel + 128) / 2 for theme-aware color | ✓ Good — works with light and dark themes |
| OnBlameToggled callback pattern | Break circular dependency KeyBinding ↔ Registration | ✓ Good — clean decoupling via TProc |

---
*Last updated: 2026-03-23 after v1.0 milestone*
