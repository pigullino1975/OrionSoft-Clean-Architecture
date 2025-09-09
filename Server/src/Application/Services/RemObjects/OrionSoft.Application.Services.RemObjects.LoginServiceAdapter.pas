unit OrionSoft.Application.Services.RemObjects.LoginServiceAdapter;

{*
  Adaptador RemObjects para el servicio de Login/Autenticación
  Mantiene compatibilidad con el cliente legacy mientras usa la nueva Clean Architecture
  
  Este adaptador:
  1. Implementa las mismas interfaces que el servicio legacy
  2. Traduce entre DTOs legacy y nuevos DTOs clean
  3. Delega la lógica de negocio al AuthenticationService
  4. Maneja la serialización RemObjects (OleVariant)
*}

interface

uses
  System.SysUtils,
  System.Variants,
  System.Classes,
  System.Generics.Collections,
  uROServerIntf,
  uDADataModule,
  OrionSoft.Application.Services.AuthenticationService,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Infrastructure.CrossCutting.DI.Container;

type
  // Estructura de datos legacy para compatibilidad con cliente existente
  TLegacyLoginResult = record
    Success: Boolean;
    UserId: string;
    UserName: string;
    UserRole: Integer;
    SessionId: string;
    ErrorMessage: string;
    RequiresPasswordChange: Boolean;
    UserFullName: string;
    
    class function FromAuthResult(const AuthResult: TAuthenticationResult): TLegacyLoginResult; static;
    function ToVariant: OleVariant;
  end;

  TLegacyUserInfo = record
    Id: string;
    UserName: string;
    FirstName: string;
    LastName: string;
    Email: string;
    Role: Integer;
    RoleName: string;
    IsActive: Boolean;
    IsBlocked: Boolean;
    LastLoginAt: TDateTime;
    CreatedAt: TDateTime;
    
    class function FromUser(User: TUser): TLegacyUserInfo; static;
    function ToVariant: OleVariant;
  end;

  TLegacyOperationResult = record
    Success: Boolean;
    Message: string;
    ErrorCode: string;
    
    class function FromOperationResult(const OpResult: TOperationResult): TLegacyOperationResult; static;
    function ToVariant: OleVariant;
  end;

  // Servicio RemObjects principal - mantiene compatibilidad con interfaz legacy
  TLoginServiceAdapter = class(TDataAbstractService)
  private
    FAuthenticationService: TAuthenticationService;
    FLogger: ILogger;
    FContainer: TDIContainer;
    
    function VariantToLoginRequest(const LoginData: OleVariant): TLoginRequest;
    function VariantToChangePasswordRequest(const PasswordData: OleVariant): TChangePasswordRequest;
    function VariantToLogoutRequest(const LogoutData: OleVariant): TLogoutRequest;
    function GetClientInfo(const Context: IDAServerContext): string;
    function GetClientIP(const Context: IDAServerContext): string;
    
  protected
    procedure InitializeServices; virtual;
    
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    // Métodos RemObjects - interfaz legacy compatibles con cliente existente
    
    // =====================================================================
    // Autenticación principal
    // =====================================================================
    function Login(const LoginData: OleVariant): OleVariant; override;
    function Logout(const LogoutData: OleVariant): OleVariant; override;
    function ValidateSession(const SessionId: OleVariant): OleVariant; override;
    function RefreshSession(const SessionId: OleVariant): OleVariant; override;
    
    // =====================================================================
    // Gestión de contraseñas
    // =====================================================================
    function ChangePassword(const PasswordData: OleVariant): OleVariant; override;
    function ResetPassword(const ResetData: OleVariant): OleVariant; override;
    function ForcePasswordChange(const UserId: OleVariant): OleVariant; override;
    
    // =====================================================================
    // Gestión de usuarios (para administradores)
    // =====================================================================
    function GetUserInfo(const UserId: OleVariant): OleVariant; override;
    function GetUsersByRole(const Role: OleVariant): OleVariant; override;
    function GetActiveUsers: OleVariant; override;
    function CreateUser(const UserData: OleVariant): OleVariant; override;
    function UpdateUser(const UserData: OleVariant): OleVariant; override;
    function ActivateUser(const UserId: OleVariant): OleVariant; override;
    function DeactivateUser(const UserId: OleVariant): OleVariant; override;
    function BlockUser(const BlockData: OleVariant): OleVariant; override;
    function UnblockUser(const UserId: OleVariant): OleVariant; override;
    
    // =====================================================================
    // Consultas y estadísticas
    // =====================================================================
    function GetUserStatistics: OleVariant; override;
    function GetLoginHistory(const UserId: OleVariant; DaysBack: OleVariant): OleVariant; override;
    function GetSystemConfig: OleVariant; override;
    function UpdateSystemConfig(const ConfigData: OleVariant): OleVariant; override;
    
    // =====================================================================
    // Métodos de compatibilidad con versión anterior
    // =====================================================================
    function AuthenticateUser(const UserName, Password: OleVariant): OleVariant; override; // Legacy method
    function GetCurrentUser(const SessionId: OleVariant): OleVariant; override; // Legacy method
    function CheckUserPermission(const SessionId, Permission: OleVariant): OleVariant; override; // Legacy method
  end;

