/// <summary>
/// DX.Blame.Tests.DiffFormatter
/// Unit tests for diff line color assignment logic.
/// </summary>
///
/// <remarks>
/// Validates that GetDiffLineColor correctly identifies addition lines (green),
/// deletion lines (red), hunk headers (blue), and distinguishes file headers
/// (+++ and ---) from actual diff content lines.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.DiffFormatter;

interface

uses
  DUnitX.TestFramework,
  Vcl.Graphics;

type
  [TestFixture]
  TDiffFormatterTests = class
  public
    [Test]
    procedure AdditionLine_DarkTheme_GetsGreenColor;
    [Test]
    procedure AdditionLine_LightTheme_GetsGreenColor;
    [Test]
    procedure DeletionLine_DarkTheme_GetsRedColor;
    [Test]
    procedure DeletionLine_LightTheme_GetsRedColor;
    [Test]
    procedure HunkHeader_DarkTheme_GetsBlueColor;
    [Test]
    procedure HunkHeader_LightTheme_GetsBlueColor;
    [Test]
    procedure FileHeaderPlus_GetsDefaultColor;
    [Test]
    procedure FileHeaderMinus_GetsDefaultColor;
    [Test]
    procedure ContextLine_GetsDefaultColor;
  end;

implementation

uses
  Winapi.Windows,
  DX.Blame.Formatter;

{ TDiffFormatterTests }

procedure TDiffFormatterTests.AdditionLine_DarkTheme_GetsGreenColor;
begin
  Assert.AreEqual(Integer(RGB(144, 238, 144)),
    Integer(GetDiffLineColor('+added line', True, clWhite)),
    'Dark theme addition should be light green');
end;

procedure TDiffFormatterTests.AdditionLine_LightTheme_GetsGreenColor;
begin
  Assert.AreEqual(Integer(clGreen),
    Integer(GetDiffLineColor('+added line', False, clBlack)),
    'Light theme addition should be clGreen');
end;

procedure TDiffFormatterTests.DeletionLine_DarkTheme_GetsRedColor;
begin
  Assert.AreEqual(Integer(RGB(255, 150, 150)),
    Integer(GetDiffLineColor('-removed line', True, clWhite)),
    'Dark theme deletion should be light red');
end;

procedure TDiffFormatterTests.DeletionLine_LightTheme_GetsRedColor;
begin
  Assert.AreEqual(Integer(clRed),
    Integer(GetDiffLineColor('-removed line', False, clBlack)),
    'Light theme deletion should be clRed');
end;

procedure TDiffFormatterTests.HunkHeader_DarkTheme_GetsBlueColor;
begin
  Assert.AreEqual(Integer(clSkyBlue),
    Integer(GetDiffLineColor('@@ -10,5 +10,7 @@', True, clWhite)),
    'Dark theme hunk header should be clSkyBlue');
end;

procedure TDiffFormatterTests.HunkHeader_LightTheme_GetsBlueColor;
begin
  Assert.AreEqual(Integer(clBlue),
    Integer(GetDiffLineColor('@@ -10,5 +10,7 @@', False, clBlack)),
    'Light theme hunk header should be clBlue');
end;

procedure TDiffFormatterTests.FileHeaderPlus_GetsDefaultColor;
begin
  Assert.AreEqual(Integer(clWhite),
    Integer(GetDiffLineColor('+++ b/src/file.pas', True, clWhite)),
    'File header +++ should get default color, not green');
end;

procedure TDiffFormatterTests.FileHeaderMinus_GetsDefaultColor;
begin
  Assert.AreEqual(Integer(clWhite),
    Integer(GetDiffLineColor('--- a/src/file.pas', True, clWhite)),
    'File header --- should get default color, not red');
end;

procedure TDiffFormatterTests.ContextLine_GetsDefaultColor;
begin
  Assert.AreEqual(Integer(clWhite),
    Integer(GetDiffLineColor(' unchanged context line', True, clWhite)),
    'Context line should get default color');
end;

initialization
  TDUnitX.RegisterTestFixture(TDiffFormatterTests);

end.
