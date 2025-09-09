unit Tests.Core.UseCases.Authentication;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions,
  Tests.Mocks.UserRepository,
  Tests.Mocks.Logger;

[TestFixture]
type
  TAuthenticateUserUseCaseTests = class
  private
    FUseCase: TAuthenticateUserUseCase;
    FMockRepository: TMockUserRepository;
    FMockLogger: TMockLogger;
    
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    // Success Cases
    [Test]
    procedure Test_Execute_WithValidCredentials_ReturnsSuccessResult;
    [Test]
    procedure Test_Execute_WithValidCredentials_LogsSuccessfulAuthentication;
    [Test]
    procedure Test_Execute_WithValidCredentials_UpdatesLastLoginTime;
    [Test]
    procedure Test_Execute_WithValidCredentials_ResetsFailedAttempts;
    
    // Failure Cases
    [Test]
    procedure Test_Execute_WithInvalidUserName_ReturnsFailureResult;
    [Test]
    procedure Test_Execute_WithInvalidPassword_ReturnsFailureResult;
    [Test]
    procedure Test_Execute_WithInvalidPassword_IncrementsFailedAttempts;
    [Test]
    procedure Test_Execute_WithBlockedUser_ReturnsFailureResult;
    [Test]
    procedure Test_Execute_WithInactiveUser_ReturnsFailureResult;
    [Test]
    procedure Test_Execute_WithExpiredPassword_ReturnsFailureResult;
    
    // Edge Cases
    [Test]
    procedure Test_Execute_WithEmptyUserName_RaisesException;
    [Test]
    procedure Test_Execute_WithEmptyPassword_RaisesException;
    [Test]
    procedure Test_Execute_WithNullParameters_RaisesException;
    [Test]
    procedure Test_Execute_WithRepositoryFailure_RaisesException;
    
    // Blocking Logic
    [Test]
    procedure Test_Execute_WithMaxFailedAttempts_BlocksUser;
    [Test]
    procedure Test_Execute_WithExpiredBlock_AllowsLogin;
    [Test]
    procedure Test_Execute_BlockingDuration_IncreasesWithRepeatedFailures;
    
    // Logging Tests
    [Test]
    procedure Test_Execute_LogsAuthenticationAttempts;
    [Test]
    procedure Test_Execute_LogsUserBlocking;
    [Test]
    procedure Test_Execute_LogsPasswordExpiration;
  end;

implementation

{ TAuthenticateUserUseCaseTests }

procedure TAuthenticateUserUseCaseTests.Setup;
begin
  FMockRepository := TMockUserRepository.Create;
  FMockLogger := TMockLogger.Create;
  FUseCase := TAuthenticateUserUseCase.Create(FMockRepository, FMockLogger);
end;

procedure TAuthenticateUserUseCaseTests.TearDown;
begin
  FUseCase.Free;
  FMockRepository.Free;
  FMockLogger.Free;
end;

// Success Cases

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithValidCredentials_ReturnsSuccessResult;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'TestAgent';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(Response.IsSuccess);
  Assert.AreEqual('user-id', Response.UserId);
  Assert.AreEqual('testuser', Response.UserName);
  Assert.AreEqual(TUserRole.User, Response.UserRole);
  Assert.IsEmpty(Response.ErrorMessage);
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithValidCredentials_LogsSuccessfulAuthentication;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(FMockLogger.HasLogEntry(TLogLevel.Information, 'Authentication SUCCESS'));
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithValidCredentials_UpdatesLastLoginTime;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  OriginalLastLogin: TDateTime;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  OriginalLastLogin := User.LastLoginAt;
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  Sleep(10); // Ensure time difference
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert - verify that the user in repository was updated
  var UpdatedUser := FMockRepository.GetByUserName('testuser');
  Assert.IsTrue(UpdatedUser.LastLoginAt > OriginalLastLogin);
  User.Free;
  UpdatedUser.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithValidCredentials_ResetsFailedAttempts;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.RecordFailedLoginAttempt;
  User.RecordFailedLoginAttempt;
  Assert.AreEqual(2, User.FailedLoginAttempts);
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert
  var UpdatedUser := FMockRepository.GetByUserName('testuser');
  Assert.AreEqual(0, UpdatedUser.FailedLoginAttempts);
  User.Free;
  UpdatedUser.Free;
end;

