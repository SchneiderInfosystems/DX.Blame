/// <summary>
/// DX.Blame.Formatter
/// Pure formatting functions for blame annotation text and color derivation.
/// </summary>
///
/// <remarks>
/// Provides FormatBlameAnnotation (assembles display text from TBlameLineInfo
/// and TDXBlameSettings), FormatRelativeTime (human-readable time deltas),
/// and DeriveAnnotationColor (theme-adaptive muted color). All functions
/// except DeriveAnnotationColor are pure and depend only on RTL.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Formatter;

interface

uses
  System.SysUtils,
  Vcl.Graphics,
  DX.Blame.Git.Types,
  DX.Blame.Settings;

/// <summary>Formats a TDateTime as a human-readable relative time string.</summary>
function FormatRelativeTime(ADateTime: TDateTime): string;

/// <summary>Assembles blame annotation text from line info and settings.</summary>
/// <remarks>
/// For committed lines, the annotation is prefixed with the 7-char short hash
/// followed by two spaces. Use GetAnnotationHashLength to determine how many
/// characters of the result belong to the clickable hash prefix.
/// </remarks>
function FormatBlameAnnotation(const ALineInfo: TBlameLineInfo;
  const ASettings: TDXBlameSettings): string;

/// <summary>
/// Returns the length of the clickable hash prefix in the annotation text.
/// Returns 0 for uncommitted lines (no hash shown), or 9 for committed lines
/// (7-char hash + 2 spaces).
/// </summary>
function GetAnnotationHashLength(const ALineInfo: TBlameLineInfo): Integer;

/// <summary>Derives a muted annotation color from the editor background.</summary>
function DeriveAnnotationColor: TColor;

/// <summary>
/// Pure function that determines the display color for a diff line based on
/// its prefix characters, theme mode, and a fallback default color.
/// </summary>
function GetDiffLineColor(const ALine: string; AIsDarkTheme: Boolean;
  ADefaultColor: TColor): TColor;

implementation

uses
  System.DateUtils,
  System.StrUtils,
  System.Math,
  Winapi.Windows;

function FormatRelativeTime(ADateTime: TDateTime): string;
var
  LNow: TDateTime;
  LYears, LMonths, LDays, LHours, LMinutes: Integer;
begin
  LNow := Now;

  LYears := YearsBetween(LNow, ADateTime);
  if LYears > 0 then
    Exit(IntToStr(LYears) + IfThen(LYears = 1, ' year ago', ' years ago'));

  LMonths := MonthsBetween(LNow, ADateTime);
  if LMonths > 0 then
    Exit(IntToStr(LMonths) + IfThen(LMonths = 1, ' month ago', ' months ago'));

  LDays := DaysBetween(LNow, ADateTime);
  if LDays > 0 then
    Exit(IntToStr(LDays) + IfThen(LDays = 1, ' day ago', ' days ago'));

  LHours := HoursBetween(LNow, ADateTime);
  if LHours > 0 then
    Exit(IntToStr(LHours) + IfThen(LHours = 1, ' hour ago', ' hours ago'));

  LMinutes := MinutesBetween(LNow, ADateTime);
  if LMinutes > 0 then
    Exit(IntToStr(LMinutes) + IfThen(LMinutes = 1, ' minute ago', ' minutes ago'));

  Result := 'just now';
end;

function FormatBlameAnnotation(const ALineInfo: TBlameLineInfo;
  const ASettings: TDXBlameSettings): string;
var
  LParts: TStringBuilder;
  LShortHash: string;
begin
  if ALineInfo.IsUncommitted then
    Exit(cNotCommittedAuthor);

  LParts := TStringBuilder.Create;
  try
    // Always prefix with 7-char short hash for committed lines
    LShortHash := Copy(ALineInfo.CommitHash, 1, 7);
    LParts.Append(LShortHash);
    LParts.Append('  ');

    if ASettings.ShowAuthor then
    begin
      LParts.Append(ALineInfo.Author);
      LParts.Append(', ');
    end;

    case ASettings.DateFormat of
      dfRelative: LParts.Append(FormatRelativeTime(ALineInfo.AuthorTime));
      dfAbsolute: LParts.Append(FormatDateTime('yyyy-mm-dd', ALineInfo.AuthorTime));
    end;

    if ASettings.ShowSummary and (ALineInfo.Summary <> '') then
    begin
      LParts.Append(' ');
      LParts.Append(#$2022); // bullet
      LParts.Append(' ');
      LParts.Append(ALineInfo.Summary);
    end;

    Result := LParts.ToString;

    if (ASettings.MaxLength > 0) and (Length(Result) > ASettings.MaxLength) then
      Result := Copy(Result, 1, ASettings.MaxLength - 1) + #$2026; // ellipsis
  finally
    LParts.Free;
  end;
end;

function GetAnnotationHashLength(const ALineInfo: TBlameLineInfo): Integer;
begin
  if ALineInfo.IsUncommitted then
    Result := 0
  else
    Result := 7; // 7-char hash only, no trailing spaces
end;

function DeriveAnnotationColor: TColor;
begin
  // Fallback for non-IDE context. The renderer (Plan 02) will override this
  // with INTACodeEditorServices.Options.BackgroundColor[atWhiteSpace] blending.
  Result := clGray;
end;

function GetDiffLineColor(const ALine: string; AIsDarkTheme: Boolean;
  ADefaultColor: TColor): TColor;
begin
  Result := ADefaultColor;
  if Length(ALine) = 0 then
    Exit;

  if ALine.StartsWith('@@') then
  begin
    if AIsDarkTheme then
      Result := clSkyBlue
    else
      Result := clBlue;
  end
  else if ALine.StartsWith('+++') or ALine.StartsWith('---') then
  begin
    // File headers: keep default color
    Result := ADefaultColor;
  end
  else if ALine[1] = '+' then
  begin
    if AIsDarkTheme then
      Result := TColor(RGB(144, 238, 144))
    else
      Result := clGreen;
  end
  else if ALine[1] = '-' then
  begin
    if AIsDarkTheme then
      Result := TColor(RGB(255, 150, 150))
    else
      Result := clRed;
  end;
end;

end.
