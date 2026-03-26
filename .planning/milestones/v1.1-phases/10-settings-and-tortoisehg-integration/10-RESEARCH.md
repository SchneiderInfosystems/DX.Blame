# Phase 10: Settings and TortoiseHg Integration - Research

**Researched:** 2026-03-24
**Domain:** Delphi VCL settings UI, TortoiseHg CLI integration, IDE context menu injection
**Confidence:** HIGH

## Summary

Phase 10 has three distinct deliverables: (1) add a VCS preference combo box to the existing settings dialog, (2) add a "TortoiseHg Annotate" context menu item, and (3) add a "TortoiseHg Log" context menu item. All three build on well-established patterns already present in the codebase.

The settings dialog (`DX.Blame.Settings.Form`) already exists as a VCL modal form with GroupBox-organized controls and a Load/Save cycle through the `TDXBlameSettings` singleton. Adding a VCS preference dropdown follows the exact same pattern as the existing Date Format combo box. The context menu injection pattern is already proven in `DX.Blame.Navigation` which dynamically injects "Previous Revision" via the editor popup's `OnPopup` hook.

TortoiseHg provides `thg.exe` as a command-line GUI launcher. The relevant commands are `thg annotate <file>` and `thg log <file>`, both accepting an optional `-R <repo-root>` global option. The executable lives in the same directory as `hg.exe` (the TortoiseHg install folder), so discovery is already solved by `FindHgExecutable` in `DX.Blame.Hg.Discovery`.

**Primary recommendation:** Extend the existing Settings.Form/Settings unit with a VCS preference combo, extend the existing Navigation context menu hook to add two TortoiseHg items (visible only when Mercurial is active), and derive `thg.exe` path from the already-discovered `hg.exe` path.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETT-01 | User can select VCS preference (Auto/Git/Mercurial) in settings dialog | Add combo box to existing Settings.Form, add VCSPreference property to TDXBlameSettings, wire into VCS.Discovery |
| SETT-02 | User can open current file in TortoiseHg Annotate via context menu | Add "Open in TortoiseHg Annotate" to editor popup using existing OnPopup hook pattern, launch thg annotate <file> |
| SETT-03 | User can open current file in TortoiseHg Log via context menu | Add "Open in TortoiseHg Log" to editor popup using same pattern, launch thg log <file> |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| VCL (TGroupBox, TComboBox, TMenuItem) | Delphi 13 | Settings UI and context menu | Already used throughout the project |
| ToolsAPI (INTAEditorServices) | Delphi 13 | Editor popup menu injection | Already used in DX.Blame.Navigation |
| TIniFile | RTL | Settings persistence | Already used in DX.Blame.Settings |
| ShellExecute / CreateProcess | WinAPI | Launch thg.exe | Standard Windows process launch |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| System.IOUtils (TPath) | RTL | Path manipulation for thg.exe discovery | Deriving thg.exe from hg.exe path |

## Architecture Patterns

### Existing Pattern: Settings Load/Save Cycle

The settings form uses a proven pattern:
1. `FormCreate` calls `LoadFromSettings` (reads from `BlameSettings` singleton)
2. User edits controls
3. `ButtonOKClick` calls `SaveToSettings` (writes back to singleton + `Save`)
4. `Save` persists to `%APPDATA%\DX.Blame\settings.ini`

The new VCS Preference combo follows this exactly.

### Existing Pattern: Context Menu Injection via OnPopup Hook

`DX.Blame.Navigation` hooks the editor's `EditorLocalMenu` popup:
1. `AttachContextMenu` finds the popup via `INTAEditorServices.TopEditWindow.Form.FindComponent('EditorLocalMenu')`
2. Saves original `OnPopup`, replaces with own handler
3. `OnEditorPopup` removes old items, creates fresh `TMenuItem` instances, appends to popup
4. Chains to original `OnPopup`
5. `DetachContextMenu` restores original handler and frees items

The TortoiseHg menu items should be added through the same hook, not a separate one.

### Recommended Approach for VCS Preference

