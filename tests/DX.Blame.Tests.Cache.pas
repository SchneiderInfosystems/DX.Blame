/// <summary>
/// DX.Blame.Tests.Cache
/// Unit tests for the thread-safe blame data cache.
/// </summary>
///
/// <remarks>
/// Validates TBlameCache store/retrieve, invalidation, clearing,
/// case-insensitive path normalization, and overwrite behavior.
/// </remarks>
///
/// <copyright>
/// Copyright (c) 2026 Olaf Monien
/// Licensed under MIT
/// </copyright>

unit DX.Blame.Tests.Cache;

interface

uses
  DUnitX.TestFramework,
  DX.Blame.VCS.Types,
  DX.Blame.Git.Types,
  DX.Blame.Cache;

type
  [TestFixture]
  TBlameCacheTests = class
  private
    FCache: TBlameCache;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestStoreAndRetrieve;
    [Test]
    procedure TestTryGetMissing;
    [Test]
    procedure TestInvalidate;
    [Test]
    procedure TestInvalidateNonExistent;
    [Test]
    procedure TestClear;
    [Test]
    procedure TestCaseInsensitiveLookup;
    [Test]
    procedure TestStoreOverwrites;
  end;

implementation

uses
  System.SysUtils;

{ TBlameCacheTests }

procedure TBlameCacheTests.Setup;
begin
  FCache := TBlameCache.Create;
end;

procedure TBlameCacheTests.TearDown;
begin
  FCache.Free;
end;

procedure TBlameCacheTests.TestStoreAndRetrieve;
var
  LData: TBlameData;
  LResult: TBlameData;
begin
  LData := TBlameData.Create('C:\Project\src\Unit1.pas');
  FCache.Store('C:\Project\src\Unit1.pas', LData);
  Assert.IsTrue(FCache.TryGet('C:\Project\src\Unit1.pas', LResult));
  Assert.AreSame(LData, LResult, 'Should return the same instance');
end;

procedure TBlameCacheTests.TestTryGetMissing;
var
  LResult: TBlameData;
begin
  Assert.IsFalse(FCache.TryGet('C:\NonExistent\File.pas', LResult));
end;

procedure TBlameCacheTests.TestInvalidate;
var
  LData: TBlameData;
  LResult: TBlameData;
begin
  LData := TBlameData.Create('C:\Project\src\Unit1.pas');
  FCache.Store('C:\Project\src\Unit1.pas', LData);
  FCache.Invalidate('C:\Project\src\Unit1.pas');
  Assert.IsFalse(FCache.TryGet('C:\Project\src\Unit1.pas', LResult));
end;

procedure TBlameCacheTests.TestInvalidateNonExistent;
begin
  // Should not raise an exception
  FCache.Invalidate('C:\NonExistent\File.pas');
  Assert.Pass('Invalidate on non-existent key did not raise');
end;

procedure TBlameCacheTests.TestClear;
var
  LResult: TBlameData;
begin
  FCache.Store('C:\File1.pas', TBlameData.Create('C:\File1.pas'));
  FCache.Store('C:\File2.pas', TBlameData.Create('C:\File2.pas'));
  FCache.Store('C:\File3.pas', TBlameData.Create('C:\File3.pas'));
  FCache.Clear;
  Assert.IsFalse(FCache.TryGet('C:\File1.pas', LResult));
  Assert.IsFalse(FCache.TryGet('C:\File2.pas', LResult));
  Assert.IsFalse(FCache.TryGet('C:\File3.pas', LResult));
end;

procedure TBlameCacheTests.TestCaseInsensitiveLookup;
var
  LData: TBlameData;
  LResult: TBlameData;
begin
  LData := TBlameData.Create('C:\Project\SRC\Unit1.PAS');
  FCache.Store('C:\Project\SRC\Unit1.PAS', LData);
  Assert.IsTrue(FCache.TryGet('c:\project\src\unit1.pas', LResult));
  Assert.AreSame(LData, LResult, 'Case-insensitive lookup should find same instance');
end;

procedure TBlameCacheTests.TestStoreOverwrites;
var
  LData1: TBlameData;
  LData2: TBlameData;
  LResult: TBlameData;
begin
  LData1 := TBlameData.Create('C:\Project\Unit1.pas');
  LData2 := TBlameData.Create('C:\Project\Unit1.pas');
  FCache.Store('C:\Project\Unit1.pas', LData1);
  FCache.Store('C:\Project\Unit1.pas', LData2);
  Assert.IsTrue(FCache.TryGet('C:\Project\Unit1.pas', LResult));
  Assert.AreSame(LData2, LResult, 'Should return the latest stored instance');
end;

initialization
  TDUnitX.RegisterTestFixture(TBlameCacheTests);

end.
