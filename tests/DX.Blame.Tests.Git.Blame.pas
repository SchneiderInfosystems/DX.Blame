/// <summary>
/// DX.Blame.Tests.Git.Blame
/// Unit tests for the git blame porcelain output parser.
/// </summary>
///
/// <remarks>
/// Validates ParseBlameOutput against realistic git blame --line-porcelain
/// output including committed lines, uncommitted lines, multi-line files,
/// empty output, and UTF-8 author names.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Git.Blame;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.Git.Types;

type
  [TestFixture]
  TBlameParserTests = class
  private
    /// <summary>Sample porcelain output for a single committed line.</summary>
    function SampleCommittedLine: string;
    /// <summary>Sample porcelain output for an uncommitted (dirty) line.</summary>
    function SampleUncommittedLine: string;
    /// <summary>Sample porcelain output with multiple lines.</summary>
    function SampleMultipleLines: string;
    /// <summary>Sample porcelain output with UTF-8 author name.</summary>
    function SampleUTF8Author: string;
  public
    [Test]
    procedure TestParseSingleCommittedLine;
    [Test]
    procedure TestParseUncommittedLine;
    [Test]
    procedure TestParseMultipleLines;
    [Test]
    procedure TestParseEmptyOutput;
    [Test]
    procedure TestParseUTF8Author;
    [Test]
    procedure TestParseSummaryExtraction;
  end;

implementation

uses
  System.SysUtils,
  System.DateUtils,
  DX.Blame.Git.Blame;

const
  LF = #10;

{ TBlameParserTests }

function TBlameParserTests.SampleCommittedLine: string;
begin
  Result :=
    'abc1234567890123456789012345678901234567 10 1 1' + LF +
    'author John Doe' + LF +
    'author-mail <john@example.com>' + LF +
    'author-time 1700000000' + LF +
    'author-tz +0100' + LF +
    'committer John Doe' + LF +
    'committer-mail <john@example.com>' + LF +
    'committer-time 1700000000' + LF +
    'committer-tz +0100' + LF +
    'summary Fix the widget' + LF +
    'filename src/Unit1.pas' + LF +
    #9'procedure DoSomething;' + LF;
end;

function TBlameParserTests.SampleUncommittedLine: string;
begin
  Result :=
    '0000000000000000000000000000000000000000 5 1 1' + LF +
    'author Not Committed Yet' + LF +
    'author-mail <not.committed.yet>' + LF +
    'author-time 1700000000' + LF +
    'author-tz +0000' + LF +
    'committer Not Committed Yet' + LF +
    'committer-mail <not.committed.yet>' + LF +
    'committer-time 1700000000' + LF +
    'committer-tz +0000' + LF +
    'summary Version of src/Unit1.pas from modified content' + LF +
    'filename src/Unit1.pas' + LF +
    #9'var x: Integer;' + LF;
end;

function TBlameParserTests.SampleMultipleLines: string;
begin
  Result :=
    'abc1234567890123456789012345678901234567 10 1 2' + LF +
    'author John Doe' + LF +
    'author-mail <john@example.com>' + LF +
    'author-time 1700000000' + LF +
    'author-tz +0100' + LF +
    'committer John Doe' + LF +
    'committer-mail <john@example.com>' + LF +
    'committer-time 1700000000' + LF +
    'committer-tz +0100' + LF +
    'summary Fix the widget' + LF +
    'filename src/Unit1.pas' + LF +
    #9'procedure DoSomething;' + LF +
    'abc1234567890123456789012345678901234567 11 2' + LF +
    'author John Doe' + LF +
    'author-mail <john@example.com>' + LF +
    'author-time 1700000000' + LF +
    'author-tz +0100' + LF +
    'committer John Doe' + LF +
    'committer-mail <john@example.com>' + LF +
    'committer-time 1700000000' + LF +
    'committer-tz +0100' + LF +
    'summary Fix the widget' + LF +
    'filename src/Unit1.pas' + LF +
    #9'begin' + LF +
    'def4567890123456789012345678901234567890 1 3 1' + LF +
    'author Jane Smith' + LF +
    'author-mail <jane@example.com>' + LF +
    'author-time 1690000000' + LF +
    'author-tz +0200' + LF +
    'committer Jane Smith' + LF +
    'committer-mail <jane@example.com>' + LF +
    'committer-time 1690000000' + LF +
    'committer-tz +0200' + LF +
    'summary Initial commit' + LF +
    'filename src/Unit1.pas' + LF +
    #9'end;' + LF;