```
TDXBlameVCSPreference = (vpAuto, vpGit, vpMercurial);
```

- `vpAuto`: Current behavior -- auto-detect, prompt on dual-VCS (default)
- `vpGit`: Force Git backend
- `vpMercurial`: Force Mercurial backend

This enum is stored in `TDXBlameSettings` and read by `TVCSDiscovery.DetectProvider` to skip detection when a preference is set.

### Recommended Approach for TortoiseHg Context Menu

Add items to the existing `OnEditorPopup` handler in `DX.Blame.Navigation`:

```
--- separator ---
Show revision <time>      (existing)
--- separator ---                       (new, only when Mercurial active)
Open in TortoiseHg Annotate             (new)
Open in TortoiseHg Log                  (new)
```

Items are only visible when:
1. `BlameEngine.Provider` is not nil
2. `BlameEngine.Provider.GetDisplayName = 'Mercurial'`
3. `thg.exe` can be located

### Recommended Approach for thg.exe Discovery

`thg.exe` ships alongside `hg.exe` in the TortoiseHg installation directory. Given that `FindHgExecutable` already returns the full path to `hg.exe`, deriving `thg.exe` is:

```pascal
function FindThgExecutable: string;
var
  LHgPath: string;
begin
  LHgPath := FindHgExecutable;
  if LHgPath = '' then
    Exit('');
  Result := TPath.Combine(TPath.GetDirectoryName(LHgPath), 'thg.exe');
  if not TFile.Exists(Result) then
    Result := '';
end;
```

### TortoiseHg Command-Line Syntax

```
thg annotate -R "<repo-root>" "<file-path>"
thg log -R "<repo-root>" "<file-path>"
```

Global options: `-R <path>` sets repository root. File path is the last positional argument.

Launch with `CreateProcess` or `ShellExecute` with `SW_SHOWNORMAL` -- the thg GUI runs independently.

### Anti-Patterns to Avoid

- **Separate OnPopup hook for TortoiseHg items:** Would conflict with the existing hook in Navigation. Extend the existing one instead.
- **Blocking launch (WaitForSingleObject):** thg is a GUI app; launch fire-and-forget.
- **Hard-coding thg.exe path:** Derive from the already-discovered hg.exe path.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process launching | Custom WinAPI CreateProcess wrapper | ShellExecute or existing TVCSProcess pattern | ShellExecute handles path quoting, SW_SHOWNORMAL, and is simpler for fire-and-forget GUI launch |
| thg.exe discovery | Separate search of PATH and install dirs | Derive from FindHgExecutable result | thg.exe and hg.exe always ship in the same directory in TortoiseHg |
| VCS preference persistence | New INI section | Extend existing TDXBlameSettings Load/Save with new [VCS] section | Consistent with all other settings |

## Common Pitfalls

### Pitfall 1: VCS Preference vs Per-Project Choice Conflict
**What goes wrong:** The global VCS preference and the per-project dual-VCS choice (already persisted via `SetVCSChoice`) could conflict.
**Why it happens:** `ResolveChoice` in `VCS.Discovery` currently only checks stored per-project choice for dual-VCS repos.
**How to avoid:** The global preference should take priority over auto-detection but the per-project choice for dual-VCS repos should still be respected when preference is Auto. When preference is Git or Mercurial, skip detection entirely and create the forced provider.
**Warning signs:** Changing preference in settings has no effect on current project.

### Pitfall 2: Context Menu Items Leaking When Provider Changes
**What goes wrong:** TortoiseHg menu items remain visible after switching to a Git-only project.
**Why it happens:** Context menu items are created dynamically on each popup, but the check for Mercurial provider must be current.
**How to avoid:** Check `BlameEngine.Provider.GetDisplayName` on every popup event, not cached at attach time. The existing pattern already recreates items on every popup, so this is naturally handled.

### Pitfall 3: thg.exe Not Found Despite hg.exe Present
**What goes wrong:** User has standalone Mercurial (not TortoiseHg) installed; hg.exe exists but thg.exe does not.
**Why it happens:** Some Mercurial installations ship hg.exe without the TortoiseHg GUI.
**How to avoid:** Menu items should check for thg.exe existence and be hidden/disabled when not found. Do not show error -- just omit the items.

