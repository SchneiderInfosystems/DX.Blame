/// <summary>
/// DX.Blame.Registration
/// Central OTA lifecycle unit for the DX.Blame design-time plugin.
/// </summary>
///
/// <remarks>
/// Handles all IDE integration: wizard registration, splash screen bitmap,
/// Help > About entry, and Tools menu placeholder. All OTA registrations
/// are cleaned up in reverse order during finalization to prevent access
/// violations on BPL unload.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Registration;

interface

procedure Register;

implementation

uses
  ToolsAPI,
  System.SysUtils,
  System.Classes,
  Vcl.Menus,
  Winapi.Windows,
  DX.Blame.Version,
  DX.Blame.IDE.Notifier,
  DX.Blame.Engine,
  DX.Blame.Renderer,
  DX.Blame.KeyBinding,
  DX.Blame.Settings,
  DX.Blame.Settings.Form,
  DX.Blame.Navigation;

var
  GWizardIndex: Integer = -1;
  GAboutPluginIndex: Integer = -1;
  GMenuParentItem: TMenuItem = nil;
  GMenuHandler: TObject = nil;

type
  /// <summary>
  /// Simple handler object for the Enable Blame menu item OnClick event.
  /// </summary>
  TDXBlameMenuHandler = class
  public
    procedure ToggleBlame(Sender: TObject);
    procedure ShowSettings(Sender: TObject);
  end;

type
  /// <summary>
  /// Minimal IOTAWizard implementation for IDE registration.
  /// Phase 1 placeholder -- Execute is a no-op.
  /// </summary>
  TDXBlameWizard = class(TNotifierObject, IOTAWizard)
  public
    { IOTAWizard }
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

{ TDXBlameWizard }

function TDXBlameWizard.GetIDString: string;
begin
  Result := 'DX.Blame';
end;

function TDXBlameWizard.GetName: string;
begin
  Result := cDXBlameName;
end;

function TDXBlameWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDXBlameWizard.Execute;
begin
  // No-op for Phase 1 -- wizard exists for IDE registration only
end;

{ TDXBlameMenuHandler }

procedure TDXBlameMenuHandler.ToggleBlame(Sender: TObject);
var
  LMenuItem: TMenuItem;
begin
  BlameSettings.Enabled := not BlameSettings.Enabled;
  BlameSettings.Save;

  if Sender is TMenuItem then
  begin
    LMenuItem := TMenuItem(Sender);
    LMenuItem.Checked := BlameSettings.Enabled;
  end;

  InvalidateAllEditors;
end;

procedure TDXBlameMenuHandler.ShowSettings(Sender: TObject);
begin
  TFormDXBlameSettings.ShowSettings;
end;

/// <summary>
/// Creates the "DX Blame" submenu under the IDE Tools menu with
/// "Enable Blame" (toggle) and "Settings..." (disabled placeholder).
/// </summary>
procedure CreateToolsMenu;
var
  LNTAServices: INTAServices;
  LToolsMenu: TMenuItem;
  LSubItem: TMenuItem;
  LCaption: string;
  i: Integer;
begin
  if not Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    Exit;

  // Find the IDE Tools menu by caption (Name varies across Delphi versions)
  LToolsMenu := nil;
  for i := 0 to LNTAServices.MainMenu.Items.Count - 1 do
  begin
    LCaption := StringReplace(LNTAServices.MainMenu.Items[i].Caption, '&', '', [rfReplaceAll]);
    if SameText(LCaption, 'Tools') then
    begin
      LToolsMenu := LNTAServices.MainMenu.Items[i];
      Break;
    end;
  end;

  if LToolsMenu = nil then
    Exit;

  // Create the menu handler for event callbacks
  GMenuHandler := TDXBlameMenuHandler.Create;

  GMenuParentItem := TMenuItem.Create(nil);
  GMenuParentItem.Caption := 'DX Blame';
  GMenuParentItem.Name := 'DXBlameMenu';

  // Enable Blame -- checkbox-style toggle
  LSubItem := TMenuItem.Create(GMenuParentItem);
  LSubItem.Caption := 'Enable Blame';
  LSubItem.Name := 'DXBlameEnableItem';
  LSubItem.Checked := BlameSettings.Enabled;
  LSubItem.OnClick := TDXBlameMenuHandler(GMenuHandler).ToggleBlame;
  GMenuParentItem.Add(LSubItem);

  // Settings... -- opens configuration dialog
  LSubItem := TMenuItem.Create(GMenuParentItem);
  LSubItem.Caption := 'Settings...';
  LSubItem.Name := 'DXBlameSettingsItem';
  LSubItem.OnClick := TDXBlameMenuHandler(GMenuHandler).ShowSettings;
  GMenuParentItem.Add(LSubItem);

  // Add as child of the Tools menu, not next to it
  LToolsMenu.Add(GMenuParentItem);
