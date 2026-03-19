# Phase 1: Package Foundation - Research

**Researched:** 2026-03-19
**Domain:** Delphi Open Tools API (OTA) - Design-Time Package Development
**Confidence:** HIGH

## Summary

Phase 1 creates a design-time BPL that installs in Delphi 11.3+ (Alexandria), 12 (Athens), and 13 (Florence), registers with the IDE splash screen and About dialog, provides a disabled "DX Blame" menu placeholder under Tools, and unloads cleanly. This is a well-established pattern in the Delphi OTA ecosystem with extensive documentation from Embarcadero, GExperts, and community sources.

The core technique is straightforward: a single design-time package (.dpk) requiring `designide`, containing a `Register` procedure that registers an `IOTAWizard` via `IOTAWizardServices.AddWizard`, with splash/about registration in the unit initialization section and full cleanup in finalization. The main risk areas are (1) proper cleanup ordering on unload to avoid access violations and (2) bitmap resource ownership differences between splash screen and about box services.

**Primary recommendation:** Follow the DWScriptExpert/GExperts pattern -- wizard registration via `Register` procedure, splash in `initialization`, about box via `IOTAAboutBoxServices.AddPluginInfo`, menu items via `INTAServices`, and reverse-order cleanup in `finalization`. Keep all OTA lifecycle management in a single registration unit (`DX.Blame.Registration.pas`).

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions
- Display name: "DX.Blame" in splash screen and Install Packages dialog
- Description in Help > About: "Git Blame for Delphi"
- Custom splash icon -- user will provide the bitmap, code sets up the resource framework
- Copyright: Olaf Monien (per CLAUDE.md standard)
- Single source codebase with conditional compilation (`{$IF}` directives) for OTA differences
- Primary development/test target: Delphi 13
- BPL output filename without version suffix: `DX.Blame.bpl`
- Build one Delphi version at a time using DelphiBuildDPROJ.ps1
- Single design-time package (no engine/runtime split) -- DX.Blame.dpk
- Simplified folder structure: src/, build/, docs/, tests/, res/ -- no FMX/VCL/demo subfolders
- Central OTA registration unit: DX.Blame.Registration.pas handles splash, about, menu, and all notifier lifecycle
- Unit tests with DUnitX (git submodule)
- Register "DX Blame" submenu under the IDE Tools menu
- Two disabled/greyed-out items: "Enable Blame" (toggle) and "Settings..."
- Menu entries must be removed on BPL unload
- Phase 3 enables and implements the menu actions

### Claude's Discretion
- Exact OTA interface usage and notifier implementation details
- Conditional compilation strategy for version differences
- DUnitX test structure and what's testable outside the IDE
- Resource file format for splash icon placeholder

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope

</user_constraints>

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UX-04 | Plugin wird als Design-Time Package (BPL) installiert und unterstuetzt Delphi 11.3+, 12 und 13 | Covered by: DPK structure with `designide` requirement, `Register` procedure pattern, CompilerVersion conditional compilation (35/36/37), IOTASplashScreenServices and IOTAAboutBoxServices for IDE presence, clean unload via finalization |

</phase_requirements>

## Standard Stack

### Core
| Library/Unit | Version | Purpose | Why Standard |
|-------------|---------|---------|--------------|
| ToolsAPI | Ships with IDE | OTA interfaces (IOTAWizard, IOTAWizardServices, IOTAAboutBoxServices, IOTASplashScreenServices, INTAServices) | Official Embarcadero extension API |
| designide | Ships with IDE | Design-time package dependency providing BorlandIDEServices | Required for all design-time OTA packages |
| System.SysUtils | RTL | String handling, version formatting | Standard RTL |
| Vcl.Menus | VCL | TMenuItem for IDE menu integration | IDE menus are VCL-based |
| Vcl.Graphics | VCL | TBitmap for resource loading | Splash/about bitmap handling |
| Winapi.Windows | RTL | LoadBitmap, HInstance, FindResourceHInstance | Windows resource loading |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DUnitX | Latest (git submodule) | Unit testing framework | Testing non-OTA logic (version formatting, menu structure) |
| BRCC32 | Ships with IDE | Resource compiler (.rc to .res) | Compiling splash icon bitmap into resource |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Single design-time package | Separate runtime + design-time packages | Overkill for this project -- no runtime components to register |
| TMenuItem direct creation | TAction + TActionList | TAction adds complexity; disabled placeholders don't need action management |
| BRCC32 resource compiler | Delphi IDE resource editor | BRCC32 is scriptable and works in CI; IDE editor is interactive only |

