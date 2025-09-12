unit Tests.Core.UseCases.AuthenticateUserUseCaseTests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Hash,
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository,
  Tests.Mocks.MockLogger,
  Tests.TestBase;

type
  [TestFixture]
  TAuthenticateUserUseCaseTests = class(TTestBase)
  private
    FUserRepository: TInMemoryUserRepository;
    FMockLoggerObject: TMockLogger;  // Mantener referencia al objeto concreto
    FMockLogger: ILogger;            // Interfaz para pasar al UseCase  
    FSystemConfig: TSystemConfig;
    FUseCase: TAuthenticateUserUseCase;
    
    procedure SetupTestUser(const UserName, Password: string; Role: TUserRole = TUserRole.User);
    function HashPassword(const Password: string): string;
    
  public
    [Setup]
    procedure Setup; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure TestExecute_ValidCredentials_ShouldReturnSuccess;
    
    [Test]
    procedure TestExecute_InvalidCredentials_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_NonExistentUser_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_EmptyUserName_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_EmptyPassword_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_InactiveUser_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_BlockedUser_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_ExpiredPassword_ShouldReturnFailure;
    
    [Test]
    procedure TestExecute_MultipleFailedAttempts_ShouldBlockUser;
    
    [Test]
    procedure TestExecute_SuccessfulLogin_ShouldResetFailedAttempts;
    
    [Test]
    procedure TestSimple_ShouldNotCrash;
  end;

implementation

{ TAuthenticateUserUseCaseTests }

procedure TAuthenticateUserUseCaseTests.Setup;
begin
  inherited Setup;
  
  FUserRepository := TInMemoryUserRepository.Create;
  FMockLoggerObject := TMockLogger.Create;
  FMockLogger := FMockLoggerObject;  // Asignar la interfaz
  
  // Configure system settings
  FSystemConfig.MaxLoginAttempts := 3;
  FSystemConfig.SessionTimeoutMinutes := 30;
  FSystemConfig.PasswordExpirationDays := 90;
  FSystemConfig.RequirePasswordComplexity := True;
  FSystemConfig.MinPasswordLength := 6;
  FSystemConfig.MaxPasswordLength := 128;
  FSystemConfig.EnableAuditLog := True;
  FSystemConfig.LogLevel := TLogLevel.Information;
  
  FUseCase := TAuthenticateUserUseCase.Create(FUserRepository, FMockLogger, FSystemConfig);
end;

procedure TAuthenticateUserUseCaseTests.TearDown;
begin
  // Liberar en orden inverso al de creación para evitar referencias colgantes
  if Assigned(FUseCase) then
  begin
    FUseCase.Free;
    FUseCase := nil;
  end;
  
  if Assigned(FUserRepository) then
  begin
    FUserRepository.Free;
    FUserRepository := nil;
  end;
  
  // Primero liberar la interfaz, luego el objeto
  FMockLogger := nil;
  if Assigned(FMockLoggerObject) then
  begin
    FMockLoggerObject.Free;
    FMockLoggerObject := nil;
  end;
  
  inherited TearDown;
end;

procedure TAuthenticateUserUseCaseTests.SetupTestUser(const UserName, Password: string; Role: TUserRole);
var
  User: TUser;
  PasswordHash: string;
begin
  PasswordHash := HashPassword(Password);
  User := TUser.Create(
    'TEST-USER-' + UserName + '-ID',
    UserName,
    UserName + '@test.com',
    PasswordHash,
    Role
  );
  
  try
    User.FirstName := 'Test';
    User.LastName := 'User';
    User.IsActive := True;
    User.CreatedAt := Now;
    
    FUserRepository.Save(User);
  finally
    User.Free;
  end;
end;