### Pitfall 4: Settings Dialog Height Insufficient
**What goes wrong:** Adding a new GroupBox to the form causes controls to overlap or be clipped.
**Why it happens:** The form has a fixed `ClientHeight = 470` and is `bsDialog` (non-resizable).
**How to avoid:** Increase `ClientHeight` to accommodate the new VCS GroupBox. Move OK/Cancel buttons down. The new GroupBox needs approximately 65px (matching GroupBoxDisplay height).

### Pitfall 5: Fire-and-Forget Process Handle Leak
**What goes wrong:** Using CreateProcess without closing the process/thread handles leaks handles.
**Why it happens:** CreateProcess returns handles that must be explicitly closed even for detached processes.
**How to avoid:** Use `ShellExecute` which does not return handles that need closing. Or if using `CreateProcess`, close both `hProcess` and `hThread` immediately after launch.

## Code Examples

### Adding VCS Preference to Settings

```pascal
// In DX.Blame.Settings.pas
type
  TDXBlameVCSPreference = (vpAuto, vpGit, vpMercurial);

// Add to TDXBlameSettings
FVCSPreference: TDXBlameVCSPreference;
property VCSPreference: TDXBlameVCSPreference read FVCSPreference write FVCSPreference;

// In Load:
LPrefStr := LIni.ReadString('VCS', 'Preference', 'Auto');
if SameText(LPrefStr, 'Git') then
  FVCSPreference := vpGit
else if SameText(LPrefStr, 'Mercurial') then
  FVCSPreference := vpMercurial
else
  FVCSPreference := vpAuto;

// In Save:
case FVCSPreference of
  vpAuto: LIni.WriteString('VCS', 'Preference', 'Auto');
  vpGit: LIni.WriteString('VCS', 'Preference', 'Git');
  vpMercurial: LIni.WriteString('VCS', 'Preference', 'Mercurial');
end;
```

### VCS Discovery Integration

```pascal
// In TVCSDiscovery.DetectProvider - at top of method:
case BlameSettings.VCSPreference of
  vpGit:
  begin
    Result := TGitProvider.Create;
    if Result.FindExecutable = '' then Exit(nil);
    ARepoRoot := Result.FindRepoRoot(AProjectPath);
    if ARepoRoot = '' then Result := nil;
    Exit;
  end;
  vpMercurial:
  begin
    Result := THgProvider.Create;
    if Result.FindExecutable = '' then Exit(nil);
    ARepoRoot := Result.FindRepoRoot(AProjectPath);
    if ARepoRoot = '' then Result := nil;
    Exit;
  end;
  // vpAuto: fall through to existing detection logic
end;
```

### Launching TortoiseHg

```pascal
// Fire-and-forget launch of thg.exe
procedure LaunchThg(const ACommand, ARepoRoot, AFilePath: string);
var
  LThgPath: string;
  LArgs: string;
begin
  LThgPath := FindThgExecutable;
  if LThgPath = '' then
    Exit;

  LArgs := ACommand + ' -R "' + ARepoRoot + '" "' + AFilePath + '"';
  ShellExecute(0, 'open', PChar(LThgPath), PChar(LArgs), PChar(ARepoRoot), SW_SHOWNORMAL);
end;
```

### Context Menu Injection (extending existing OnEditorPopup)