## Architecture Patterns

### Recommended Project Structure
```
DX.Blame/
├── src/
│   ├── DX.Blame.dpk                  # Package source
│   ├── DX.Blame.dproj                # Project file
│   ├── DX.Blame.Registration.pas     # Central OTA lifecycle unit
│   └── DX.Blame.Version.pas          # Version constants (shared)
├── res/
│   ├── DX.Blame.SplashIcon.bmp       # 24x24 splash bitmap (user provides)
│   └── DX.Blame.res.rc               # Resource script
├── build/
│   ├── DelphiBuildDPROJ.ps1          # Universal build script
│   └── $(Platform)/$(Config)/        # Build output
├── tests/
│   └── DX.Blame.Tests.dproj          # DUnitX test project
├── docs/
├── libs/
│   └── DUnitX/                       # Git submodule
└── DX.Blame.groupproj               # Project group
```

### Pattern 1: Wizard Registration via Register Procedure
**What:** Design-time packages use a `Register` procedure (called by the IDE when the package loads) to register the wizard with `IOTAWizardServices.AddWizard`.
**When to use:** Always for design-time BPL packages.
**Example:**
```pascal
// Source: Embarcadero OTAPI-Docs, DWScriptExpert pattern
var
  GWizardIndex: Integer = -1;

procedure Register;
var
  LWizardServices: IOTAWizardServices;
begin
  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
    GWizardIndex := LWizardServices.AddWizard(TDXBlameWizard.Create);
end;
```

### Pattern 2: Splash Screen Registration in Initialization
**What:** Splash screen bitmap must be registered during unit initialization (before wizard registration), because the splash screen is shown before `BorlandIDEServices` is fully available.
**When to use:** Always -- initialization runs as BPL loads.
**Example:**
```pascal
// Source: GExperts FAQ, blog.dummzeuch.de
initialization
  // Splash screen -- runs early during BPL load
  if Assigned(SplashScreenServices) then
  begin
    LSplashBmp := LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH');
    SplashScreenServices.AddPluginBitmap(
      'DX.Blame',          // Plugin name
      LSplashBmp,          // 24x24 bitmap handle
      False,               // Not unregistered
      'Open Source'         // License status
    );
  end;
```

### Pattern 3: About Box Registration and Cleanup
**What:** About box entry via `IOTAAboutBoxServices.AddPluginInfo`, storing the returned index for removal in finalization.
**When to use:** After BorlandIDEServices is available (in Register or initialization).
**Critical:** The about box bitmap must NOT be freed -- the IDE takes ownership. The splash screen bitmap CAN be freed after registration.
**Example:**
```pascal
// Source: blog.dummzeuch.de, DWScriptExpert
var
  GAboutPluginIndex: Integer = -1;

// In Register or initialization:
if Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutBoxServices) then
begin
  LAboutBmp := LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH');
  GAboutPluginIndex := LAboutBoxServices.AddPluginInfo(
    'DX.Blame',                            // Title
    'Git Blame for Delphi' + sLineBreak +
    'Copyright (c) 2026 Olaf Monien',      // Description
    LAboutBmp,                             // Bitmap (do NOT free!)
    False,                                 // Not unregistered
    '',                                    // LicenceStatus (leave empty!)
    '1.0.0.0'                              // SKUName = version string
  );
end;

// In finalization:
if GAboutPluginIndex > 0 then
  if Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutBoxServices) then
    LAboutBoxServices.RemovePluginInfo(GAboutPluginIndex);
```

