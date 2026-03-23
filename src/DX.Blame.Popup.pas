/// <summary>
/// DX.Blame.Popup
/// Borderless popup panel for displaying commit information on annotation click.
/// </summary>
///
/// <remarks>
/// TDXBlamePopup is a borderless TCustomForm descendant that shows commit hash,
/// author, email, date, and full commit message when the user clicks a blame
/// annotation. The popup dismisses on click-outside (CM_DEACTIVATE) or Escape
/// key. Clicking a different annotation updates the content in-place without
/// flicker. The short commit hash is clickable to copy the full SHA to clipboard
/// with visual feedback. Theme colors adapt to the IDE dark/light setting.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Popup;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  Winapi.Windows,
  Winapi.Messages,
  DX.Blame.Git.Types,
  DX.Blame.CommitDetail;

type
  /// <summary>
  /// Borderless popup form displaying commit information for a blame annotation.
  /// </summary>
  TDXBlamePopup = class(TCustomForm)
  private
    FHashLabel: TLabel;
    FAuthorLabel: TLabel;
    FDateLabel: TLabel;
    FMessageMemo: TMemo;
    FShowDiffButton: TButton;
    FLoadingLabel: TLabel;
    FCopiedTimer: TTimer;
    FFullHash: string;
    FOriginalHashText: string;
    FOnShowDiffClick: TNotifyEvent;
    FRepoRoot: string;
    FRelativeFilePath: string;
    FLineInfo: TBlameLineInfo;

    procedure DoHashClick(ASender: TObject);
    procedure DoCopiedTimerTick(ASender: TObject);
    procedure DoShowDiffClick(ASender: TObject);
    procedure HandleCommitDetailComplete(const ADetail: TCommitDetail);
    procedure ApplyThemeColors;
    function IsDarkTheme: Boolean;
    procedure CMDeactivate(var AMessage: TMessage); message CM_DEACTIVATE;
    procedure CMDialogKey(var AMessage: TCMDialogKey); message CM_DIALOGKEY;
  protected
    procedure CreateParams(var AParams: TCreateParams); override;
  public
    constructor CreateNew(AOwner: TComponent; ADummy: Integer = 0); override;

    /// <summary>
    /// Shows the popup for a commit, populating immediate fields and
    /// launching async fetch for full message.
    /// </summary>
    procedure ShowForCommit(const ALineInfo: TBlameLineInfo;
      const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);

    /// <summary>
    /// Updates popup content in-place when clicking a different annotation
    /// while popup is already visible.
    /// </summary>
    procedure UpdateContent(const ALineInfo: TBlameLineInfo;
      const ARepoRoot, ARelativeFilePath: string);

    /// <summary>External handler for the Show Diff button.</summary>
    property OnShowDiffClick: TNotifyEvent read FOnShowDiffClick write FOnShowDiffClick;
  end;

implementation

uses
  Vcl.Clipbrd,
  System.Math,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.Diff.Form;

const
  cPopupWidth = 400;
  cPopupMinHeight = 200;
  cPopupMaxHeight = 400;
  cPadding = 10;
  cMemoMinLines = 4;
  cCopiedFeedbackMs = 1500;

  // Dark theme colors
  cDarkBackground = $002D2D2D;
  cDarkForeground = $00D4D4D4;
  cDarkMemoBackground = $00252525;

  // Light theme colors
  cLightBackground = clWindow;
  cLightForeground = clWindowText;
  cLightMemoBackground = clWindow;

{ TDXBlamePopup }