```pascal
// In OnEditorPopup, after existing "Show revision" item:
if (BlameEngine.Provider <> nil) and
   SameText(BlameEngine.Provider.GetDisplayName, 'Mercurial') and
   (FindThgExecutable <> '') then
begin
  LThgSeparator := TMenuItem.Create(nil);
  LThgSeparator.Caption := '-';
  TPopupMenu(Sender).Items.Add(LThgSeparator);

  LThgAnnotateItem := TMenuItem.Create(nil);
  LThgAnnotateItem.Caption := 'Open in TortoiseHg Annotate';
  LThgAnnotateItem.OnClick := Self.OnThgAnnotateClick;
  TPopupMenu(Sender).Items.Add(LThgAnnotateItem);

  LThgLogItem := TMenuItem.Create(nil);
  LThgLogItem.Caption := 'Open in TortoiseHg Log';
  LThgLogItem.OnClick := Self.OnThgLogClick;
  TPopupMenu(Sender).Items.Add(LThgLogItem);
end;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| hgtk (old TortoiseHg launcher) | thg (current launcher) | TortoiseHg 2.0+ | Always use `thg`, never `hgtk` |
| thg.exe (console) vs thgw.exe (GUI) | thg.exe handles both | Current | Use `thg.exe` -- works from both console and GUI contexts |

## Open Questions

1. **Should VCS preference change trigger immediate re-detection?**
   - What we know: Currently project switch calls `OnProjectSwitch` which re-detects. Settings change does not trigger re-detection.
   - What's unclear: Should changing VCS preference in settings immediately reinitialize the engine?
   - Recommendation: Yes -- after saving VCS preference, call `BlameEngine.OnProjectSwitch` with the current project path to re-detect with the new preference. This is the simplest approach using existing infrastructure.

2. **Should TortoiseHg items be visible for Git repos too (TortoiseGit)?**
   - What we know: Requirements only mention TortoiseHg, not TortoiseGit.
   - Recommendation: Out of scope per requirements. Only show for Mercurial provider.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | DUnitX (not confirmed if test project exists) |
| Config file | tests/ directory (check existence) |
| Quick run command | Manual IDE verification |
| Full suite command | Manual IDE verification |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETT-01 | VCS combo in settings, persisted to INI, affects discovery | manual-only | Load package in IDE, open settings, change VCS preference, verify INI | N/A |
| SETT-02 | TortoiseHg Annotate context menu launches thg annotate | manual-only | Right-click in Hg project, select item, verify thg opens | N/A |
| SETT-03 | TortoiseHg Log context menu launches thg log | manual-only | Right-click in Hg project, select item, verify thg opens | N/A |

**Justification for manual-only:** All three requirements involve IDE integration (OTA context menu, VCL modal dialog, external process launch) that cannot be automated without a running IDE instance.

### Sampling Rate
- **Per task commit:** Compile package with DelphiBuildDPROJ.ps1
- **Per wave merge:** Full compile + manual IDE smoke test
- **Phase gate:** All three context menu items functional in IDE

### Wave 0 Gaps
None -- no automated test infrastructure needed. Verification is compilation + manual IDE testing (consistent with all prior phases in this project).

## Sources

### Primary (HIGH confidence)
- Codebase analysis: `DX.Blame.Settings.pas`, `DX.Blame.Settings.Form.pas/.dfm`, `DX.Blame.Navigation.pas`, `DX.Blame.VCS.Discovery.pas`, `DX.Blame.Hg.Discovery.pas`, `DX.Blame.Registration.pas`, `DX.Blame.Engine.pas`
- [TortoiseHg man page (Debian)](https://manpages.debian.org/jessie/tortoisehg/thg.1.en.html) -- thg command syntax, global options (-R), annotate/log commands
- [TortoiseHg Introduction](https://tortoisehg.readthedocs.io/en/latest/intro.html) -- thg.exe as console launcher

### Secondary (MEDIUM confidence)
- [Matthew Manela blog on thg log](https://matthewmanela.com/blog/launching-the-tortoisehg-log-more-conveniently-from-the-command-line/) -- thg log file path syntax
- [TortoiseHg Documentation](https://tortoisehg.readthedocs.io/en/latest/) -- general reference

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all patterns already exist in codebase, no new libraries
- Architecture: HIGH - extending existing settings form and context menu hook
- Pitfalls: HIGH - well-understood VCL/OTA patterns with clear edge cases
- TortoiseHg CLI: MEDIUM - thg annotate/log syntax verified from man pages, but exact behavior with -R and file paths should be tested

**Research date:** 2026-03-24
**Valid until:** 2026-04-24 (stable -- no moving targets)
