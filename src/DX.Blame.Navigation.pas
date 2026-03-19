/// <summary>
/// DX.Blame.Navigation
/// Parent commit navigation for blame archaeology.
/// </summary>
///
/// <remarks>
/// Enables users to trace a line's history through successive commits by
/// navigating to the parent revision. The file content at the parent commit
/// is retrieved via git show, written to a temp file, and opened in a new
/// IDE editor tab. Context menu integration attaches a "Previous Revision"
/// item to the editor popup menu.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Navigation;

interface

/// <summary>
/// Opens the file at the parent commit of ACommitHash in a new editor tab.
/// Shows an IDE message if the commit has no parent (root commit).
/// </summary>
procedure NavigateToParentRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string);

/// <summary>
/// Returns True if the commit hash is valid for parent navigation.
/// Returns False for empty hashes or uncommitted lines.
/// </summary>
function IsParentRevisionAvailable(const ACommitHash: string): Boolean;

/// <summary>
/// Attaches "Previous Revision" menu item to the editor context menu.
/// </summary>
procedure AttachContextMenu;

/// <summary>
/// Removes "Previous Revision" menu item from the editor context menu.
/// </summary>
procedure DetachContextMenu;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Vcl.Menus,
  Vcl.Dialogs,
  Vcl.Forms,
  ToolsAPI,
  DX.Blame.Git.Types,
  DX.Blame.Git.Discovery,
  DX.Blame.Git.Process,
  DX.Blame.Engine;

const
  cMenuItemName = 'DXBlamePreviousRevision';
  cMenuItemCaption = 'Previous Revision';

type
  /// <summary>
  /// Helper object to provide a method-based event handler for the context menu.
  /// Standalone procedures cannot be assigned to TNotifyEvent (method pointer).
  /// </summary>
  TNavigationMenuHandler = class
  public
    procedure OnPreviousRevisionClick(Sender: TObject);
  end;

var
  GContextMenuItem: TMenuItem;
  GMenuHandler: TNavigationMenuHandler;

/// <summary>
/// Resolves the parent commit hash using git rev-parse.
/// Returns empty string if no parent exists (root commit).
/// </summary>
function ResolveParentHash(const ACommitHash, ARepoRoot: string): string;
var
  LGitPath: string;
  LProcess: TGitProcess;
  LOutput: string;
  LExitCode: Integer;
begin
  Result := '';

  LGitPath := FindGitExecutable;
  if LGitPath = '' then
    Exit;

  LProcess := TGitProcess.Create(LGitPath, ARepoRoot);
  try
    LExitCode := LProcess.Execute('rev-parse ' + ACommitHash + '^', LOutput);
    if LExitCode = 0 then
      Result := Trim(LOutput);
  finally
    LProcess.Free;
  end;
end;

/// <summary>
/// Retrieves file content at a specific commit via git show.
/// </summary>
function GetFileAtCommit(const ACommitHash, ARelativePath, ARepoRoot: string): string;
var
  LGitPath: string;
  LProcess: TGitProcess;
  LOutput: string;
  LExitCode: Integer;
begin
  Result := '';

  LGitPath := FindGitExecutable;
  if LGitPath = '' then
    Exit;

  LProcess := TGitProcess.Create(LGitPath, ARepoRoot);
  try
    LExitCode := LProcess.Execute('show ' + ACommitHash + ':' + ARelativePath, LOutput);
    if LExitCode = 0 then
      Result := LOutput;
  finally
    LProcess.Free;
  end;
end;

function IsParentRevisionAvailable(const ACommitHash: string): Boolean;
begin
  Result := (ACommitHash <> '') and (ACommitHash <> cUncommittedHash);
end;

procedure NavigateToParentRevision(const AFileName: string;
  const ACommitHash: string; const ARepoRoot: string);
var
  LParentHash: string;
  LRelPath: string;
  LContent: string;
  LTempDir: string;
  LTempFile: string;
  LShortHash: string;
  LBaseName: string;
  LExt: string;
  LActionServices: IOTAActionServices;
