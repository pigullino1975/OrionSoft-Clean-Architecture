unit Tests.Core.Entities.UserTests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions,
  Tests.TestBase;

type
  [TestFixture]
  TUserTests = class(TTestBase)
  private
    function CreateTestUser: TUser;
  public
    [Setup]
    procedure Setup; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure TestUserCreation_WithValidData_ShouldSucceed;
    
    [Test]
    procedure TestUserCreation_WithEmptyId_ShouldRaiseException;
    
    [Test]
    procedure TestUserCreation_WithEmptyUserName_ShouldRaiseException;
    
    [Test]
    procedure TestUserCreation_WithEmptyEmail_ShouldRaiseException;
    
    [Test]
    procedure TestUserCreation_WithInvalidEmail_ShouldRaiseException;
    
    [Test]
    procedure TestChangePassword_WithValidHash_ShouldUpdatePassword;
    
    [Test]
    procedure TestRecordFailedLogin_ShouldIncrementAttempts;
    
    [Test]
    procedure TestRecordFailedLogin_ExceedsMax_ShouldBlockUser;
    
    [Test]
    procedure TestRecordSuccessfulLogin_ShouldResetAttempts;
    
    [Test]
    procedure TestActivate_ShouldSetUserActive;
    
    [Test]
    procedure TestDeactivate_ShouldSetUserInactive;
    
    [Test]
    procedure TestBlock_ShouldBlockUser;
    
    [Test]
    procedure TestUnblock_ShouldUnblockUser;
    
    [Test]
    procedure TestCanLogin_ActiveUser_ShouldReturnTrue;
    
    [Test]
    procedure TestCanLogin_InactiveUser_ShouldReturnFalse;
    
    [Test]
    procedure TestCanLogin_BlockedUser_ShouldReturnFalse;
    
    [Test]
    procedure TestIsPasswordExpired_RecentPassword_ShouldReturnFalse;
    
    [Test]
    procedure TestIsPasswordExpired_OldPassword_ShouldReturnTrue;
    
    [Test]
    procedure TestPromoteToRole_ShouldUpdateRole;
    
    [Test]
    procedure TestDegradeRole_ShouldUpdateRole;
  end;

implementation

{ TUserTests }

procedure TUserTests.Setup;
begin
  inherited Setup;
end;

procedure TUserTests.TearDown;
begin
  inherited TearDown;
end;

function TUserTests.CreateTestUser: TUser;
begin
  Result := TUser.Create(
    'TEST-USER-' + CreateRandomString(6),
    CreateRandomString(8),
    CreateRandomEmail,
    'hashed_password_123',
    TUserRole.User
  );
  Result.FirstName := 'John';
  Result.LastName := 'Doe';
end;

procedure TUserTests.TestUserCreation_WithValidData_ShouldSucceed;
var
  User: TUser;
begin
  // Arrange & Act
  User := CreateTestUser;
  
  try
    // Assert
    Assert.IsNotNull(User);
    Assert.IsNotEmpty(User.Id);
    Assert.IsNotEmpty(User.UserName);
    Assert.IsNotEmpty(User.Email);
    Assert.AreEqual('John', User.FirstName);
    Assert.AreEqual('Doe', User.LastName);
    Assert.AreEqual(TUserRole.User, User.Role);
    Assert.IsTrue(User.IsActive);
    Assert.IsFalse(User.IsBlocked);
    Assert.AreEqual(0, User.FailedLoginAttempts);
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestUserCreation_WithEmptyId_ShouldRaiseException;
begin
  // Arrange, Act & Assert
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('', 'testuser', 'test@example.com', 'hash', TUserRole.User).Free;
    end,
    EValidationException
  );
end;

procedure TUserTests.TestUserCreation_WithEmptyUserName_ShouldRaiseException;
begin
  // Arrange, Act & Assert
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', '', 'test@example.com', 'hash', TUserRole.User).Free;
    end,
    EValidationException
  );
end;

procedure TUserTests.TestUserCreation_WithEmptyEmail_ShouldRaiseException;
begin
  // Arrange, Act & Assert
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', 'testuser', '', 'hash', TUserRole.User).Free;
    end,
    EValidationException
  );
end;

procedure TUserTests.TestUserCreation_WithInvalidEmail_ShouldRaiseException;
begin
  // Arrange, Act & Assert
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', 'testuser', 'invalid-email', 'hash', TUserRole.User).Free;
    end,
    EValidationException
  );
end;

procedure TUserTests.TestChangePassword_WithValidHash_ShouldUpdatePassword;
var
  User: TUser;
  NewPasswordHash: string;
  OriginalPasswordChangedAt: TDateTime;
