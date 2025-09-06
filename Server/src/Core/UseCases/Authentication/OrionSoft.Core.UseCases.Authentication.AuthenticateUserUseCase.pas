unit OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase;

{*
  Use Case para autenticación de usuarios
  Implementa las reglas de negocio para el login de usuarios
*}

interface

uses
  System.SysUtils,
  System.Hash,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions;

type
  // Request para autenticación
  TAuthenticateUserRequest = record
    UserName: string;
    Password: string;
    ClientIP: string;
    UserAgent: string;
    
    constructor Create(const AUserName, APassword: string; const AClientIP: string = ''; const AUserAgent: string = '');
  end;

  // Response de autenticación
  TAuthenticateUserResponse = record
    Success: Boolean;
    User: TUser;
    SessionId: string;
    ErrorMessage: string;
    ErrorCode: string;
    
    class function CreateSuccess(AUser: TUser; const ASessionId: string): TAuthenticateUserResponse; static;
    class function CreateFailure(const AErrorMessage, AErrorCode: string): TAuthenticateUserResponse; static;
    
    procedure Free;
  end;

  // Use Case principal
  TAuthenticateUserUseCase = class
  private
    FUserRepository: IUserRepository;
    FLogger: ILogger;
    FSystemConfig: TSystemConfig;
    
    function ValidateRequest(const Request: TAuthenticateUserRequest): Boolean;
    function HashPassword(const Password: string): string;
    function GenerateSessionId: string;
    procedure LogAuthenticationAttempt(const UserName: string; Success: Boolean; const Details: string = '');
  public
    constructor Create(UserRepository: IUserRepository; Logger: ILogger; const SystemConfig: TSystemConfig);
    
    function Execute(const Request: TAuthenticateUserRequest): TAuthenticateUserResponse;
  end;

implementation

uses
  System.DateUtils;

{ TAuthenticateUserRequest }

constructor TAuthenticateUserRequest.Create(const AUserName, APassword, AClientIP, AUserAgent: string);
begin
  UserName := AUserName;
  Password := APassword;
  ClientIP := AClientIP;
  UserAgent := AUserAgent;
end;

{ TAuthenticateUserResponse }

class function TAuthenticateUserResponse.CreateSuccess(AUser: TUser; const ASessionId: string): TAuthenticateUserResponse;
begin
  Result.Success := True;
  Result.User := AUser;
  Result.SessionId := ASessionId;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
end;

class function TAuthenticateUserResponse.CreateFailure(const AErrorMessage, AErrorCode: string): TAuthenticateUserResponse;
begin
  Result.Success := False;
  Result.User := nil;
  Result.SessionId := '';
  Result.ErrorMessage := AErrorMessage;
  Result.ErrorCode := AErrorCode;
end;

procedure TAuthenticateUserResponse.Free;
begin
  if Assigned(User) then
    User.Free;
end;

{ TAuthenticateUserUseCase }

constructor TAuthenticateUserUseCase.Create(UserRepository: IUserRepository; Logger: ILogger; const SystemConfig: TSystemConfig);
begin
  if not Assigned(UserRepository) then
    raise EArgumentException.Create('UserRepository cannot be nil');
    
  if not Assigned(Logger) then
    raise EArgumentException.Create('Logger cannot be nil');
  
  FUserRepository := UserRepository;
  FLogger := Logger;
  FSystemConfig := SystemConfig;
end;

function TAuthenticateUserUseCase.Execute(const Request: TAuthenticateUserRequest): TAuthenticateUserResponse;
var
  User: TUser;
  PasswordHash: string;
  SessionId: string;
  Context: TLogContext;
