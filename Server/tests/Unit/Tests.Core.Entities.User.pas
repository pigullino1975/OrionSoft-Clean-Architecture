unit Tests.Core.Entities.User;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions;

[TestFixture]
type
  TUserEntityTests = class
  private
    FUser: TUser;
    
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Constructor Tests
    [Test]
    procedure Test_Constructor_WithValidData_CreatesUser;
    [Test]
    procedure Test_Constructor_WithEmptyId_RaisesException;
    [Test]
    procedure Test_Constructor_WithEmptyUserName_RaisesException;
    [Test]
    procedure Test_Constructor_WithInvalidEmail_RaisesException;
    [Test]
    procedure Test_Constructor_WithEmptyPasswordHash_RaisesException;
    
    // Password Tests
    [Test]
    procedure Test_SetPassword_WithValidPassword_SetsHashAndUpdatesTimestamp;
    [Test]
    procedure Test_SetPassword_WithEmptyPassword_RaisesException;
    [Test]
    procedure Test_SetPassword_WithShortPassword_RaisesException;
    [Test]
    procedure Test_VerifyPassword_WithCorrectPassword_ReturnsTrue;
    [Test]
    procedure Test_VerifyPassword_WithIncorrectPassword_ReturnsFalse;
    [Test]
    procedure Test_IsPasswordExpired_WithExpiredPassword_ReturnsTrue;
    [Test]
    procedure Test_IsPasswordExpired_WithValidPassword_ReturnsFalse;
    
    // Login Attempts Tests
    [Test]
    procedure Test_RecordFailedLoginAttempt_IncrementsCounter;
    [Test]
    procedure Test_RecordSuccessfulLogin_ResetsCounterAndUpdatesTimestamp;
    [Test]
    procedure Test_IsBlocked_WithMaxFailedAttempts_ReturnsTrue;
    [Test]
    procedure Test_IsBlocked_WithBlockedUntilInFuture_ReturnsTrue;
    [Test]
    procedure Test_IsBlocked_WithValidUser_ReturnsFalse;
    
    // Blocking Tests
    [Test]
    procedure Test_Block_WithValidDuration_BlocksUser;
    [Test]
    procedure Test_Block_PermanentBlock_BlocksUserIndefinitely;
    [Test]
    procedure Test_Unblock_RemovesBlock;
    [Test]
    procedure Test_IsBlockExpired_WithExpiredBlock_ReturnsTrue;
    [Test]
    procedure Test_IsBlockExpired_WithActiveBlock_ReturnsFalse;
    
    // Validation Tests
    [Test]
    procedure Test_ValidateEmail_WithValidEmail_DoesNotRaise;
    [Test]
    procedure Test_ValidateEmail_WithInvalidEmail_RaisesException;
    [Test]
    procedure Test_ValidateUserName_WithValidName_DoesNotRaise;
    [Test]
    procedure Test_ValidateUserName_WithInvalidName_RaisesException;
    
    // Property Tests
    [Test]
    procedure Test_FullName_ReturnsCorrectConcatenation;
    [Test]
    procedure Test_UpdatedAt_IsSetOnConstruction;
    [Test]
    procedure Test_CreatedAt_IsSetOnConstruction;
    
    // Role Tests
    [Test]
    procedure Test_HasRole_WithMatchingRole_ReturnsTrue;
    [Test]
    procedure Test_HasRole_WithDifferentRole_ReturnsFalse;
    [Test]
    procedure Test_IsInRole_WithAdministrator_ReturnsTrue;
    [Test]
    procedure Test_IsInRole_WithManager_ReturnsTrue;
    [Test]
    procedure Test_IsInRole_WithUser_ReturnsFalse;
  end;

implementation

{ TUserEntityTests }

procedure TUserEntityTests.Setup;
begin
  FUser := TUser.Create(
    'test-id-123',
    'testuser',
    'test@example.com',
    'hashed-password',
    TUserRole.User
  );
  FUser.FirstName := 'John';
  FUser.LastName := 'Doe';
end;

procedure TUserEntityTests.TearDown;
begin
  FreeAndNil(FUser);
end;

// Constructor Tests

procedure TUserEntityTests.Test_Constructor_WithValidData_CreatesUser;
var
  User: TUser;