implementation

uses
  System.DateUtils,
  System.StrUtils,
  System.Hash;

const
  // Códigos de error para compatibilidad legacy
  LEGACY_ERROR_INVALID_CREDENTIALS = 'LOGIN_001';
  LEGACY_ERROR_USER_BLOCKED = 'LOGIN_002';
  LEGACY_ERROR_SESSION_EXPIRED = 'LOGIN_003';
  LEGACY_ERROR_INSUFFICIENT_PRIVILEGES = 'LOGIN_004';
  LEGACY_ERROR_PASSWORD_EXPIRED = 'LOGIN_005';

{ TLegacyLoginResult }

class function TLegacyLoginResult.FromAuthResult(const AuthResult: TAuthenticationResult): TLegacyLoginResult;
begin
  Result.Success := AuthResult.Success;
  Result.SessionId := AuthResult.SessionId;
  Result.ErrorMessage := AuthResult.ErrorMessage;
  Result.RequiresPasswordChange := AuthResult.RequiresPasswordChange;
  
  if Assigned(AuthResult.User) then
  begin
    Result.UserId := AuthResult.User.Id;
    Result.UserName := AuthResult.User.UserName;
    Result.UserRole := Integer(AuthResult.User.Role);
    Result.UserFullName := Trim(AuthResult.User.FirstName + ' ' + AuthResult.User.LastName);
    if Result.UserFullName = '' then
      Result.UserFullName := AuthResult.User.UserName;
  end
  else
  begin
    Result.UserId := '';
    Result.UserName := '';
    Result.UserRole := 0;
    Result.UserFullName := '';
  end;
end;

function TLegacyLoginResult.ToVariant: OleVariant;
begin
  Result := VarArrayCreate([0, 6], varVariant);
  Result[0] := Success;
  Result[1] := UserId;
  Result[2] := UserName;
  Result[3] := UserRole;
  Result[4] := SessionId;
  Result[5] := ErrorMessage;
  Result[6] := RequiresPasswordChange;
  Result[7] := UserFullName;
end;

{ TLegacyUserInfo }

class function TLegacyUserInfo.FromUser(User: TUser): TLegacyUserInfo;
begin
  Result.Id := User.Id;
  Result.UserName := User.UserName;
  Result.FirstName := User.FirstName;
  Result.LastName := User.LastName;
  Result.Email := User.Email;
  Result.Role := Integer(User.Role);
  Result.RoleName := UserRoleToString(User.Role);
  Result.IsActive := User.IsActive;
  Result.IsBlocked := User.IsBlocked;
  Result.LastLoginAt := User.LastLoginAt;
  Result.CreatedAt := User.CreatedAt;
end;

function TLegacyUserInfo.ToVariant: OleVariant;
begin
  Result := VarArrayCreate([0, 9], varVariant);
  Result[0] := Id;
  Result[1] := UserName;
  Result[2] := FirstName;
  Result[3] := LastName;
  Result[4] := Email;
  Result[5] := Role;
  Result[6] := RoleName;
  Result[7] := IsActive;
  Result[8] := IsBlocked;
  Result[9] := LastLoginAt;
  Result[10] := CreatedAt;
end;

{ TLegacyOperationResult }

class function TLegacyOperationResult.FromOperationResult(const OpResult: TOperationResult): TLegacyOperationResult;
begin
  Result.Success := OpResult.Success;
  Result.Message := OpResult.Message;
  Result.ErrorCode := OpResult.ErrorCode;
end;

function TLegacyOperationResult.ToVariant: OleVariant;
begin
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := Success;
  Result[1] := Message;
  Result[2] := ErrorCode;
end;

{ TLoginServiceAdapter }

