program OrionSoftServer;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Hash,
  // Core Units - Common
  OrionSoft.Core.Common.Types in 'src\\Core\\Common\\OrionSoft.Core.Common.Types.pas',
  OrionSoft.Core.Common.Exceptions in 'src\\Core\\Common\\OrionSoft.Core.Common.Exceptions.pas',
  // Core Units - Entities
  OrionSoft.Core.Entities.User in 'src\\Core\\Entities\\OrionSoft.Core.Entities.User.pas',
  // Core Units - Interfaces
  OrionSoft.Core.Interfaces.Services.ILogger in 'src\\Core\\Interfaces\\Services\\OrionSoft.Core.Interfaces.Services.ILogger.pas',
  OrionSoft.Core.Interfaces.Repositories.IUserRepository in 'src\\Core\\Interfaces\\Repositories\\OrionSoft.Core.Interfaces.Repositories.IUserRepository.pas',
  // Core Units - Use Cases
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase in 'src\\Core\\UseCases\\Authentication\\OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase.pas',
  // Application Layer
  OrionSoft.Application.Services.AuthenticationService in 'src\\Application\\Services\\OrionSoft.Application.Services.AuthenticationService.pas',
  // Infrastructure Layer - DI
  OrionSoft.Infrastructure.CrossCutting.DI.Container in 'src\\Infrastructure\\CrossCutting\\DI\\OrionSoft.Infrastructure.CrossCutting.DI.Container.pas',
  // Infrastructure Layer - Data Context  
  OrionSoft.Infrastructure.Data.Context.IDbConnection in 'src\\Infrastructure\\Data\\Context\\OrionSoft.Infrastructure.Data.Context.IDbConnection.pas',
  // Infrastructure Layer - Repositories
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository in 'src\\Infrastructure\\Data\\Repositories\\OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository.pas',
  OrionSoft.Infrastructure.Data.Repositories.SqlUserRepository in 'src\\Infrastructure\\Data\\Repositories\\OrionSoft.Infrastructure.Data.Repositories.SqlUserRepository.pas',
  // Infrastructure Layer - Services
  OrionSoft.Infrastructure.Services.FileLogger in 'src\\Infrastructure\\Services\\OrionSoft.Infrastructure.Services.FileLogger.pas';

// Mock logger simple
type
  TSimpleLogger = class(TInterfacedObject, ILogger)
  public
    procedure Debug(const Message: string); overload;
    procedure Debug(const Message: string; const Args: array of const); overload;
    procedure Debug(const Message: string; const Context: TLogContext); overload;
    procedure Info(const Message: string); overload;
    procedure Info(const Message: string; const Args: array of const); overload;
    procedure Info(const Message: string; const Context: TLogContext); overload;
    procedure Warning(const Message: string); overload;
    procedure Warning(const Message: string; const Args: array of const); overload;
    procedure Warning(const Message: string; const Context: TLogContext); overload;
    procedure Error(const Message: string); overload;
    procedure Error(const Message: string; const Args: array of const); overload;
    procedure Error(const Message: string; const Context: TLogContext); overload;
    procedure Error(const Message: string; E: Exception); overload;
    procedure Error(const Message: string; E: Exception; const Context: TLogContext); overload;
    procedure Fatal(const Message: string); overload;
    procedure Fatal(const Message: string; const Args: array of const); overload;
    procedure Fatal(const Message: string; const Context: TLogContext); overload;
    procedure Fatal(const Message: string; E: Exception); overload;
    procedure LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = '');
    procedure LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = '');
    procedure LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = '');
    procedure LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
    procedure SetLogLevel(Level: TLogLevel);
    function GetLogLevel: TLogLevel;
    procedure SetCorrelationId(const CorrelationId: string);
    procedure SetUserId(const UserId: string);
    procedure SetSessionId(const SessionId: string);
  end;

procedure TSimpleLogger.Debug(const Message: string); begin Writeln('[DEBUG] ', Message); end;
procedure TSimpleLogger.Debug(const Message: string; const Args: array of const); begin Debug(Format(Message, Args)); end;
procedure TSimpleLogger.Debug(const Message: string; const Context: TLogContext); begin Debug(Message); end;
procedure TSimpleLogger.Info(const Message: string); begin Writeln('[INFO] ', Message); end;
procedure TSimpleLogger.Info(const Message: string; const Args: array of const); begin Info(Format(Message, Args)); end;
procedure TSimpleLogger.Info(const Message: string; const Context: TLogContext); begin Info(Message); end;
procedure TSimpleLogger.Warning(const Message: string); begin Writeln('[WARNING] ', Message); end;
procedure TSimpleLogger.Warning(const Message: string; const Args: array of const); begin Warning(Format(Message, Args)); end;
procedure TSimpleLogger.Warning(const Message: string; const Context: TLogContext); begin Warning(Message); end;
procedure TSimpleLogger.Error(const Message: string); begin Writeln('[ERROR] ', Message); end;
procedure TSimpleLogger.Error(const Message: string; const Args: array of const); begin Error(Format(Message, Args)); end;
procedure TSimpleLogger.Error(const Message: string; const Context: TLogContext); begin Error(Message); end;
procedure TSimpleLogger.Error(const Message: string; E: Exception); begin Error(Message + ': ' + E.Message); end;
procedure TSimpleLogger.Error(const Message: string; E: Exception; const Context: TLogContext); begin Error(Message, E); end;
procedure TSimpleLogger.Fatal(const Message: string); begin Writeln('[FATAL] ', Message); end;
procedure TSimpleLogger.Fatal(const Message: string; const Args: array of const); begin Fatal(Format(Message, Args)); end;
procedure TSimpleLogger.Fatal(const Message: string; const Context: TLogContext); begin Fatal(Message); end;
procedure TSimpleLogger.Fatal(const Message: string; E: Exception); begin Fatal(Message, E); end;
procedure TSimpleLogger.LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = ''); begin Info(Format('Authentication: %s - %s', [UserName, BoolToStr(Success, True)])); end;
procedure TSimpleLogger.LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = ''); begin end;
procedure TSimpleLogger.LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = ''); begin end;
procedure TSimpleLogger.LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer); begin end;
procedure TSimpleLogger.SetLogLevel(Level: TLogLevel); begin end;
function TSimpleLogger.GetLogLevel: TLogLevel; begin Result := TLogLevel.Information; end;
procedure TSimpleLogger.SetCorrelationId(const CorrelationId: string); begin end;
procedure TSimpleLogger.SetUserId(const UserId: string); begin end;
procedure TSimpleLogger.SetSessionId(const SessionId: string); begin end;

