unit OrionSoft.Infrastructure.Data.Context.FireDACConnection;

{*
  Implementación concreta de IDbConnection usando FireDAC
  Soporte completo para múltiples bases de datos
*}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Variants,
  FireDAC.Comp.Client,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Error,
  FireDAC.Phys,
  FireDAC.Phys.ODBCBase,
  FireDAC.Phys.MSSQL,
  FireDAC.Phys.MySQL,
  FireDAC.Phys.PG,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper,
  FireDAC.DApt,
  FireDAC.UI.Intf,
  FireDAC.VCLUI.Wait,
  FireDAC.Comp.UI,
  Data.DB,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TFireDACConnection = class(TInterfacedObject, IDbConnection)
  private
    FConnection: TFDConnection;
    FConfig: TConnectionConfig;
    FTransactionLevel: Integer;
    FOnConnectionLost: TNotifyEvent;
    FOnConnectionRestored: TNotifyEvent;
    FOnError: TDataSetErrorEvent;
    
    procedure ConfigureConnection;
    function GetDriverName(DatabaseType: TDatabaseType): string;
    procedure SetConnectionParameters;
    procedure HandleConnectionError(E: Exception);
    function IsConnectionError(E: Exception): Boolean;
    procedure AttemptReconnection;
    
  protected
    // Eventos de FireDAC
    procedure OnConnectionLostEvent(Sender: TObject);
    procedure OnConnectionRestoredEvent(Sender: TObject);
    procedure OnErrorEvent(ASender, AInitiator: TObject; var AException: Exception);
    
  public
    constructor Create(const Config: TConnectionConfig);
    destructor Destroy; override;
    
    // IDbConnection - Gestión de conexión
    procedure Connect;
    procedure Disconnect;
    function IsConnected: Boolean;
    function GetConnectionState: TConnectionState;
    function GetConnectionConfig: TConnectionConfig;
    procedure SetConnectionConfig(const Config: TConnectionConfig);
    
    // IDbConnection - Creación de objetos
    function CreateQuery: TFDQuery; overload;
    function CreateQuery(const SQL: string): TFDQuery; overload;
    function CreateCommand: TFDCommand; overload;
    function CreateCommand(const SQL: string): TFDCommand; overload;
    function CreateStoredProc(const ProcName: string): TFDStoredProc;
    
    // IDbConnection - Transacciones
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function InTransaction: Boolean;
    
    // IDbConnection - Ejecución directa
    function ExecuteScalar(const SQL: string): Variant; overload;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant; overload;
    function ExecuteNonQuery(const SQL: string): Integer; overload;
    function ExecuteNonQuery(const SQL: string; const Params: array of Variant): Integer; overload;
    
    // IDbConnection - Información
    function GetDatabaseType: TDatabaseType;
    function GetServerVersion: string;
    function GetClientVersion: string;
    function GetLastInsertId: Int64;
    
    // IDbConnection - Testing
    function TestConnection: Boolean; overload;
    function TestConnection(out ErrorMessage: string): Boolean; overload;
    function GetConnectionInfo: string;
    
    // IDbConnection - Utilidades
    function QuoteIdentifier(const Identifier: string): string;
    function FormatDateTime(const DateTime: TDateTime): string;
    function GetSQLForLimit(const SQL: string; Limit, Offset: Integer): string;
    
    // IDbConnection - Eventos
    procedure SetOnConnectionLost(const Handler: TNotifyEvent);
    procedure SetOnConnectionRestored(const Handler: TNotifyEvent);
    procedure SetOnError(const Handler: TDataSetErrorEvent);
  end;

implementation

uses
  System.StrUtils,
  System.DateUtils;

{ TFireDACConnection }

constructor TFireDACConnection.Create(const Config: TConnectionConfig);
begin
  inherited Create;
  
  FConnection := TFDConnection.Create(nil);
  FConfig := Config;
  FTransactionLevel := 0;
  
  // Configurar eventos
  FConnection.OnLost := OnConnectionLostEvent;
  FConnection.OnRestored := OnConnectionRestoredEvent;
  FConnection.OnError := OnErrorEvent;
  
  ConfigureConnection;
end;

destructor TFireDACConnection.Destroy;
begin
  try
    if InTransaction then
    begin
      try
        RollbackTransaction;
      except
        // Ignorar errores durante rollback en destructor
      end;
    end;
    
    if Assigned(FConnection) and FConnection.Connected then
    begin
      try
        FConnection.Close;
      except
        // Ignorar errores durante cierre en destructor
      end;
    end;
  finally
    FreeAndNil(FConnection);
    inherited Destroy;
  end;