// Failure Cases

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithInvalidUserName_ReturnsFailureResult;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  Request.UserName := 'nonexistentuser';
  Request.Password := 'password';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess);
  Assert.IsNotEmpty(Response.ErrorMessage);
  Assert.AreEqual('', Response.UserId);
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithInvalidPassword_ReturnsFailureResult;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('CorrectPassword');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess);
  Assert.IsNotEmpty(Response.ErrorMessage);
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithInvalidPassword_IncrementsFailedAttempts;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  OriginalFailedAttempts: Integer;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('CorrectPassword');
  OriginalFailedAttempts := User.FailedLoginAttempts;
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert
  var UpdatedUser := FMockRepository.GetByUserName('testuser');
  Assert.AreEqual(OriginalFailedAttempts + 1, UpdatedUser.FailedLoginAttempts);
  User.Free;
  UpdatedUser.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithBlockedUser_ReturnsFailureResult;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.Block(60); // Block for 60 minutes
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess);
  Assert.IsNotEmpty(Response.ErrorMessage);
  Assert.IsTrue(Pos('blocked', Response.ErrorMessage) > 0);
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithInactiveUser_ReturnsFailureResult;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.IsActive := False;
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess);
  Assert.IsNotEmpty(Response.ErrorMessage);
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithExpiredPassword_ReturnsFailureResult;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.SetPasswordChangedAt(Now - 100); // 100 days ago
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess);
  Assert.IsTrue(Response.IsPasswordExpired);
  User.Free;
end;

// Edge Cases

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithEmptyUserName_RaisesException;
var
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  Request.UserName := '';
  Request.Password := 'password';
  
  // Act & Assert
  Assert.WillRaise(
    procedure
    begin
      FUseCase.Execute(Request);
    end,
    EValidationException
  );
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithEmptyPassword_RaisesException;
var
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := '';
  
  // Act & Assert
  Assert.WillRaise(
    procedure
    begin
      FUseCase.Execute(Request);
    end,
    EValidationException
  );
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithNullParameters_RaisesException;
var
  Request: TAuthenticateUserRequest;
begin
  // Arrange - leave request empty (default values)
  FillChar(Request, SizeOf(Request), 0);
  
  // Act & Assert
  Assert.WillRaise(
    procedure
    begin
      FUseCase.Execute(Request);
    end,
    EValidationException
  );
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithRepositoryFailure_RaisesException;
var
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  FMockRepository.SetShouldFailOnNextOperation(True);
  Request.UserName := 'testuser';
  Request.Password := 'password';
  
  // Act & Assert
  Assert.WillRaise(
    procedure
    begin
      FUseCase.Execute(Request);
    end,
    Exception
  );
end;

// Blocking Logic

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithMaxFailedAttempts_BlocksUser;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('CorrectPassword');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  
  // Act - make multiple failed attempts
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  
  // Assert
  var UpdatedUser := FMockRepository.GetByUserName('testuser');
  Assert.IsTrue(UpdatedUser.IsBlocked);
  User.Free;
  UpdatedUser.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_WithExpiredBlock_AllowsLogin;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.SetBlockedUntil(Now - 1); // Block expired yesterday
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(Response.IsSuccess);
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_BlockingDuration_IncreasesWithRepeatedFailures;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
  FirstBlockTime, SecondBlockTime: TDateTime;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('CorrectPassword');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  
  // Act - First round of failures
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  
  var UpdatedUser := FMockRepository.GetByUserName('testuser');
  FirstBlockTime := UpdatedUser.BlockedUntil;
  UpdatedUser.Free;
  
  // Unblock and try again
  User.Unblock;
  FMockRepository.Save(User);
  
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  
  UpdatedUser := FMockRepository.GetByUserName('testuser');
  SecondBlockTime := UpdatedUser.BlockedUntil;
  
  // Assert - second block should be longer
  Assert.IsTrue(SecondBlockTime > FirstBlockTime);
  User.Free;
  UpdatedUser.Free;
end;

// Logging Tests

procedure TAuthenticateUserUseCaseTests.Test_Execute_LogsAuthenticationAttempts;
var
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := 'password';
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(FMockLogger.GetLogEntriesCount > 0);
  Assert.IsTrue(FMockLogger.HasLogEntry(TLogLevel.Warning, 'Authentication FAILED'));
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_LogsUserBlocking;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('CorrectPassword');
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  
  // Act - Trigger blocking
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(FMockLogger.HasLogEntry(TLogLevel.Warning, 'User blocked'));
  User.Free;
end;

procedure TAuthenticateUserUseCaseTests.Test_Execute_LogsPasswordExpiration;
var
  User: TUser;
  Request: TAuthenticateUserRequest;
begin
  // Arrange
  User := TUser.Create('user-id', 'testuser', 'test@example.com', 'hashedpass', TUserRole.User);
  User.SetPassword('TestPassword123');
  User.SetPasswordChangedAt(Now - 100); // Expired password
  FMockRepository.AddTestUser(User);
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123';
  
  // Act
  FUseCase.Execute(Request);
  
  // Assert
  Assert.IsTrue(FMockLogger.HasLogEntry(TLogLevel.Warning, 'password expired'));
  User.Free;
end;

initialization
  TDUnitX.RegisterTestFixture(TAuthenticateUserUseCaseTests);

end.