constructor TLoginServiceAdapter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  
  try
    // Obtener el contenedor DI global
    FContainer := GlobalDIContainer;
    if not Assigned(FContainer) then
      raise Exception.Create('DI Container not initialized');
    
    // Resolver dependencias
    FLogger := FContainer.Resolve<ILogger>();
    
    // Inicializar servicios
    InitializeServices;
    
    FLogger.Info('LoginServiceAdapter initialized successfully', 
      CreateLogContext('LoginServiceAdapter', 'Initialize'));
      
  except
    on E: Exception do
    begin
      if Assigned(FLogger) then
        FLogger.Error('Failed to initialize LoginServiceAdapter', E, 
          CreateLogContext('LoginServiceAdapter', 'Initialize'))
      else
        // Fallback si no hay logger
        raise Exception.CreateFmt('Failed to initialize LoginServiceAdapter: %s', [E.Message]);
    end;
  end;
end;

destructor TLoginServiceAdapter.Destroy;
begin
  if Assigned(FLogger) then
    FLogger.Info('LoginServiceAdapter being destroyed', 
      CreateLogContext('LoginServiceAdapter', 'Destroy'));
      
  FAuthenticationService.Free;
  inherited Destroy;
end;

procedure TLoginServiceAdapter.InitializeServices;
begin
  // Crear AuthenticationService con dependencias resueltas
  FAuthenticationService := TAuthenticationService.Create(FContainer);
end;

function TLoginServiceAdapter.GetClientInfo(const Context: IDAServerContext): string;
begin
  Result := 'RemObjects Client';
  if Assigned(Context) then
  begin
    // Extraer información del contexto si está disponible
    try
      Result := Context.ClientInfo;
    except
      // Ignorar errores al obtener info del cliente
    end;
  end;
end;

function TLoginServiceAdapter.GetClientIP(const Context: IDAServerContext): string;
begin
  Result := '127.0.0.1';
  if Assigned(Context) then
  begin
    try
      Result := Context.ClientAddress;
    except
      // Ignorar errores al obtener IP del cliente
    end;
  end;
end;

function TLoginServiceAdapter.VariantToLoginRequest(const LoginData: OleVariant): TLoginRequest;
begin
  if VarIsArray(LoginData) then
  begin
    Result.UserName := VarToStr(LoginData[0]);
    Result.Password := VarToStr(LoginData[1]);
    Result.RememberMe := VarToBool(LoginData[2]);
    
    if VarArrayHighBound(LoginData, 1) >= 3 then
      Result.ClientInfo := VarToStr(LoginData[3])
    else
      Result.ClientInfo := GetClientInfo(nil);
  end
  else
  begin
    raise Exception.Create('Invalid login data format');
  end;
end;

function TLoginServiceAdapter.VariantToChangePasswordRequest(const PasswordData: OleVariant): TChangePasswordRequest;
begin
  if VarIsArray(PasswordData) then
  begin
    Result.UserId := VarToStr(PasswordData[0]);
    Result.CurrentPassword := VarToStr(PasswordData[1]);
    Result.NewPassword := VarToStr(PasswordData[2]);
    Result.ConfirmPassword := VarToStr(PasswordData[3]);
  end
  else
  begin
    raise Exception.Create('Invalid password change data format');
  end;
end;

function TLoginServiceAdapter.VariantToLogoutRequest(const LogoutData: OleVariant): TLogoutRequest;
begin
  if VarIsArray(LogoutData) then
  begin
    Result.SessionId := VarToStr(LogoutData[0]);
    Result.UserId := VarToStr(LogoutData[1]);
  end
  else
  begin
    Result.SessionId := VarToStr(LogoutData);
    Result.UserId := '';
  end;
end;

// =====================================================================
// Implementación de métodos RemObjects
// =====================================================================

function TLoginServiceAdapter.Login(const LoginData: OleVariant): OleVariant;
var
  LoginRequest: TLoginRequest;
  AuthResult: TAuthenticationResult;
  LegacyResult: TLegacyLoginResult;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'Login');
  
  try
    FLogger.Debug('Processing login request', Context);
    
    // Convertir datos legacy a nuevo formato
    LoginRequest := VariantToLoginRequest(LoginData);
    
    // Ejecutar autenticación usando el servicio clean
    AuthResult := FAuthenticationService.Login(LoginRequest);
    
    // Convertir resultado a formato legacy
    LegacyResult := TLegacyLoginResult.FromAuthResult(AuthResult);
    Result := LegacyResult.ToVariant;
    
    // Log del resultado
    if AuthResult.Success then
      FLogger.Info(Format('Login successful for user: %s', [LoginRequest.UserName]), Context)
    else
      FLogger.Warning(Format('Login failed for user: %s - %s', [LoginRequest.UserName, AuthResult.ErrorMessage]), Context);
    
    // Limpiar recursos
    AuthResult.Free;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in Login method', E, Context);
      
      LegacyResult.Success := False;
      LegacyResult.ErrorMessage := 'Internal server error during login';
      LegacyResult.SessionId := '';
      LegacyResult.UserId := '';
      LegacyResult.UserName := '';
      LegacyResult.UserRole := 0;
      LegacyResult.RequiresPasswordChange := False;
      LegacyResult.UserFullName := '';
      
      Result := LegacyResult.ToVariant;
    end;
  end;