begin
  Context := CreateLogContext('Authentication', 'AuthenticateUser');
  
  try
    FLogger.Info('Iniciando proceso de autenticación para usuario: ' + Request.UserName, Context);
    
    // Validar request
    if not ValidateRequest(Request) then
    begin
      Result := TAuthenticateUserResponse.CreateFailure('Invalid request parameters', ERROR_VALIDATION_FAILED);
      LogAuthenticationAttempt(Request.UserName, False, 'Invalid request parameters');
      Exit;
    end;
    
    // Buscar usuario
    User := FUserRepository.GetByUserName(Request.UserName);
    if not Assigned(User) then
    begin
      Result := TAuthenticateUserResponse.CreateFailure('Invalid credentials', ERROR_AUTHENTICATION_FAILED);
      LogAuthenticationAttempt(Request.UserName, False, 'User not found');
      
      // Log para auditoría pero sin revelar que el usuario no existe
      FLogger.Warning('Login attempt for non-existent user: ' + Request.UserName, Context);
      Exit;
    end;
    
    try
      // Verificar si el usuario puede hacer login
      if not User.CanLogin then
      begin
        var reason := 'User cannot login';
        if not User.IsActive then
          reason := 'User account is inactive'
        else if User.IsBlocked then
        begin
          if User.BlockedUntil > 0 then
            reason := Format('User account is blocked until %s', [DateTimeToStr(User.BlockedUntil)])
          else
            reason := 'User account is permanently blocked';
        end;
        
        Result := TAuthenticateUserResponse.CreateFailure(reason, ERROR_USER_BLOCKED);
        LogAuthenticationAttempt(Request.UserName, False, reason);
        Exit;
      end;
      
      // Verificar contraseña
      PasswordHash := HashPassword(Request.Password);
      if User.PasswordHash <> PasswordHash then
      begin
        // Registrar intento fallido
        User.RecordFailedLogin(FSystemConfig.MaxLoginAttempts, 30); // Block for 30 minutes
        FUserRepository.Save(User);
        
        Result := TAuthenticateUserResponse.CreateFailure('Invalid credentials', ERROR_INVALID_CREDENTIALS);
        LogAuthenticationAttempt(Request.UserName, False, Format('Invalid password. Failed attempts: %d', [User.FailedLoginAttempts]));
        Exit;
      end;
      
      // Verificar si la contraseña ha expirado (opcional)
      if User.IsPasswordExpired(90) then // 90 días
      begin
        Result := TAuthenticateUserResponse.CreateFailure('Password has expired', ERROR_AUTHENTICATION_FAILED);
        LogAuthenticationAttempt(Request.UserName, False, 'Password expired');
        Exit;
      end;
      
      // Autenticación exitosa
      SessionId := GenerateSessionId;
      User.RecordSuccessfulLogin;
      FUserRepository.Save(User);
      
      Result := TAuthenticateUserResponse.CreateSuccess(User, SessionId);
      LogAuthenticationAttempt(Request.UserName, True, Format('Session: %s, Role: %s', [SessionId, UserRoleToString(User.Role)]));
      
      FLogger.Info(Format('Usuario %s autenticado exitosamente. SessionId: %s', [Request.UserName, SessionId]), Context);
      
    except
      on E: Exception do
      begin
        Result := TAuthenticateUserResponse.CreateFailure('Authentication error', ERROR_AUTHENTICATION_FAILED);
        FLogger.Error('Error during authentication process', E, Context);
        User.Free;
        raise;
      end;
    end;
    
  except
    on E: EValidationException do
    begin
      Result := TAuthenticateUserResponse.CreateFailure(E.Message, E.ErrorCode);
      FLogger.Warning('Validation error during authentication: ' + E.Message, Context);
    end;
    on E: EBusinessRuleException do
    begin
      Result := TAuthenticateUserResponse.CreateFailure(E.Message, E.ErrorCode);
      FLogger.Warning('Business rule violation during authentication: ' + E.Message, Context);
    end;
    on E: Exception do
    begin
      Result := TAuthenticateUserResponse.CreateFailure('Internal server error', 'AUTH_500');
      FLogger.Error('Unexpected error during authentication', E, Context);
    end;
  end;
end;

function TAuthenticateUserUseCase.ValidateRequest(const Request: TAuthenticateUserRequest): Boolean;
begin
  Result := True;
  
  if Trim(Request.UserName) = '' then
  begin
    FLogger.Warning('Authentication request with empty username');
    Result := False;
  end;
  
  if Trim(Request.Password) = '' then
  begin
    FLogger.Warning('Authentication request with empty password for user: ' + Request.UserName);
    Result := False;
  end;
  
  if Length(Request.UserName) > MAX_USERNAME_LENGTH then
  begin
    FLogger.Warning(Format('Username exceeds maximum length (%d) for user: %s', [MAX_USERNAME_LENGTH, Request.UserName]));
    Result := False;
  end;
  
  if Length(Request.Password) > MAX_PASSWORD_LENGTH then
  begin
    FLogger.Warning('Password exceeds maximum length for user: ' + Request.UserName);
    Result := False;
  end;
end;

function TAuthenticateUserUseCase.HashPassword(const Password: string): string;
begin
  // En una implementación real, usar un algoritmo más seguro como bcrypt, scrypt, o Argon2
  // Por simplicidad, usamos SHA256 con salt
  Result := THashSHA2.GetHashString(Password + 'ORION_SALT_2024', SHA256);
end;

function TAuthenticateUserUseCase.GenerateSessionId: string;
begin
  // Generar un ID de sesión único
  Result := THashSHA2.GetHashString(
    FormatDateTime('yyyymmddhhnnsszzz', Now) + 
    IntToStr(Random(MaxInt)) + 
    'SESSION_SALT', 
    SHA256
  );
end;

procedure TAuthenticateUserUseCase.LogAuthenticationAttempt(const UserName: string; Success: Boolean; const Details: string);
begin
  FLogger.LogAuthentication(UserName, Success);
  
  if Success then
    FLogger.Info(Format('Successful authentication for user %s. %s', [UserName, Details]))
  else
    FLogger.Warning(Format('Failed authentication for user %s. %s', [UserName, Details]));
end;

end.
