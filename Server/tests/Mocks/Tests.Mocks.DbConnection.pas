unit Tests.Mocks.DbConnection;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.Comp.Client,
  FireDAC.Comp.DataSet,
  FireDAC.Stan.StorageJSON,
  Data.DB,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TMockDbConnection = class(TInterfacedObject, IDbConnection)
  private
    FIsConnected: Boolean;
    FShouldFailOnNextOperation: Boolean;
    FLastMethodCalled: string;
    FCallCount: Integer;
    FConfig: TConnectionConfig;
    FInTransaction: Boolean;
    
  public
    constructor Create;
    
    // IDbConnection implementation
    function IsConnected: Boolean;
    procedure Connect;
    procedure Disconnect;
    function GetConnectionState: TConnectionState;
    function GetConnectionConfig: TConnectionConfig;
    procedure SetConnectionConfig(const Config: TConnectionConfig);
    
    function CreateQuery: TFDQuery; overload;
    function CreateQuery(const SQL: string): TFDQuery; overload;
    function CreateCommand: TFDCommand; overload;
    function CreateCommand(const SQL: string): TFDCommand; overload;
    function CreateStoredProc(const ProcName: string): TFDStoredProc;
    
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function InTransaction: Boolean;
    
    function ExecuteQuery(const SQL: string): TFDQuery;
    function ExecuteScalar(const SQL: string): Variant; overload;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Variant; overload;
    function ExecuteNonQuery(const SQL: string): Integer; overload;
    function ExecuteNonQuery(const SQL: string; const Params: array of Variant): Integer; overload;
    
    function GetDatabaseType: TDatabaseType;
    function GetServerVersion: string;
    function GetClientVersion: string;
    function GetLastInsertId: Int64;
    
    function TestConnection: Boolean; overload;
    function TestConnection(out ErrorMessage: string): Boolean; overload;
    function GetConnectionInfo: string;
    
    function QuoteIdentifier(const Identifier: string): string;
    function FormatDateTime(const DateTime: TDateTime): string;
    function GetSQLForLimit(const SQL: string; Limit, Offset: Integer): string;
    
    procedure SetOnConnectionLost(const Handler: TNotifyEvent);
    procedure SetOnConnectionRestored(const Handler: TNotifyEvent);
    procedure SetOnError(const Handler: TDataSetErrorEvent);
    
    // Mock-specific methods for testing
    procedure SetShouldFailOnNextOperation(ShouldFail: Boolean);
    function GetLastMethodCalled: string;
    function GetCallCount: Integer;
    procedure ResetCallCount;
    procedure SimulateConnectionFailure;
  end;

implementation

{ TMockDbConnection }

constructor TMockDbConnection.Create;
begin
  inherited Create;
  FIsConnected := False;
  FShouldFailOnNextOperation := False;
  FLastMethodCalled := '';
  FCallCount := 0;
  FConfig := TConnectionConfig.Default;
  FInTransaction := False;
end;

function TMockDbConnection.IsConnected: Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'IsConnected';
  Result := FIsConnected;
end;

procedure TMockDbConnection.Connect;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'Connect';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - Connect');
  end;
  
  FIsConnected := True;
end;

procedure TMockDbConnection.Disconnect;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'Disconnect';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - Disconnect');
  end;
  
  FIsConnected := False;
end;

function TMockDbConnection.CreateQuery: TFDQuery;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CreateQuery';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - CreateQuery');
  end;
  
  // Return a simple TFDQuery for testing
  // In real tests, you might want to use a more sophisticated mock
  Result := TFDQuery.Create(nil);
end;

procedure TMockDbConnection.BeginTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'BeginTransaction';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - BeginTransaction');
  end;
  
  FInTransaction := True;
end;

procedure TMockDbConnection.CommitTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CommitTransaction';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - CommitTransaction');
  end;
  
  FInTransaction := False;
end;

procedure TMockDbConnection.RollbackTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'RollbackTransaction';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - RollbackTransaction');
  end;
  
  FInTransaction := False;
end;

function TMockDbConnection.InTransaction: Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'InTransaction';
  Result := FInTransaction;
end;

function TMockDbConnection.ExecuteQuery(const SQL: string): TFDQuery;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteQuery';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteQuery');
  end;
  
  Result := TFDQuery.Create(nil);
end;

function TMockDbConnection.ExecuteScalar(const SQL: string): Variant;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteScalar';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteScalar');
  end;
  
  // Return a default value for testing
  Result := 0;
end;

function TMockDbConnection.ExecuteNonQuery(const SQL: string): Integer;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteNonQuery';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteNonQuery');
  end;
  
  Result := 1; // Mock result - 1 row affected
end;

// Mock-specific methods
procedure TMockDbConnection.SetShouldFailOnNextOperation(ShouldFail: Boolean);
begin
  FShouldFailOnNextOperation := ShouldFail;
