/// <summary>
/// DX.Blame.CommitDetail
/// Commit detail cache and async fetch for full commit messages and diffs.
/// </summary>
///
/// <remarks>
/// Provides TCommitDetail record for storing full commit message, file-specific
/// diff, and full-commit diff. TCommitDetailCache is a thread-safe dictionary
/// keyed by 40-char commit hash. FetchCommitDetailAsync spawns a background
/// thread using the TGitProcess pattern to retrieve data via git log and git show.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.CommitDetail;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

type
  /// <summary>
  /// Holds the full commit message and diff data fetched asynchronously.
  /// </summary>
  TCommitDetail = record
    /// <summary>Full multi-line commit message from git log --format=%B.</summary>
    FullMessage: string;
    /// <summary>Diff output for a single file from git show &lt;hash&gt; -- &lt;file&gt;.</summary>
    FileDiff: string;
    /// <summary>Full commit diff from git show &lt;hash&gt;.</summary>
    FullDiff: string;
    /// <summary>True when data has been fetched from git.</summary>
    Fetched: Boolean;
  end;

  /// <summary>
  /// Thread-safe cache for commit detail data, keyed by 40-char commit hash.
  /// </summary>
  TCommitDetailCache = class
  private
    FLock: TCriticalSection;
    FItems: TDictionary<string, TCommitDetail>;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Retrieves cached commit detail if available.</summary>
    function TryGet(const AHash: string; out ADetail: TCommitDetail): Boolean;
    /// <summary>Stores commit detail in the cache.</summary>
    procedure Store(const AHash: string; const ADetail: TCommitDetail);
    /// <summary>Clears all cached commit details.</summary>
    procedure Clear;
  end;

  /// <summary>
  /// Callback interface for async commit detail fetch completion.
  /// Avoids Delphi generic anonymous method type issues.
  /// </summary>
  TCommitDetailCompleteEvent = procedure(const ADetail: TCommitDetail) of object;

  /// <summary>
  /// Background thread that fetches full commit message and diffs via git.
  /// Follows the TBlameThread pattern from DX.Blame.Engine.
  /// </summary>
  TCommitDetailThread = class(TThread)
  private
    FCommitHash: string;
    FRepoRoot: string;
    FRelativeFilePath: string;
    FOnComplete: TCommitDetailCompleteEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(const ACommitHash, ARepoRoot, ARelativeFilePath: string;
      AOnComplete: TCommitDetailCompleteEvent);
  end;

/// <summary>Returns the singleton TCommitDetailCache instance (lazy-initialized).</summary>
function CommitDetailCache: TCommitDetailCache;

/// <summary>
/// Starts an async fetch of commit detail data in a background thread.
/// On completion, delivers the result to the main thread via AOnComplete.
/// </summary>
procedure FetchCommitDetailAsync(const ACommitHash, ARepoRoot, ARelativeFilePath: string;
  AOnComplete: TCommitDetailCompleteEvent);

implementation

uses
  DX.Blame.Git.Discovery,
  DX.Blame.Git.Process;

var
  GCommitDetailCache: TCommitDetailCache;

function CommitDetailCache: TCommitDetailCache;
begin
  if GCommitDetailCache = nil then
    GCommitDetailCache := TCommitDetailCache.Create;
  Result := GCommitDetailCache;
end;

{ TCommitDetailCache }

constructor TCommitDetailCache.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FItems := TDictionary<string, TCommitDetail>.Create;
end;

destructor TCommitDetailCache.Destroy;
begin
  FItems.Free;
  FLock.Free;
  inherited;
end;

function TCommitDetailCache.TryGet(const AHash: string;
  out ADetail: TCommitDetail): Boolean;
begin
  FLock.Enter;
  try
    Result := FItems.TryGetValue(AHash, ADetail);
  finally
    FLock.Leave;
  end;
end;

procedure TCommitDetailCache.Store(const AHash: string;
  const ADetail: TCommitDetail);
begin
  FLock.Enter;
  try
    FItems.AddOrSetValue(AHash, ADetail);
  finally
    FLock.Leave;
  end;
end;

procedure TCommitDetailCache.Clear;
begin
  FLock.Enter;
  try
    FItems.Clear;
  finally
    FLock.Leave;
  end;
end;

{ TCommitDetailThread }

constructor TCommitDetailThread.Create(const ACommitHash, ARepoRoot,
  ARelativeFilePath: string; AOnComplete: TCommitDetailCompleteEvent);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FCommitHash := ACommitHash;
  FRepoRoot := ARepoRoot;
  FRelativeFilePath := ARelativeFilePath;
  FOnComplete := AOnComplete;
end;

procedure TCommitDetailThread.Execute;
var
  LProcess: TGitProcess;
  LOutput: string;
  LGitPath: string;
  LDetail: TCommitDetail;
  LOnComplete: TCommitDetailCompleteEvent;
begin
  LGitPath := FindGitExecutable;
  if LGitPath = '' then
    Exit;

  LOnComplete := FOnComplete;

  LProcess := TGitProcess.Create(LGitPath, FRepoRoot);
  try
    // Fetch full commit message
    if LProcess.Execute('log -1 --format=%B ' + FCommitHash, LOutput) = 0 then
      LDetail.FullMessage := Trim(LOutput);

    if Terminated then
      Exit;

    // Fetch file-specific diff
    if FRelativeFilePath <> '' then
    begin
      if LProcess.Execute('show ' + FCommitHash + ' -- "' + FRelativeFilePath + '"', LOutput) = 0 then
        LDetail.FileDiff := LOutput;
    end;

    if Terminated then
      Exit;

    // Fetch full commit diff
    if LProcess.Execute('show ' + FCommitHash, LOutput) = 0 then
      LDetail.FullDiff := LOutput;

    LDetail.Fetched := True;

    TThread.Queue(nil,
      procedure
      begin
        if Assigned(LOnComplete) then
          LOnComplete(LDetail);
      end);
  finally
    LProcess.Free;
  end;
end;

{ Module-level }

procedure FetchCommitDetailAsync(const ACommitHash, ARepoRoot,
  ARelativeFilePath: string; AOnComplete: TCommitDetailCompleteEvent);
var
  LThread: TCommitDetailThread;
begin
  LThread := TCommitDetailThread.Create(ACommitHash, ARepoRoot,
    ARelativeFilePath, AOnComplete);
  LThread.Start;
end;

initialization

finalization
  FreeAndNil(GCommitDetailCache);

end.