begin
  // Arrange
  User := CreateTestUser;
  try
    OriginalPasswordChangedAt := User.PasswordChangedAt;
    Sleep(1); // Ensure time difference
    NewPasswordHash := 'new_hashed_password_456';
    
    // Act
    User.ChangePassword(NewPasswordHash);
    
    // Assert
    Assert.AreEqual(NewPasswordHash, User.PasswordHash);
    Assert.IsTrue(User.PasswordChangedAt > OriginalPasswordChangedAt);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestRecordFailedLogin_ShouldIncrementAttempts;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    Assert.AreEqual(0, User.FailedLoginAttempts);
    
    // Act
    User.RecordFailedLogin(5, 30);
    
    // Assert
    Assert.AreEqual(1, User.FailedLoginAttempts);
    Assert.IsFalse(User.IsBlocked);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestRecordFailedLogin_ExceedsMax_ShouldBlockUser;
var
  User: TUser;
  I: Integer;
begin
  // Arrange
  User := CreateTestUser;
  try
    // Act - Exceed max attempts
    for I := 1 to 6 do
      User.RecordFailedLogin(5, 30);
    
    // Assert
    Assert.AreEqual(5, User.FailedLoginAttempts);
    Assert.IsTrue(User.IsBlocked);
    Assert.IsTrue(User.BlockedUntil > Now);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestRecordSuccessfulLogin_ShouldResetAttempts;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.RecordFailedLogin(5, 30);
    User.RecordFailedLogin(5, 30);
    Assert.AreEqual(2, User.FailedLoginAttempts);
    
    // Act
    User.RecordSuccessfulLogin;
    
    // Assert
    Assert.AreEqual(0, User.FailedLoginAttempts);
    Assert.IsTrue(User.LastLoginAt > 0);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestActivate_ShouldSetUserActive;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.Deactivate;
    Assert.IsFalse(User.IsActive);
    
    // Act
    User.Activate;
    
    // Assert
    Assert.IsTrue(User.IsActive);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestDeactivate_ShouldSetUserInactive;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    Assert.IsTrue(User.IsActive);
    
    // Act
    User.Deactivate;
    
    // Assert
    Assert.IsFalse(User.IsActive);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestBlock_ShouldBlockUser;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    Assert.IsFalse(User.IsBlocked);
    
    // Act
    User.Block(60); // Block for 60 minutes
    
    // Assert
    Assert.IsTrue(User.IsBlocked);
    Assert.IsTrue(User.BlockedUntil > Now);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestUnblock_ShouldUnblockUser;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.Block(60);
    Assert.IsTrue(User.IsBlocked);
    
    // Act
    User.Unblock;
    
    // Assert
    Assert.IsFalse(User.IsBlocked);
    Assert.AreEqual(0.0, User.BlockedUntil, 0.001);
    Assert.AreEqual(0, User.FailedLoginAttempts);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestCanLogin_ActiveUser_ShouldReturnTrue;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    // El usuario ya está activo por defecto, no necesita activarse
    Assert.IsTrue(User.IsActive, 'User should be active by default');
    
    // Act & Assert
    Assert.IsTrue(User.CanLogin);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestCanLogin_InactiveUser_ShouldReturnFalse;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.Deactivate;
    
    // Act & Assert
    Assert.IsFalse(User.CanLogin);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestCanLogin_BlockedUser_ShouldReturnFalse;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.Block(60);
    
    // Act & Assert
    Assert.IsFalse(User.CanLogin);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestIsPasswordExpired_RecentPassword_ShouldReturnFalse;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.ChangePassword('new_hash'); // Set recent password change
    
    // Act & Assert
    Assert.IsFalse(User.IsPasswordExpired(90));
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestIsPasswordExpired_OldPassword_ShouldReturnTrue;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    // Set password change date to 100 days ago to simulate old password
    User.PasswordChangedAt := Now - 100;
    
    // Act & Assert - password older than 90 days should be expired
    Assert.IsTrue(User.IsPasswordExpired(90), 'Password should be expired after 90 days');
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestPromoteToRole_ShouldUpdateRole;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    Assert.AreEqual(TUserRole.User, User.Role);
    
    // Act
    User.PromoteToRole(TUserRole.Manager);
    
    // Assert
    Assert.AreEqual(TUserRole.Manager, User.Role);
    
  finally
    User.Free;
  end;
end;

procedure TUserTests.TestDegradeRole_ShouldUpdateRole;
var
  User: TUser;
begin
  // Arrange
  User := CreateTestUser;
  try
    User.PromoteToRole(TUserRole.Administrator);
    Assert.AreEqual(TUserRole.Administrator, User.Role);
    
    // Act
    User.DegradeRole(TUserRole.Manager);
    
    // Assert
    Assert.AreEqual(TUserRole.Manager, User.Role);
    
  finally
    User.Free;
  end;
end;

end.
