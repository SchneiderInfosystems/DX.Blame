/// <summary>
/// DX.Blame.Tests
/// DUnitX console test runner for DX.Blame.
/// </summary>
///
/// <remarks>
/// Runs all registered DUnitX test fixtures and reports results to console.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

program DX.Blame.Tests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DUnitX.Loggers.Console,
  DUnitX.MemoryLeakMonitor.Default,
  DX.Blame.Tests.Version in 'DX.Blame.Tests.Version.pas',
  DX.Blame.Tests.Git.Blame in 'DX.Blame.Tests.Git.Blame.pas';

var
  LRunner: ITestRunner;
  LResults: IRunResults;
  LLogger: ITestLogger;
begin
  try
    TDUnitX.CheckCommandLine;
    LRunner := TDUnitX.CreateRunner;
    LLogger := TDUnitXConsoleLogger.Create(True);
    LRunner.AddLogger(LLogger);
    LRunner.FailsOnNoAsserts := False;
    LResults := LRunner.Execute;
    if not LResults.AllPassed then
      System.ExitCode := 1
    else
      System.ExitCode := 0;
  except
    on E: Exception do
    begin
      System.ExitCode := 1;
      Writeln(E.ClassName, ': ', E.Message);
    end;
  end;
end.