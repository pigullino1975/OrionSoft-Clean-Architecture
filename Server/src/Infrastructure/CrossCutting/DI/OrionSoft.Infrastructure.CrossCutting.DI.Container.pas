unit OrionSoft.Infrastructure.CrossCutting.DI.Container;

{*
  Contenedor de Dependency Injection simplificado
  Versión básica para demostración
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository;

type
  // Contenedor simple de DI
  TDIContainer = class
  private
    FLogger: ILogger;
    FUserRepository: IUserRepository;
  public
    constructor Create;
    destructor Destroy; override;
    
    // Registro de servicios específicos
    procedure RegisterLogger(Logger: ILogger);
    procedure RegisterUserRepository(UserRepository: IUserRepository);
    
    // Resolución de servicios específicos
    function GetLogger: ILogger;
    function GetUserRepository: IUserRepository;
  end;

// Singleton global
function GlobalContainer: TDIContainer;

implementation

var
  GContainer: TDIContainer;

function GlobalContainer: TDIContainer;
begin
  if not Assigned(GContainer) then
    GContainer := TDIContainer.Create;
  Result := GContainer;
end;

{ TDIContainer }

constructor TDIContainer.Create;
begin
  inherited Create;
  FLogger := nil;
  FUserRepository := nil;
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

initialization

finalization
  if Assigned(GContainer) then
    GContainer.Free;

end.
