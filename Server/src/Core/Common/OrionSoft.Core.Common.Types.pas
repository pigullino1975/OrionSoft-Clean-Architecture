unit OrionSoft.Core.Common.Types;

{*
  Tipos comunes y constantes para el dominio de la aplicación
  Incluye enumeraciones, tipos básicos y constantes del sistema
*}

interface

uses
  System.SysUtils;

type
  // Tipos de usuario del sistema
  TUserRole = (None, User, Manager, Administrator);
  
  // Estados de sesión
  TSessionStatus = (ssActive, ssExpired, ssBlocked, ssTerminated);
  
  // Estados de entidades
  TEntityStatus = (esActive, esInactive, esSuspended, esDeleted);
  
  // Niveles de log
  TLogLevel = (Debug, Information, Warning, Error, Fatal);
  
  // Tipos de operación para auditoria
  TAuditOperation = (aoCreate, aoRead, aoUpdate, aoDelete, aoLogin, aoLogout);
  
  // Configuración de sistema
  TSystemConfig = record
    SessionTimeoutMinutes: Integer;
    MaxLoginAttempts: Integer;
    PasswordExpirationDays: Integer;
    RequirePasswordComplexity: Boolean;
    MinPasswordLength: Integer;
    MaxPasswordLength: Integer;
    DatabaseTimeout: Integer;
    LogLevel: TLogLevel;
    EnableAuditLog: Boolean;
    
    class function Default: TSystemConfig; static;
  end;
  
  // Estadísticas de usuarios
  TUserStatistics = record
    TotalUsers: Integer;
    ActiveUsers: Integer;
    InactiveUsers: Integer;
    BlockedUsers: Integer;
    AdminUsers: Integer;
    ManagerUsers: Integer;
    RegularUsers: Integer;
  end;
  
  // Contexto para logging
  TLogContext = record
    Component: string;
    Operation: string;
    CorrelationId: string;
    UserId: string;
    
    class function Create(const AComponent, AOperation: string): TLogContext; static;
  end;

// Constantes del sistema
const
  // Longitudes máximas de campos
  MAX_USERNAME_LENGTH = 50;
  MAX_PASSWORD_LENGTH = 100;
  MAX_EMAIL_LENGTH = 254;
  MAX_NAME_LENGTH = 100;
  MAX_CODE_LENGTH = 20;
  MAX_DESCRIPTION_LENGTH = 500;
  
  // Valores por defecto
  DEFAULT_SESSION_TIMEOUT = 30; // minutos
  DEFAULT_MAX_LOGIN_ATTEMPTS = 3;
  DEFAULT_PASSWORD_MIN_LENGTH = 6;
  DEFAULT_DATABASE_TIMEOUT = 30; // segundos
  
  // Códigos de error del sistema
  ERROR_AUTHENTICATION_FAILED = 'AUTH_001';
  ERROR_SESSION_EXPIRED = 'AUTH_002';
  ERROR_INSUFFICIENT_PRIVILEGES = 'AUTH_003';
  ERROR_USER_BLOCKED = 'AUTH_004';
  ERROR_INVALID_CREDENTIALS = 'AUTH_005';
  
  ERROR_VALIDATION_FAILED = 'VAL_001';
  ERROR_REQUIRED_FIELD = 'VAL_002';
  ERROR_INVALID_FORMAT = 'VAL_003';
  ERROR_DUPLICATE_VALUE = 'VAL_004';
  
  ERROR_DATABASE_CONNECTION = 'DB_001';
  ERROR_DATABASE_TIMEOUT = 'DB_002';
  ERROR_DATABASE_CONSTRAINT = 'DB_003';
  
  ERROR_BUSINESS_RULE = 'BUS_001';
  ERROR_CONCURRENCY = 'BUS_002';
  ERROR_NOT_FOUND = 'BUS_003';
  
// Helper functions
function UserRoleToString(Role: TUserRole): string;
function StringToUserRole(const RoleStr: string): TUserRole;
function SessionStatusToString(Status: TSessionStatus): string;
function LogLevelToString(Level: TLogLevel): string;
function CreateLogContext(const Component, Operation: string): TLogContext;

implementation

class function TSystemConfig.Default: TSystemConfig;
begin
  Result.SessionTimeoutMinutes := DEFAULT_SESSION_TIMEOUT;
  Result.MaxLoginAttempts := DEFAULT_MAX_LOGIN_ATTEMPTS;
  Result.PasswordExpirationDays := 90;
  Result.RequirePasswordComplexity := True;
  Result.MinPasswordLength := DEFAULT_PASSWORD_MIN_LENGTH;
  Result.MaxPasswordLength := MAX_PASSWORD_LENGTH;
  Result.DatabaseTimeout := DEFAULT_DATABASE_TIMEOUT;
  Result.LogLevel := TLogLevel.Information;
  Result.EnableAuditLog := True;
end;

class function TLogContext.Create(const AComponent, AOperation: string): TLogContext;
begin
  Result.Component := AComponent;
  Result.Operation := AOperation;
  Result.CorrelationId := '';
  Result.UserId := '';
end;

function UserRoleToString(Role: TUserRole): string;
begin
  case Role of
    TUserRole.None: Result := 'None';
    TUserRole.User: Result := 'User';
    TUserRole.Manager: Result := 'Manager';
    TUserRole.Administrator: Result := 'Administrator';
  else
    Result := 'Unknown';
  end;
end;

function StringToUserRole(const RoleStr: string): TUserRole;
begin
  if SameText(RoleStr, 'None') then Result := TUserRole.None
  else if SameText(RoleStr, 'User') then Result := TUserRole.User
  else if SameText(RoleStr, 'Manager') then Result := TUserRole.Manager
  else if SameText(RoleStr, 'Administrator') then Result := TUserRole.Administrator
  else raise Exception.CreateFmt('Unknown user role: %s', [RoleStr]);
end;

function SessionStatusToString(Status: TSessionStatus): string;
begin
  case Status of
    ssActive: Result := 'Active';
    ssExpired: Result := 'Expired';
    ssBlocked: Result := 'Blocked';
    ssTerminated: Result := 'Terminated';
  else
    Result := 'Unknown';
  end;
end;

function LogLevelToString(Level: TLogLevel): string;
begin
  case Level of
    TLogLevel.Debug: Result := 'DEBUG';
    TLogLevel.Information: Result := 'INFO';
    TLogLevel.Warning: Result := 'WARNING';
    TLogLevel.Error: Result := 'ERROR';
    TLogLevel.Fatal: Result := 'FATAL';
  else
    Result := 'UNKNOWN';
  end;
end;

function CreateLogContext(const Component, Operation: string): TLogContext;
begin
  Result := TLogContext.Create(Component, Operation);
end;

end.