### Pattern 4: Menu Registration and Cleanup
**What:** Create TMenuItem hierarchy, add to IDE Tools menu via `INTAServices.AddActionMenu` or direct menu insertion.
**When to use:** In wizard initialization or Register.
**Example:**
```pascal
// Source: Embarcadero RAD Studio docs, DWScriptExpert
var
  GMenuItems: array of TMenuItem;

procedure CreateToolsMenu;
var
  LNTAServices: INTAServices;
  LParentItem, LSubItem: TMenuItem;
begin
  if not Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    Exit;

  // Create parent submenu "DX Blame"
  LParentItem := TMenuItem.Create(nil);
  LParentItem.Caption := 'DX Blame';
  LParentItem.Name := 'DXBlameMenu';

  // Create child items (disabled)
  LSubItem := TMenuItem.Create(LParentItem);
  LSubItem.Caption := 'Enable Blame';
  LSubItem.Name := 'DXBlameEnableItem';
  LSubItem.Enabled := False;
  LParentItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LParentItem);
  LSubItem.Caption := 'Settings...';
  LSubItem.Name := 'DXBlameSettingsItem';
  LSubItem.Enabled := False;
  LParentItem.Add(LSubItem);

  // Insert into Tools menu
  LNTAServices.AddActionMenu('ToolsMenu', nil, LParentItem);
end;

procedure RemoveToolsMenu;
begin
  // Free menu items (children freed by owner)
  FreeAndNil(GParentMenuItem);
end;
```

### Pattern 5: Finalization Cleanup Order
**What:** Reverse-order cleanup of all OTA registrations in finalization section.
**When to use:** Always in finalization of the registration unit.
**Example:**
```pascal
finalization
  // 1. Remove menu items first (UI elements)
  RemoveToolsMenu;
  // 2. Remove wizard
  if GWizardIndex > 0 then
    (BorlandIDEServices as IOTAWizardServices).RemoveWizard(GWizardIndex);
  // 3. Remove about box entry
  if GAboutPluginIndex > 0 then
    (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(GAboutPluginIndex);
end.
```

### Anti-Patterns to Avoid
- **Hardcoding menu indices:** Never use `NTAServices.MainMenu.Items[3]` to find the Tools menu -- the index varies by IDE version and installed plugins. Use `AddActionMenu('ToolsMenu', ...)` instead.
- **Freeing the about box bitmap:** The IDE takes ownership of the about box bitmap. Freeing it causes the bitmap to disappear from Help > About.
- **Using `SplashScreenServices.AddProductBitmap`:** Known bug (QC 42320) -- does nothing with only a single personality loaded. Always use `AddPluginBitmap`.
- **Registering splash screen in `Register` procedure:** Splash screen must be in `initialization` because it runs before `Register` is called, and the splash screen is shown early during IDE startup.
- **Multiple registration units:** Splitting OTA lifecycle across multiple units makes finalization ordering unpredictable. Keep everything in one unit.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| IDE splash screen integration | Custom splash window | IOTASplashScreenServices.AddPluginBitmap | Standard OTA interface, auto-positioned |
| IDE About dialog integration | Custom about form | IOTAAboutBoxServices.AddPluginInfo | Appears in official Help > About list |
| IDE menu integration | Finding menu by iterating MainMenu | INTAServices.AddActionMenu('ToolsMenu') | Version-independent menu location |
| Notifier base class | Custom IOTANotifier stub | TNotifierObject | Provides empty implementations for all IOTANotifier methods |
| Build automation | Custom MSBuild scripts | DelphiBuildDPROJ.ps1 | Already established in project standards |
| Resource compilation | Manual .res creation | BRCC32 with .rc script | Standard Delphi toolchain |

**Key insight:** The OTA provides service interfaces for every IDE integration point needed in this phase. There is zero reason to interact with IDE internals directly.

## Common Pitfalls

### Pitfall 1: Access Violation on BPL Unload
**What goes wrong:** IDE crashes with AV when unloading the BPL via Component > Install Packages.
**Why it happens:** Notifiers, wizard references, or menu items not properly removed before the BPL's code is unloaded from memory. The IDE then tries to call into freed memory.
**How to avoid:** Store all registration indices (wizard, about box). Remove ALL registrations in finalization, in reverse order. Nil-check BorlandIDEServices before calling Remove methods.
**Warning signs:** Any global variable holding an OTA index that doesn't have corresponding cleanup code.