end;

/// <summary>
/// Removes the "DX Blame" menu and all children from the IDE.
/// Children are freed automatically by the parent TMenuItem owner.
/// </summary>
procedure RemoveToolsMenu;
begin
  FreeAndNil(GMenuParentItem);
  FreeAndNil(GMenuHandler);
end;

/// <summary>
/// Called by the IDE when the design-time package is loaded.
/// Registers the wizard, about box entry, and Tools menu items.
/// </summary>
procedure Register;
var
  LWizardServices: IOTAWizardServices;
  LAboutBoxServices: IOTAAboutBoxServices;
  LAboutBmp: HBITMAP;
  LModuleServices: IOTAModuleServices;
  LProject: IOTAProject;
begin
  // Register wizard
  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
    GWizardIndex := LWizardServices.AddWizard(TDXBlameWizard.Create);

  // Register about box entry (bitmap ownership transfers to IDE -- do NOT free)
  if Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutBoxServices) then
  begin
    LAboutBmp := LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH');
    GAboutPluginIndex := LAboutBoxServices.AddPluginInfo(
      cDXBlameName,
      cDXBlameDescription + sLineBreak + cDXBlameCopyright,
      LAboutBmp,
      False,
      '',
      cDXBlameVersion
    );
  end;

  // Create Tools menu placeholder
  CreateToolsMenu;

  // Register IDE notifiers for file open/close/save events
  RegisterIDENotifiers;

  // Initialize blame engine with current project path
  if Supports(BorlandIDEServices, IOTAModuleServices, LModuleServices) then
  begin
    LProject := LModuleServices.GetActiveProject;
    if LProject <> nil then
      BlameEngine.Initialize(ExtractFileDir(LProject.FileName));
  end;

  // Register renderer and keyboard binding for inline blame display
  RegisterRenderer;
  RegisterKeyBinding;

  // Attach "Previous Revision" item to the editor context menu
  AttachContextMenu;
end;

initialization
  // Splash screen registration -- must happen during initialization,
  // before Register is called, while IDE splash screen is still visible.
  // Use AddPluginBitmap, NOT AddProductBitmap (broken per QC 42320).
  if Assigned(SplashScreenServices) then
  begin
    SplashScreenServices.AddPluginBitmap(
      cDXBlameName,
      LoadBitmap(FindResourceHInstance(HInstance), 'DXBLAMESPLASH'),
      False,
      cDXBlameDescription
    );
  end;

finalization
  // Reverse-order cleanup to prevent access violations on BPL unload:
  // 1. Detach context menu (must happen before any other cleanup)
  DetachContextMenu;

  // 2. Stop keyboard binding (must stop before renderer to avoid toggle during unload)
  UnregisterKeyBinding;

  // 3. Stop renderer (must stop painting before notifiers are removed)
  UnregisterRenderer;

  // 4. Remove IDE notifiers (notifiers must stop before UI cleanup)
  UnregisterIDENotifiers;

  // 5. Remove UI elements (menu items and handler)
  RemoveToolsMenu;

  // 6. Remove wizard registration
  if GWizardIndex >= 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAWizardServices).RemoveWizard(GWizardIndex);

  // 7. Remove about box entry last
  if GAboutPluginIndex >= 0 then
    if Assigned(BorlandIDEServices) then
      (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(GAboutPluginIndex);

  // BlameEngine singleton is freed in DX.Blame.Engine finalization

end.
