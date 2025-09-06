unit Tests.Mocks.MockLogger;

{*
  Mock implementation de ILogger para testing
  Permite verificar las llamadas de logging en tests unitarios
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Common.Types;

type
  // Entrada de log para testing
  TLogEntry = record
    Level: TLogLevel;
    Message: string;
    Context: TLogContext;
    Exception: string;
    Timestamp: TDateTime;
    
    constructor Create(ALevel: TLogLevel; const AMessage: string; 
      const AContext: TLogContext; E: Exception = nil);
  end;

  // Mock Logger para testing
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
    
    procedure Critical(const Message: string); overload;
    procedure Critical(const Message: string; const Args: array of const); overload;
    procedure Critical(const Message: string; const Context: TLogContext); overload;
    procedure Critical(const Message: string; E: Exception); overload;
    
    procedure LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = '');
    procedure LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = '');
    procedure LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = '');
    procedure LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
    
    procedure SetLogLevel(Level: TLogLevel);
    function GetLogLevel: TLogLevel;
    
    procedure SetCorrelationId(const CorrelationId: string);
    procedure SetUserId(const UserId: string);
    procedure SetSessionId(const SessionId: string);
    
    // Testing helpers
    procedure Clear;
    function GetLogCount: Integer;
    function GetLogCount(Level: TLogLevel): Integer;
    function GetLogEntries: TArray<TLogEntry>;
    function GetLastLogEntry: TLogEntry;
    function HasLogEntry(Level: TLogLevel; const MessageContains: string): Boolean;
    function HasErrorWithException(const ExceptionMessage: string): Boolean;
    
    // Verification methods
    procedure VerifyLogged(Level: TLogLevel; const MessageContains: string);
    procedure VerifyNotLogged(Level: TLogLevel; const MessageContains: string);
    procedure VerifyLogCount(ExpectedCount: Integer); overload;
    procedure VerifyLogCount(Level: TLogLevel; ExpectedCount: Integer); overload;
    
    // Properties for testing
    property LogEntries: TList<TLogEntry> read FLogEntries;
  end;

implementation

uses
  System.StrUtils;

{ TLogEntry }

constructor TLogEntry.Create(ALevel: TLogLevel; const AMessage: string; 
  const AContext: TLogContext; E: Exception);
begin
  Level := ALevel;
  Message := AMessage;
  Context := AContext;
  Exception := '';
  if Assigned(E) then
    Exception := E.Message;
  Timestamp := Now;
end;

{ TMockLogger }

constructor TMockLogger.Create;
begin
  FLogEntries := TList<TLogEntry>.Create;
  FLogLevel := llDebug; // Log everything for testing
end;

destructor TMockLogger.Destroy;
begin
  FLogEntries.Free;
  inherited;
end;

procedure TMockLogger.Debug(const Message: string);
begin
  Debug(Message, Default(TLogContext));
end;

procedure TMockLogger.Debug(const Message: string; const Args: array of const);
begin
  Debug(Format(Message, Args));
end;

procedure TMockLogger.Debug(const Message: string; const Context: TLogContext);
begin
  if FLogLevel <= llDebug then
    FLogEntries.Add(TLogEntry.Create(llDebug, Message, Context));
end;

procedure TMockLogger.Info(const Message: string);
begin
  Info(Message, Default(TLogContext));
end;

procedure TMockLogger.Info(const Message: string; const Args: array of const);
begin
  Info(Format(Message, Args));
end;

procedure TMockLogger.Info(const Message: string; const Context: TLogContext);
begin
  if FLogLevel <= llInfo then
    FLogEntries.Add(TLogEntry.Create(llInfo, Message, Context));
end;

procedure TMockLogger.Warning(const Message: string);
begin
  Warning(Message, Default(TLogContext));
end;

procedure TMockLogger.Warning(const Message: string; const Args: array of const);
begin
  Warning(Format(Message, Args));
end;

procedure TMockLogger.Warning(const Message: string; const Context: TLogContext);
begin
  if FLogLevel <= llWarning then
    FLogEntries.Add(TLogEntry.Create(llWarning, Message, Context));
end;

procedure TMockLogger.Error(const Message: string);
begin
  Error(Message, Default(TLogContext));
end;

procedure TMockLogger.Error(const Message: string; const Args: array of const);
begin
  Error(Format(Message, Args));
end;

procedure TMockLogger.Error(const Message: string; const Context: TLogContext);
begin
  if FLogLevel <= llError then
    FLogEntries.Add(TLogEntry.Create(llError, Message, Context));
end;

procedure TMockLogger.Error(const Message: string; E: Exception);
begin
  Error(Message, E, Default(TLogContext));
end;

procedure TMockLogger.Error(const Message: string; E: Exception; const Context: TLogContext);
begin
  if FLogLevel <= llError then
    FLogEntries.Add(TLogEntry.Create(llError, Message, Context, E));
end;

procedure TMockLogger.Critical(const Message: string);
begin
  Critical(Message, Default(TLogContext));