### Pitfall 2: Bitmap Ownership Confusion
**What goes wrong:** Splash icon disappears from About dialog after some time, or AV on IDE close.
**Why it happens:** About box bitmap is freed by the plugin code, but the IDE still holds a reference to it. Splash screen bitmap is different -- it's copied internally.
**How to avoid:** Load TWO separate bitmap handles: one for splash (can be freed), one for about box (must NOT be freed). Or load once and don't free.
**Warning signs:** Using a single local bitmap variable for both splash and about registration.

### Pitfall 3: SplashScreenServices Not Available
**What goes wrong:** `SplashScreenServices` is nil when accessed.
**Why it happens:** The splash screen service is only available during IDE startup. It may not be available if the BPL is loaded late (e.g., dynamically installed after IDE start).
**How to avoid:** Always nil-check: `if Assigned(SplashScreenServices) then`. The splash registration gracefully degrades -- it just won't show on the splash screen for that session.
**Warning signs:** Using `BorlandIDEServices as IOTASplashScreenServices` (crashes if not available).

### Pitfall 4: Unit Name Conflicts
**What goes wrong:** Package fails to load or conflicts with another package.
**Why it happens:** Two loaded packages contain units with the same name.
**How to avoid:** Prefix all unit names with `DX.Blame.` -- this is already the project convention.
**Warning signs:** Generic unit names like `Registration.pas` or `Utils.pas`.

### Pitfall 5: Menu Items Not Found After IDE Restart
**What goes wrong:** Menu appears during session but disappears after IDE restart.
**Why it happens:** Menu registration happens in the wrong place or the package isn't set to auto-load.
**How to avoid:** Menu creation in `Register` procedure (or called from it). Ensure the BPL is in the IDE's known packages registry (automatic when installed via Component > Install Packages).
**Warning signs:** Menu registration code only in a wizard's `Execute` method.

### Pitfall 6: DesignIDE Version Mismatch
**What goes wrong:** BPL compiled against one Delphi version won't load in another.
**Why it happens:** `designide.dcp` is version-specific. A BPL compiled with Delphi 12's designide won't load in Delphi 13.
**How to avoid:** Build separately for each Delphi version using DelphiBuildDPROJ.ps1. Ship version-specific BPLs. The DPROJ handles this through $(ProductVersion) paths.
**Warning signs:** Trying to build one BPL for all Delphi versions.

## Code Examples

### Complete DPK File
```pascal
// Source: Established Delphi package pattern
package DX.Blame;

{$R *.res}
{$IFDEF IMPLICITBUILDING This SHOULD NOT be
  defined}
{$ALIGN 8}
{$ASSERTIONS ON}
{$BOOLEVAL OFF}
{$DEBUGINFO OFF}
{$EXTENDEDSYNTAX ON}
{$IMPORTEDDATA ON}
{$IOCHECKS ON}
{$LOCALSYMBOLS ON}
{$LONGSTRINGS ON}
{$OPENSTRINGS ON}
{$OPTIMIZATION OFF}
{$OVERFLOWCHECKS ON}
{$RANGECHECKS ON}
{$REFERENCEINFO ON}
{$SAFEDIVIDE OFF}
{$STACKFRAMES ON}
{$TYPEDADDRESS OFF}
{$VARSTRINGCHECKS ON}
{$WRITEABLECONST OFF}
{$MINENUMSIZE 1}
{$IMAGEBASE $400000}
{$DEFINE DEBUG}
{$ENDIF IMPLICITBUILDING}
{$DESCRIPTION 'DX.Blame - Git Blame for Delphi'}
{$DESIGNONLY}
{$IMPLICITBUILD ON}

requires
  rtl,
  vcl,
  designide;

contains
  DX.Blame.Registration in 'DX.Blame.Registration.pas',
  DX.Blame.Version in 'DX.Blame.Version.pas';

end.
```

### Resource Script (res/DX.Blame.res.rc)
```
// 24x24 bitmap for splash screen and about dialog
DXBLAMESPLASH BITMAP "DX.Blame.SplashIcon.bmp"
```

### Minimal Wizard Class
```pascal
// Source: Embarcadero OTAPI-Docs, standard OTA pattern
type
  TDXBlameWizard = class(TNotifierObject, IOTAWizard)
  public
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

function TDXBlameWizard.GetIDString: string;
begin
  Result := 'DX.Blame';
end;

function TDXBlameWizard.GetName: string;
begin
  Result := 'DX.Blame';
end;

function TDXBlameWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDXBlameWizard.Execute;
begin
  // No-op for Phase 1 -- wizard exists for IDE registration only
end;
```

