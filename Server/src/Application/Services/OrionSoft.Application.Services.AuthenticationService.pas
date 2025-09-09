unit OrionSoft.Application.Services.AuthenticationService;

{*
  Servicio de aplicación para la gestión de autenticación
  Orquesta los casos de uso relacionados con autenticación y autorización
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions,
  OrionSoft.Infrastructure.CrossCutting.DI.Container;

type
  // DTOs para entrada
  TLoginRequest = record
    UserName: string;
    Password: string;
    RememberMe: Boolean;
    ClientInfo: string;
    
    constructor Create(const AUserName, APassword: string; ARememberMe: Boolean = False; const AClientInfo: string = '');
  end;

  TLogoutRequest = record
    SessionId: string;
    UserId: string;
    
    constructor Create(const ASessionId, AUserId: string);
  end;

  TChangePasswordRequest = record
    UserId: string;
    CurrentPassword: string;
    NewPassword: string;
    ConfirmPassword: string;
    
    constructor Create(const AUserId, ACurrentPassword, ANewPassword, AConfirmPassword: string);
  end;

  // DTOs para salida
  TAuthenticationResult = record
    Success: Boolean;
    User: TUser;
    SessionId: string;
    ErrorMessage: string;
    ErrorCode: string;
    RequiresPasswordChange: Boolean;
    
    class function CreateSuccess(AUser: TUser; const ASessionId: string; ARequiresPasswordChange: Boolean = False): TAuthenticationResult; static;
    class function CreateFailure(const AErrorMessage, AErrorCode: string): TAuthenticationResult; static;
    
    procedure Free;
  end;

  TOperationResult = record
    Success: Boolean;
    Message: string;
    ErrorCode: string;
    
    class function CreateSuccess(const AMessage: string = ''): TOperationResult; static;
    class function CreateFailure(const AMessage, AErrorCode: string): TOperationResult; static;
  end;

  // Servicio principal
  TAuthenticationService = class
  private
    FContainer: TDIContainer;
    FLogger: ILogger;
    FSystemConfig: TSystemConfig;
    FSessions: TDictionary<string, string>; // SessionId -> UserId
    
    function GetUserRepository: IUserRepository;
    function CreateAuthenticateUserUseCase: TAuthenticateUserUseCase;
    function IsValidPassword(const Password: string): Boolean;
    function GenerateSessionId: string;
    procedure InitializeSystemConfig;
    
  public
    constructor Create(Container: TDIContainer);
    destructor Destroy; override;
    
    // Operaciones principales
    function Login(const Request: TLoginRequest): TAuthenticationResult;
    function Logout(const Request: TLogoutRequest): TOperationResult;
    function ChangePassword(const Request: TChangePasswordRequest): TOperationResult;
    function ValidateSession(const SessionId: string): Boolean;
    function GetUserBySessionId(const SessionId: string): TUser;
    
    // Operaciones de gestión de usuarios (para administradores)
    function CreateUser(const UserName, Email, Password: string; Role: TUserRole): TOperationResult;
    function ActivateUser(const UserId: string): TOperationResult;
    function DeactivateUser(const UserId: string): TOperationResult;
    function ResetPassword(const UserId, NewPassword: string): TOperationResult;
    function UnblockUser(const UserId: string): TOperationResult;
    
    // Consultas
    function GetActiveUsers: TObjectList<TUser>;
    function GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
    function GetUserStatistics: TUserStatistics;
    
    // Configuración
    procedure UpdateSystemConfig(const Config: TSystemConfig);
    function GetSystemConfig: TSystemConfig;
  end;

implementation

uses
  System.Hash,
  System.DateUtils,
  System.StrUtils,
  Winapi.Windows;

{ TLoginRequest }

constructor TLoginRequest.Create(const AUserName, APassword: string; ARememberMe: Boolean; const AClientInfo: string);
begin
  UserName := AUserName;
  Password := APassword;
  RememberMe := ARememberMe;
  ClientInfo := AClientInfo;
end;

{ TLogoutRequest }

constructor TLogoutRequest.Create(const ASessionId, AUserId: string);
begin
  SessionId := ASessionId;
  UserId := AUserId;
end;

{ TChangePasswordRequest }

constructor TChangePasswordRequest.Create(const AUserId, ACurrentPassword, ANewPassword, AConfirmPassword: string);
begin
  UserId := AUserId;
  CurrentPassword := ACurrentPassword;
  NewPassword := ANewPassword;
  ConfirmPassword := AConfirmPassword;
end;

{ TAuthenticationResult }

class function TAuthenticationResult.CreateSuccess(AUser: TUser; const ASessionId: string; ARequiresPasswordChange: Boolean): TAuthenticationResult;
begin
  Result.Success := True;
  Result.User := AUser;
  Result.SessionId := ASessionId;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
  Result.RequiresPasswordChange := ARequiresPasswordChange;
end;

class function TAuthenticationResult.CreateFailure(const AErrorMessage, AErrorCode: string): TAuthenticationResult;
begin
  Result.Success := False;
  Result.User := nil;
  Result.SessionId := '';
  Result.ErrorMessage := AErrorMessage;
  Result.ErrorCode := AErrorCode;
  Result.RequiresPasswordChange := False;
end;

procedure TAuthenticationResult.Free;
begin
  if Assigned(User) then
    User.Free;
end;

{ TOperationResult }

class function TOperationResult.CreateSuccess(const AMessage: string): TOperationResult;
begin
  Result.Success := True;
  Result.Message := AMessage;
  Result.ErrorCode := '';
end;

class function TOperationResult.CreateFailure(const AMessage, AErrorCode: string): TOperationResult;
begin
  Result.Success := False;
  Result.Message := AMessage;
  Result.ErrorCode := AErrorCode;
end;

{ TAuthenticationService }

constructor TAuthenticationService.Create(Container: TDIContainer);
begin
  inherited Create;
  
  if not Assigned(Container) then
    raise EArgumentException.Create('Container cannot be nil');
    
  FContainer := Container;
  FLogger := FContainer.ResolveLogger();
  FSessions := TDictionary<string, string>.Create;
  
  InitializeSystemConfig;
  
  FLogger.Info('AuthenticationService initialized', CreateLogContext('AuthenticationService', 'Initialize'));
end;

destructor TAuthenticationService.Destroy;
begin
  FSessions.Free;
  inherited Destroy;
end;

function TAuthenticationService.GetUserRepository: IUserRepository;
begin
  Result := FContainer.ResolveUserRepository();
end;

function TAuthenticationService.CreateAuthenticateUserUseCase: TAuthenticateUserUseCase;
begin
  Result := TAuthenticateUserUseCase.Create(
    GetUserRepository,
    FLogger,
    FSystemConfig
  );
end;

procedure TAuthenticationService.InitializeSystemConfig;
begin
  // Configuración por defecto del sistema
  FSystemConfig.MaxLoginAttempts := 5;
  FSystemConfig.SessionTimeoutMinutes := 30;
  FSystemConfig.PasswordExpirationDays := 90;
  FSystemConfig.RequirePasswordComplexity := True;
  FSystemConfig.MinPasswordLength := 8;
  FSystemConfig.MaxPasswordLength := 128;
  FSystemConfig.EnableAuditLog := True;
  FSystemConfig.LogLevel := TLogLevel.Information;
end;

function TAuthenticationService.Login(const Request: TLoginRequest): TAuthenticationResult;
var
  UseCase: TAuthenticateUserUseCase;
  AuthRequest: TAuthenticateUserRequest;
  AuthResponse: TAuthenticateUserResponse;
  SessionId: string;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'Login');
  Context.UserId := Request.UserName; // Para tracking
  
  try
    FLogger.Info('Iniciando proceso de login para usuario: ' + Request.UserName, Context);
    
    // Crear y ejecutar el caso de uso
    UseCase := CreateAuthenticateUserUseCase;
    try
      AuthRequest := TAuthenticateUserRequest.Create(
        Request.UserName,
        Request.Password,
        '', // ClientIP - se podría obtener del contexto
        Request.ClientInfo
      );
      
      AuthResponse := UseCase.Execute(AuthRequest);
      
      if AuthResponse.Success then
      begin
        // Generar sesión
        SessionId := GenerateSessionId;
        FSessions.AddOrSetValue(SessionId, AuthResponse.User.Id);
        
        // Verificar si requiere cambio de contraseña
        var RequiresPasswordChange := AuthResponse.User.IsPasswordExpired(FSystemConfig.PasswordExpirationDays);
        
        Result := TAuthenticationResult.CreateSuccess(
          AuthResponse.User,
          SessionId,
          RequiresPasswordChange
        );
        
        FLogger.Info(Format('Login exitoso para usuario %s. SessionId: %s', [Request.UserName, SessionId]), Context);
      end
      else
      begin
        Result := TAuthenticationResult.CreateFailure(
          AuthResponse.ErrorMessage,
          AuthResponse.ErrorCode
        );
        
        FLogger.Warning(Format('Login fallido para usuario %s: %s', [Request.UserName, AuthResponse.ErrorMessage]), Context);
      end;
      
    finally
      UseCase.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TAuthenticationResult.CreateFailure('Internal server error', 'LOGIN_500');
      FLogger.Error('Error during login process', E, Context);
    end;
  end;
