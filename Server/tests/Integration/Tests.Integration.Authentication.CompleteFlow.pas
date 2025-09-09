unit Tests.Integration.Authentication.CompleteFlow;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions,
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase,
  OrionSoft.Application.Services.AuthenticationService,
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository,
  OrionSoft.Infrastructure.Services.FileLogger,
  OrionSoft.Infrastructure.CrossCutting.DI.Container;

[TestFixture]
type
  TIntegrationAuthenticationFlowTests = class
  private
    FContainer: TDIContainer;
    FUserRepository: TInMemoryUserRepository;
    FLogger: TFileLogger;
    FAuthService: TAuthenticationService;
    FTestUser: TUser;
    
    procedure SetupContainer;
    procedure CreateTestUser;
    
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_CompleteAuthentication_WithValidUser_Success;
    [Test]
    procedure Test_CompleteAuthentication_WithInvalidCredentials_Failure;
    [Test] 
    procedure Test_CompleteAuthentication_WithMultipleFailedAttempts_BlocksUser;
    [Test]
    procedure Test_CompleteAuthentication_WithExpiredPassword_ReturnsPasswordExpiredFlag;
    [Test]
    procedure Test_CompleteAuthentication_EndToEndFlow_LogsAllOperations;
  end;

implementation

uses
  System.DateUtils;

{ TIntegrationAuthenticationFlowTests }

procedure TIntegrationAuthenticationFlowTests.Setup;
begin
  FContainer := TDIContainer.Create;
  SetupContainer;
  CreateTestUser;
  
  FAuthService := FContainer.Resolve<TAuthenticationService>;
end;

procedure TIntegrationAuthenticationFlowTests.TearDown;
begin
  FTestUser.Free;
  FAuthService.Free;
  FContainer.Free;
end;

procedure TIntegrationAuthenticationFlowTests.SetupContainer;
var
  LogSettings: TLogFileSettings;
begin
  // Configurar logging para tests
  LogSettings := TLogFileSettings.Default;
  LogSettings.BaseDirectory := ExtractFilePath(ParamStr(0)) + 'TestLogs';
  LogSettings.MaxFileSize := 10 * 1024 * 1024; // 10 MB
  LogSettings.MaxFiles := 5;
  
  FLogger := TFileLogger.Create(LogSettings, TLogLevel.Debug);
  FUserRepository := TInMemoryUserRepository.Create;
  
  // Registrar servicios en el container
  FContainer.RegisterSingleton<ILogger>(
    function: ILogger
    begin
      Result := FLogger;
    end
  );
  
  FContainer.RegisterSingleton<IUserRepository>(
    function: IUserRepository
    begin
      Result := FUserRepository;
    end
  );
  
  FContainer.RegisterSingleton<TAuthenticationService>(
    function: TAuthenticationService
    begin
      Result := TAuthenticationService.Create(
        FContainer.ResolveUserRepository,
        FContainer.ResolveLogger
      );
    end
  );
end;

procedure TIntegrationAuthenticationFlowTests.CreateTestUser;
begin
  FTestUser := TUser.Create(
    'test-user-id-123',
    'testuser',
    'testuser@example.com',
    '',
    TUserRole.User
  );
  
  FTestUser.FirstName := 'Test';
  FTestUser.LastName := 'User';
  FTestUser.SetPassword('TestPassword123!');
  FTestUser.IsActive := True;
  
  // Agregar usuario al repositorio
  FUserRepository.Save(FTestUser);
end;

procedure TIntegrationAuthenticationFlowTests.Test_CompleteAuthentication_WithValidUser_Success;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  UserFromRepo: TUser;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123!';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'Integration Test';
  Request.SessionId := 'test-session-123';
  
  // Act
  Response := FAuthService.AuthenticateUser(Request);
  
  // Assert
  Assert.IsTrue(Response.IsSuccess, 'Authentication should succeed with valid credentials');
  Assert.AreEqual('test-user-id-123', Response.UserId, 'Should return correct user ID');
  Assert.AreEqual('testuser', Response.UserName, 'Should return correct username');
  Assert.AreEqual(TUserRole.User, Response.UserRole, 'Should return correct user role');
  Assert.IsFalse(Response.IsPasswordExpired, 'Password should not be expired for new user');
  Assert.IsNotEmpty(Response.SessionId, 'Should return a session ID');
  
  // Verificar que el usuario fue actualizado en el repositorio
  UserFromRepo := FUserRepository.GetById('test-user-id-123');
  try
    Assert.IsTrue(UserFromRepo.LastLoginAt > 0, 'Last login time should be updated');
    Assert.AreEqual(0, UserFromRepo.FailedLoginAttempts, 'Failed attempts should be reset');
  finally
    UserFromRepo.Free;
  end;
