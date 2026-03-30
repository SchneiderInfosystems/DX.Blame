/// <summary>
/// DX.Blame.Tests.CommitDetail
/// Unit tests for TCommitDetailCache CRUD operations.
/// </summary>
///
/// <remarks>
/// Validates Store/TryGet round-trip, unknown hash returns False,
/// and Clear removes all entries from the commit detail cache.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.CommitDetail;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.CommitDetail;

type
  [TestFixture]
  TCommitDetailCacheTests = class
  private
    FCache: TCommitDetailCache;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Store_ThenTryGet_ReturnsTrue;
    [Test]
    procedure TryGet_UnknownHash_ReturnsFalse;
    [Test]
    procedure Clear_RemovesAllEntries;
  end;

implementation

uses
  System.SysUtils;

{ TCommitDetailCacheTests }

procedure TCommitDetailCacheTests.Setup;
begin
  FCache := TCommitDetailCache.Create;
end;

procedure TCommitDetailCacheTests.TearDown;
begin
  FreeAndNil(FCache);
end;

procedure TCommitDetailCacheTests.Store_ThenTryGet_ReturnsTrue;
var
  LDetail, LResult: TCommitDetail;
begin
  LDetail.FullMessage := 'Fix login bug';
  LDetail.FileDiff := 'diff --git a/login.pas';
  LDetail.FullDiff := 'diff --git a/login.pas b/login.pas';
  LDetail.Fetched := True;

  FCache.Store('abc1234567890abcdef1234567890abcdef123456', LDetail);

  Assert.IsTrue(
    FCache.TryGet('abc1234567890abcdef1234567890abcdef123456', LResult),
    'TryGet should return True for stored hash');
  Assert.AreEqual('Fix login bug', LResult.FullMessage, 'FullMessage mismatch');
  Assert.AreEqual('diff --git a/login.pas', LResult.FileDiff, 'FileDiff mismatch');
  Assert.AreEqual('diff --git a/login.pas b/login.pas', LResult.FullDiff, 'FullDiff mismatch');
  Assert.IsTrue(LResult.Fetched, 'Fetched should be True');
end;

procedure TCommitDetailCacheTests.TryGet_UnknownHash_ReturnsFalse;
var
  LResult: TCommitDetail;
begin
  Assert.IsFalse(
    FCache.TryGet('0000000000000000000000000000000000000000', LResult),
    'TryGet should return False for unknown hash');
end;

procedure TCommitDetailCacheTests.Clear_RemovesAllEntries;
var
  LDetail, LResult: TCommitDetail;
begin
  LDetail.FullMessage := 'Test message';
  LDetail.Fetched := True;

  FCache.Store('aaa1111111111111111111111111111111111111a', LDetail);
  FCache.Store('bbb2222222222222222222222222222222222222b', LDetail);

  FCache.Clear;

  Assert.IsFalse(
    FCache.TryGet('aaa1111111111111111111111111111111111111a', LResult),
    'TryGet should return False after Clear for first hash');
  Assert.IsFalse(
    FCache.TryGet('bbb2222222222222222222222222222222222222b', LResult),
    'TryGet should return False after Clear for second hash');
end;

initialization
  TDUnitX.RegisterTestFixture(TCommitDetailCacheTests);

end.
