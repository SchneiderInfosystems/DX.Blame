/// <summary>
/// DX.Blame.Diff.Form
/// Modal dialog for displaying color-coded unified diff output for a commit.
/// </summary>
///
/// <remarks>
/// TFormDXBlameDiff shows the full commit header (hash, author, date, message)
/// and a TRichEdit with color-coded diff lines: green for additions, red for
/// deletions, blue for hunk headers. Supports toggling between current-file
/// and full-commit diff scope. Dialog size persists via BlameSettings INI.
/// GetDiffLineColor is exposed as a unit-level pure function for testability.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Diff.Form;

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Winapi.Windows,
  DX.Blame.Git.Types,
  DX.Blame.CommitDetail;

type
  /// <summary>
  /// Modal diff dialog showing commit header and color-coded unified diff.
  /// </summary>
  TFormDXBlameDiff = class(TForm)
  private
    FPanelHeader: TPanel;
    FLabelHash: TLabel;
    FLabelAuthor: TLabel;
    FLabelDate: TLabel;
    FMemoMessage: TMemo;
    FPanelToolbar: TPanel;
    FButtonToggleScope: TButton;
    FLabelLoading: TLabel;
    FRichEditDiff: TRichEdit;

    FCommitHash: string;
    FRepoRoot: string;
    FRelativeFilePath: string;
    FShowingFullDiff: Boolean;
    FFileDiff: string;
    FFullDiff: string;

    procedure DoToggleScopeClick(ASender: TObject);
    procedure HandleCommitDetailComplete(const ADetail: TCommitDetail);
    procedure LoadDiffIntoRichEdit(const ADiff: string);
    procedure ApplyThemeColors;
    function IsDarkTheme: Boolean;
  public
    /// <summary>
    /// Shows the diff dialog modally for the given commit.
    /// Creates the form, populates it, shows modal, saves size, and frees.
    /// </summary>
    class procedure ShowDiff(const ACommitHash, ARepoRoot, ARelativeFilePath: string;
      const ALineInfo: TBlameLineInfo);
  end;

implementation

uses
  System.Math,
  Winapi.Messages,
  ToolsAPI,
  ToolsAPI.Editor,
  DX.Blame.Settings,
  DX.Blame.Formatter;

const
  cMaxDiffLines = 5000;

{ TFormDXBlameDiff }

class procedure TFormDXBlameDiff.ShowDiff(const ACommitHash, ARepoRoot,
  ARelativeFilePath: string; const ALineInfo: TBlameLineInfo);
var
  LForm: TFormDXBlameDiff;
  LDetail: TCommitDetail;
