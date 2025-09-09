unit OrionSoft.Infrastructure.CrossCutting.DI.Container;

{*
  Contenedor de Dependency Injection extendido
  Soporte para resolución genérica y servicios adicionales
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.TypInfo,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  // Contenedor extendido de DI
  TDIContainer = class
  private
    FLogger: ILogger;
    FUserRepository: IUserRepository;
    FDbConnection: IDbConnection;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // Registro de servicios específicos
    procedure RegisterLogger(Logger: ILogger);
    procedure RegisterUserRepository(UserRepository: IUserRepository);
    procedure RegisterDbConnection(Connection: IDbConnection);
    
    // Resolución de servicios específicos
    function GetLogger: ILogger;
    function GetUserRepository: IUserRepository;
    function GetDbConnection: IDbConnection;
    
    // Métodos de resolución específicos adicionales
    function ResolveLogger: ILogger;
    function ResolveUserRepository: IUserRepository;
    function ResolveDbConnection: IDbConnection;
  end;

// Singleton global
function GlobalContainer: TDIContainer;
function GlobalDIContainer: TDIContainer; // Alias para compatibilidad

implementation

var
  GContainer: TDIContainer;

function GlobalContainer: TDIContainer;
begin
  if not Assigned(GContainer) then
    GContainer := TDIContainer.Create;
  Result := GContainer;
end;

function GlobalDIContainer: TDIContainer;
begin
  Result := GlobalContainer;
end;

{ TDIContainer }

constructor TDIContainer.Create;
begin
  inherited Create;
  FLogger := nil;
  FUserRepository := nil;
  FDbConnection := nil;
end;

destructor TDIContainer.Destroy;
begin
  // No liberamos las interfaces aquí porque son referenciadas
  inherited Destroy;
end;

procedure TDIContainer.RegisterLogger(Logger: ILogger);
begin
  FLogger := Logger;
end;

procedure TDIContainer.RegisterUserRepository(UserRepository: IUserRepository);
begin
  FUserRepository := UserRepository;
end;

procedure TDIContainer.RegisterDbConnection(Connection: IDbConnection);
begin
  FDbConnection := Connection;
end;

function TDIContainer.GetLogger: ILogger;
begin
  if not Assigned(FLogger) then
    raise Exception.Create('Logger not registered');
  Result := FLogger;
end;

function TDIContainer.GetUserRepository: IUserRepository;
begin
  if not Assigned(FUserRepository) then
    raise Exception.Create('UserRepository not registered');
  Result := FUserRepository;
end;

function TDIContainer.GetDbConnection: IDbConnection;
begin
  if not Assigned(FDbConnection) then
    raise Exception.Create('DbConnection not registered');
  Result := FDbConnection;
end;

function TDIContainer.ResolveLogger: ILogger;
begin
  Result := GetLogger;
end;

function TDIContainer.ResolveUserRepository: IUserRepository;
begin
  Result := GetUserRepository;
end;

function TDIContainer.ResolveDbConnection: IDbConnection;
begin
  Result := GetDbConnection;
end;

initialization

finalization
  if Assigned(GContainer) then
    GContainer.Free;

end.