begin
  User := TUser.Create('id123', 'username', 'user@test.com', 'passwordhash', TUserRole.User);
  try
    Assert.AreEqual('id123', User.Id);
    Assert.AreEqual('username', User.UserName);
    Assert.AreEqual('user@test.com', User.Email);
    Assert.AreEqual('passwordhash', User.PasswordHash);
    Assert.AreEqual(TUserRole.User, User.Role);
    Assert.IsTrue(User.IsActive);
    Assert.IsFalse(User.IsBlocked);
    Assert.AreEqual(0, User.FailedLoginAttempts);
  finally
    User.Free;
  end;
end;

procedure TUserEntityTests.Test_Constructor_WithEmptyId_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('', 'username', 'user@test.com', 'passwordhash', TUserRole.User);
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_Constructor_WithEmptyUserName_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', '', 'user@test.com', 'passwordhash', TUserRole.User);
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_Constructor_WithInvalidEmail_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', 'username', 'invalid-email', 'passwordhash', TUserRole.User);
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_Constructor_WithEmptyPasswordHash_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TUser.Create('id123', 'username', 'user@test.com', '', TUserRole.User);
    end,
    EValidationException
  );
end;

// Password Tests

procedure TUserEntityTests.Test_SetPassword_WithValidPassword_SetsHashAndUpdatesTimestamp;
var
  OldTimestamp: TDateTime;
begin
  OldTimestamp := FUser.PasswordChangedAt;
  Sleep(10); // Ensure time difference
  
  FUser.SetPassword('NewPassword123');
  
  Assert.AreNotEqual('hashed-password', FUser.PasswordHash);
  Assert.IsTrue(FUser.PasswordChangedAt > OldTimestamp);
end;

procedure TUserEntityTests.Test_SetPassword_WithEmptyPassword_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FUser.SetPassword('');
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_SetPassword_WithShortPassword_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FUser.SetPassword('123'); // Too short
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_VerifyPassword_WithCorrectPassword_ReturnsTrue;
begin
  FUser.SetPassword('TestPassword123');
  Assert.IsTrue(FUser.VerifyPassword('TestPassword123'));
end;

procedure TUserEntityTests.Test_VerifyPassword_WithIncorrectPassword_ReturnsFalse;
begin
  FUser.SetPassword('TestPassword123');
  Assert.IsFalse(FUser.VerifyPassword('WrongPassword'));
end;

procedure TUserEntityTests.Test_IsPasswordExpired_WithExpiredPassword_ReturnsTrue;
begin
  // Set password change date to 100 days ago
  FUser.SetPasswordChangedAt(Now - 100);
  Assert.IsTrue(FUser.IsPasswordExpired(90));
end;

procedure TUserEntityTests.Test_IsPasswordExpired_WithValidPassword_ReturnsFalse;
begin
  // Set password change date to yesterday
  FUser.SetPasswordChangedAt(Now - 1);
  Assert.IsFalse(FUser.IsPasswordExpired(90));
end;

// Login Attempts Tests

procedure TUserEntityTests.Test_RecordFailedLoginAttempt_IncrementsCounter;
var
  InitialCount: Integer;
begin
  InitialCount := FUser.FailedLoginAttempts;
  FUser.RecordFailedLoginAttempt;
  Assert.AreEqual(InitialCount + 1, FUser.FailedLoginAttempts);
  Assert.IsTrue(FUser.LastFailedLoginAt > 0);
end;

procedure TUserEntityTests.Test_RecordSuccessfulLogin_ResetsCounterAndUpdatesTimestamp;
begin
  // First record some failed attempts
  FUser.RecordFailedLoginAttempt;
  FUser.RecordFailedLoginAttempt;
  Assert.AreEqual(2, FUser.FailedLoginAttempts);
  
  // Then record successful login
  FUser.RecordSuccessfulLogin;
  
  Assert.AreEqual(0, FUser.FailedLoginAttempts);
  Assert.IsTrue(FUser.LastLoginAt > 0);
  Assert.AreEqual(0, FUser.LastFailedLoginAt); // Should be reset
end;

procedure TUserEntityTests.Test_IsBlocked_WithMaxFailedAttempts_ReturnsTrue;
begin
  // Record maximum failed attempts
  FUser.RecordFailedLoginAttempt;
  FUser.RecordFailedLoginAttempt;
  FUser.RecordFailedLoginAttempt;
  
  Assert.IsTrue(FUser.IsBlocked);
end;

procedure TUserEntityTests.Test_IsBlocked_WithBlockedUntilInFuture_ReturnsTrue;
begin
  FUser.Block(60); // Block for 60 minutes
  Assert.IsTrue(FUser.IsBlocked);
end;