end;

function TBlameParserTests.SampleUTF8Author: string;
begin
  Result :=
    'abc1234567890123456789012345678901234567 1 1 1' + LF +
    'author M' + #$C3#$BC + 'ller ' + #$C3#$96 + 'sterreich' + LF +
    'author-mail <mueller@example.com>' + LF +
    'author-time 1700000000' + LF +
    'author-tz +0100' + LF +
    'committer M' + #$C3#$BC + 'ller ' + #$C3#$96 + 'sterreich' + LF +
    'committer-mail <mueller@example.com>' + LF +
    'committer-time 1700000000' + LF +
    'committer-tz +0100' + LF +
    'summary Add umlauts test' + LF +
    'filename src/Unit1.pas' + LF +
    #9'// test' + LF;
end;

procedure TBlameParserTests.TestParseSingleCommittedLine;
var
  LLines: TArray<TBlameLineInfo>;
begin
  ParseBlameOutput(SampleCommittedLine, LLines);
  Assert.AreEqual(Integer(1), Integer(Length(LLines)), 'Should parse exactly one line');
  Assert.AreEqual('abc1234567890123456789012345678901234567', LLines[0].CommitHash);
  Assert.AreEqual('John Doe', LLines[0].Author);
  Assert.AreEqual('<john@example.com>', LLines[0].AuthorMail);
  Assert.AreEqual(Integer(10), Integer(LLines[0].OriginalLine));
  Assert.AreEqual(Integer(1), Integer(LLines[0].FinalLine));
  Assert.IsFalse(LLines[0].IsUncommitted);
end;

procedure TBlameParserTests.TestParseUncommittedLine;
var
  LLines: TArray<TBlameLineInfo>;
begin
  ParseBlameOutput(SampleUncommittedLine, LLines);
  Assert.AreEqual(Integer(1), Integer(Length(LLines)), 'Should parse exactly one line');
  Assert.IsTrue(LLines[0].IsUncommitted, 'Should be marked as uncommitted');
  Assert.AreEqual(cUncommittedHash, LLines[0].CommitHash);
  Assert.AreEqual(cNotCommittedAuthor, LLines[0].Author);
end;

procedure TBlameParserTests.TestParseMultipleLines;
var
  LLines: TArray<TBlameLineInfo>;
begin
  ParseBlameOutput(SampleMultipleLines, LLines);
  Assert.AreEqual(Integer(3), Integer(Length(LLines)), 'Should parse three line entries');
  Assert.AreEqual(Integer(1), Integer(LLines[0].FinalLine));
  Assert.AreEqual(Integer(2), Integer(LLines[1].FinalLine));
  Assert.AreEqual(Integer(3), Integer(LLines[2].FinalLine));
  Assert.AreEqual('Jane Smith', LLines[2].Author);
end;

procedure TBlameParserTests.TestParseEmptyOutput;
var
  LLines: TArray<TBlameLineInfo>;
begin
  ParseBlameOutput('', LLines);
  Assert.AreEqual(Integer(0), Integer(Length(LLines)), 'Empty output should produce empty array');
end;

procedure TBlameParserTests.TestParseUTF8Author;
var
  LLines: TArray<TBlameLineInfo>;
  LExpectedAuthor: string;
begin
  ParseBlameOutput(SampleUTF8Author, LLines);
  Assert.AreEqual(Integer(1), Integer(Length(LLines)));
  LExpectedAuthor := 'M' + #$C3#$BC + 'ller ' + #$C3#$96 + 'sterreich';
  Assert.AreEqual(LExpectedAuthor, LLines[0].Author, 'UTF-8 author name must be preserved');
end;

procedure TBlameParserTests.TestParseSummaryExtraction;
var
  LLines: TArray<TBlameLineInfo>;
begin
  ParseBlameOutput(SampleCommittedLine, LLines);
  Assert.AreEqual(Integer(1), Integer(Length(LLines)));
  Assert.AreEqual('Fix the widget', LLines[0].Summary);
end;

initialization
  TDUnitX.RegisterTestFixture(TBlameParserTests);

end.
