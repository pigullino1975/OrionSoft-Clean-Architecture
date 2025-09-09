unit OrionSoft.Infrastructure.Services.FileLogger;

{*
  Implementación concreta del logger usando archivos
  Permite logging a múltiples archivos con rotación automática
*}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.DateUtils,
  System.IOUtils,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Core.Common.Types;

type
  TLogFileSettings = record
    BaseDirectory: string;
    MaxFileSize: Int64; // en bytes
    MaxFiles: Integer;  // cantidad máxima de archivos de rotación
    FlushInterval: Integer; // en milisegundos
    DatePattern: string; // patrón para nombres de archivo con fecha
    
    class function Default: TLogFileSettings; static;
  end;

  TFileLogger = class(TInterfacedObject, ILogger)
  private
    FSettings: TLogFileSettings;
    FCriticalSection: TCriticalSection;
    FCurrentLogFile: string;
    FCurrentFileHandle: TextFile;
    FFileOpen: Boolean;
    FMinLogLevel: TLogLevel;
    FLastFlush: TDateTime;
    FBuffer: TStringList;
    FCorrelationId: string;
    FUserId: string;
    FSessionId: string;
    
    procedure EnsureLogDirectory;
    function GetLogFileName(Level: TLogLevel): string;
    function ShouldRotateFile(const FileName: string): Boolean;
    procedure RotateLogFile(const FileName: string);
    procedure OpenLogFile(const FileName: string);
    procedure CloseLogFile;
    procedure WriteToFile(const LogEntry: string);
    function FormatLogEntry(Level: TLogLevel; const Message: string; const Context: TLogContext; Exception: Exception = nil): string;
    function LogLevelToString(Level: TLogLevel): string;
    procedure FlushIfNeeded;
    
  public
    constructor Create(const Settings: TLogFileSettings; MinLevel: TLogLevel = TLogLevel.Information);
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
    
    // Additional methods
    function IsEnabled(Level: TLogLevel): Boolean;
    procedure Flush;
  end;

  TLoggerFactory = class(TInterfacedObject, ILoggerFactory)
  private
    FSettings: TLogFileSettings;
    FMinLevel: TLogLevel;
    
  public
    constructor Create(const Settings: TLogFileSettings; MinLevel: TLogLevel = TLogLevel.Information);
    
    function CreateLogger(const Name: string): ILogger;
    function GetLogger(const Name: string): ILogger;
  end;

implementation

uses
  System.StrUtils;

{ TLogFileSettings }

class function TLogFileSettings.Default: TLogFileSettings;
begin
  Result.BaseDirectory := TPath.Combine(TPath.GetDocumentsPath, 'OrionSoft\Logs');
  Result.MaxFileSize := 50 * 1024 * 1024; // 50 MB
  Result.MaxFiles := 10;
  Result.FlushInterval := 5000; // 5 segundos
  Result.DatePattern := 'yyyymmdd';
end;

{ TFileLogger }

constructor TFileLogger.Create(const Settings: TLogFileSettings; MinLevel: TLogLevel);
begin
  inherited Create;
  FSettings := Settings;
  FMinLogLevel := MinLevel;
  FCriticalSection := TCriticalSection.Create;
  FFileOpen := False;
  FBuffer := TStringList.Create;
  FLastFlush := Now;
  
  EnsureLogDirectory;
end;

destructor TFileLogger.Destroy;
begin
  try
    Flush;
    CloseLogFile;
  except
    // Ignorar errores durante destrucción
  end;
  
  FBuffer.Free;
  FCriticalSection.Free;
  inherited Destroy;
end;

procedure TFileLogger.EnsureLogDirectory;
begin
  if not TDirectory.Exists(FSettings.BaseDirectory) then
    TDirectory.CreateDirectory(FSettings.BaseDirectory);
end;

function TFileLogger.GetLogFileName(Level: TLogLevel): string;
var
  DateStr: string;
  LevelStr: string;
begin
  DateStr := FormatDateTime(FSettings.DatePattern, Now);
  
  // Archivos separados para diferentes niveles críticos
  case Level of
    TLogLevel.Fatal, TLogLevel.Error: LevelStr := 'error';
    TLogLevel.Warning: LevelStr := 'warning';
    else LevelStr := 'app';
  end;
  
  Result := TPath.Combine(FSettings.BaseDirectory, 
    Format('orion-%s-%s.log', [LevelStr, DateStr]));
end;

function TFileLogger.ShouldRotateFile(const FileName: string): Boolean;
begin
  Result := TFile.Exists(FileName) and (TFile.GetSize(FileName) >= FSettings.MaxFileSize);
end;

procedure TFileLogger.RotateLogFile(const FileName: string);
var
  I: Integer;
  OldName, NewName: string;