end;

procedure TMockLogger.Critical(const Message: string; const Args: array of const);
begin
  Critical(Format(Message, Args));
end;

procedure TMockLogger.Critical(const Message: string; const Context: TLogContext);
begin
  if FLogLevel <= llCritical then
    FLogEntries.Add(TLogEntry.Create(llCritical, Message, Context));
end;

procedure TMockLogger.Critical(const Message: string; E: Exception);
begin
  if FLogLevel <= llCritical then
    FLogEntries.Add(TLogEntry.Create(llCritical, Message, Default(TLogContext), E));
end;

procedure TMockLogger.LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string);
var
  Message: string;
begin
  if Success then
    Message := Format('Usuario %s autenticado exitosamente. Session: %s', [UserName, SessionId])
  else
    Message := Format('Fallo de autenticación para usuario %s', [UserName]);
    
  Info(Message);
end;

procedure TMockLogger.LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string);
var
  Message: string;
  Level: TLogLevel;
begin
  if Success then
  begin
    Message := Format('Regla de negocio %s aplicada exitosamente para %s (ID: %s)', [RuleName, EntityType, EntityId]);
    Level := llInfo;
  end
  else
  begin
    Message := Format('Regla de negocio %s falló para %s (ID: %s). Detalles: %s', [RuleName, EntityType, EntityId, Details]);
    Level := llWarning;
  end;
  
  if FLogLevel <= Level then
    FLogEntries.Add(TLogEntry.Create(Level, Message, Default(TLogContext)));
end;

procedure TMockLogger.LogPerformance(const Operation: string; DurationMs: Integer; const Details: string);
var
  Message: string;
begin
  Message := Format('Performance: %s completada en %d ms. %s', [Operation, DurationMs, Details]);
  Info(Message);
end;

procedure TMockLogger.LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
var
  Message: string;
begin
  Message := Format('DB Operation: %s en tabla %s. Registros afectados: %d. Duración: %d ms', 
    [Operation, TableName, RecordsAffected, DurationMs]);
  Debug(Message);
end;

procedure TMockLogger.SetLogLevel(Level: TLogLevel);
begin
  FLogLevel := Level;
end;

function TMockLogger.GetLogLevel: TLogLevel;
begin
  Result := FLogLevel;
end;

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

// Testing helpers

procedure TMockLogger.Clear;
begin
  FLogEntries.Clear;
end;

function TMockLogger.GetLogCount: Integer;
begin
  Result := FLogEntries.Count;
end;

function TMockLogger.GetLogCount(Level: TLogLevel): Integer;
var
  Entry: TLogEntry;
begin
  Result := 0;
  for Entry in FLogEntries do
    if Entry.Level = Level then
      Inc(Result);
end;

function TMockLogger.GetLogEntries: TArray<TLogEntry>;
begin
  Result := FLogEntries.ToArray;
end;

function TMockLogger.GetLastLogEntry: TLogEntry;
begin
  if FLogEntries.Count > 0 then
    Result := FLogEntries.Last
  else
    raise Exception.Create('No hay entradas de log');
end;

function TMockLogger.HasLogEntry(Level: TLogLevel; const MessageContains: string): Boolean;
var
  Entry: TLogEntry;
begin
  Result := False;
  for Entry in FLogEntries do
  begin
    if (Entry.Level = Level) and ContainsText(Entry.Message, MessageContains) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TMockLogger.HasErrorWithException(const ExceptionMessage: string): Boolean;
var
  Entry: TLogEntry;
begin
  Result := False;
  for Entry in FLogEntries do
  begin
    if (Entry.Level = llError) and ContainsText(Entry.Exception, ExceptionMessage) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

// Verification methods

procedure TMockLogger.VerifyLogged(Level: TLogLevel; const MessageContains: string);
begin
  if not HasLogEntry(Level, MessageContains) then
    raise Exception.CreateFmt('Expected log entry not found: Level=%s, Message contains "%s"', 
      [LogLevelToString(Level), MessageContains]);
end;

procedure TMockLogger.VerifyNotLogged(Level: TLogLevel; const MessageContains: string);
begin
  if HasLogEntry(Level, MessageContains) then
    raise Exception.CreateFmt('Unexpected log entry found: Level=%s, Message contains "%s"', 
      [LogLevelToString(Level), MessageContains]);
end;

procedure TMockLogger.VerifyLogCount(ExpectedCount: Integer);
begin
  if FLogEntries.Count <> ExpectedCount then
    raise Exception.CreateFmt('Expected %d log entries, but found %d', [ExpectedCount, FLogEntries.Count]);
end;

procedure TMockLogger.VerifyLogCount(Level: TLogLevel; ExpectedCount: Integer);
var
  ActualCount: Integer;
begin
  ActualCount := GetLogCount(Level);
  if ActualCount <> ExpectedCount then
    raise Exception.CreateFmt('Expected %d log entries of level %s, but found %d', 
      [ExpectedCount, LogLevelToString(Level), ActualCount]);
end;

end.
