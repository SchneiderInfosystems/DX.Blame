/// <summary>
/// DX.Blame.Git.Types
/// Shared data contracts for the blame data pipeline.
/// </summary>
///
/// <remarks>
/// Defines the core types used across all Phase 2 units: TBlameLineInfo
/// holds per-line blame metadata, TBlameData wraps a complete file result,
/// and constants define sentinel values for uncommitted lines and timing
/// defaults. This unit depends only on RTL.
/// </remarks>
///
/// <copyright>
/// Copyright © 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Git.Types;

interface

uses
  System.SysUtils;

const
  /// <summary>SHA-1 hash sentinel for lines not yet committed.</summary>
  cUncommittedHash = '0000000000000000000000000000000000000000';

  /// <summary>Display author name for uncommitted lines.</summary>
  cNotCommittedAuthor = 'Not committed yet';

  /// <summary>Retry delay in milliseconds for transient git errors.</summary>
  cDefaultRetryDelayMs = 2500;

  /// <summary>Debounce interval in milliseconds for save-triggered re-blame.</summary>
  cDefaultDebounceMs = 500;

type
  /// <summary>
  /// Per-line blame metadata returned by git blame --line-porcelain.
  /// </summary>
  TBlameLineInfo = record
    /// <summary>40-character SHA-1 commit hash. All zeros for uncommitted lines.</summary>
    CommitHash: string;
    /// <summary>Author name from the commit.</summary>
    Author: string;
    /// <summary>Author email address.</summary>
    AuthorMail: string;
    /// <summary>Author timestamp converted from Unix epoch to TDateTime.</summary>
    AuthorTime: TDateTime;
    /// <summary>First line of the commit message.</summary>
    Summary: string;
    /// <summary>Line number in the original (committed) file.</summary>
    OriginalLine: Integer;
    /// <summary>Line number in the current (working) file.</summary>
    FinalLine: Integer;
    /// <summary>True when CommitHash equals cUncommittedHash.</summary>
    IsUncommitted: Boolean;
  end;

  /// <summary>
  /// Container for a file's complete blame results.
  /// </summary>
  TBlameData = class
  private
    FLines: TArray<TBlameLineInfo>;
    FFileName: string;
    FTimestamp: TDateTime;
  public
    /// <summary>Creates a new blame data container for the given file.</summary>
    constructor Create(const AFileName: string);
    /// <summary>Blame entries indexed by final line number (1-based).</summary>
    property Lines: TArray<TBlameLineInfo> read FLines write FLines;
    /// <summary>Lowercase normalized full path of the blamed file.</summary>
    property FileName: string read FFileName;
    /// <summary>UTC timestamp when the blame was executed.</summary>
    property Timestamp: TDateTime read FTimestamp write FTimestamp;
  end;

implementation

{ TBlameData }

constructor TBlameData.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := LowerCase(AFileName);
  FTimestamp := Now;
end;

end.