begin
  // Rotar archivos existentes
  for I := FSettings.MaxFiles - 1 downto 1 do
  begin
    OldName := ChangeFileExt(FileName, Format('.%d.log', [I]));
    NewName := ChangeFileExt(FileName, Format('.%d.log', [I + 1]));
    
    if TFile.Exists(OldName) then
    begin
      if TFile.Exists(NewName) then
        TFile.Delete(NewName);
      TFile.Move(OldName, NewName);
    end;
  end;
  
  // Mover archivo actual a .1
  if TFile.Exists(FileName) then
  begin
    NewName := ChangeFileExt(FileName, '.1.log');
    if TFile.Exists(NewName) then
      TFile.Delete(NewName);
    TFile.Move(FileName, NewName);
  end;
end;

procedure TFileLogger.OpenLogFile(const FileName: string);
begin
  if FFileOpen then
    CloseLogFile;
    
  if ShouldRotateFile(FileName) then
    RotateLogFile(FileName);
    
  FCurrentLogFile := FileName;
  AssignFile(FCurrentFileHandle, FileName);
  
  if TFile.Exists(FileName) then
    Append(FCurrentFileHandle)
  else
    Rewrite(FCurrentFileHandle);
    
  FFileOpen := True;
end;

procedure TFileLogger.CloseLogFile;
begin
  if FFileOpen then
  begin
    CloseFile(FCurrentFileHandle);
    FFileOpen := False;
    FCurrentLogFile := '';
  end;
end;

procedure TFileLogger.WriteToFile(const LogEntry: string);
begin
  try
    if FFileOpen then
    begin
      Writeln(FCurrentFileHandle, LogEntry);
      FlushIfNeeded;
    end;
  except
    // En caso de error de escritura, intentar reabrir el archivo
    try
      CloseLogFile;
      OpenLogFile(FCurrentLogFile);
      if FFileOpen then
        Writeln(FCurrentFileHandle, LogEntry);
    except
      // Si sigue fallando, ignorar para evitar loops infinitos
    end;
  end;
end;

function TFileLogger.FormatLogEntry(Level: TLogLevel; const Message: string; const Context: TLogContext; Exception: Exception): string;
var
  Timestamp: string;
  LevelStr: string;
  ContextStr: string;
  ExceptionStr: string;
begin
  Timestamp := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now);
  LevelStr := LogLevelToString(Level);
  
  // Formatear contexto
  if Context.Component <> '' then
    ContextStr := Format('[%s]', [Context.Component]);
  if Context.Operation <> '' then
    ContextStr := ContextStr + Format('[%s]', [Context.Operation]);
  if Context.CorrelationId <> '' then
    ContextStr := ContextStr + Format('[%s]', [Context.CorrelationId]);
  if Context.UserId <> '' then
    ContextStr := ContextStr + Format('[User:%s]', [Context.UserId]);
    
  // Formatear excepción si existe
  if Assigned(Exception) then
  begin
    ExceptionStr := Format(' | EXCEPTION: %s: %s', [Exception.ClassName, Exception.Message]);
    if Exception.StackTrace <> '' then
      ExceptionStr := ExceptionStr + ' | STACK: ' + Exception.StackTrace;
  end;
  
  Result := Format('%s [%s] %s %s%s', [
    Timestamp,
    LevelStr,
    ContextStr,
    Message,
    ExceptionStr
  ]);
end;

function TFileLogger.LogLevelToString(Level: TLogLevel): string;
begin
  case Level of
    TLogLevel.Debug: Result := 'DEBUG';
    TLogLevel.Information: Result := 'INFO ';
    TLogLevel.Warning: Result := 'WARN ';
    TLogLevel.Error: Result := 'ERROR';
    TLogLevel.Fatal: Result := 'FATAL';
    else Result := 'UNKNW';
  end;
end;

procedure TFileLogger.FlushIfNeeded;
begin
  if MilliSecondsBetween(Now, FLastFlush) >= FSettings.FlushInterval then
    Flush;
end;

// ILogger Implementation

procedure TFileLogger.Debug(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Debug');
  Debug(Message, Context);
end;

procedure TFileLogger.Debug(const Message: string; const Args: array of const);
var
  FormattedMessage: string;
begin
  FormattedMessage := Format(Message, Args);
  Debug(FormattedMessage);
end;

procedure TFileLogger.Debug(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Debug) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Debug);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Debug, Message, Context));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Info(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Info');
  Info(Message, Context);
end;

procedure TFileLogger.Info(const Message: string; const Args: array of const);
var
  FormattedMessage: string;
begin
  FormattedMessage := Format(Message, Args);
  Info(FormattedMessage);
end;

procedure TFileLogger.Info(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Information) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Information);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Information, Message, Context));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