end;

procedure TFireDACConnection.ConfigureConnection;
begin
  if not Assigned(FConnection) then
    Exit;
    
  FConnection.DriverName := GetDriverName(FConfig.DatabaseType);
  SetConnectionParameters;
  
  // Configuración general
  FConnection.LoginPrompt := False;
  FConnection.ConnectedStoredUsage := [];
  FConnection.ResourceOptions.AutoReconnect := True;
  FConnection.ResourceOptions.KeepConnection := True;
  
  // Timeouts
  FConnection.ResourceOptions.CmdExecTimeout := FConfig.CommandTimeout * 1000; // milisegundos
  FConnection.ConnectedStoredUsage := []; // No usar stored connections para esta demo
end;

function TFireDACConnection.GetDriverName(DatabaseType: TDatabaseType): string;
begin
  case DatabaseType of
    dtSQLServer: Result := 'MSSQL';
    dtMySQL: Result := 'MySQL';
    dtPostgreSQL: Result := 'PG';
    dtSQLite: Result := 'SQLite';
    dtOracle: Result := 'Ora';
    dtFirebird: Result := 'FB';
  else
    Result := 'MSSQL'; // Default
  end;
end;

procedure TFireDACConnection.SetConnectionParameters;
begin
  FConnection.Params.Clear;
  
  case FConfig.DatabaseType of
    dtSQLServer:
    begin
      FConnection.Params.Add('Server=' + FConfig.Server);
      FConnection.Params.Add('Database=' + FConfig.Database);
      if FConfig.Username <> '' then
      begin
        FConnection.Params.Add('User_Name=' + FConfig.Username);
        FConnection.Params.Add('Password=' + FConfig.Password);
      end
      else
      begin
        FConnection.Params.Add('OSAuthent=Yes');
      end;
      FConnection.Params.Add('ApplicationName=OrionSoft');
    end;
    
    dtMySQL:
    begin
      FConnection.Params.Add('Server=' + FConfig.Server);
      FConnection.Params.Add('Port=' + IntToStr(FConfig.Port));
      FConnection.Params.Add('Database=' + FConfig.Database);
      FConnection.Params.Add('User_Name=' + FConfig.Username);
      FConnection.Params.Add('Password=' + FConfig.Password);
      FConnection.Params.Add('CharacterSet=' + FConfig.Charset);
    end;
    
    dtPostgreSQL:
    begin
      FConnection.Params.Add('Server=' + FConfig.Server);
      FConnection.Params.Add('Port=' + IntToStr(FConfig.Port));
      FConnection.Params.Add('Database=' + FConfig.Database);
      FConnection.Params.Add('User_Name=' + FConfig.Username);
      FConnection.Params.Add('Password=' + FConfig.Password);
      FConnection.Params.Add('CharacterSet=' + FConfig.Charset);
    end;
    
    dtSQLite:
    begin
      FConnection.Params.Add('Database=' + FConfig.Database);
      if not FileExists(FConfig.Database) then
        FConnection.Params.Add('OpenMode=CreateUTF8');
    end;
  end;
end;

procedure TFireDACConnection.Connect;
begin
  try
    if not FConnection.Connected then
    begin
      ConfigureConnection;
      FConnection.Open;
    end;
  except
    on E: Exception do
    begin
      HandleConnectionError(E);
      raise;
    end;
  end;
end;

procedure TFireDACConnection.Disconnect;
begin
  try
    if FConnection.Connected then
    begin
      // Rollback cualquier transacción pendiente
      while InTransaction do
        RollbackTransaction;
        
      FConnection.Close;
    end;
  except
    on E: Exception do
    begin
      // Log error pero no re-raise en disconnect
      // En un sistema real, esto iría al logger
    end;
  end;
end;

function TFireDACConnection.IsConnected: Boolean;
begin
  Result := Assigned(FConnection) and FConnection.Connected;
end;

function TFireDACConnection.GetConnectionState: TConnectionState;
begin
  if not Assigned(FConnection) then
    Result := csError
  else if FConnection.Connected then
    Result := csConnected
  else
    Result := csDisconnected;
end;

function TFireDACConnection.GetConnectionConfig: TConnectionConfig;
begin
  Result := FConfig;
end;

procedure TFireDACConnection.SetConnectionConfig(const Config: TConnectionConfig);
var
  WasConnected: Boolean;
begin
  WasConnected := IsConnected;
  
  if WasConnected then
    Disconnect;
    
  FConfig := Config;
  
  if WasConnected then
    Connect;
