unit Tests.Infrastructure.Data.InMemoryUserRepositoryTests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  Tests.TestBase;

type
  [TestFixture]
  TInMemoryUserRepositoryTests = class(TTestBase)
  private
    FRepository: TInMemoryUserRepository;
    
  public
    [Setup]
    procedure Setup; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure TestSave_NewUser_ShouldSucceed;
    
    [Test]
    procedure TestGetByUserName_ExistingUser_ShouldReturnUser;
    
    [Test]
    procedure TestGetByUserName_NonExistentUser_ShouldReturnNil;
  end;

implementation

{ TInMemoryUserRepositoryTests }

procedure TInMemoryUserRepositoryTests.Setup;
begin
  inherited Setup;
  FRepository := TInMemoryUserRepository.Create;
end;

procedure TInMemoryUserRepositoryTests.TearDown;
begin
  FRepository.Free;
  inherited TearDown;
end;

procedure TInMemoryUserRepositoryTests.TestSave_NewUser_ShouldSucceed;
var
  User: TUser;
begin
  // Arrange
  User := TUser.Create(
    'TEST-USER-1',
    'testuser',
    'test@example.com',
    'hashedpass',
    TUserRole.User
  );
  
  try
    // Act
    var Result := FRepository.Save(User);
    
    // Assert
    Assert.IsTrue(Result);
    Assert.IsTrue(FRepository.ExistsById(User.Id));
  finally
    User.Free;
  end;
end;

procedure TInMemoryUserRepositoryTests.TestGetByUserName_ExistingUser_ShouldReturnUser;
var
  User, FoundUser: TUser;
begin
  // Arrange
  User := TUser.Create(
    'TEST-USER-2',
    'testuser',
    'test@example.com',
    'hashedpass',
    TUserRole.User
  );
  
  try
    FRepository.Save(User);
    
    // Act
    FoundUser := FRepository.GetByUserName('testuser');
    
    // Assert
    try
      Assert.IsNotNull(FoundUser);
      Assert.AreEqual('testuser', FoundUser.UserName);
    finally
      FoundUser.Free;
    end;
  finally
    User.Free;
  end;
end;

procedure TInMemoryUserRepositoryTests.TestGetByUserName_NonExistentUser_ShouldReturnNil;
var
  FoundUser: TUser;
begin
  // Act
  FoundUser := FRepository.GetByUserName('nonexistent');
  
  // Assert
  Assert.IsNull(FoundUser);
end;

end.