end;

function TAuthenticationService.Logout(const Request: TLogoutRequest): TOperationResult;
var
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'Logout');
  Context.UserId := Request.UserId;
  
  try
    FLogger.Info('Iniciando proceso de logout', Context);
    
    if FSessions.ContainsKey(Request.SessionId) then
    begin
      FSessions.Remove(Request.SessionId);
      Result := TOperationResult.CreateSuccess('Logout successful');
      FLogger.Info('Logout exitoso', Context);
    end
    else
    begin
      Result := TOperationResult.CreateFailure('Invalid session', 'INVALID_SESSION');
      FLogger.Warning('Intento de logout con sesión inválida: ' + Request.SessionId, Context);
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'LOGOUT_500');
      FLogger.Error('Error during logout process', E, Context);
    end;
  end;
end;

function TAuthenticationService.ChangePassword(const Request: TChangePasswordRequest): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'ChangePassword');
  Context.UserId := Request.UserId;
  
  try
    FLogger.Info('Iniciando cambio de contraseña', Context);
    
    // Validaciones básicas
    if Request.NewPassword <> Request.ConfirmPassword then
    begin
      Result := TOperationResult.CreateFailure('Password confirmation does not match', 'PASSWORD_MISMATCH');
      Exit;
    end;
    
    if not IsValidPassword(Request.NewPassword) then
    begin
      Result := TOperationResult.CreateFailure('Password does not meet complexity requirements', 'PASSWORD_COMPLEXITY');
      Exit;
    end;
    
    // Obtener usuario
    UserRepo := GetUserRepository;
    User := UserRepo.GetById(Request.UserId);
    if not Assigned(User) then
    begin
      Result := TOperationResult.CreateFailure('User not found', 'USER_NOT_FOUND');
      Exit;
    end;
    
    try
      // Verificar contraseña actual
      var CurrentPasswordHash := THashSHA2.GetHashString(Request.CurrentPassword + 'ORION_SALT_2024', SHA256);
      if User.PasswordHash <> CurrentPasswordHash then
      begin
        Result := TOperationResult.CreateFailure('Current password is incorrect', 'INVALID_CURRENT_PASSWORD');
        Exit;
      end;
      
      // Cambiar contraseña
      var NewPasswordHash := THashSHA2.GetHashString(Request.NewPassword + 'ORION_SALT_2024', SHA256);
      User.ChangePassword(NewPasswordHash);
      
      // Guardar cambios
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('Password changed successfully');
        FLogger.Info('Contraseña cambiada exitosamente', Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save password change', 'SAVE_ERROR');
        FLogger.Error('Error al guardar el cambio de contraseña', Context);
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'CHANGE_PASSWORD_500');
      FLogger.Error('Error during password change process', E, Context);
    end;
  end;
