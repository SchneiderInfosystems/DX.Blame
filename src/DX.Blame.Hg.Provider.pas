/// <summary>
/// DX.Blame.Hg.Provider
/// Full IVCSProvider implementation for Mercurial.
/// </summary>
///
/// <remarks>
/// THgProvider implements IVCSProvider with working discovery operations
/// (delegating to DX.Blame.Hg.Discovery) and full blame operations that
/// delegate to DX.Blame.Hg.Process, DX.Blame.Hg.Blame, and DX.Blame.Hg.Types.
/// This class mirrors TGitProvider's delegation pattern exactly.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Hg.Provider;

interface

uses
  Winapi.Windows,
  DX.Blame.VCS.Types,
  DX.Blame.VCS.Provider;

type
  /// <summary>
  /// Mercurial-specific implementation of IVCSProvider.
  /// Delegates all operations to existing Hg discovery, process, and blame units.
  /// </summary>
  THgProvider = class(TInterfacedObject, IVCSProvider)
  public
    { IVCSProvider - Discovery }
    function FindExecutable: string;
    function FindRepoRoot(const APath: string): string;
    procedure ClearDiscoveryCache;
    function GetDisplayName: string;
    function GetUncommittedHash: string;
    function GetUncommittedAuthor: string;

    { IVCSProvider - Blame operations }
    function ExecuteBlame(const ARepoRoot, AFilePath: string;
      out AOutput: string; var AProcessHandle: THandle): Integer;
    function ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;
    function GetCommitMessage(const ARepoRoot, ACommitHash: string;
      out AMessage: string): Boolean;
    function GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
      out ADiff: string): Boolean;
    function GetFullDiff(const ARepoRoot, ACommitHash: string;
      out ADiff: string): Boolean;
    function GetFileAtRevision(const ARepoRoot, ACommitHash, ARelativePath: string;
      out AContent: string): Boolean;
  end;

implementation

uses
  System.SysUtils,
  DX.Blame.Hg.Types,
  DX.Blame.Hg.Process,
  DX.Blame.Hg.Discovery,
  DX.Blame.Hg.Blame;

{ THgProvider - Discovery }

function THgProvider.FindExecutable: string;
begin
  Result := FindHgExecutable;
end;

function THgProvider.FindRepoRoot(const APath: string): string;
begin
  Result := FindHgRepoRoot(APath);
end;

procedure THgProvider.ClearDiscoveryCache;
begin
  ClearHgDiscoveryCache;
end;

function THgProvider.GetDisplayName: string;
begin
  Result := 'Mercurial';
end;

function THgProvider.GetUncommittedHash: string;
begin
  Result := cHgUncommittedHash;
end;

function THgProvider.GetUncommittedAuthor: string;
begin
  Result := cHgNotCommittedAuthor;
end;

{ THgProvider - Blame operations }

function THgProvider.ExecuteBlame(const ARepoRoot, AFilePath: string;
  out AOutput: string; var AProcessHandle: THandle): Integer;
var
  LProcess: THgProcess;
  LRelPath: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    LRelPath := ExtractRelativePath(IncludeTrailingPathDelimiter(ARepoRoot), AFilePath);
    LRelPath := StringReplace(LRelPath, '\', '/', [rfReplaceAll]);
    Result := LProcess.ExecuteAsync(BuildAnnotateArgs(LRelPath), AOutput, AProcessHandle);
  finally
    LProcess.Free;
  end;
end;

function THgProvider.ParseBlameOutput(const AOutput: string): TArray<TBlameLineInfo>;
begin
  ParseHgAnnotateOutput(AOutput, Result);
end;

function THgProvider.GetCommitMessage(const ARepoRoot, ACommitHash: string;
  out AMessage: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('log -r ' + ACommitHash + ' -T "{desc}"', LOutput) = 0;
    if Result then
      AMessage := Trim(LOutput);
  finally
    LProcess.Free;
  end;
end;

function THgProvider.GetFileDiff(const ARepoRoot, ACommitHash, ARelativePath: string;
  out ADiff: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('diff -c ' + ACommitHash + ' "' + ARelativePath + '"', LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;

function THgProvider.GetFullDiff(const ARepoRoot, ACommitHash: string;
  out ADiff: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('diff -c ' + ACommitHash, LOutput) = 0;
    if Result then
      ADiff := LOutput;
  finally
    LProcess.Free;
  end;
end;

function THgProvider.GetFileAtRevision(const ARepoRoot, ACommitHash,
  ARelativePath: string; out AContent: string): Boolean;
var
  LProcess: THgProcess;
  LOutput: string;
begin
  LProcess := THgProcess.Create(FindHgExecutable, ARepoRoot);
  try
    Result := LProcess.Execute('cat -r ' + ACommitHash + ' "' + ARelativePath + '"', LOutput) = 0;
    if Result then
      AContent := LOutput;
  finally
    LProcess.Free;
  end;
end;

end.
