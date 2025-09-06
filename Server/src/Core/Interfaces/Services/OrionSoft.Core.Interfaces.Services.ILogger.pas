unit OrionSoft.Core.Interfaces.Services.ILogger;

{*
  Interface de logging para Clean Architecture
  Abstracción que permite diferentes implementaciones de logging
*}

interface

uses
  System.SysUtils,
  System.DateUtils,
  OrionSoft.Core.Common.Types;

type

  // Interface principal de logging
  ILogger = interface
    ['{8C9F2A3E-1B4D-4F5A-9E7C-3D2A1B8F9E6C}']
    
    // Métodos básicos de logging
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
    
    // Métodos específicos del dominio
    procedure LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = '');
    procedure LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = '');
    procedure LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = '');
    procedure LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
    
    // Configuración
    procedure SetLogLevel(Level: TLogLevel);
    function GetLogLevel: TLogLevel;
    
    // Control de contexto
    procedure SetCorrelationId(const CorrelationId: string);
    procedure SetUserId(const UserId: string);
    procedure SetSessionId(const SessionId: string);
    
    // Propiedades
    property LogLevel: TLogLevel read GetLogLevel write SetLogLevel;
  end;

  // Interface para factory de loggers
  ILoggerFactory = interface
    ['{A1B2C3D4-E5F6-7890-1234-567890ABCDEF}']
    function CreateLogger(const Name: string): ILogger;
    function GetLogger(const Name: string): ILogger;
  end;

  // Interface para auditoria
  IAuditLogger = interface
    ['{F1E2D3C4-B5A6-9788-4321-FEDCBA098765}']
    procedure LogAudit(Operation: TAuditOperation; const EntityType, EntityId: string; 
      const UserId, Details: string; const Context: TLogContext);
    procedure LogUserAction(const UserId, Action, Resource, Details: string);
    procedure LogSystemEvent(const EventType, Description, Details: string);
  end;

// Helper functions
function CreatePerformanceContext(const Operation: string; StartTime: TDateTime): TLogContext;

implementation

function CreatePerformanceContext(const Operation: string; StartTime: TDateTime): TLogContext;
begin
  Result := CreateLogContext('Performance', Operation);
  Result.UserId := '';
  Result.CorrelationId := IntToStr(MilliSecondsBetween(Now, StartTime));
end;

end.