begin
  LForm := TFormDXBlameDiff.CreateNew(nil);
  try
    LForm.Caption := 'Commit Diff';
    LForm.Width := BlameSettings.DiffDialogWidth;
    LForm.Height := BlameSettings.DiffDialogHeight;
    LForm.Position := poScreenCenter;
    LForm.BorderStyle := bsSizeable;
    LForm.KeyPreview := True;

    LForm.FCommitHash := ACommitHash;
    LForm.FRepoRoot := ARepoRoot;
    LForm.FRelativeFilePath := ARelativeFilePath;
    LForm.FShowingFullDiff := False;

    // Header panel
    LForm.FPanelHeader := TPanel.Create(LForm);
    LForm.FPanelHeader.Parent := LForm;
    LForm.FPanelHeader.Align := alTop;
    LForm.FPanelHeader.Height := 120;
    LForm.FPanelHeader.BevelOuter := bvNone;

    LForm.FLabelHash := TLabel.Create(LForm);
    LForm.FLabelHash.Parent := LForm.FPanelHeader;
    LForm.FLabelHash.Left := 10;
    LForm.FLabelHash.Top := 8;
    LForm.FLabelHash.Font.Style := [fsBold];
    LForm.FLabelHash.Caption := Copy(ACommitHash, 1, 7);

    LForm.FLabelAuthor := TLabel.Create(LForm);
    LForm.FLabelAuthor.Parent := LForm.FPanelHeader;
    LForm.FLabelAuthor.Left := 10;
    LForm.FLabelAuthor.Top := 28;
    LForm.FLabelAuthor.Caption := ALineInfo.Author + ' <' + ALineInfo.AuthorMail + '>';

    LForm.FLabelDate := TLabel.Create(LForm);
    LForm.FLabelDate.Parent := LForm.FPanelHeader;
    LForm.FLabelDate.Left := 10;
    LForm.FLabelDate.Top := 46;
    LForm.FLabelDate.Caption := FormatDateTime('yyyy-mm-dd hh:nn:ss', ALineInfo.AuthorTime);

    LForm.FMemoMessage := TMemo.Create(LForm);
    LForm.FMemoMessage.Parent := LForm.FPanelHeader;
    LForm.FMemoMessage.Left := 10;
    LForm.FMemoMessage.Top := 66;
    LForm.FMemoMessage.Width := LForm.Width - 30;
    LForm.FMemoMessage.Height := 48;
    LForm.FMemoMessage.Anchors := [akLeft, akTop, akRight];
    LForm.FMemoMessage.ReadOnly := True;
    LForm.FMemoMessage.BorderStyle := bsNone;
    LForm.FMemoMessage.ScrollBars := ssVertical;
    LForm.FMemoMessage.WordWrap := True;
    LForm.FMemoMessage.TabStop := False;

    // Toolbar panel
    LForm.FPanelToolbar := TPanel.Create(LForm);
    LForm.FPanelToolbar.Parent := LForm;
    LForm.FPanelToolbar.Align := alTop;
    LForm.FPanelToolbar.Height := 30;
    LForm.FPanelToolbar.BevelOuter := bvNone;

    LForm.FButtonToggleScope := TButton.Create(LForm);
    LForm.FButtonToggleScope.Parent := LForm.FPanelToolbar;
    LForm.FButtonToggleScope.Left := 10;
    LForm.FButtonToggleScope.Top := 3;
    LForm.FButtonToggleScope.Width := 180;
    LForm.FButtonToggleScope.Caption := 'Show Full Commit Diff';
    LForm.FButtonToggleScope.OnClick := LForm.DoToggleScopeClick;

    LForm.FLabelLoading := TLabel.Create(LForm);
    LForm.FLabelLoading.Parent := LForm.FPanelToolbar;
    LForm.FLabelLoading.Left := 200;
    LForm.FLabelLoading.Top := 7;
    LForm.FLabelLoading.Caption := 'Loading...';
    LForm.FLabelLoading.Font.Style := [fsItalic];
    LForm.FLabelLoading.Visible := False;

    // RichEdit for diff display
    LForm.FRichEditDiff := TRichEdit.Create(LForm);
    LForm.FRichEditDiff.Parent := LForm;
    LForm.FRichEditDiff.Align := alClient;
    LForm.FRichEditDiff.Font.Name := 'Consolas';
    LForm.FRichEditDiff.Font.Size := 10;
    LForm.FRichEditDiff.ReadOnly := True;
    LForm.FRichEditDiff.WordWrap := False;
    LForm.FRichEditDiff.ScrollBars := ssBoth;
    LForm.FRichEditDiff.HideSelection := False;

    // Apply theme colors
    LForm.ApplyThemeColors;

    // Populate from cache or fetch async
    if CommitDetailCache.TryGet(ACommitHash, LDetail) and LDetail.Fetched then
    begin
      LForm.FLabelLoading.Visible := False;
      LForm.FMemoMessage.Text := LDetail.FullMessage;
      LForm.FFileDiff := LDetail.FileDiff;
      LForm.FFullDiff := LDetail.FullDiff;
      LForm.LoadDiffIntoRichEdit(LDetail.FileDiff);
    end
    else
    begin
      LForm.FLabelLoading.Visible := True;
      FetchCommitDetailAsync(ACommitHash, ARepoRoot, ARelativeFilePath,
        LForm.HandleCommitDetailComplete);
    end;

    LForm.ShowModal;

    // Save dialog size on close
    BlameSettings.DiffDialogWidth := LForm.Width;
    BlameSettings.DiffDialogHeight := LForm.Height;
    BlameSettings.Save;
  finally
    LForm.Free;
  end;
end;

procedure TFormDXBlameDiff.HandleCommitDetailComplete(const ADetail: TCommitDetail);
begin
  FLabelLoading.Visible := False;

  if ADetail.Fetched then
  begin
    FMemoMessage.Text := ADetail.FullMessage;
    FFileDiff := ADetail.FileDiff;
    FFullDiff := ADetail.FullDiff;

    CommitDetailCache.Store(FCommitHash, ADetail);

    if FShowingFullDiff then
      LoadDiffIntoRichEdit(FFullDiff)
    else
      LoadDiffIntoRichEdit(FFileDiff);
  end
  else
    FMemoMessage.Text := '(Failed to fetch commit details)';
end;

procedure TFormDXBlameDiff.DoToggleScopeClick(ASender: TObject);
var
  LDetail: TCommitDetail;
