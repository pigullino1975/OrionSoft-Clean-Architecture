unit Tests.Mocks.Logger;

{$INCLUDE '..\..\..\src\Core\Common\OrionSoft.Core.Common.Compiler.inc'}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Common.Types;

type
  TLogEntry = record
    Level: TLogLevel;
    Message: string;
    Context: TLogContext;
    Exception: Exception;
    Timestamp: TDateTime;
  end;

  TMockLogger = class(TInterfacedObject, ILogger)
  private
    FLogEntries: TList<TLogEntry>;
    FLogLevel: TLogLevel;
    FCorrelationId: string;
    FUserId: string;
    FSessionId: string;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // ILogger implementation
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
    
    // Domain-specific methods
    procedure LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = '');
    procedure LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = '');
    procedure LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = '');
    procedure LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
    
    // Configuration
    procedure SetLogLevel(Level: TLogLevel);
    function GetLogLevel: TLogLevel;
    
    // Control de contexto
    procedure SetCorrelationId(const CorrelationId: string);
    procedure SetUserId(const UserId: string);
    procedure SetSessionId(const SessionId: string);
    
    // Mock-specific methods for testing
    function GetLogEntriesCount: Integer;
    function GetLogEntry(Index: Integer): TLogEntry;
    function HasLogEntry(Level: TLogLevel; const MessageSubstring: string): Boolean;
    procedure ClearLogs;
    function GetLastLogEntry: TLogEntry;
  end;

implementation

{ TMockLogger }

constructor TMockLogger.Create;
begin
  inherited Create;
  FLogEntries := TList<TLogEntry>.Create;
  FLogLevel := TLogLevel.Debug;
end;

destructor TMockLogger.Destroy;
begin
  FLogEntries.Free;
  inherited Destroy;
end;

procedure TMockLogger.Debug(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Debug');
  Debug(Message, Context);
end;

procedure TMockLogger.Debug(const Message: string; const Args: array of const);
begin
  Debug(Format(Message, Args));
end;

procedure TMockLogger.Debug(const Message: string; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Debug;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := nil;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Info(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Info');
  Info(Message, Context);
end;

procedure TMockLogger.Info(const Message: string; const Args: array of const);
begin
  Info(Format(Message, Args));
end;

procedure TMockLogger.Info(const Message: string; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Information;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := nil;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Warning(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Warning');
  Warning(Message, Context);
end;

procedure TMockLogger.Warning(const Message: string; const Args: array of const);
begin
  Warning(Format(Message, Args));
end;

procedure TMockLogger.Warning(const Message: string; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Warning;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := nil;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Error(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Error');
  Error(Message, Context);
end;

procedure TMockLogger.Error(const Message: string; const Args: array of const);
begin
  Error(Format(Message, Args));
end;

procedure TMockLogger.Error(const Message: string; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Error;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := nil;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Error(const Message: string; E: Exception);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Error');
  Error(Message, E, Context);
end;

procedure TMockLogger.Error(const Message: string; E: Exception; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Error;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := E;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Fatal(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Fatal');
  Fatal(Message, Context);
end;

procedure TMockLogger.Fatal(const Message: string; const Args: array of const);
begin
  Fatal(Format(Message, Args));
end;

procedure TMockLogger.Fatal(const Message: string; const Context: TLogContext);
var
  Entry: TLogEntry;
begin
  Entry.Level := TLogLevel.Fatal;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := nil;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

procedure TMockLogger.Fatal(const Message: string; E: Exception);
var
  Entry: TLogEntry;
  Context: TLogContext;
begin
  Context := CreateLogContext('Mock', 'Fatal');
  Entry.Level := TLogLevel.Fatal;
  Entry.Message := Message;
  Entry.Context := Context;
  Entry.Exception := E;
  Entry.Timestamp := Now;
  FLogEntries.Add(Entry);
end;

// Domain-specific methods
procedure TMockLogger.LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string);
var
  Message: string;
begin
  Message := Format('Authentication %s for user: %s', [
    IfThen(Success, 'SUCCESS', 'FAILED'), UserName]);
  if Success then
    Info(Message)
  else
    Warning(Message);
end;

procedure TMockLogger.LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string);
var
  Message: string;
begin
  Message := Format('Business Rule %s: %s on %s[%s]. %s', [
    IfThen(Success, 'OK', 'VIOLATION'), RuleName, EntityType, EntityId, Details]);
  if Success then
    Info(Message)
  else
    Warning(Message);
end;

procedure TMockLogger.LogPerformance(const Operation: string; DurationMs: Integer; const Details: string);
var
  Message: string;
begin
  Message := Format('Performance: %s took %d ms. %s', [Operation, DurationMs, Details]);
  Info(Message);
end;

procedure TMockLogger.LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
var
  Message: string;
begin
  Message := Format('Database: %s on %s affected %d records in %d ms', [
    Operation, TableName, RecordsAffected, DurationMs]);
  Info(Message);
end;

// Configuration
procedure TMockLogger.SetLogLevel(Level: TLogLevel);
begin
  FLogLevel := Level;
end;

function TMockLogger.GetLogLevel: TLogLevel;
begin
  Result := FLogLevel;
end;

// Control de contexto
procedure TMockLogger.SetCorrelationId(const CorrelationId: string);
begin
  FCorrelationId := CorrelationId;
end;

procedure TMockLogger.SetUserId(const UserId: string);
begin
  FUserId := UserId;
end;

procedure TMockLogger.SetSessionId(const SessionId: string);
begin
  FSessionId := SessionId;
end;

// Mock-specific methods for testing
function TMockLogger.GetLogEntriesCount: Integer;
begin
  Result := FLogEntries.Count;
end;

function TMockLogger.GetLogEntry(Index: Integer): TLogEntry;
begin
  Result := FLogEntries[Index];
end;

function TMockLogger.HasLogEntry(Level: TLogLevel; const MessageSubstring: string): Boolean;
var
  Entry: TLogEntry;
begin
  Result := False;
  for Entry in FLogEntries do
  begin
    if (Entry.Level = Level) and (Pos(MessageSubstring, Entry.Message) > 0) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TMockLogger.ClearLogs;
begin
  FLogEntries.Clear;
end;

function TMockLogger.GetLastLogEntry: TLogEntry;
begin
  if FLogEntries.Count > 0 then
    Result := FLogEntries.Last
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Level := TLogLevel.Debug;
    Result.Message := '';
  end;
end;

end.