function TAuthenticateUserUseCaseTests.HashPassword(const Password: string): string;
begin
  Result := THashSHA2.GetHashString(Password + 'ORION_SALT_2024', SHA256);
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_ValidCredentials_ShouldReturnSuccess;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  SetupTestUser('testuser', 'testpass123');
  Request := TAuthenticateUserRequest.Create('testuser', 'testpass123', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsTrue(Response.Success, 'Authentication should succeed with valid credentials');
    Assert.IsNotNull(Response.User, 'User should be returned on successful authentication');
    Assert.IsNotEmpty(Response.SessionId, 'SessionId should be generated');
    Assert.AreEqual('testuser', Response.User.UserName);
    Assert.IsEmpty(Response.ErrorMessage);
    
    // Verify logging
    Assert.IsTrue(FMockLoggerObject.HasLogEntry(TLogLevel.Information, 'Iniciando proceso de autenticación para usuario: testuser'));
    Assert.IsTrue(FMockLoggerObject.HasLogEntry(TLogLevel.Information, 'Usuario testuser autenticado exitosamente'));
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_InvalidCredentials_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  SetupTestUser('testuser', 'correctpass');
  Request := TAuthenticateUserRequest.Create('testuser', 'wrongpass', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail with invalid credentials');
    Assert.IsNull(Response.User, 'User should not be returned on failed authentication');
    Assert.IsEmpty(Response.SessionId, 'SessionId should not be generated');
    Assert.AreEqual('Invalid credentials', Response.ErrorMessage);
    Assert.AreEqual(ERROR_INVALID_CREDENTIALS, Response.ErrorCode);
    
    // Verify logging
    Assert.IsTrue(FMockLoggerObject.HasLogEntry(TLogLevel.Warning, 'Failed authentication for user testuser'));
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_NonExistentUser_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  Request := TAuthenticateUserRequest.Create('nonexistent', 'password', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail for non-existent user');
    Assert.IsNull(Response.User, 'User should not be returned');
    Assert.AreEqual('Invalid credentials', Response.ErrorMessage);
    Assert.AreEqual(ERROR_AUTHENTICATION_FAILED, Response.ErrorCode);
    
    // Verify logging - should not reveal user doesn't exist
    Assert.IsTrue(FMockLoggerObject.HasLogEntry(TLogLevel.Warning, 'Login attempt for non-existent user: nonexistent'));
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_EmptyUserName_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  Request := TAuthenticateUserRequest.Create('', 'password', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert - TESTING WITHOUT Response.Free to isolate problem
  Assert.IsFalse(Response.Success, 'Authentication should fail with empty username');
  Assert.AreEqual('Invalid request parameters', Response.ErrorMessage);
  Assert.AreEqual(ERROR_VALIDATION_FAILED, Response.ErrorCode);
  // NOTE: Not calling Response.Free to test if that's the source of the problem
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_EmptyPassword_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  // Arrange
  Request := TAuthenticateUserRequest.Create('testuser', '', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail with empty password');
    Assert.AreEqual('Invalid request parameters', Response.ErrorMessage);
    Assert.AreEqual(ERROR_VALIDATION_FAILED, Response.ErrorCode);
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_InactiveUser_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  User: TUser;
begin
  // Arrange
  SetupTestUser('testuser', 'testpass123');
  
  // Deactivate the user
  User := FUserRepository.GetByUserName('testuser');
  try
    User.Deactivate;
    FUserRepository.Save(User);
  finally
    User.Free;
  end;
  
  Request := TAuthenticateUserRequest.Create('testuser', 'testpass123', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail for inactive user');
    Assert.AreEqual('User account is inactive', Response.ErrorMessage);
    Assert.AreEqual(ERROR_USER_BLOCKED, Response.ErrorCode);
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_BlockedUser_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  User: TUser;
begin
  // Arrange
  SetupTestUser('testuser', 'testpass123');
  
  // Block the user
  User := FUserRepository.GetByUserName('testuser');
  try
    User.Block(60); // Block for 60 minutes
    FUserRepository.Save(User);
  finally
    User.Free;
  end;
  
  Request := TAuthenticateUserRequest.Create('testuser', 'testpass123', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail for blocked user');
    Assert.Contains(Response.ErrorMessage, 'User account is blocked');
    Assert.AreEqual(ERROR_USER_BLOCKED, Response.ErrorCode);
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_ExpiredPassword_ShouldReturnFailure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  User: TUser;
begin
  // Arrange
  SetupTestUser('testuser', 'testpass123');
  
  // Set password as expired
  User := FUserRepository.GetByUserName('testuser');
  try
    User.PasswordChangedAt := Now - 100; // 100 days ago
    FUserRepository.Save(User);
  finally
    User.Free;
  end;
  
  Request := TAuthenticateUserRequest.Create('testuser', 'testpass123', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsFalse(Response.Success, 'Authentication should fail for expired password');
    Assert.AreEqual('Password has expired', Response.ErrorMessage);
    Assert.AreEqual(ERROR_AUTHENTICATION_FAILED, Response.ErrorCode);
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_MultipleFailedAttempts_ShouldBlockUser;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  I: Integer;
  User: TUser;
begin
  // Arrange
  SetupTestUser('testuser', 'correctpass');
  
  // Act - Multiple failed attempts
  for I := 1 to FSystemConfig.MaxLoginAttempts + 1 do
  begin
    Request := TAuthenticateUserRequest.Create('testuser', 'wrongpass', '127.0.0.1', 'TestClient');
    Response := FUseCase.Execute(Request);
    Response.Free;
  end;
  
  // Assert - Verify user is blocked
  User := FUserRepository.GetByUserName('testuser');
  try
    Assert.IsTrue(User.IsBlocked, 'User should be blocked after max failed attempts');
    Assert.AreEqual(FSystemConfig.MaxLoginAttempts, User.FailedLoginAttempts);
  finally
    User.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestExecute_SuccessfulLogin_ShouldResetFailedAttempts;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  User: TUser;
begin
  // Arrange
  SetupTestUser('testuser', 'testpass123');
  
  // Add some failed attempts
  User := FUserRepository.GetByUserName('testuser');
  try
    User.RecordFailedLogin(5, 30);
    User.RecordFailedLogin(5, 30);
    FUserRepository.Save(User);
  finally
    User.Free;
  end;
  
  Request := TAuthenticateUserRequest.Create('testuser', 'testpass123', '127.0.0.1', 'TestClient');
  
  // Act
  Response := FUseCase.Execute(Request);
  
  // Assert
  try
    Assert.IsTrue(Response.Success, 'Authentication should succeed with correct credentials');
    
    // Verify failed attempts are reset
    User := FUserRepository.GetByUserName('testuser');
    try
      Assert.AreEqual(0, User.FailedLoginAttempts, 'Failed attempts should be reset on successful login');
      Assert.IsTrue(User.LastLoginAt > 0, 'LastLoginAt should be updated');
    finally
      User.Free;
    end;
  finally
    Response.Free;
  end;
end;

procedure TAuthenticateUserUseCaseTests.TestSimple_ShouldNotCrash;
begin
  // Test absolutamente mínimo - si esto falla, el problema está en Setup/TearDown
  Assert.IsTrue(True, 'Basic assertion should pass');
  
  // Test que los objetos fueron creados correctamente
  Assert.IsNotNull(FUserRepository, 'UserRepository should be created');
  Assert.IsNotNull(FMockLoggerObject, 'MockLogger should be created');
  Assert.IsNotNull(FMockLogger, 'MockLogger interface should be assigned');
  Assert.IsNotNull(FUseCase, 'UseCase should be created');
end;

end.
