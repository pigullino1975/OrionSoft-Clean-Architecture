unit OrionSoft.Core.Common.Exceptions;

{*
  Excepciones personalizadas para el dominio de la aplicación
  Siguiendo los principios de Clean Architecture
*}

interface

uses
  System.SysUtils,
  OrionSoft.Core.Common.Types;

type
  // Excepción base para todas las excepciones del dominio
  EOrionSoftException = class(Exception)
  private
    FErrorCode: string;
    FDetails: string;
    FLogLevel: TLogLevel;
  public
    constructor Create(const AMessage, AErrorCode: string; ALogLevel: TLogLevel = TLogLevel.Error); overload;
    constructor Create(const AMessage, AErrorCode, ADetails: string; ALogLevel: TLogLevel = TLogLevel.Error); overload;
    
    property ErrorCode: string read FErrorCode;
    property Details: string read FDetails;
    property LogLevel: TLogLevel read FLogLevel;
  end;

  // Excepciones de validación
  EValidationException = class(EOrionSoftException)
  private
    FFieldName: string;
    FFieldValue: string;
  public
    constructor Create(const AMessage, AFieldName: string); overload;
    constructor Create(const AMessage, AFieldName, AFieldValue: string); overload;
    
    property FieldName: string read FFieldName;
    property FieldValue: string read FFieldValue;
  end;

  // Excepciones de reglas de negocio
  EBusinessRuleException = class(EOrionSoftException)
  private
    FRuleName: string;
    FEntityType: string;
    FEntityId: string;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage, ARuleName: string); overload;
    constructor Create(const AMessage, ARuleName, AEntityType, AEntityId: string); overload;
    
    property RuleName: string read FRuleName;
    property EntityType: string read FEntityType;
    property EntityId: string read FEntityId;
  end;

  // Excepciones de autenticación y autorización
  EAuthenticationException = class(EOrionSoftException)
  private
    FUserName: string;
    FAttemptCount: Integer;
  public
    constructor Create(const AMessage: string); overload;
    constructor Create(const AMessage, AUserName: string; AAttemptCount: Integer = 0); overload;
    
    property UserName: string read FUserName;
    property AttemptCount: Integer read FAttemptCount;
  end;

  EAuthorizationException = class(EOrionSoftException)
  private
    FUserName: string;
    FRequiredRole: TUserRole;
    FUserRole: TUserRole;
    FResource: string;
    FAction: string;
  public
    constructor Create(const AMessage, AUserName, AResource, AAction: string); overload;
    constructor Create(const AMessage, AUserName: string; ARequiredRole, AUserRole: TUserRole; const AResource, AAction: string); overload;
    
    property UserName: string read FUserName;
    property RequiredRole: TUserRole read FRequiredRole;
    property UserRole: TUserRole read FUserRole;
    property Resource: string read FResource;
    property Action: string read FAction;
  end;

  // Excepciones de infraestructura
  EInfrastructureException = class(EOrionSoftException)
  private
    FComponentName: string;
    FOperation: string;
  public
    constructor Create(const AMessage, AComponentName, AOperation: string); overload;
    
    property ComponentName: string read FComponentName;
    property Operation: string read FOperation;
  end;

  // Excepciones de base de datos
  EDatabaseException = class(EInfrastructureException)
  private
    FSqlState: string;
    FSqlErrorCode: Integer;
  public
    constructor Create(const AMessage: string; ASqlErrorCode: Integer = 0; const ASqlState: string = ''); overload;
    constructor Create(const AMessage, AComponentName, AOperation: string; ASqlErrorCode: Integer = 0; const ASqlState: string = ''); overload;
    
    property SqlState: string read FSqlState;
    property SqlErrorCode: Integer read FSqlErrorCode;
  end;

  // Excepciones de concurrencia
  EConcurrencyException = class(EOrionSoftException)
  private
    FEntityType: string;
    FEntityId: string;
    FExpectedVersion: Integer;
    FActualVersion: Integer;
  public
    constructor Create(const AEntityType, AEntityId: string; AExpectedVersion, AActualVersion: Integer); overload;
    
    property EntityType: string read FEntityType;
    property EntityId: string read FEntityId;
    property ExpectedVersion: Integer read FExpectedVersion;
    property ActualVersion: Integer read FActualVersion;
  end;

  // Excepción para entidades no encontradas
  EEntityNotFoundException = class(EOrionSoftException)
  private
    FEntityType: string;
    FEntityId: string;
    FSearchCriteria: string;
  public
    constructor Create(const AEntityType, AEntityId: string); overload;
    constructor CreateWithCriteria(const AEntityType, ASearchCriteria: string); overload;
    
    property EntityType: string read FEntityType;
    property EntityId: string read FEntityId;
    property SearchCriteria: string read FSearchCriteria;
  end;