end;

function TAuthenticationService.ValidateSession(const SessionId: string): Boolean;
begin
  Result := FSessions.ContainsKey(SessionId);
end;

function TAuthenticationService.GetUserBySessionId(const SessionId: string): TUser;
var
  UserId: string;
  UserRepo: IUserRepository;
begin
  Result := nil;
  
  if FSessions.TryGetValue(SessionId, UserId) then
  begin
    UserRepo := GetUserRepository;
    Result := UserRepo.GetById(UserId);
  end;
end;

function TAuthenticationService.CreateUser(const UserName, Email, Password: string; Role: TUserRole): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  PasswordHash: string;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'CreateUser');
  
  try
    FLogger.Info('Creando nuevo usuario: ' + UserName, Context);
    
    // Validaciones
    if not IsValidPassword(Password) then
    begin
      Result := TOperationResult.CreateFailure('Password does not meet complexity requirements', 'PASSWORD_COMPLEXITY');
      Exit;
    end;
    
    UserRepo := GetUserRepository;
    
    if UserRepo.IsUserNameTaken(UserName) then
    begin
      Result := TOperationResult.CreateFailure('Username is already taken', 'DUPLICATE_USERNAME');
      Exit;
    end;
    
    if UserRepo.IsEmailTaken(Email) then
    begin
      Result := TOperationResult.CreateFailure('Email is already taken', 'DUPLICATE_EMAIL');
      Exit;
    end;
    
    // Crear usuario
    PasswordHash := THashSHA2.GetHashString(Password + 'ORION_SALT_2024', SHA256);
    User := TUser.Create(
      THashSHA2.GetHashString(UserName + Email + FormatDateTime('yyyymmddhhnnsszzz', Now), SHA256), // ID único
      UserName,
      Email,
      PasswordHash,
      Role
    );
    
    try
      User.IsActive := True;
      User.CreatedAt := Now;
      
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('User created successfully');
        FLogger.Info('Usuario creado exitosamente: ' + UserName, Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save user', 'SAVE_ERROR');
        FLogger.Error('Error al guardar el usuario: ' + UserName, Context);
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'CREATE_USER_500');
      FLogger.Error('Error durante la creación del usuario', E, Context);
    end;
  end;