constructor TDXBlamePopup.CreateNew(AOwner: TComponent; ADummy: Integer);
begin
  inherited CreateNew(AOwner, ADummy);

  BorderStyle := bsNone;
  Width := cPopupWidth;
  Height := cPopupMinHeight;
  KeyPreview := True;
  Position := poDesigned;

  // Hash label -- clickable, styled as link
  FHashLabel := TLabel.Create(Self);
  FHashLabel.Parent := Self;
  FHashLabel.Left := cPadding;
  FHashLabel.Top := cPadding;
  FHashLabel.Font.Style := [fsUnderline, fsBold];
  FHashLabel.Cursor := crHandPoint;
  FHashLabel.OnClick := DoHashClick;

  // Author label
  FAuthorLabel := TLabel.Create(Self);
  FAuthorLabel.Parent := Self;
  FAuthorLabel.Left := cPadding;
  FAuthorLabel.Top := FHashLabel.Top + FHashLabel.Height + 6;
  FAuthorLabel.Width := cPopupWidth - (cPadding * 2);
  FAuthorLabel.AutoSize := True;

  // Date label
  FDateLabel := TLabel.Create(Self);
  FDateLabel.Parent := Self;
  FDateLabel.Left := cPadding;
  FDateLabel.Top := FAuthorLabel.Top + FAuthorLabel.Height + 4;
  FDateLabel.Width := cPopupWidth - (cPadding * 2);
  FDateLabel.AutoSize := True;

  // Loading label
  FLoadingLabel := TLabel.Create(Self);
  FLoadingLabel.Parent := Self;
  FLoadingLabel.Left := cPadding;
  FLoadingLabel.Top := FDateLabel.Top + FDateLabel.Height + 8;
  FLoadingLabel.Caption := 'Loading...';
  FLoadingLabel.Font.Style := [fsItalic];
  FLoadingLabel.Visible := False;

  // Message memo -- read-only, multi-line
  FMessageMemo := TMemo.Create(Self);
  FMessageMemo.Parent := Self;
  FMessageMemo.Left := cPadding;
  FMessageMemo.Top := FDateLabel.Top + FDateLabel.Height + 8;
  FMessageMemo.Width := cPopupWidth - (cPadding * 2);
  FMessageMemo.Height := cMemoMinLines * 16;
  FMessageMemo.ReadOnly := True;
  FMessageMemo.BorderStyle := bsNone;
  FMessageMemo.ScrollBars := ssVertical;
  FMessageMemo.WordWrap := True;
  FMessageMemo.TabStop := False;

  // Show Diff button
  FShowDiffButton := TButton.Create(Self);
  FShowDiffButton.Parent := Self;
  FShowDiffButton.Caption := 'Show Diff';
  FShowDiffButton.Width := 90;
  FShowDiffButton.Left := cPopupWidth - FShowDiffButton.Width - cPadding;
  FShowDiffButton.Top := FMessageMemo.Top + FMessageMemo.Height + 8;
  FShowDiffButton.OnClick := DoShowDiffClick;

  // Copied feedback timer
  FCopiedTimer := TTimer.Create(Self);
  FCopiedTimer.Enabled := False;
  FCopiedTimer.Interval := cCopiedFeedbackMs;
  FCopiedTimer.OnTimer := DoCopiedTimerTick;
end;

procedure TDXBlamePopup.CreateParams(var AParams: TCreateParams);
begin
  inherited CreateParams(AParams);
  AParams.Style := WS_POPUP or WS_BORDER;
  AParams.ExStyle := AParams.ExStyle or WS_EX_TOOLWINDOW;
end;

procedure TDXBlamePopup.CMDeactivate(var AMessage: TMessage);
begin
  inherited;
  Hide;
end;

procedure TDXBlamePopup.CMDialogKey(var AMessage: TCMDialogKey);
begin
  if AMessage.CharCode = VK_ESCAPE then
  begin
    Hide;
    AMessage.Result := 1;
  end
  else
    inherited;
end;

procedure TDXBlamePopup.DoHashClick(ASender: TObject);
begin
  if FFullHash = '' then
    Exit;

  Clipboard.AsText := FFullHash;

  // Visual feedback: show "Copied!" temporarily
  FOriginalHashText := FHashLabel.Caption;
  FHashLabel.Caption := 'Copied!';
  FCopiedTimer.Enabled := False;
  FCopiedTimer.Enabled := True;
end;

procedure TDXBlamePopup.DoCopiedTimerTick(ASender: TObject);
begin
  FCopiedTimer.Enabled := False;
  FHashLabel.Caption := FOriginalHashText;
end;