procedure TUserEntityTests.Test_IsBlocked_WithValidUser_ReturnsFalse;
begin
  Assert.IsFalse(FUser.IsBlocked);
end;

// Blocking Tests

procedure TUserEntityTests.Test_Block_WithValidDuration_BlocksUser;
begin
  FUser.Block(30); // 30 minutes
  Assert.IsTrue(FUser.BlockedUntil > Now);
  Assert.IsTrue(FUser.IsBlocked);
end;

procedure TUserEntityTests.Test_Block_PermanentBlock_BlocksUserIndefinitely;
begin
  FUser.Block(0); // Permanent block
  Assert.IsTrue(FUser.BlockedUntil > Now + 365); // More than a year in future
  Assert.IsTrue(FUser.IsBlocked);
end;

procedure TUserEntityTests.Test_Unblock_RemovesBlock;
begin
  FUser.Block(30);
  Assert.IsTrue(FUser.IsBlocked);
  
  FUser.Unblock;
  Assert.IsFalse(FUser.IsBlocked);
  Assert.AreEqual(Double(0), Double(FUser.BlockedUntil));
  Assert.AreEqual(0, FUser.FailedLoginAttempts);
end;

procedure TUserEntityTests.Test_IsBlockExpired_WithExpiredBlock_ReturnsTrue;
begin
  FUser.SetBlockedUntil(Now - 1); // Block expired yesterday
  Assert.IsTrue(FUser.IsBlockExpired);
end;

procedure TUserEntityTests.Test_IsBlockExpired_WithActiveBlock_ReturnsFalse;
begin
  FUser.Block(60); // Block for 60 minutes
  Assert.IsFalse(FUser.IsBlockExpired);
end;

// Validation Tests

procedure TUserEntityTests.Test_ValidateEmail_WithValidEmail_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FUser.ValidateEmail('valid@email.com');
    end
  );
end;

procedure TUserEntityTests.Test_ValidateEmail_WithInvalidEmail_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FUser.ValidateEmail('invalid-email');
    end,
    EValidationException
  );
end;

procedure TUserEntityTests.Test_ValidateUserName_WithValidName_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FUser.ValidateUserName('ValidUserName');
    end
  );
end;

procedure TUserEntityTests.Test_ValidateUserName_WithInvalidName_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      FUser.ValidateUserName(''); // Empty username
    end,
    EValidationException
  );
end;

// Property Tests

procedure TUserEntityTests.Test_FullName_ReturnsCorrectConcatenation;
begin
  Assert.AreEqual('John Doe', FUser.FullName);
end;

procedure TUserEntityTests.Test_UpdatedAt_IsSetOnConstruction;
begin
  Assert.IsTrue(FUser.UpdatedAt > 0);
end;

procedure TUserEntityTests.Test_CreatedAt_IsSetOnConstruction;
begin
  Assert.IsTrue(FUser.CreatedAt > 0);
end;

// Role Tests

procedure TUserEntityTests.Test_HasRole_WithMatchingRole_ReturnsTrue;
begin
  Assert.IsTrue(FUser.HasRole(TUserRole.User));
end;

procedure TUserEntityTests.Test_HasRole_WithDifferentRole_ReturnsFalse;
begin
  Assert.IsFalse(FUser.HasRole(TUserRole.Administrator));
end;

procedure TUserEntityTests.Test_IsInRole_WithAdministrator_ReturnsTrue;
var
  AdminUser: TUser;
begin
  AdminUser := TUser.Create('admin-id', 'admin', 'admin@test.com', 'hash', TUserRole.Administrator);
  try
    Assert.IsTrue(AdminUser.IsInRole([TUserRole.Administrator, TUserRole.Manager]));
  finally
    AdminUser.Free;
  end;
end;

procedure TUserEntityTests.Test_IsInRole_WithManager_ReturnsTrue;
var
  ManagerUser: TUser;
begin
  ManagerUser := TUser.Create('mgr-id', 'manager', 'mgr@test.com', 'hash', TUserRole.Manager);
  try
    Assert.IsTrue(ManagerUser.IsInRole([TUserRole.Administrator, TUserRole.Manager]));
  finally
    ManagerUser.Free;
  end;
end;

procedure TUserEntityTests.Test_IsInRole_WithUser_ReturnsFalse;
begin
  Assert.IsFalse(FUser.IsInRole([TUserRole.Administrator, TUserRole.Manager]));
end;

initialization
  TDUnitX.RegisterTestFixture(TUserEntityTests);

end.