begin
  if not IsParentRevisionAvailable(ACommitHash) then
    Exit;

  // 1. Resolve parent hash
  LParentHash := ResolveParentHash(ACommitHash, ARepoRoot);
  if LParentHash = '' then
  begin
    if Supports(BorlandIDEServices, IOTAActionServices) then
      MessageDlg('This is the root commit -- no parent revision available.', mtInformation, [mbOK], 0);
    Exit;
  end;

  // 2. Compute relative path (forward slashes for git)
  LRelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ARepoRoot), AFileName);
  LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);

  // 3. Get file content at parent commit
  LContent := GetFileAtCommit(LParentHash, LRelPath, ARepoRoot);
  if LContent = '' then
  begin
    MessageDlg('Could not retrieve file content at parent revision.', mtWarning, [mbOK], 0);
    Exit;
  end;

  // 4. Write to temp file
  LShortHash := Copy(LParentHash, 1, 7);
  LBaseName := ChangeFileExt(ExtractFileName(AFileName), '');
  LExt := ExtractFileExt(AFileName);
  LTempDir := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'DX.Blame';
  ForceDirectories(LTempDir);
  LTempFile := IncludeTrailingPathDelimiter(LTempDir) + LBaseName + '.' + LShortHash + LExt;

  TFile.WriteAllText(LTempFile, LContent, TEncoding.UTF8);

  // 5. Open in IDE
  if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
  begin
    LActionServices.OpenFile(LTempFile);

    // 6. Trigger blame on the temp file so annotations appear
    BlameEngine.RequestBlame(LTempFile);
  end;
end;

{ TNavigationMenuHandler }

procedure TNavigationMenuHandler.OnPreviousRevisionClick(Sender: TObject);
var
  LEditorServices: IOTAEditorServices;
  LTopView: IOTAEditView;
  LFileName: string;
  LLine: Integer;
  LData: TBlameData;
  LLineInfo: TBlameLineInfo;
  LRepoRoot: string;
begin
  if not Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
    Exit;

  LTopView := LEditorServices.TopView;
  if LTopView = nil then
    Exit;

  LFileName := LTopView.Buffer.FileName;
  LLine := LTopView.CursorPos.Line;

  if not BlameEngine.GitAvailable then
    Exit;

  LRepoRoot := BlameEngine.RepoRoot;

  if not BlameEngine.Cache.TryGet(LFileName, LData) then
    Exit;

  if (LLine < 1) or (LLine > Length(LData.Lines)) then
    Exit;

  LLineInfo := LData.Lines[LLine - 1];

  if not IsParentRevisionAvailable(LLineInfo.CommitHash) then
    Exit;

  NavigateToParentRevision(LFileName, LLineInfo.CommitHash, LRepoRoot);
end;

/// <summary>
/// Finds the editor popup menu via the active edit window form.
/// </summary>
function FindEditorPopupMenu: TPopupMenu;
var
  LNTAServices: INTAEditorServices;
  LEditWindow: INTAEditWindow;
  LForm: TCustomForm;
  LComponent: TComponent;
begin
  Result := nil;

  if not Supports(BorlandIDEServices, INTAEditorServices, LNTAServices) then
    Exit;

  LEditWindow := LNTAServices.TopEditWindow;
  if LEditWindow = nil then
    Exit;

  LForm := LEditWindow.Form;
  if LForm = nil then
    Exit;

  LComponent := LForm.FindComponent('EditorLocalMenu');
  if (LComponent <> nil) and (LComponent is TPopupMenu) then
    Result := TPopupMenu(LComponent);
end;

procedure AttachContextMenu;
var
  LPopup: TPopupMenu;
  LSeparator: TMenuItem;
begin
  if GContextMenuItem <> nil then
    Exit;

  LPopup := FindEditorPopupMenu;
  if LPopup = nil then
    Exit;

  // Add separator before our item
  LSeparator := TMenuItem.Create(LPopup);
  LSeparator.Caption := '-';
  LSeparator.Name := 'DXBlameSeparator';
  LPopup.Items.Add(LSeparator);

  GContextMenuItem := TMenuItem.Create(LPopup);
  GContextMenuItem.Caption := cMenuItemCaption;
  GContextMenuItem.Name := cMenuItemName;
  if GMenuHandler = nil then
    GMenuHandler := TNavigationMenuHandler.Create;
  GContextMenuItem.OnClick := GMenuHandler.OnPreviousRevisionClick;
  LPopup.Items.Add(GContextMenuItem);
end;

procedure DetachContextMenu;
var
  LPopup: TPopupMenu;
  LSeparator: TComponent;
begin
  if GContextMenuItem = nil then
    Exit;

  LPopup := FindEditorPopupMenu;
  if LPopup <> nil then
  begin
    LSeparator := LPopup.FindComponent('DXBlameSeparator');
    if LSeparator <> nil then
      LSeparator.Free;
  end;

  FreeAndNil(GContextMenuItem);
  FreeAndNil(GMenuHandler);
end;

end.