end;

function TMockDbConnection.GetLastMethodCalled: string;
begin
  Result := FLastMethodCalled;
end;

function TMockDbConnection.GetCallCount: Integer;
begin
  Result := FCallCount;
end;

procedure TMockDbConnection.ResetCallCount;
begin
  FCallCount := 0;
end;

procedure TMockDbConnection.SimulateConnectionFailure;
begin
  FIsConnected := False;
  FShouldFailOnNextOperation := True;
end;

// Missing method implementations

function TMockDbConnection.GetConnectionState: TConnectionState;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetConnectionState';
  if FIsConnected then
    Result := csConnected
  else
    Result := csDisconnected;
end;

function TMockDbConnection.GetConnectionConfig: TConnectionConfig;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetConnectionConfig';
  Result := FConfig;
end;

procedure TMockDbConnection.SetConnectionConfig(const Config: TConnectionConfig);
begin
  Inc(FCallCount);
  FLastMethodCalled := 'SetConnectionConfig';
  FConfig := Config;
end;

function TMockDbConnection.CreateQuery(const SQL: string): TFDQuery;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CreateQuery(SQL)';
  Result := TFDQuery.Create(nil);
  Result.SQL.Text := SQL;
end;

function TMockDbConnection.CreateCommand: TFDCommand;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CreateCommand';
  Result := TFDCommand.Create(nil);
end;

function TMockDbConnection.CreateCommand(const SQL: string): TFDCommand;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CreateCommand(SQL)';
  Result := TFDCommand.Create(nil);
  Result.CommandText.Text := SQL;
end;

function TMockDbConnection.CreateStoredProc(const ProcName: string): TFDStoredProc;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CreateStoredProc';
  Result := TFDStoredProc.Create(nil);
  Result.StoredProcName := ProcName;
end;

function TMockDbConnection.ExecuteScalar(const SQL: string; const Params: array of Variant): Variant;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteScalar(params)';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteScalar');
  end;
  
  Result := 0; // Mock result
end;

function TMockDbConnection.ExecuteNonQuery(const SQL: string; const Params: array of Variant): Integer;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteNonQuery(params)';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteNonQuery');
  end;
  
  Result := 1; // Mock result
end;

function TMockDbConnection.GetDatabaseType: TDatabaseType;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetDatabaseType';
  Result := FConfig.DatabaseType;
end;

function TMockDbConnection.GetServerVersion: string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetServerVersion';
  Result := 'Mock Server Version 1.0';
end;

function TMockDbConnection.GetClientVersion: string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetClientVersion';
  Result := 'Mock Client Version 1.0';
end;

function TMockDbConnection.GetLastInsertId: Int64;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetLastInsertId';
  Result := 1; // Mock ID
end;

function TMockDbConnection.TestConnection: Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'TestConnection';
  Result := not FShouldFailOnNextOperation;
end;

function TMockDbConnection.TestConnection(out ErrorMessage: string): Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'TestConnection(ErrorMessage)';
  if FShouldFailOnNextOperation then
  begin
    Result := False;
    ErrorMessage := 'Mock connection test failure';
  end
  else
  begin
    Result := True;
    ErrorMessage := '';
  end;
end;

function TMockDbConnection.GetConnectionInfo: string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetConnectionInfo';
  Result := Format('Mock Connection: %s@%s', [FConfig.Database, FConfig.Server]);
end;

function TMockDbConnection.QuoteIdentifier(const Identifier: string): string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'QuoteIdentifier';
  Result := '[' + Identifier + ']'; // SQL Server style
end;

function TMockDbConnection.FormatDateTime(const DateTime: TDateTime): string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'FormatDateTime';
  Result := System.SysUtils.FormatDateTime('yyyy-mm-dd hh:nn:ss', DateTime);
end;

function TMockDbConnection.GetSQLForLimit(const SQL: string; Limit, Offset: Integer): string;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetSQLForLimit';
  // Mock implementation - SQL Server style
  Result := SQL + Format(' OFFSET %d ROWS FETCH NEXT %d ROWS ONLY', [Offset, Limit]);
end;

procedure TMockDbConnection.SetOnConnectionLost(const Handler: TNotifyEvent);
begin
  Inc(FCallCount);
  FLastMethodCalled := 'SetOnConnectionLost';
  // Mock - do nothing
end;

procedure TMockDbConnection.SetOnConnectionRestored(const Handler: TNotifyEvent);
begin
  Inc(FCallCount);
  FLastMethodCalled := 'SetOnConnectionRestored';
  // Mock - do nothing
end;

procedure TMockDbConnection.SetOnError(const Handler: TDataSetErrorEvent);
begin
  Inc(FCallCount);
  FLastMethodCalled := 'SetOnError';
  // Mock - do nothing
end;

end.
