unit Tests.Mocks.DbConnection;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TMockDbConnection = class(TInterfacedObject, IDbConnection)
  private
    FIsConnected: Boolean;
    FShouldFailOnNextOperation: Boolean;
    FLastMethodCalled: string;
    FCallCount: Integer;
    
  public
    constructor Create;
    
    // IDbConnection implementation
    function IsConnected: Boolean;
    procedure Connect;
    procedure Disconnect;
    
    function CreateQuery: TFDQuery;
    
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function InTransaction: Boolean;
    
    function ExecuteQuery(const SQL: string): TFDQuery;
    function ExecuteScalar(const SQL: string): Variant;
    procedure ExecuteNonQuery(const SQL: string);
    
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
end;

function TMockDbConnection.InTransaction: Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'InTransaction';
  // Simplified - just return false for most tests
  Result := False;
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

procedure TMockDbConnection.ExecuteNonQuery(const SQL: string);
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExecuteNonQuery';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - ExecuteNonQuery');
  end;
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

end.