end;

function TAuthenticationService.IsValidPassword(const Password: string): Boolean;
var
  HasLower, HasUpper, HasNumber, HasSpecial: Boolean;
  I: Integer;
  C: Char;
begin
  Result := False;
  
  // Verificar longitud
  if (Length(Password) < FSystemConfig.MinPasswordLength) or 
     (Length(Password) > FSystemConfig.MaxPasswordLength) then
    Exit;
    
  // Si no requiere complejidad, solo verificar longitud
  if not FSystemConfig.RequirePasswordComplexity then
  begin
    Result := True;
    Exit;
  end;
  
  // Verificar complejidad
  HasLower := False;
  HasUpper := False;
  HasNumber := False;
  HasSpecial := False;
  
  for I := 1 to Length(Password) do
  begin
    C := Password[I];
    
    if (C >= 'a') and (C <= 'z') then HasLower := True
    else if (C >= 'A') and (C <= 'Z') then HasUpper := True
    else if (C >= '0') and (C <= '9') then HasNumber := True
    else if not ((C >= 'a') and (C <= 'z')) and 
            not ((C >= 'A') and (C <= 'Z')) and 
            not ((C >= '0') and (C <= '9')) then HasSpecial := True;
  end;
  
  // Requiere al menos 3 de los 4 tipos de caracteres
  var ComplexityCount := 0;
  if HasLower then Inc(ComplexityCount);
  if HasUpper then Inc(ComplexityCount);
  if HasNumber then Inc(ComplexityCount);
  if HasSpecial then Inc(ComplexityCount);
  
  Result := ComplexityCount >= 3;
end;

function TAuthenticationService.GenerateSessionId: string;
begin
  Result := THashSHA2.GetHashString(
    FormatDateTime('yyyymmddhhnnsszzz', Now) + 
    IntToStr(Random(MaxInt)) + 
    'SESSION_SALT_' + IntToStr(GetCurrentThreadId), 
    SHA256
  );
end;

// Implementaciones adicionales para gestión de usuarios

function TAuthenticationService.ActivateUser(const UserId: string): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'ActivateUser');
  Context.UserId := UserId;
  
  try
    UserRepo := GetUserRepository;
    User := UserRepo.GetById(UserId);
    
    if not Assigned(User) then
    begin
      Result := TOperationResult.CreateFailure('User not found', 'USER_NOT_FOUND');
      Exit;
    end;
    
    try
      User.Activate;
      
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('User activated successfully');
        FLogger.Info('Usuario activado exitosamente', Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save user activation', 'SAVE_ERROR');
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'ACTIVATE_USER_500');
      FLogger.Error('Error durante la activación del usuario', E, Context);
    end;
  end;
end;