end;

function TLoginServiceAdapter.Logout(const LogoutData: OleVariant): OleVariant;
var
  LogoutRequest: TLogoutRequest;
  OpResult: TOperationResult;
  LegacyResult: TLegacyOperationResult;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'Logout');
  
  try
    FLogger.Debug('Processing logout request', Context);
    
    LogoutRequest := VariantToLogoutRequest(LogoutData);
    OpResult := FAuthenticationService.Logout(LogoutRequest);
    
    LegacyResult := TLegacyOperationResult.FromOperationResult(OpResult);
    Result := LegacyResult.ToVariant;
    
    FLogger.Info('Logout processed', Context);
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in Logout method', E, Context);
      
      LegacyResult.Success := False;
      LegacyResult.Message := 'Internal server error during logout';
      LegacyResult.ErrorCode := 'LOGOUT_ERROR';
      
      Result := LegacyResult.ToVariant;
    end;
  end;
end;

function TLoginServiceAdapter.ValidateSession(const SessionId: OleVariant): OleVariant;
var
  SessionIdStr: string;
  IsValid: Boolean;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'ValidateSession');
  
  try
    SessionIdStr := VarToStr(SessionId);
    FLogger.Debug('Validating session: ' + Copy(SessionIdStr, 1, 10) + '...', Context);
    
    IsValid := FAuthenticationService.ValidateSession(SessionIdStr);
    
    Result := VarArrayCreate([0, 1], varVariant);
    Result[0] := IsValid;
    Result[1] := IfThen(IsValid, 'Session valid', 'Session invalid or expired');
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in ValidateSession method', E, Context);
      
      Result := VarArrayCreate([0, 1], varVariant);
      Result[0] := False;
      Result[1] := 'Error validating session';
    end;
  end;
end;

function TLoginServiceAdapter.RefreshSession(const SessionId: OleVariant): OleVariant;
var
  SessionIdStr: string;
  User: TUser;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'RefreshSession');
  
  try
    SessionIdStr := VarToStr(SessionId);
    FLogger.Debug('Refreshing session', Context);
    
    User := FAuthenticationService.GetUserBySessionId(SessionIdStr);
    
    if Assigned(User) then
    begin
      try
        Result := VarArrayCreate([0, 2], varVariant);
        Result[0] := True;
        Result[1] := 'Session refreshed successfully';
        Result[2] := SessionIdStr; // En una implementación completa, podríamos generar nuevo SessionId
        
        FLogger.Info('Session refreshed for user: ' + User.UserName, Context);
      finally
        User.Free;
      end;
    end
    else
    begin
      Result := VarArrayCreate([0, 2], varVariant);
      Result[0] := False;
      Result[1] := 'Invalid session';
      Result[2] := '';
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in RefreshSession method', E, Context);
      
      Result := VarArrayCreate([0, 2], varVariant);
      Result[0] := False;
      Result[1] := 'Error refreshing session';
      Result[2] := '';
    end;
  end;
end;

function TLoginServiceAdapter.ChangePassword(const PasswordData: OleVariant): OleVariant;
var
  PasswordRequest: TChangePasswordRequest;
  OpResult: TOperationResult;
  LegacyResult: TLegacyOperationResult;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'ChangePassword');
  
  try
    FLogger.Debug('Processing password change request', Context);
    
    PasswordRequest := VariantToChangePasswordRequest(PasswordData);
    OpResult := FAuthenticationService.ChangePassword(PasswordRequest);
    
    LegacyResult := TLegacyOperationResult.FromOperationResult(OpResult);
    Result := LegacyResult.ToVariant;
    
    if OpResult.Success then
      FLogger.Info('Password changed successfully', Context)
    else
      FLogger.Warning('Password change failed: ' + OpResult.Message, Context);
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in ChangePassword method', E, Context);
      
      LegacyResult.Success := False;
      LegacyResult.Message := 'Internal server error during password change';
      LegacyResult.ErrorCode := 'CHANGE_PWD_ERROR';
      
      Result := LegacyResult.ToVariant;
    end;
  end;
