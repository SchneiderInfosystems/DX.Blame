# Phase 1: Package Foundation - Context

**Gathered:** 2026-03-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Installable design-time BPL for Delphi 11.3+, 12, and 13 that registers with the IDE (splash screen, About dialog), provides a disabled menu placeholder under Tools, and unloads cleanly without crashes or leaks. No blame functionality — just the stable plugin shell.

</domain>

<decisions>
## Implementation Decisions

### Package Identity
- Display name: "DX.Blame" in splash screen and Install Packages dialog
- Description in Help > About: "Git Blame for Delphi"
- Custom splash icon — user will provide the bitmap, code sets up the resource framework
- Copyright: Olaf Monien (per CLAUDE.md standard)

### Multi-Delphi Strategy
- Single source codebase with conditional compilation (`{$IF}` directives) for OTA differences between Delphi versions
- Primary development/test target: Delphi 13
- BPL output filename without version suffix: `DX.Blame.bpl`
- Build one Delphi version at a time using DelphiBuildDPROJ.ps1

### Project Structure
- Single design-time package (no engine/runtime split) — DX.Blame.dpk
- Simplified folder structure: src/, build/, docs/, tests/, res/ — no FMX/VCL/demo subfolders
- Central OTA registration unit: DX.Blame.Registration.pas handles splash, about, menu, and all notifier lifecycle
- Unit tests with DUnitX (git submodule)

### Menu Placeholder
- Register "DX Blame" submenu under the IDE Tools menu
- Two disabled/greyed-out items: "Enable Blame" (toggle) and "Settings..."
- Menu entries must be removed on BPL unload — part of "clean unload" verification
- Phase 3 enables and implements the menu actions

### Claude's Discretion
- Exact OTA interface usage and notifier implementation details
- Conditional compilation strategy for version differences
- DUnitX test structure and what's testable outside the IDE
- Resource file format for splash icon placeholder

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard OTA plugin approaches. User will provide the splash icon bitmap separately.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- CLAUDE.md defines Delphi project structure, naming conventions, and build standards
- DelphiBuildDPROJ.ps1 from omonien/DelphiStandards for building
- Git standards (.gitignore, .gitattributes) from omonien/DelphiStandards

### Integration Points
- BPL installs via Component > Install Packages in the IDE
- OTA services (IOTAServices, INTAServices) are the primary integration surface
- res/ directory will hold the splash icon bitmap resource

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-package-foundation*
*Context gathered: 2026-03-19*