procedure TDXBlamePopup.DoShowDiffClick(ASender: TObject);
begin
  if FFullHash = '' then
    Exit;

  Hide;
  TFormDXBlameDiff.ShowDiff(FFullHash, FRepoRoot, FRelativeFilePath, FLineInfo);

  if Assigned(FOnShowDiffClick) then
    FOnShowDiffClick(ASender);
end;

procedure TDXBlamePopup.HandleCommitDetailComplete(const ADetail: TCommitDetail);
begin
  FLoadingLabel.Visible := False;
  FMessageMemo.Visible := True;

  if ADetail.Fetched then
  begin
    FMessageMemo.Text := ADetail.FullMessage;
    // Cache the detail
    CommitDetailCache.Store(FFullHash, ADetail);
  end
  else
    FMessageMemo.Text := '(Failed to fetch commit details)';
end;

procedure TDXBlamePopup.ShowForCommit(const ALineInfo: TBlameLineInfo;
  const AScreenPos: TPoint; const ARepoRoot, ARelativeFilePath: string);
var
  LDetail: TCommitDetail;
  LScreenRect: TRect;
  LLeft, LTop: Integer;
begin
  ApplyThemeColors;

  // Store context for Show Diff button
  FRepoRoot := ARepoRoot;
  FRelativeFilePath := ARelativeFilePath;
  FLineInfo := ALineInfo;

  if ALineInfo.IsUncommitted then
  begin
    // Simplified display for uncommitted lines
    FFullHash := '';
    FHashLabel.Caption := '';
    FHashLabel.Visible := False;
    FAuthorLabel.Caption := cNotCommittedAuthor;
    FDateLabel.Caption := '';
    FDateLabel.Visible := False;
    FMessageMemo.Text := 'This line has not been committed yet.';
    FMessageMemo.Visible := True;
    FLoadingLabel.Visible := False;
    FShowDiffButton.Visible := False;

    // Layout for uncommitted
    FAuthorLabel.Top := cPadding;
    FMessageMemo.Top := FAuthorLabel.Top + FAuthorLabel.Height + 8;
    FMessageMemo.Height := 2 * 16;
    Height := FMessageMemo.Top + FMessageMemo.Height + cPadding;
  end
  else
  begin
    // Full commit display
    FFullHash := ALineInfo.CommitHash;
    FHashLabel.Caption := Copy(ALineInfo.CommitHash, 1, 7);
    FHashLabel.Visible := True;
    FAuthorLabel.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';
    FDateLabel.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);
    FDateLabel.Visible := True;
    FShowDiffButton.Visible := True;

    // Recalculate layout
    FAuthorLabel.Top := FHashLabel.Top + FHashLabel.Height + 6;
    FDateLabel.Top := FAuthorLabel.Top + FAuthorLabel.Height + 4;
    FLoadingLabel.Top := FDateLabel.Top + FDateLabel.Height + 8;
    FMessageMemo.Top := FDateLabel.Top + FDateLabel.Height + 8;
    FMessageMemo.Height := cMemoMinLines * 16;

    // Check cache first
    if CommitDetailCache.TryGet(ALineInfo.CommitHash, LDetail) and LDetail.Fetched then
    begin
      FLoadingLabel.Visible := False;
      FMessageMemo.Visible := True;
      FMessageMemo.Text := LDetail.FullMessage;
    end
    else
    begin
      // Show loading, fetch async
      FLoadingLabel.Visible := True;
      FMessageMemo.Visible := False;
      FMessageMemo.Text := '';
      FetchCommitDetailAsync(ALineInfo.CommitHash, ARepoRoot,
        ARelativeFilePath, HandleCommitDetailComplete);
    end;

    FShowDiffButton.Top := FMessageMemo.Top + FMessageMemo.Height + 8;
    Height := Min(cPopupMaxHeight,
      Max(cPopupMinHeight, FShowDiffButton.Top + FShowDiffButton.Height + cPadding));
  end;

  // Position popup near click, keeping within screen bounds
  LScreenRect := Screen.MonitorFromPoint(AScreenPos).WorkareaRect;
  LLeft := AScreenPos.X;
  LTop := AScreenPos.Y + 20; // offset below cursor

  if LLeft + Width > LScreenRect.Right then
    LLeft := LScreenRect.Right - Width;
  if LTop + Height > LScreenRect.Bottom then
    LTop := AScreenPos.Y - Height - 4; // show above if not enough room below
  if LLeft < LScreenRect.Left then
    LLeft := LScreenRect.Left;
  if LTop < LScreenRect.Top then
    LTop := LScreenRect.Top;

  Left := LLeft;
  Top := LTop;

  Show;