procedure ConfigureDependencies(Container: TDIContainer);
var
  Logger: ILogger;
  UserRepo: TInMemoryUserRepository;
begin
  // Configurar logging simple
  Logger := TSimpleLogger.Create;
  Container.RegisterLogger(Logger);
  
  // Crear y configurar repositorio con datos de prueba
  UserRepo := TInMemoryUserRepository.Create;
  UserRepo.SeedWithTestData;
  Container.RegisterUserRepository(UserRepo);
end;

procedure RunDemo(Container: TDIContainer);
var
  UserRepo: IUserRepository;
  Logger: ILogger;
  AuthService: TAuthenticationService;
  User: TUser;
  LoginRequest: TLoginRequest;
  AuthResult: TAuthenticationResult;
begin
  Logger := Container.GetLogger;
  UserRepo := Container.GetUserRepository;
  
  Logger.Info('Iniciando demostración del servidor OrionSoft');
  
  try
    // Mostrar usuarios del sistema
    Writeln('=== DEMO: Sistema de usuarios OrionSoft - Clean Architecture ===');
    Writeln('Delphi 12 Athens - Clean Architecture Pattern');
    Writeln;
    
    // Probar obtener usuario directamente del repositorio
    Writeln('--- Acceso directo al repositorio ---');
    User := UserRepo.GetByUserName('admin');
    if Assigned(User) then
    begin
      Writeln('✓ Usuario encontrado: ', User.UserName);
      Writeln('  - Nombre: ', User.FirstName, ' ', User.LastName);
      Writeln('  - Email: ', User.Email);
      Writeln('  - Rol: ', UserRoleToString(User.Role));
      Writeln('  - Activo: ', BoolToStr(User.IsActive, True));
      Writeln('  - Puede hacer login: ', BoolToStr(User.CanLogin, True));
      User.Free;
    end
    else
      Writeln('✗ Usuario admin no encontrado');
    
    Writeln;
    
    // Probar AuthenticationService (Clean Architecture)
    Writeln('--- Prueba de AuthenticationService (Clean Architecture) ---');
    AuthService := TAuthenticationService.Create(Container);
    try
      // Crear request de login
      LoginRequest := TLoginRequest.Create('admin', '123456', False, 'Demo Client');
      
      Writeln('Intentando login con usuario: admin / 123456');
      AuthResult := AuthService.Login(LoginRequest);
      
      if AuthResult.Success then
      begin
        Writeln('✓ Login exitoso!');
        Writeln('  - Usuario: ', AuthResult.User.UserName);
        Writeln('  - Rol: ', UserRoleToString(AuthResult.User.Role));
        Writeln('  - SessionId: ', Copy(AuthResult.SessionId, 1, 20), '...');
        Writeln('  - Requiere cambio contraseña: ', BoolToStr(AuthResult.RequiresPasswordChange, True));
        
        // Probar validación de sesión
        Writeln('  - Sesión válida: ', BoolToStr(AuthService.ValidateSession(AuthResult.SessionId), True));
      end
      else
      begin
        Writeln('✗ Login fallido: ', AuthResult.ErrorMessage);
      end;
      
      // Limpiar recursos
      AuthResult.Free;
      
    finally
      AuthService.Free;
    end;
    
    Writeln;
    
    // Mostrar estadísticas básicas
    Writeln('--- Estadísticas del repositorio ---');
    Writeln('Total de usuarios: ', UserRepo.GetTotalCount);
    Writeln('Usuarios activos: ', UserRepo.GetActiveCount);
    Writeln('Administradores: ', UserRepo.GetCountByRole(TUserRole.Administrator));
    Writeln('Managers: ', UserRepo.GetCountByRole(TUserRole.Manager));
    Writeln('Usuarios regulares: ', UserRepo.GetCountByRole(TUserRole.User));
    
    Writeln;
    Logger.Info('Demostración completada exitosamente');
    
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.Message);
      Writeln('Stack trace: ', E.StackTrace);
      Logger.Error('Error durante la demostración', E);
    end;
  end;
end;

var
  Container: TDIContainer;
begin
  try
    Writeln('OrionSoft Server - Clean Architecture Demo');
    Writeln('==========================================');
    Writeln;
    
    // Configurar contenedor DI
    Container := GlobalContainer;
    ConfigureDependencies(Container);
    
    // Ejecutar demostración
    RunDemo(Container);
    
    Writeln;
    Writeln('Presione ENTER para salir...');
    Readln;
    
  except
    on E: Exception do
    begin
      Writeln('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      Writeln('Presione ENTER para salir...');
      Readln;
    end;
  end;
end.
