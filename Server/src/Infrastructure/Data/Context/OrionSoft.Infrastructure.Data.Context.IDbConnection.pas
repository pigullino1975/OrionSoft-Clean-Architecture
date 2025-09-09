unit OrionSoft.Infrastructure.Data.Context.IDbConnection;

{*
  Interfaz para abstracción de conexiones de base de datos
  Permite cambiar entre diferentes proveedores de BD sin afectar los repositorios
  Soporte: SQL Server, MySQL, PostgreSQL, SQLite
*}

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.DApt,
  Data.DB;

type
  // Tipos de base de datos soportados
  TDatabaseType = (dtSQLServer, dtMySQL, dtPostgreSQL, dtSQLite, dtOracle, dtFirebird);
  
  // Estado de conexión
  TConnectionState = (csDisconnected, csConnected, csConnecting, csError);
  
  // Configuración de conexión
  TConnectionConfig = record
    DatabaseType: TDatabaseType;
    Server: string;
    Port: Integer;
    Database: string;
    Username: string;
    Password: string;
    ConnectionTimeout: Integer;
    CommandTimeout: Integer;
    MaxPoolSize: Integer;
    MinPoolSize: Integer;
    Charset: string;
    Options: string;
    
    class function Default: TConnectionConfig; static;
    class function SQLServer(const AServer, ADatabase, AUsername, APassword: string): TConnectionConfig; static;
    class function MySQL(const AServer, ADatabase, AUsername, APassword: string; APort: Integer = 3306): TConnectionConfig; static;
    class function PostgreSQL(const AServer, ADatabase, AUsername, APassword: string; APort: Integer = 5432): TConnectionConfig; static;
    class function SQLite(const ADatabaseFile: string): TConnectionConfig; static;
  end;

  // Interfaz principal de conexión
  IDbConnection = interface
    ['{F1E2D3C4-B5A6-4978-8E9F-0A1B2C3D4E5F}']
    
    // Gestión de conexión
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function GetConnectionState: TConnectionState;
    function GetConnectionConfig: TConnectionConfig;
    procedure SetConnectionConfig(const Config: TConnectionConfig);
    
    // Creación de objetos de datos
    function CreateQuery: TFDQuery; overload;
    function CreateQuery(const SQL: string): TFDQuery; overload;
    function CreateCommand: TFDCommand; overload;
    function CreateCommand(const SQL: string): TFDCommand; overload;
    function CreateStoredProc(const ProcName: string): TFDStoredProc;
    
    // Gestión de transacciones
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function InTransaction: Boolean;
    
    // Ejecución directa de comandos
    function ExecuteScalar(const SQL: string): Variant; overload;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant; overload;
    function ExecuteNonQuery(const SQL: string): Integer; overload;
    function ExecuteNonQuery(const SQL: string; const Params: array of Variant): Integer; overload;
    
    // Información de la conexión
    function GetDatabaseType: TDatabaseType;
    function GetServerVersion: string;
    function GetClientVersion: string;
    function GetLastInsertId: Int64;
    
    // Testing y diagnóstico
    function TestConnection: Boolean; overload;
    function TestConnection(out ErrorMessage: string): Boolean; overload;
    function GetConnectionInfo: string;
    
    // Utilidades
    function QuoteIdentifier(const Identifier: string): string;
    function FormatDateTime(const DateTime: TDateTime): string;
    function GetSQLForLimit(const SQL: string; Limit, Offset: Integer): string;
    
    // Eventos
    procedure SetOnConnectionLost(const Handler: TNotifyEvent);
    procedure SetOnConnectionRestored(const Handler: TNotifyEvent);
    procedure SetOnError(const Handler: TDataSetErrorEvent);
  end;

implementation

{ TConnectionConfig }

class function TConnectionConfig.Default: TConnectionConfig;
begin
  Result.DatabaseType := dtSQLServer;
  Result.Server := 'localhost';
  Result.Port := 1433;
  Result.Database := 'OrionSoft';
  Result.Username := 'sa';
  Result.Password := '';
  Result.ConnectionTimeout := 30;
  Result.CommandTimeout := 30;
  Result.MaxPoolSize := 100;
  Result.MinPoolSize := 5;
  Result.Charset := 'UTF8';
  Result.Options := '';
end;

class function TConnectionConfig.SQLServer(const AServer, ADatabase, AUsername, APassword: string): TConnectionConfig;
begin
  Result := Default;
  Result.DatabaseType := dtSQLServer;
  Result.Server := AServer;
  Result.Database := ADatabase;
  Result.Username := AUsername;
  Result.Password := APassword;
  Result.Port := 1433;
end;

class function TConnectionConfig.MySQL(const AServer, ADatabase, AUsername, APassword: string; APort: Integer): TConnectionConfig;
begin
  Result := Default;
  Result.DatabaseType := dtMySQL;
  Result.Server := AServer;
  Result.Database := ADatabase;
  Result.Username := AUsername;
  Result.Password := APassword;
  Result.Port := APort;
  Result.Charset := 'utf8mb4';
end;

class function TConnectionConfig.PostgreSQL(const AServer, ADatabase, AUsername, APassword: string; APort: Integer): TConnectionConfig;
begin
  Result := Default;
  Result.DatabaseType := dtPostgreSQL;
  Result.Server := AServer;
  Result.Database := ADatabase;
  Result.Username := AUsername;
  Result.Password := APassword;
  Result.Port := APort;
  Result.Charset := 'UTF8';
end;

class function TConnectionConfig.SQLite(const ADatabaseFile: string): TConnectionConfig;
begin
  Result := Default;
  Result.DatabaseType := dtSQLite;
  Result.Server := '';
  Result.Database := ADatabaseFile;
  Result.Username := '';
  Result.Password := '';
  Result.Port := 0;
end;

end.