end;

procedure TDXBlamePopup.UpdateContent(const ALineInfo: TBlameLineInfo;
  const ARepoRoot, ARelativeFilePath: string);
var
  LDetail: TCommitDetail;
begin
  ApplyThemeColors;

  // Store context for Show Diff button
  FRepoRoot := ARepoRoot;
  FRelativeFilePath := ARelativeFilePath;
  FLineInfo := ALineInfo;

  if ALineInfo.IsUncommitted then
  begin
    FFullHash := '';
    FHashLabel.Caption := '';
    FHashLabel.Visible := False;
    FAuthorLabel.Caption := cNotCommittedAuthor;
    FDateLabel.Caption := '';
    FDateLabel.Visible := False;
    FMessageMemo.Text := 'This line has not been committed yet.';
    FMessageMemo.Visible := True;
    FLoadingLabel.Visible := False;
    FShowDiffButton.Visible := False;
  end
  else
  begin
    FFullHash := ALineInfo.CommitHash;
    FHashLabel.Caption := Copy(ALineInfo.CommitHash, 1, 7);
    FHashLabel.Visible := True;
    FAuthorLabel.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';
    FDateLabel.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);
    FDateLabel.Visible := True;
    FShowDiffButton.Visible := True;

    // Check cache first
    if CommitDetailCache.TryGet(ALineInfo.CommitHash, LDetail) and LDetail.Fetched then
    begin
      FLoadingLabel.Visible := False;
      FMessageMemo.Visible := True;
      FMessageMemo.Text := LDetail.FullMessage;
    end
    else
    begin
      FLoadingLabel.Visible := True;
      FMessageMemo.Visible := False;
      FMessageMemo.Text := '';
      FetchCommitDetailAsync(ALineInfo.CommitHash, ARepoRoot,
        ARelativeFilePath, HandleCommitDetailComplete);
    end;
  end;
end;

procedure TDXBlamePopup.ApplyThemeColors;
begin
  if IsDarkTheme then
  begin
    Color := cDarkBackground;
    Font.Color := cDarkForeground;
    FHashLabel.Font.Color := $00569CD6; // blue-ish link color for dark theme
    FAuthorLabel.Font.Color := cDarkForeground;
    FDateLabel.Font.Color := $00808080; // muted gray
    FMessageMemo.Color := cDarkMemoBackground;
    FMessageMemo.Font.Color := cDarkForeground;
    FLoadingLabel.Font.Color := $00808080;
  end
  else
  begin
    Color := cLightBackground;
    Font.Color := cLightForeground;
    FHashLabel.Font.Color := clBlue;
    FAuthorLabel.Font.Color := cLightForeground;
    FDateLabel.Font.Color := clGray;
    FMessageMemo.Color := cLightMemoBackground;
    FMessageMemo.Font.Color := cLightForeground;
    FLoadingLabel.Font.Color := clGray;
  end;
end;

function TDXBlamePopup.IsDarkTheme: Boolean;
var
  LServices: INTACodeEditorServices;
  LBgColor: TColor;
  LR, LG, LB: Byte;
begin
  Result := False;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LServices) then
  begin
    LBgColor := ColorToRGB(LServices.Options.BackgroundColor[atWhiteSpace]);
    LR := GetRValue(LBgColor);
    LG := GetGValue(LBgColor);
    LB := GetBValue(LBgColor);
    Result := ((Integer(LR) + Integer(LG) + Integer(LB)) div 3) < 128;
  end;
end;

end.