// Factory methods para crear excepciones comunes
function CreateValidationError(const FieldName, Message: string): EValidationException;
function CreateRequiredFieldError(const FieldName: string): EValidationException;
function CreateInvalidFormatError(const FieldName, Value, ExpectedFormat: string): EValidationException;
function CreateDuplicateValueError(const FieldName, Value: string): EValidationException;

function CreateBusinessRuleError(const Message: string): EBusinessRuleException;
function CreateEntityNotFoundError(const EntityType, EntityId: string): EEntityNotFoundException;
function CreateConcurrencyError(const EntityType, EntityId: string; ExpectedVersion, ActualVersion: Integer): EConcurrencyException;

function CreateAuthenticationError(const UserName: string; AttemptCount: Integer = 0): EAuthenticationException;
function CreateInsufficientPrivilegesError(const UserName, Resource, Action: string): EAuthorizationException;

implementation

{ EOrionSoftException }

constructor EOrionSoftException.Create(const AMessage, AErrorCode: string; ALogLevel: TLogLevel);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FDetails := '';
  FLogLevel := ALogLevel;
end;

constructor EOrionSoftException.Create(const AMessage, AErrorCode, ADetails: string; ALogLevel: TLogLevel);
begin
  inherited Create(AMessage);
  FErrorCode := AErrorCode;
  FDetails := ADetails;
  FLogLevel := ALogLevel;
end;

{ EValidationException }

constructor EValidationException.Create(const AMessage, AFieldName: string);
begin
  inherited Create(AMessage, ERROR_VALIDATION_FAILED, TLogLevel.Warning);
  FFieldName := AFieldName;
  FFieldValue := '';
end;

constructor EValidationException.Create(const AMessage, AFieldName, AFieldValue: string);
begin
  inherited Create(AMessage, ERROR_VALIDATION_FAILED, Format('Field: %s, Value: %s', [AFieldName, AFieldValue]), TLogLevel.Warning);
  FFieldName := AFieldName;
  FFieldValue := AFieldValue;
end;

{ EBusinessRuleException }

constructor EBusinessRuleException.Create(const AMessage: string);
begin
  inherited Create(AMessage, ERROR_BUSINESS_RULE, TLogLevel.Warning);
  FRuleName := '';
  FEntityType := '';
  FEntityId := '';
end;

constructor EBusinessRuleException.Create(const AMessage, ARuleName: string);
begin
  inherited Create(AMessage, ERROR_BUSINESS_RULE, Format('Rule: %s', [ARuleName]), TLogLevel.Warning);
  FRuleName := ARuleName;
  FEntityType := '';
  FEntityId := '';
end;

constructor EBusinessRuleException.Create(const AMessage, ARuleName, AEntityType, AEntityId: string);
begin
  inherited Create(AMessage, ERROR_BUSINESS_RULE, 
    Format('Rule: %s, Entity: %s, ID: %s', [ARuleName, AEntityType, AEntityId]), TLogLevel.Warning);
  FRuleName := ARuleName;
  FEntityType := AEntityType;
  FEntityId := AEntityId;
end;

{ EAuthenticationException }

constructor EAuthenticationException.Create(const AMessage: string);
begin
  inherited Create(AMessage, ERROR_AUTHENTICATION_FAILED, TLogLevel.Warning);
  FUserName := '';
  FAttemptCount := 0;
end;

constructor EAuthenticationException.Create(const AMessage, AUserName: string; AAttemptCount: Integer);
begin
  inherited Create(AMessage, ERROR_AUTHENTICATION_FAILED, 
    Format('User: %s, Attempts: %d', [AUserName, AAttemptCount]), TLogLevel.Warning);
  FUserName := AUserName;
  FAttemptCount := AAttemptCount;
end;

{ EAuthorizationException }

constructor EAuthorizationException.Create(const AMessage, AUserName, AResource, AAction: string);
begin
  inherited Create(AMessage, ERROR_INSUFFICIENT_PRIVILEGES, 
    Format('User: %s, Resource: %s, Action: %s', [AUserName, AResource, AAction]), TLogLevel.Warning);
  FUserName := AUserName;
  FResource := AResource;
  FAction := AAction;
end;

constructor EAuthorizationException.Create(const AMessage, AUserName: string; ARequiredRole, AUserRole: TUserRole; 
  const AResource, AAction: string);
begin
  inherited Create(AMessage, ERROR_INSUFFICIENT_PRIVILEGES, 
    Format('User: %s, Required Role: %s, User Role: %s, Resource: %s, Action: %s', 
      [AUserName, UserRoleToString(ARequiredRole), UserRoleToString(AUserRole), AResource, AAction]), TLogLevel.Warning);
  FUserName := AUserName;
  FRequiredRole := ARequiredRole;
  FUserRole := AUserRole;
  FResource := AResource;
  FAction := AAction;
end;

{ EInfrastructureException }