function TAuthenticationService.DeactivateUser(const UserId: string): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'DeactivateUser');
  Context.UserId := UserId;
  
  try
    UserRepo := GetUserRepository;
    User := UserRepo.GetById(UserId);
    
    if not Assigned(User) then
    begin
      Result := TOperationResult.CreateFailure('User not found', 'USER_NOT_FOUND');
      Exit;
    end;
    
    try
      User.Deactivate;
      
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('User deactivated successfully');
        FLogger.Info('Usuario desactivado exitosamente', Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save user deactivation', 'SAVE_ERROR');
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'DEACTIVATE_USER_500');
      FLogger.Error('Error durante la desactivación del usuario', E, Context);
    end;
  end;
end;

function TAuthenticationService.ResetPassword(const UserId, NewPassword: string): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  PasswordHash: string;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'ResetPassword');
  Context.UserId := UserId;
  
  try
    if not IsValidPassword(NewPassword) then
    begin
      Result := TOperationResult.CreateFailure('Password does not meet complexity requirements', 'PASSWORD_COMPLEXITY');
      Exit;
    end;
    
    UserRepo := GetUserRepository;
    User := UserRepo.GetById(UserId);
    
    if not Assigned(User) then
    begin
      Result := TOperationResult.CreateFailure('User not found', 'USER_NOT_FOUND');
      Exit;
    end;
    
    try
      PasswordHash := THashSHA2.GetHashString(NewPassword + 'ORION_SALT_2024', SHA256);
      User.ResetPassword(PasswordHash);
      
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('Password reset successfully');
        FLogger.Info('Contraseña restablecida exitosamente', Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save password reset', 'SAVE_ERROR');
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'RESET_PASSWORD_500');
      FLogger.Error('Error durante el restablecimiento de contraseña', E, Context);
    end;
  end;
end;

function TAuthenticationService.UnblockUser(const UserId: string): TOperationResult;
var
  UserRepo: IUserRepository;
  User: TUser;
  Context: TLogContext;
begin
  Context := CreateLogContext('AuthenticationService', 'UnblockUser');
  Context.UserId := UserId;
  
  try
    UserRepo := GetUserRepository;
    User := UserRepo.GetById(UserId);
    
    if not Assigned(User) then
    begin
      Result := TOperationResult.CreateFailure('User not found', 'USER_NOT_FOUND');
      Exit;
    end;
    
    try
      User.Unblock;
      
      if UserRepo.Save(User) then
      begin
        Result := TOperationResult.CreateSuccess('User unblocked successfully');
        FLogger.Info('Usuario desbloqueado exitosamente', Context);
      end
      else
      begin
        Result := TOperationResult.CreateFailure('Failed to save user unblock', 'SAVE_ERROR');
      end;
      
    finally
      User.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result := TOperationResult.CreateFailure('Internal server error', 'UNBLOCK_USER_500');
      FLogger.Error('Error durante el desbloqueo del usuario', E, Context);
    end;
  end;
end;

function TAuthenticationService.GetActiveUsers: TObjectList<TUser>;
var
  UserRepo: IUserRepository;
begin
  UserRepo := GetUserRepository;
  Result := UserRepo.GetActiveUsers;
end;

function TAuthenticationService.GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
var
  UserRepo: IUserRepository;
begin
  UserRepo := GetUserRepository;
  Result := UserRepo.GetUsersByRole(Role);
end;

function TAuthenticationService.GetUserStatistics: TUserStatistics;
var
  UserRepo: IUserRepository;
begin
  UserRepo := GetUserRepository;
  
  Result.TotalUsers := UserRepo.GetTotalCount;
  Result.ActiveUsers := UserRepo.GetActiveCount;
  Result.InactiveUsers := Result.TotalUsers - Result.ActiveUsers;
  Result.BlockedUsers := UserRepo.GetBlockedUsers.Count;
  Result.AdminUsers := UserRepo.GetCountByRole(TUserRole.Administrator);
  Result.ManagerUsers := UserRepo.GetCountByRole(TUserRole.Manager);
  Result.RegularUsers := UserRepo.GetCountByRole(TUserRole.User);
end;

procedure TAuthenticationService.UpdateSystemConfig(const Config: TSystemConfig);
begin
  FSystemConfig := Config;
  FLogger.Info('Configuración del sistema actualizada', CreateLogContext('AuthenticationService', 'UpdateSystemConfig'));
end;

function TAuthenticationService.GetSystemConfig: TSystemConfig;
begin
  Result := FSystemConfig;
end;

end.