end;

procedure TIntegrationAuthenticationFlowTests.Test_CompleteAuthentication_WithInvalidCredentials_Failure;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  UserFromRepo: TUser;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'Integration Test';
  
  // Act
  Response := FAuthService.AuthenticateUser(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess, 'Authentication should fail with invalid password');
  Assert.IsEmpty(Response.UserId, 'Should not return user ID on failure');
  Assert.IsEmpty(Response.SessionId, 'Should not return session ID on failure');
  Assert.IsNotEmpty(Response.ErrorMessage, 'Should return error message');
  
  // Verificar que los intentos fallidos fueron incrementados
  UserFromRepo := FUserRepository.GetById('test-user-id-123');
  try
    Assert.AreEqual(1, UserFromRepo.FailedLoginAttempts, 'Failed attempts should be incremented');
    Assert.IsTrue(UserFromRepo.LastFailedLoginAt > 0, 'Last failed login time should be set');
  finally
    UserFromRepo.Free;
  end;
end;

procedure TIntegrationAuthenticationFlowTests.Test_CompleteAuthentication_WithMultipleFailedAttempts_BlocksUser;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  I: Integer;
  UserFromRepo: TUser;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := 'WrongPassword';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'Integration Test';
  
  // Act - Realizar múltiples intentos fallidos
  for I := 1 to 3 do
  begin
    Response := FAuthService.AuthenticateUser(Request);
    Assert.IsFalse(Response.IsSuccess, Format('Attempt %d should fail', [I]));
  end;
  
  // Intentar con credenciales correctas después del bloqueo
  Request.Password := 'TestPassword123!';
  Response := FAuthService.AuthenticateUser(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess, 'Authentication should fail even with correct password when user is blocked');
  Assert.IsTrue(Pos('blocked', LowerCase(Response.ErrorMessage)) > 0, 'Error message should indicate user is blocked');
  
  // Verificar que el usuario está bloqueado en el repositorio
  UserFromRepo := FUserRepository.GetById('test-user-id-123');
  try
    Assert.IsTrue(UserFromRepo.IsBlocked, 'User should be blocked after max failed attempts');
    Assert.IsTrue(UserFromRepo.BlockedUntil > Now, 'User should have a future block expiration time');
  finally
    UserFromRepo.Free;
  end;
end;

procedure TIntegrationAuthenticationFlowTests.Test_CompleteAuthentication_WithExpiredPassword_ReturnsPasswordExpiredFlag;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  UserFromRepo: TUser;
begin
  // Arrange - Configurar usuario con contraseña expirada
  UserFromRepo := FUserRepository.GetById('test-user-id-123');
  try
    UserFromRepo.SetPasswordChangedAt(Now - 100); // 100 días atrás
    FUserRepository.Save(UserFromRepo);
  finally
    UserFromRepo.Free;
  end;
  
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123!';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'Integration Test';
  
  // Act
  Response := FAuthService.AuthenticateUser(Request);
  
  // Assert
  Assert.IsFalse(Response.IsSuccess, 'Authentication should fail with expired password');
  Assert.IsTrue(Response.IsPasswordExpired, 'Should indicate password is expired');
  Assert.IsNotEmpty(Response.ErrorMessage, 'Should return error message about password expiration');
end;

procedure TIntegrationAuthenticationFlowTests.Test_CompleteAuthentication_EndToEndFlow_LogsAllOperations;
var
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
  LogEntries: Integer;
begin
  // Arrange
  Request.UserName := 'testuser';
  Request.Password := 'TestPassword123!';
  Request.RemoteIP := '127.0.0.1';
  Request.UserAgent := 'Integration Test';
  
  // Obtener conteo inicial de logs
  LogEntries := FLogger.GetLogEntriesCount;
  
  // Act
  Response := FAuthService.AuthenticateUser(Request);
  
  // Assert
  Assert.IsTrue(Response.IsSuccess, 'Authentication should succeed');
  
  // Verificar que se generaron logs durante el proceso
  Assert.IsTrue(FLogger.GetLogEntriesCount > LogEntries, 'Should have generated log entries during authentication');
  
  // Verificar tipos específicos de logs
  Assert.IsTrue(FLogger.HasLogEntry(TLogLevel.Information, 'Authentication SUCCESS'), 
    'Should log successful authentication');
  Assert.IsTrue(FLogger.HasLogEntry(TLogLevel.Debug, 'Authentication attempt'), 
    'Should log debug information about the attempt');
end;

initialization
  TDUnitX.RegisterTestFixture(TIntegrationAuthenticationFlowTests);

end.