begin
  FShowingFullDiff := not FShowingFullDiff;

  if FShowingFullDiff then
  begin
    FButtonToggleScope.Caption := 'Show Current File Only';
    if FFullDiff <> '' then
      LoadDiffIntoRichEdit(FFullDiff)
    else
    begin
      // Full diff not yet available, fetch it
      FLabelLoading.Visible := True;
      if CommitDetailCache.TryGet(FCommitHash, LDetail) and LDetail.Fetched then
      begin
        FFullDiff := LDetail.FullDiff;
        FLabelLoading.Visible := False;
        LoadDiffIntoRichEdit(FFullDiff);
      end
      else
        FetchCommitDetailAsync(FCommitHash, FRepoRoot, FRelativeFilePath,
          HandleCommitDetailComplete);
    end;
  end
  else
  begin
    FButtonToggleScope.Caption := 'Show Full Commit Diff';
    LoadDiffIntoRichEdit(FFileDiff);
  end;
end;

procedure TFormDXBlameDiff.LoadDiffIntoRichEdit(const ADiff: string);
var
  LLines: TArray<string>;
  LLine: string;
  LColor: TColor;
  LDark: Boolean;
  LDefaultColor: TColor;
  i, LCount: Integer;
begin
  LDark := IsDarkTheme;
  if LDark then
    LDefaultColor := $00D4D4D4
  else
    LDefaultColor := clBlack;

  FRichEditDiff.Lines.BeginUpdate;
  try
    FRichEditDiff.Clear;
    if ADiff = '' then
    begin
      FRichEditDiff.Text := '(No diff available)';
      Exit;
    end;

    LLines := ADiff.Split([#10]);
    LCount := Length(LLines);
    if LCount > cMaxDiffLines then
      LCount := cMaxDiffLines;

    for i := 0 to LCount - 1 do
    begin
      LLine := LLines[i].TrimRight([#13]);
      LColor := GetDiffLineColor(LLine, LDark, LDefaultColor);

      FRichEditDiff.SelStart := FRichEditDiff.GetTextLen;
      FRichEditDiff.SelLength := 0;
      FRichEditDiff.SelAttributes.Color := LColor;

      if i < LCount - 1 then
        FRichEditDiff.SelText := LLine + #13#10
      else
        FRichEditDiff.SelText := LLine;
    end;

    if Length(LLines) > cMaxDiffLines then
    begin
      FRichEditDiff.SelStart := FRichEditDiff.GetTextLen;
      FRichEditDiff.SelLength := 0;
      FRichEditDiff.SelAttributes.Color := clYellow;
      FRichEditDiff.SelText := #13#10 + '[Showing first ' + IntToStr(cMaxDiffLines) + ' lines]';
    end;
  finally
    FRichEditDiff.Lines.EndUpdate;
  end;

  // Scroll to top
  FRichEditDiff.SelStart := 0;
  FRichEditDiff.SelLength := 0;
  SendMessage(FRichEditDiff.Handle, WM_VSCROLL, SB_TOP, 0);
end;

procedure TFormDXBlameDiff.ApplyThemeColors;
begin
  if IsDarkTheme then
  begin
    Color := $002D2D2D;
    Font.Color := $00D4D4D4;
    FPanelHeader.Color := $002D2D2D;
    FPanelHeader.Font.Color := $00D4D4D4;
    FPanelToolbar.Color := $002D2D2D;
    FLabelHash.Font.Color := $00569CD6;
    FLabelAuthor.Font.Color := $00D4D4D4;
    FLabelDate.Font.Color := $00808080;
    FMemoMessage.Color := $00252525;
    FMemoMessage.Font.Color := $00D4D4D4;
    FLabelLoading.Font.Color := $00808080;
    FRichEditDiff.Color := $00252525;
    FRichEditDiff.Font.Color := $00D4D4D4;
  end
  else
  begin
    Color := clWindow;
    Font.Color := clWindowText;
    FPanelHeader.Color := clWindow;
    FPanelHeader.Font.Color := clWindowText;
    FPanelToolbar.Color := clWindow;
    FLabelHash.Font.Color := clNavy;
    FLabelAuthor.Font.Color := clWindowText;
    FLabelDate.Font.Color := clGray;
    FMemoMessage.Color := clWindow;
    FMemoMessage.Font.Color := clWindowText;
    FLabelLoading.Font.Color := clGray;
    FRichEditDiff.Color := clWindow;
    FRichEditDiff.Font.Color := clWindowText;
  end;
end;

function TFormDXBlameDiff.IsDarkTheme: Boolean;
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