constructor EInfrastructureException.Create(const AMessage, AComponentName, AOperation: string);
begin
  inherited Create(AMessage, 'INFRA_001', Format('Component: %s, Operation: %s', [AComponentName, AOperation]), TLogLevel.Error);
  FComponentName := AComponentName;
  FOperation := AOperation;
end;

{ EDatabaseException }

constructor EDatabaseException.Create(const AMessage: string; ASqlErrorCode: Integer; const ASqlState: string);
begin
  inherited Create(AMessage, ERROR_DATABASE_CONNECTION, 
    Format('SQL Error: %d, State: %s', [ASqlErrorCode, ASqlState]), TLogLevel.Error);
  FSqlErrorCode := ASqlErrorCode;
  FSqlState := ASqlState;
end;

constructor EDatabaseException.Create(const AMessage, AComponentName, AOperation: string; ASqlErrorCode: Integer; const ASqlState: string);
begin
  inherited Create(AMessage, AComponentName, AOperation);
  FSqlErrorCode := ASqlErrorCode;
  FSqlState := ASqlState;
end;

{ EConcurrencyException }

constructor EConcurrencyException.Create(const AEntityType, AEntityId: string; AExpectedVersion, AActualVersion: Integer);
begin
  inherited Create(
    Format('Concurrency conflict detected for %s with ID %s. Expected version: %d, Actual version: %d', 
      [AEntityType, AEntityId, AExpectedVersion, AActualVersion]), 
    ERROR_CONCURRENCY, 
    Format('Entity: %s, ID: %s, Expected: %d, Actual: %d', [AEntityType, AEntityId, AExpectedVersion, AActualVersion]),
    TLogLevel.Warning);
  FEntityType := AEntityType;
  FEntityId := AEntityId;
  FExpectedVersion := AExpectedVersion;
  FActualVersion := AActualVersion;
end;

{ EEntityNotFoundException }

constructor EEntityNotFoundException.Create(const AEntityType, AEntityId: string);
begin
  inherited Create(
    Format('%s with ID %s was not found', [AEntityType, AEntityId]), 
    ERROR_NOT_FOUND, 
    Format('Entity: %s, ID: %s', [AEntityType, AEntityId]),
    TLogLevel.Information);
  FEntityType := AEntityType;
  FEntityId := AEntityId;
  FSearchCriteria := 'ID = ' + AEntityId;
end;

constructor EEntityNotFoundException.CreateWithCriteria(const AEntityType, ASearchCriteria: string);
begin
  inherited Create(
    Format('%s with criteria "%s" was not found', [AEntityType, ASearchCriteria]), 
    ERROR_NOT_FOUND, 
    Format('Entity: %s, Criteria: %s', [AEntityType, ASearchCriteria]),
    TLogLevel.Information);
  FEntityType := AEntityType;
  FEntityId := '';
  FSearchCriteria := ASearchCriteria;
end;

// Factory methods implementation

function CreateValidationError(const FieldName, Message: string): EValidationException;
begin
  Result := EValidationException.Create(Message, FieldName);
end;

function CreateRequiredFieldError(const FieldName: string): EValidationException;
begin
  Result := EValidationException.Create(Format('El campo %s es requerido', [FieldName]), FieldName);
end;

function CreateInvalidFormatError(const FieldName, Value, ExpectedFormat: string): EValidationException;
begin
  Result := EValidationException.Create(
    Format('El campo %s tiene un formato inválido. Valor: "%s", Formato esperado: %s', [FieldName, Value, ExpectedFormat]),
    FieldName, Value);
end;

function CreateDuplicateValueError(const FieldName, Value: string): EValidationException;
begin
  Result := EValidationException.Create(
    Format('El valor "%s" para el campo %s ya existe', [Value, FieldName]),
    FieldName, Value);
end;

function CreateBusinessRuleError(const Message: string): EBusinessRuleException;
begin
  Result := EBusinessRuleException.Create(Message);
end;

function CreateEntityNotFoundError(const EntityType, EntityId: string): EEntityNotFoundException;
begin
  Result := EEntityNotFoundException.Create(EntityType, EntityId);
end;

function CreateConcurrencyError(const EntityType, EntityId: string; ExpectedVersion, ActualVersion: Integer): EConcurrencyException;
begin
  Result := EConcurrencyException.Create(EntityType, EntityId, ExpectedVersion, ActualVersion);
end;

function CreateAuthenticationError(const UserName: string; AttemptCount: Integer): EAuthenticationException;
begin
  Result := EAuthenticationException.Create('Credenciales inválidas', UserName, AttemptCount);
end;

function CreateInsufficientPrivilegesError(const UserName, Resource, Action: string): EAuthorizationException;
begin
  Result := EAuthorizationException.Create(
    Format('El usuario %s no tiene permisos para %s en %s', [UserName, Action, Resource]),
    UserName, Resource, Action);
end;

end.