end;

function TLoginServiceAdapter.GetActiveUsers: OleVariant;
var
  Users: TObjectList<TUser>;
  UserInfoArray: array of TLegacyUserInfo;
  I: Integer;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'GetActiveUsers');
  
  try
    FLogger.Debug('Getting active users', Context);
    
    Users := FAuthenticationService.GetActiveUsers;
    try
      SetLength(UserInfoArray, Users.Count);
      
      for I := 0 to Users.Count - 1 do
        UserInfoArray[I] := TLegacyUserInfo.FromUser(Users[I]);
      
      // Convertir array a variant array para RemObjects
      Result := VarArrayCreate([0, Users.Count - 1], varVariant);
      for I := 0 to Users.Count - 1 do
        Result[I] := UserInfoArray[I].ToVariant;
        
      FLogger.Debug(Format('Retrieved %d active users', [Users.Count]), Context);
      
    finally
      Users.Free;
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in GetActiveUsers method', E, Context);
      Result := VarArrayCreate([0, -1], varVariant); // Empty array
    end;
  end;
end;

// =====================================================================
// Métodos de compatibilidad legacy
// =====================================================================

function TLoginServiceAdapter.AuthenticateUser(const UserName, Password: OleVariant): OleVariant;
var
  LoginData: OleVariant;
begin
  // Convertir a formato moderno y delegar
  LoginData := VarArrayCreate([0, 3], varVariant);
  LoginData[0] := UserName;
  LoginData[1] := Password;
  LoginData[2] := False; // RememberMe = False
  LoginData[3] := 'Legacy Client';
  
  Result := Login(LoginData);
end;

function TLoginServiceAdapter.GetCurrentUser(const SessionId: OleVariant): OleVariant;
var
  User: TUser;
  UserInfo: TLegacyUserInfo;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'GetCurrentUser');
  
  try
    User := FAuthenticationService.GetUserBySessionId(VarToStr(SessionId));
    
    if Assigned(User) then
    begin
      try
        UserInfo := TLegacyUserInfo.FromUser(User);
        Result := UserInfo.ToVariant;
      finally
        User.Free;
      end;
    end
    else
    begin
      Result := Null;
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in GetCurrentUser method', E, Context);
      Result := Null;
    end;
  end;
end;

function TLoginServiceAdapter.CheckUserPermission(const SessionId, Permission: OleVariant): OleVariant;
var
  User: TUser;
  HasPermission: Boolean;
  Context: TLogContext;
begin
  Context := CreateLogContext('LoginServiceAdapter', 'CheckUserPermission');
  
  try
    User := FAuthenticationService.GetUserBySessionId(VarToStr(SessionId));
    
    if Assigned(User) then
    begin
      try
        HasPermission := User.CanAccessResource(VarToStr(Permission));
        
        Result := VarArrayCreate([0, 1], varVariant);
        Result[0] := HasPermission;
        Result[1] := IfThen(HasPermission, 'Permission granted', 'Permission denied');
      finally
        User.Free;
      end;
    end
    else
    begin
      Result := VarArrayCreate([0, 1], varVariant);
      Result[0] := False;
      Result[1] := 'Invalid session';
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error in CheckUserPermission method', E, Context);
      
      Result := VarArrayCreate([0, 1], varVariant);
      Result[0] := False;
      Result[1] := 'Error checking permission';
    end;
  end;
end;

// Implementaciones de métodos restantes (simplificadas para brevedad)
function TLoginServiceAdapter.ResetPassword(const ResetData: OleVariant): OleVariant;
begin
  // TODO: Implementar reset de contraseña
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Password reset not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

function TLoginServiceAdapter.ForcePasswordChange(const UserId: OleVariant): OleVariant;
begin
  // TODO: Implementar forzar cambio de contraseña
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Force password change not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

function TLoginServiceAdapter.GetUserInfo(const UserId: OleVariant): OleVariant;
begin
  // TODO: Implementar obtener información de usuario
  Result := Null;
end;

function TLoginServiceAdapter.GetUsersByRole(const Role: OleVariant): OleVariant;
begin
  // TODO: Implementar obtener usuarios por rol
  Result := VarArrayCreate([0, -1], varVariant);
end;