### Version Constants Unit
```pascal
// Source: Standard Delphi versioning pattern
unit DX.Blame.Version;

interface

const
  cDXBlameMajorVersion = 1;
  cDXBlameMinorVersion = 0;
  cDXBlameRelease = 0;
  cDXBlameBuild = 0;
  cDXBlameVersion = '1.0.0.0';
  cDXBlameName = 'DX.Blame';
  cDXBlameDescription = 'Git Blame for Delphi';
  cDXBlameCopyright = 'Copyright (c) 2026 Olaf Monien';

implementation

end.
```

## Conditional Compilation Reference

### CompilerVersion Values
| Delphi Version | CompilerVersion | RTLVersion | Define |
|----------------|----------------|------------|--------|
| Delphi 11.3+ Alexandria | 35.0 | 35.0 | VER350 |
| Delphi 12 Athens | 36.0 | 36.0 | VER360 |
| Delphi 13 Florence | 37.0 | 37.0 | VER370 |

### Conditional Compilation Pattern
```pascal
{$IF CompilerVersion >= 35.0}  // Delphi 11+
  // Common code for all supported versions
{$IFEND}

{$IF CompilerVersion >= 37.0}  // Delphi 13 Florence
  // Florence-specific code (e.g., new OTA interfaces)
{$IFEND}
```

**Note:** For Phase 1, no conditional compilation is expected to be needed. The core OTA interfaces (IOTAWizard, IOTAWizardServices, IOTAAboutBoxServices, IOTASplashScreenServices, INTAServices) have been stable since Delphi 2005+. The conditional compilation infrastructure should be established now for use in later phases.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| DLL Experts (InitWizard/FinalizeWizard) | Design-time packages with Register procedure | Delphi 6+ | Packages can be loaded/unloaded dynamically; DLLs load once |
| SplashScreenServices.AddProductBitmap | SplashScreenServices.AddPluginBitmap | BDS 2006 (QC 42320) | AddProductBitmap broken with single personality |
| Manual IOTANotifier stubs | TNotifierObject base class | Delphi 6+ | Eliminates boilerplate for notifier interfaces |
| Delphi 13 OTA additions | New Welcome Page and mouse event interception APIs | RAD Studio 13.0 | Not relevant for Phase 1, but may matter for Phase 3/4 editor integration |

**Deprecated/outdated:**
- `InitWizard0`/`InitWizard` exported functions: DLL expert pattern, not used for packages
- `AddProductBitmap`: Known broken, use `AddPluginBitmap` instead

## Open Questions

1. **Delphi 13 Florence OTA surface changes**
   - What we know: Florence added Welcome Page UI update and mouse event interception APIs
   - What's unclear: Whether any changes affect basic wizard/splash/about registration
   - Recommendation: Unlikely to affect Phase 1 -- these are additive APIs. Verify during implementation by compiling against Delphi 13.

2. **DUnitX test scope for OTA plugin**
   - What we know: OTA code requires the IDE to run (BorlandIDEServices is IDE-provided). Unit tests can only test non-OTA logic.
   - What's unclear: How much testable logic exists in Phase 1 (mostly OTA registration code)
   - Recommendation: Test what's testable: version constants, string formatting. For OTA integration, manual verification (install/uninstall in IDE) is the practical approach. Consider a smoke test checklist rather than automated tests for OTA lifecycle.

3. **Splash icon bitmap format requirements**
   - What we know: 24x24 pixels, 16 or 256 colors traditional. Modern IDEs may accept 32-bit bitmaps.
   - What's unclear: Whether Delphi 13 supports PNG or higher color depth splash icons
   - Recommendation: Start with a 24x24, 24-bit BMP. Create a placeholder bitmap for Phase 1. User provides final artwork later.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | DUnitX (latest, git submodule) |
