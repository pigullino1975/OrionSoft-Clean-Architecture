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
    procedure Debug(const Message: string; const Context: TLogContext); overload;
    procedure Debug(const Message: string; Exception: Exception; const Context: TLogContext); overload;
    
    procedure Info(const Message: string; const Context: TLogContext); overload;
    procedure Info(const Message: string; Exception: Exception; const Context: TLogContext); overload;
    
    procedure Warning(const Message: string; const Context: TLogContext); overload;
    procedure Warning(const Message: string; Exception: Exception; const Context: TLogContext); overload;
    
    procedure Error(const Message: string; const Context: TLogContext); overload;
    procedure Error(const Message: string; Exception: Exception; const Context: TLogContext); overload;
    
    procedure Fatal(const Message: string; const Context: TLogContext); overload;
    procedure Fatal(const Message: string; Exception: Exception; const Context: TLogContext); overload;
    
    // Domain-specific methods
    procedure LogAuthentication(const UserName: string; Success: Boolean);
    procedure LogDatabaseOperation(const Operation: string; const TableName: string; const Duration: Integer);
    procedure LogBusinessRuleViolation(const Rule: string; const Details: string);
    procedure LogPerformanceMetric(const OperationName: string; const Duration: Integer; const AdditionalData: string = '');
    
    // Configuration
    procedure SetMinimumLevel(Level: TLogLevel);
    function IsEnabled(Level: TLogLevel): Boolean;
    procedure Flush;
  end;

  TLoggerFactory = class(TInterfacedObject, ILoggerFactory)
  private
    FSettings: TLogFileSettings;
    FMinLevel: TLogLevel;
    
  public
    constructor Create(const Settings: TLogFileSettings; MinLevel: TLogLevel = TLogLevel.Information);
    
    function CreateLogger: ILogger;
    function CreateAuditLogger: IAuditLogger;
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

procedure TFileLogger.Debug(const Message: string; Exception: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Debug) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Debug);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Debug, Message, Context, Exception));
    finally
      FCriticalSection.Leave;
    end;
  end;
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

procedure TFileLogger.Info(const Message: string; Exception: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Information) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Information);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Information, Message, Context, Exception));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Warning(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Warning) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Warning);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Warning, Message, Context));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Warning(const Message: string; Exception: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Warning) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Warning);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Warning, Message, Context, Exception));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Error(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Error) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Error);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Error, Message, Context));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Error(const Message: string; Exception: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Error) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Error);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Error, Message, Context, Exception));
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Fatal(const Message: string; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Fatal) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Fatal);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Fatal, Message, Context));
      Flush; // Forzar flush inmediato para logs fatales
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

procedure TFileLogger.Fatal(const Message: string; Exception: Exception; const Context: TLogContext);
begin
  if IsEnabled(TLogLevel.Fatal) then
  begin
    FCriticalSection.Enter;
    try
      var FileName := GetLogFileName(TLogLevel.Fatal);
      if FCurrentLogFile <> FileName then
        OpenLogFile(FileName);
      WriteToFile(FormatLogEntry(TLogLevel.Fatal, Message, Context, Exception));
      Flush; // Forzar flush inmediato para logs fatales
    finally
      FCriticalSection.Leave;
    end;
  end;
end;

// Domain-specific methods

procedure TFileLogger.LogAuthentication(const UserName: string; Success: Boolean);
var
  Context: TLogContext;
  Message: string;
begin
  Context := CreateLogContext('Authentication', 'Login');
  if Success then
    Message := Format('Successful login for user: %s', [UserName])
  else
    Message := Format('Failed login attempt for user: %s', [UserName]);
    
  if Success then
    Info(Message, Context)
  else
    Warning(Message, Context);
end;

procedure TFileLogger.LogDatabaseOperation(const Operation, TableName: string; const Duration: Integer);
var
  Context: TLogContext;
  Message: string;
begin
  Context := CreateLogContext('Database', Operation);
  Message := Format('Database operation: %s on table %s completed in %d ms', [Operation, TableName, Duration]);
  Info(Message, Context);
end;

procedure TFileLogger.LogBusinessRuleViolation(const Rule, Details: string);
var
  Context: TLogContext;
  Message: string;
begin
  Context := CreateLogContext('BusinessRules', Rule);
  Message := Format('Business rule violation: %s. Details: %s', [Rule, Details]);
  Warning(Message, Context);
end;

procedure TFileLogger.LogPerformanceMetric(const OperationName: string; const Duration: Integer; const AdditionalData: string);
var
  Context: TLogContext;
  Message: string;
begin
  Context := CreateLogContext('Performance', OperationName);
  Message := Format('Performance metric: %s took %d ms', [OperationName, Duration]);
  if AdditionalData <> '' then
    Message := Message + ' | ' + AdditionalData;
  Info(Message, Context);
end;

// Configuration methods

procedure TFileLogger.SetMinimumLevel(Level: TLogLevel);
begin
  FCriticalSection.Enter;
  try
    FMinLogLevel := Level;
  finally
    FCriticalSection.Leave;
  end;
end;

function TFileLogger.IsEnabled(Level: TLogLevel): Boolean;
begin
  Result := Ord(Level) >= Ord(FMinLogLevel);
end;

procedure TFileLogger.Flush;
begin
  FCriticalSection.Enter;
  try
    if FFileOpen then
    begin
      System.Flush(FCurrentFileHandle);
      FLastFlush := Now;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

{ TLoggerFactory }

constructor TLoggerFactory.Create(const Settings: TLogFileSettings; MinLevel: TLogLevel);
begin
  inherited Create;
  FSettings := Settings;
  FMinLevel := MinLevel;
end;

function TLoggerFactory.CreateLogger: ILogger;
begin
  Result := TFileLogger.Create(FSettings, FMinLevel);
end;

function TLoggerFactory.CreateAuditLogger: IAuditLogger;
begin
  // Para simplicidad, retornamos el mismo logger
  // En una implementación completa, podría ser un logger especializado
  Result := TFileLogger.Create(FSettings, TLogLevel.Information) as IAuditLogger;
end;

end.
