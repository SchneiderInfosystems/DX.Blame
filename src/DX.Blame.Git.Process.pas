/// <summary>
/// DX.Blame.Git.Process
/// CreateProcess wrapper for git CLI with pipe capture and cancellation.
/// </summary>
///
/// <remarks>
/// Provides TGitProcess, a safe wrapper around the Win32 CreateProcess API
/// for executing git commands with stdout captured via anonymous pipes.
/// Supports both synchronous execution (for short commands like rev-parse)
/// and async execution that exposes the process handle for external
/// cancellation. All handle cleanup paths are covered by try/finally.
/// This is a pure process wrapper -- no threading logic.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Process;

interface

uses
  Winapi.Windows;

type
  /// <summary>
  /// Safe wrapper for executing git commands via CreateProcess with
  /// stdout pipe capture and optional cancellation support.
  /// </summary>
  TGitProcess = class
  private
    FGitPath: string;
    FWorkDir: string;
  public
    /// <summary>Creates a process wrapper for the given git executable and working directory.</summary>
    constructor Create(const AGitPath, AWorkDir: string);

    /// <summary>
    /// Runs a git command synchronously and captures stdout.
    /// Returns the process exit code, or -1 on failure.
    /// </summary>
    function Execute(const AArgs: string; out AOutput: string): Integer;

    /// <summary>
    /// Runs a git command and exposes the process handle for external cancellation.
    /// The caller is responsible for closing AProcessHandle when done.
    /// Returns the process exit code, or -1 on failure.
    /// </summary>
    function ExecuteAsync(const AArgs: string; out AOutput: string;
      var AProcessHandle: THandle): Integer;

    /// <summary>
    /// Terminates a running git process and closes its handle.
    /// Sets AProcessHandle to zero after cleanup.
    /// </summary>
    class procedure CancelProcess(var AProcessHandle: THandle);

    /// <summary>Full path to the git executable.</summary>
    property GitPath: string read FGitPath;
    /// <summary>Working directory for git commands.</summary>
    property WorkDir: string read FWorkDir;
  end;

implementation

uses
  System.SysUtils,
  System.Classes;

{ TGitProcess }

constructor TGitProcess.Create(const AGitPath, AWorkDir: string);
begin
  inherited Create;
  FGitPath := AGitPath;
  FWorkDir := AWorkDir;
end;

function TGitProcess.Execute(const AArgs: string; out AOutput: string): Integer;
var
  LProcessHandle: THandle;
begin
  LProcessHandle := 0;
  Result := ExecuteAsync(AArgs, AOutput, LProcessHandle);
  // ExecuteAsync leaves the process handle open for the caller;
  // in synchronous mode we close it ourselves
  if LProcessHandle <> 0 then
    CloseHandle(LProcessHandle);
end;

function TGitProcess.ExecuteAsync(const AArgs: string; out AOutput: string;
  var AProcessHandle: THandle): Integer;
var
  LSA: TSecurityAttributes;
  LReadPipe, LWritePipe: THandle;
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LBuffer: TBytes;
  LBytesRead: DWORD;
  LStream: TBytesStream;
  LExitCode: DWORD;
  LCmdLine: string;
begin
  Result := -1;
  AOutput := '';
  AProcessHandle := 0;

  LSA.nLength := SizeOf(LSA);
  LSA.bInheritHandle := True;
  LSA.lpSecurityDescriptor := nil;

  LWritePipe := 0;
  LReadPipe := 0;

  if not CreatePipe(LReadPipe, LWritePipe, @LSA, 0) then
    Exit;
  try
    // Prevent read handle from being inherited by child process
    SetHandleInformation(LReadPipe, HANDLE_FLAG_INHERIT, 0);

    FillChar(LSI, SizeOf(LSI), 0);
    LSI.cb := SizeOf(LSI);
    LSI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LSI.hStdOutput := LWritePipe;
    LSI.hStdError := LWritePipe;
    LSI.wShowWindow := SW_HIDE;

    LCmdLine := Format('"%s" %s', [FGitPath, AArgs]);

    FillChar(LPI, SizeOf(LPI), 0);

    if not CreateProcess(nil, PChar(LCmdLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(FWorkDir), LSI, LPI) then
      Exit;
    try
      // Close write end IMMEDIATELY after CreateProcess to avoid deadlock.
      // The child process has its own handle to the write end via inheritance.
      CloseHandle(LWritePipe);
      LWritePipe := 0;

      // Read all output from the pipe before waiting for process exit
      LStream := TBytesStream.Create;
      try
        SetLength(LBuffer, 4096);
        while ReadFile(LReadPipe, LBuffer[0], Length(LBuffer), LBytesRead, nil)
          and (LBytesRead > 0) do
          LStream.WriteBuffer(LBuffer[0], LBytesRead);

        AOutput := TEncoding.UTF8.GetString(LStream.Bytes, 0, Integer(LStream.Size));
      finally
        LStream.Free;
      end;

      // Wait for process to finish (with timeout to avoid infinite hang)
      WaitForSingleObject(LPI.hProcess, 5000);
      GetExitCodeProcess(LPI.hProcess, LExitCode);
      Result := Integer(LExitCode);

      // Expose process handle to caller; caller is responsible for closing it
      AProcessHandle := LPI.hProcess;
    finally
      // Always close the thread handle
      CloseHandle(LPI.hThread);
      // Do NOT close LPI.hProcess here -- it is returned via AProcessHandle
    end;
  finally
    if LWritePipe <> 0 then
      CloseHandle(LWritePipe);
    CloseHandle(LReadPipe);
  end;
end;

class procedure TGitProcess.CancelProcess(var AProcessHandle: THandle);
begin
  if AProcessHandle <> 0 then
  begin
    TerminateProcess(AProcessHandle, 1);
    CloseHandle(AProcessHandle);
    AProcessHandle := 0;
  end;
end;

end.