| Config file | None -- Wave 0 gap |
| Quick run command | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj` |
| Full suite command | `powershell -File build/DelphiBuildDPROJ.ps1 tests/DX.Blame.Tests.dproj && build\Win64\Debug\DX.Blame.Tests.exe` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UX-04 (install) | BPL installs via Component > Install Packages | manual-only | N/A -- requires IDE interaction | N/A |
| UX-04 (splash) | Plugin appears in IDE splash screen | manual-only | N/A -- visual verification | N/A |
| UX-04 (about) | Plugin appears in Help > About | manual-only | N/A -- visual verification | N/A |
| UX-04 (unload) | BPL uninstalls without crashes | manual-only | N/A -- requires IDE interaction | N/A |
| UX-04 (compile) | BPL compiles for Delphi 11.3+, 12, 13 | build | `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` | Wave 0 |
| N/A | Version constants are correct | unit | `DX.Blame.Tests.exe` | Wave 0 |

### Sampling Rate
- **Per task commit:** `powershell -File build/DelphiBuildDPROJ.ps1 src/DX.Blame.dproj` (compilation check)
- **Per wave merge:** Full compilation + DUnitX test run
- **Phase gate:** Successful compilation on Delphi 13 + manual install/uninstall/splash/about verification

### Wave 0 Gaps
- [ ] `tests/DX.Blame.Tests.dproj` -- DUnitX test project
- [ ] `tests/DX.Blame.Tests.Version.pas` -- version constant tests
- [ ] `libs/DUnitX/` -- git submodule
- [ ] `build/DelphiBuildDPROJ.ps1` -- build script from omonien/DelphiStandards
- [ ] `res/DX.Blame.SplashIcon.bmp` -- placeholder 24x24 bitmap
- [ ] `.gitignore` and `.gitattributes` -- from omonien/DelphiStandards

## Sources

### Primary (HIGH confidence)
- [Embarcadero OTAPI-Docs](https://github.com/Embarcadero/OTAPI-Docs/blob/main/The%20Delphi%20IDE%20Open%20Tools%20API%20-%20Version%201.2.md) - wizard registration, splash screen, about box interfaces
- [Embarcadero RAD Studio Docs - Adding Menu Items](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Adding_an_Item_to_the_Main_Menu_of_the_IDE) - INTAServices.AddActionMenu usage
- [Embarcadero RAD Studio Docs - Design-time Packages](https://docwiki.embarcadero.com/RADStudio/Athens/en/Design-time_Packages) - package structure, designide requirement
- [omonien/Delphi-Version-Information](https://github.com/omonien/Delphi-Version-Information/blob/master/README.md) - CompilerVersion values for Delphi 11/12/13
- [Embarcadero RAD Studio Docs - Florence What's New](https://docwiki.embarcadero.com/RADStudio/Florence/en/New_features_and_customer_reported_issues_fixed_in_RAD_Studio_13.0) - Delphi 13 OTA changes

### Secondary (MEDIUM confidence)
- [GExperts OTA FAQ](https://www.gexperts.org/open-tools-api-faq/) - splash screen bug (QC 42320), notifier cleanup, unit naming
- [DWScriptExpert source](https://github.com/CWBudde/DWScriptExpert/blob/master/Source/DWScriptExpertWizard.pas) - complete wizard lifecycle pattern
- [blog.dummzeuch.de - About dialog entry](https://blog.dummzeuch.de/2015/11/22/adding-an-entry-to-the-delphi-ides-about-dialog/) - AddPluginInfo parameter ordering
- [blog.dummzeuch.de - Finalization AV](https://blog.dummzeuch.de/2018/11/24/found-the-cause-of-the-av-on-exiting-the-delphi-ide/) - finalization order pitfall

### Tertiary (LOW confidence)
- Delphi 13 Florence OTA specifics -- limited public documentation available; core OTA interfaces assumed stable based on historical pattern

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - ToolsAPI and designide are well-documented, stable since Delphi 6
- Architecture: HIGH - DWScriptExpert, GExperts, and many open-source plugins use identical patterns
- Pitfalls: HIGH - GExperts FAQ and community blogs document real-world crash scenarios extensively
- Conditional compilation: HIGH - CompilerVersion values confirmed from omonien/Delphi-Version-Information
- Delphi 13 specifics: MEDIUM - limited OTA change documentation, but core interfaces are stable

**Research date:** 2026-03-19
**Valid until:** 2026-04-19 (stable domain, OTA interfaces change rarely)