end;

function TFireDACConnection.CreateQuery: TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := FConnection;
end;

function TFireDACConnection.CreateQuery(const SQL: string): TFDQuery;
begin
  Result := CreateQuery;
  Result.SQL.Text := SQL;
end;

function TFireDACConnection.CreateCommand: TFDCommand;
begin
  Result := TFDCommand.Create(nil);
  Result.Connection := FConnection;
end;

function TFireDACConnection.CreateCommand(const SQL: string): TFDCommand;
begin
  Result := CreateCommand;
  Result.CommandText.Text := SQL;
end;

function TFireDACConnection.CreateStoredProc(const ProcName: string): TFDStoredProc;
begin
  Result := TFDStoredProc.Create(nil);
  Result.Connection := FConnection;
  Result.StoredProcName := ProcName;
end;

procedure TFireDACConnection.BeginTransaction;
begin
  if not IsConnected then
    Connect;
    
  if FTransactionLevel = 0 then
    FConnection.StartTransaction;
    
  Inc(FTransactionLevel);
end;

procedure TFireDACConnection.CommitTransaction;
begin
  if FTransactionLevel <= 0 then
    raise Exception.Create('No active transaction to commit');
    
  Dec(FTransactionLevel);
  
  if FTransactionLevel = 0 then
    FConnection.Commit;
end;

procedure TFireDACConnection.RollbackTransaction;
begin
  if FTransactionLevel <= 0 then
    raise Exception.Create('No active transaction to rollback');
    
  Dec(FTransactionLevel);
  
  if FTransactionLevel = 0 then
    FConnection.Rollback;
end;

function TFireDACConnection.InTransaction: Boolean;
begin
  Result := FTransactionLevel > 0;
end;

function TFireDACConnection.ExecuteScalar(const SQL: string): Variant;
var
  Query: TFDQuery;
begin
  Query := CreateQuery(SQL);
  try
    Query.Open;
    if not Query.Eof then
      Result := Query.Fields[0].Value
    else
      Result := Null;
  finally
    Query.Free;
  end;
end;

function TFireDACConnection.ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := CreateQuery(SQL);
  try
    for I := Low(Params) to High(Params) do
      Query.Params[I].Value := Params[I];
      
    Query.Open;
    if not Query.Eof then
      Result := Query.Fields[0].Value
    else
      Result := Null;
  finally
    Query.Free;
  end;
end;

function TFireDACConnection.ExecuteNonQuery(const SQL: string): Integer;
var
  Query: TFDQuery;
begin
  Query := CreateQuery(SQL);
  try
    Query.ExecSQL;
    Result := Query.RowsAffected;
  finally
    Query.Free;
  end;
end;

function TFireDACConnection.ExecuteNonQuery(const SQL: string; const Params: array of Variant): Integer;
var
  Query: TFDQuery;
  I: Integer;
begin
  Query := CreateQuery(SQL);
  try
    for I := Low(Params) to High(Params) do
      Query.Params[I].Value := Params[I];
      
    Query.ExecSQL;
    Result := Query.RowsAffected;
  finally
    Query.Free;
  end;
end;

function TFireDACConnection.GetDatabaseType: TDatabaseType;
begin
  Result := FConfig.DatabaseType;
end;

function TFireDACConnection.GetServerVersion: string;
begin
  try
    if IsConnected then
      Result := 'Server connected' // Simplificado por compatibilidad
    else
      Result := 'Not connected';
  except
    Result := 'Unknown';
  end;
end;

function TFireDACConnection.GetClientVersion: string;
begin
  try
    if IsConnected then
      Result := 'Client connected' // Simplificado por compatibilidad
    else
      Result := 'Not connected';
  except
    Result := 'Unknown';
  end;
end;

function TFireDACConnection.GetLastInsertId: Int64;
begin
  case FConfig.DatabaseType of
    dtSQLServer: Result := ExecuteScalar('SELECT @@IDENTITY');
    dtMySQL: Result := ExecuteScalar('SELECT LAST_INSERT_ID()');
    dtPostgreSQL: Result := ExecuteScalar('SELECT lastval()');
    dtSQLite: Result := ExecuteScalar('SELECT last_insert_rowid()');
  else
    Result := 0;
  end;
end;

function TFireDACConnection.TestConnection: Boolean;
var
  ErrorMessage: string;
begin
  Result := TestConnection(ErrorMessage);
end;