function TLoginServiceAdapter.CreateUser(const UserData: OleVariant): OleVariant;
begin
  // TODO: Implementar crear usuario
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Create user not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

function TLoginServiceAdapter.UpdateUser(const UserData: OleVariant): OleVariant;
begin
  // TODO: Implementar actualizar usuario
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Update user not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

function TLoginServiceAdapter.ActivateUser(const UserId: OleVariant): OleVariant;
var
  OpResult: TOperationResult;
  LegacyResult: TLegacyOperationResult;
begin
  try
    OpResult := FAuthenticationService.ActivateUser(VarToStr(UserId));
    LegacyResult := TLegacyOperationResult.FromOperationResult(OpResult);
    Result := LegacyResult.ToVariant;
  except
    Result := VarArrayCreate([0, 2], varVariant);
    Result[0] := False;
    Result[1] := 'Error activating user';
    Result[2] := 'ACTIVATE_ERROR';
  end;
end;

function TLoginServiceAdapter.DeactivateUser(const UserId: OleVariant): OleVariant;
var
  OpResult: TOperationResult;
  LegacyResult: TLegacyOperationResult;
begin
  try
    OpResult := FAuthenticationService.DeactivateUser(VarToStr(UserId));
    LegacyResult := TLegacyOperationResult.FromOperationResult(OpResult);
    Result := LegacyResult.ToVariant;
  except
    Result := VarArrayCreate([0, 2], varVariant);
    Result[0] := False;
    Result[1] := 'Error deactivating user';
    Result[2] := 'DEACTIVATE_ERROR';
  end;
end;

function TLoginServiceAdapter.BlockUser(const BlockData: OleVariant): OleVariant;
begin
  // TODO: Implementar bloquear usuario
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Block user not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

function TLoginServiceAdapter.UnblockUser(const UserId: OleVariant): OleVariant;
var
  OpResult: TOperationResult;
  LegacyResult: TLegacyOperationResult;
begin
  try
    OpResult := FAuthenticationService.UnblockUser(VarToStr(UserId));
    LegacyResult := TLegacyOperationResult.FromOperationResult(OpResult);
    Result := LegacyResult.ToVariant;
  except
    Result := VarArrayCreate([0, 2], varVariant);
    Result[0] := False;
    Result[1] := 'Error unblocking user';
    Result[2] := 'UNBLOCK_ERROR';
  end;
end;

function TLoginServiceAdapter.GetUserStatistics: OleVariant;
var
  Stats: TUserStatistics;
begin
  try
    Stats := FAuthenticationService.GetUserStatistics;
    
    Result := VarArrayCreate([0, 6], varVariant);
    Result[0] := Stats.TotalUsers;
    Result[1] := Stats.ActiveUsers;
    Result[2] := Stats.InactiveUsers;
    Result[3] := Stats.BlockedUsers;
    Result[4] := Stats.AdminUsers;
    Result[5] := Stats.ManagerUsers;
    Result[6] := Stats.RegularUsers;
  except
    Result := VarArrayCreate([0, 6], varVariant);
    // Return zeros on error
    for var I := 0 to 6 do
      Result[I] := 0;
  end;
end;

function TLoginServiceAdapter.GetLoginHistory(const UserId: OleVariant; DaysBack: OleVariant): OleVariant;
begin
  // TODO: Implementar historial de logins
  Result := VarArrayCreate([0, -1], varVariant);
end;

function TLoginServiceAdapter.GetSystemConfig: OleVariant;
var
  Config: TSystemConfig;
begin
  try
    Config := FAuthenticationService.GetSystemConfig;
    
    Result := VarArrayCreate([0, 7], varVariant);
    Result[0] := Config.SessionTimeoutMinutes;
    Result[1] := Config.MaxLoginAttempts;
    Result[2] := Config.PasswordExpirationDays;
    Result[3] := Config.RequirePasswordComplexity;
    Result[4] := Config.MinPasswordLength;
    Result[5] := Config.MaxPasswordLength;
    Result[6] := Integer(Config.LogLevel);
    Result[7] := Config.EnableAuditLog;
  except
    Result := Null;
  end;
end;

function TLoginServiceAdapter.UpdateSystemConfig(const ConfigData: OleVariant): OleVariant;
begin
  // TODO: Implementar actualizar configuración del sistema
  Result := VarArrayCreate([0, 2], varVariant);
  Result[0] := False;
  Result[1] := 'Update system config not implemented yet';
  Result[2] := 'NOT_IMPLEMENTED';
end;

end.