// Simplified implementation - basic logging functionality
procedure TFileLogger.Warning(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Warning');
  Warning(Message, Context);
end;

procedure TFileLogger.Warning(const Message: string; const Args: array of const);
var
  FormattedMessage: string;
begin
  FormattedMessage := Format(Message, Args);
  Warning(FormattedMessage);
end;

procedure TFileLogger.Warning(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Warning) then
    WriteToFile(FormatLogEntry(TLogLevel.Warning, Message, Context));
end;

procedure TFileLogger.Error(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Error');
  Error(Message, Context);
end;

procedure TFileLogger.Error(const Message: string; const Args: array of const);
var
  FormattedMessage: string;
begin
  FormattedMessage := Format(Message, Args);
  Error(FormattedMessage);
end;

procedure TFileLogger.Error(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Error) then
    WriteToFile(FormatLogEntry(TLogLevel.Error, Message, Context));
end;

procedure TFileLogger.Error(const Message: string; E: Exception);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Error');
  Error(Message, E, Context);
end;

procedure TFileLogger.Error(const Message: string; E: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Error) then
    WriteToFile(FormatLogEntry(TLogLevel.Error, Message, Context, E));
end;

procedure TFileLogger.Fatal(const Message: string);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Fatal');
  Fatal(Message, Context);
end;

procedure TFileLogger.Fatal(const Message: string; const Args: array of const);
var
  FormattedMessage: string;
begin
  FormattedMessage := Format(Message, Args);
  Fatal(FormattedMessage);
end;

procedure TFileLogger.Fatal(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Fatal) then
    WriteToFile(FormatLogEntry(TLogLevel.Fatal, Message, Context));
end;

procedure TFileLogger.Fatal(const Message: string; E: Exception);
var
  Context: TLogContext;
begin
  Context := CreateLogContext('Logger', 'Fatal');
  if IsEnabled(TLogLevel.Fatal) then
    WriteToFile(FormatLogEntry(TLogLevel.Fatal, Message, Context, E));
end;

// Domain-specific methods
procedure TFileLogger.LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string);
var
  Message: string;
begin
  Message := Format('Authentication %s for user: %s', [IfThen(Success, 'SUCCESS', 'FAILED'), UserName]);
  if Success then Info(Message) else Warning(Message);
end;

procedure TFileLogger.LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string);
var
  Message: string;
begin
  Message := Format('Business Rule %s: %s on %s[%s]. %s', [IfThen(Success, 'OK', 'VIOLATION'), RuleName, EntityType, EntityId, Details]);
  if Success then Info(Message) else Warning(Message);
end;

procedure TFileLogger.LogPerformance(const Operation: string; DurationMs: Integer; const Details: string);
var
  Message: string;
begin
  Message := Format('Performance: %s took %d ms. %s', [Operation, DurationMs, Details]);
  Info(Message);
end;

procedure TFileLogger.LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
var
  Message: string;
begin
  Message := Format('Database: %s on %s affected %d records in %d ms', [Operation, TableName, RecordsAffected, DurationMs]);
  Info(Message);
end;

// Configuration methods
procedure TFileLogger.SetLogLevel(Level: TLogLevel);
begin
  FMinLogLevel := Level;
end;

function TFileLogger.GetLogLevel: TLogLevel;
begin
  Result := FMinLogLevel;
end;

// Context methods
procedure TFileLogger.SetCorrelationId(const CorrelationId: string);
begin
  FCorrelationId := CorrelationId;
end;

procedure TFileLogger.SetUserId(const UserId: string);
begin
  FUserId := UserId;
end;

procedure TFileLogger.SetSessionId(const SessionId: string);
begin
  FSessionId := SessionId;
end;

function TFileLogger.IsEnabled(Level: TLogLevel): Boolean;
begin
  Result := Ord(Level) >= Ord(FMinLogLevel);
end;

procedure TFileLogger.Flush;
begin
  // Simplified flush - just ensure file is written
  if FFileOpen then
  begin
    System.Flush(FCurrentFileHandle);
    FLastFlush := Now;
  end;
end;

{ TLoggerFactory }

constructor TLoggerFactory.Create(const Settings: TLogFileSettings; MinLevel: TLogLevel);
begin
  inherited Create;
  FSettings := Settings;
  FMinLevel := MinLevel;
end;

function TLoggerFactory.CreateLogger(const Name: string): ILogger;
begin
  Result := TFileLogger.Create(FSettings, FMinLevel);
end;

function TLoggerFactory.GetLogger(const Name: string): ILogger;
begin
  Result := CreateLogger(Name);
end;

end.