function TFireDACConnection.TestConnection(out ErrorMessage: string): Boolean;
begin
  Result := False;
  ErrorMessage := '';
  
  try
    if not IsConnected then
      Connect;
      
    // Test simple query
    ExecuteScalar('SELECT 1');
    Result := True;
    
  except
    on E: Exception do
    begin
      ErrorMessage := E.Message;
      Result := False;
    end;
  end;
end;

function TFireDACConnection.GetConnectionInfo: string;
begin
  if IsConnected then
  begin
    Result := Format('Connected to %s on %s:%d - Database: %s - User: %s', [
      GetDriverName(FConfig.DatabaseType),
      FConfig.Server,
      FConfig.Port,
      FConfig.Database,
      FConfig.Username
    ]);
  end
  else
  begin
    Result := Format('Disconnected from %s - Database: %s', [
      GetDriverName(FConfig.DatabaseType),
      FConfig.Database
    ]);
  end;
end;

function TFireDACConnection.QuoteIdentifier(const Identifier: string): string;
begin
  case FConfig.DatabaseType of
    dtSQLServer: Result := '[' + Identifier + ']';
    dtMySQL: Result := '`' + Identifier + '`';
    dtPostgreSQL: Result := '"' + Identifier + '"';
    dtSQLite: Result := '[' + Identifier + ']';
  else
    Result := Identifier;
  end;
end;

function TFireDACConnection.FormatDateTime(const DateTime: TDateTime): string;
begin
  case FConfig.DatabaseType of
    dtSQLServer: Result := QuotedStr(System.SysUtils.FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime));
    dtMySQL: Result := QuotedStr(System.SysUtils.FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime));
    dtPostgreSQL: Result := QuotedStr(System.SysUtils.FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime));
    dtSQLite: Result := QuotedStr(System.SysUtils.FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime));
  else
    Result := QuotedStr(DateTimeToStr(DateTime));
  end;
end;

function TFireDACConnection.GetSQLForLimit(const SQL: string; Limit, Offset: Integer): string;
begin
  case FConfig.DatabaseType of
    dtSQLServer:
    begin
      if Offset > 0 then
        Result := SQL + Format(' ORDER BY (SELECT 1) OFFSET %d ROWS FETCH NEXT %d ROWS ONLY', [Offset, Limit])
      else
        Result := SQL + Format(' ORDER BY (SELECT 1) OFFSET 0 ROWS FETCH NEXT %d ROWS ONLY', [Limit]);
    end;
    
    dtMySQL, dtPostgreSQL, dtSQLite:
    begin
      if Offset > 0 then
        Result := SQL + Format(' LIMIT %d OFFSET %d', [Limit, Offset])
      else
        Result := SQL + Format(' LIMIT %d', [Limit]);
    end;
    
  else
    Result := SQL; // Sin soporte de LIMIT
  end;
end;

procedure TFireDACConnection.SetOnConnectionLost(const Handler: TNotifyEvent);
begin
  FOnConnectionLost := Handler;
end;

procedure TFireDACConnection.SetOnConnectionRestored(const Handler: TNotifyEvent);
begin
  FOnConnectionRestored := Handler;
end;

procedure TFireDACConnection.SetOnError(const Handler: TDataSetErrorEvent);
begin
  FOnError := Handler;
end;

procedure TFireDACConnection.OnConnectionLostEvent(Sender: TObject);
begin
  if Assigned(FOnConnectionLost) then
    FOnConnectionLost(Self);
end;

procedure TFireDACConnection.OnConnectionRestoredEvent(Sender: TObject);
begin
  if Assigned(FOnConnectionRestored) then
    FOnConnectionRestored(Self);
end;

procedure TFireDACConnection.OnErrorEvent(ASender, AInitiator: TObject; var AException: Exception);
begin
  // Simplificado para compatibilidad
  if IsConnectionError(AException) then
    AttemptReconnection;
end;

procedure TFireDACConnection.HandleConnectionError(E: Exception);
begin
  // En un sistema real, esto iría al logger del sistema
  // Por ahora, solo re-raise la excepción
end;

function TFireDACConnection.IsConnectionError(E: Exception): Boolean;
begin
  // Determinar si el error es de conexión perdida
  Result := (E is EDatabaseError) and 
            (Pos('connection', LowerCase(E.Message)) > 0);
end;

procedure TFireDACConnection.AttemptReconnection;
begin
  try
    if FConnection.Connected then
      FConnection.Close;
      
    FConnection.Open;
  except
    // Ignorar errores de reconexión - se maneja en el nivel superior
  end;
end;

end.
