unit Tests.Core.Common.Exceptions;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  OrionSoft.Core.Common.Exceptions,
  OrionSoft.Core.Common.Types;

[TestFixture]
type
  TExceptionsTests = class
  public
    [Test]
    procedure Test_EValidationException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_EValidationException_WithMessageAndCode_CreatesCorrectException;
    [Test]
    procedure Test_EValidationException_WithAllParameters_CreatesCorrectException;
    
    [Test]
    procedure Test_EAuthenticationException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_EAuthenticationException_WithMessageAndCode_CreatesCorrectException;
    
    [Test]
    procedure Test_EAuthorizationException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_EAuthorizationException_WithMessageAndCode_CreatesCorrectException;
    
    [Test]
    procedure Test_EBusinessRuleException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_EBusinessRuleException_WithMessageAndCode_CreatesCorrectException;
    
    [Test]
    procedure Test_EDatabaseException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_EDatabaseException_WithMessageAndCode_CreatesCorrectException;
    
    [Test]
    procedure Test_ESystemException_WithMessage_CreatesCorrectException;
    [Test]
    procedure Test_ESystemException_WithMessageAndCode_CreatesCorrectException;
    
    // Error handling tests
    [Test]
    procedure Test_CreateBusinessRuleError_ReturnsCorrectErrorInfo;
    [Test]
    procedure Test_CreateValidationError_ReturnsCorrectErrorInfo;
    [Test]
    procedure Test_CreateAuthenticationError_ReturnsCorrectErrorInfo;
    [Test]
    procedure Test_CreateSystemError_ReturnsCorrectErrorInfo;
    
    // Exception conversion tests
    [Test]
    procedure Test_ConvertExceptionToErrorInfo_WithValidationException_ReturnsCorrectInfo;
    [Test]
    procedure Test_ConvertExceptionToErrorInfo_WithBusinessRuleException_ReturnsCorrectInfo;
    [Test]
    procedure Test_ConvertExceptionToErrorInfo_WithGenericException_ReturnsCorrectInfo;
    
    // Error code validation tests
    [Test]
    procedure Test_IsValidErrorCode_WithValidCodes_ReturnsTrue;
    [Test]
    procedure Test_IsValidErrorCode_WithInvalidCode_ReturnsFalse;
    
    // Severity level tests
    [Test]
    procedure Test_GetErrorSeverity_WithDifferentExceptions_ReturnsCorrectSeverity;
  end;

implementation

{ TExceptionsTests }

procedure TExceptionsTests.Test_EValidationException_WithMessage_CreatesCorrectException;
var
  Exception: EValidationException;
begin
  Exception := EValidationException.Create('Test validation error');
  try
    Assert.AreEqual('Test validation error', Exception.Message);
    Assert.AreEqual('VAL_001', Exception.ErrorCode);
    Assert.IsEmpty(Exception.Details);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EValidationException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: EValidationException;
begin
  Exception := EValidationException.Create('Test validation error', 'CUSTOM_001');
  try
    Assert.AreEqual('Test validation error', Exception.Message);
    Assert.AreEqual('CUSTOM_001', Exception.ErrorCode);
    Assert.IsEmpty(Exception.Details);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EValidationException_WithAllParameters_CreatesCorrectException;
var
  Exception: EValidationException;
begin
  Exception := EValidationException.Create('Test validation error', 'CUSTOM_001', 'Additional details');
  try
    Assert.AreEqual('Test validation error', Exception.Message);
    Assert.AreEqual('CUSTOM_001', Exception.ErrorCode);
    Assert.AreEqual('Additional details', Exception.Details);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EAuthenticationException_WithMessage_CreatesCorrectException;
var
  Exception: EAuthenticationException;
begin
  Exception := EAuthenticationException.Create('Authentication failed');
  try
    Assert.AreEqual('Authentication failed', Exception.Message);
    Assert.AreEqual('AUTH_001', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EAuthenticationException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: EAuthenticationException;
begin
  Exception := EAuthenticationException.Create('Authentication failed', 'AUTH_CUSTOM');
  try
    Assert.AreEqual('Authentication failed', Exception.Message);
    Assert.AreEqual('AUTH_CUSTOM', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EAuthorizationException_WithMessage_CreatesCorrectException;
var
  Exception: EAuthorizationException;
begin
  Exception := EAuthorizationException.Create('Access denied');
  try
    Assert.AreEqual('Access denied', Exception.Message);
    Assert.AreEqual('AUTH_003', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EAuthorizationException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: EAuthorizationException;
begin
  Exception := EAuthorizationException.Create('Access denied', 'AUTH_CUSTOM');
  try
    Assert.AreEqual('Access denied', Exception.Message);
    Assert.AreEqual('AUTH_CUSTOM', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EBusinessRuleException_WithMessage_CreatesCorrectException;
var
  Exception: EBusinessRuleException;
begin
  Exception := EBusinessRuleException.Create('Business rule violation');
  try
    Assert.AreEqual('Business rule violation', Exception.Message);
    Assert.AreEqual('BUS_001', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EBusinessRuleException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: EBusinessRuleException;
begin
  Exception := EBusinessRuleException.Create('Business rule violation', 'BUS_CUSTOM');
  try
    Assert.AreEqual('Business rule violation', Exception.Message);
    Assert.AreEqual('BUS_CUSTOM', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EDatabaseException_WithMessage_CreatesCorrectException;
var
  Exception: EDatabaseException;
begin
  Exception := EDatabaseException.Create('Database error');
  try
    Assert.AreEqual('Database error', Exception.Message);
    Assert.AreEqual('DB_001', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_EDatabaseException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: EDatabaseException;
begin
  Exception := EDatabaseException.Create('Database error', 'DB_CUSTOM');
  try
    Assert.AreEqual('Database error', Exception.Message);
    Assert.AreEqual('DB_CUSTOM', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_ESystemException_WithMessage_CreatesCorrectException;
var
  Exception: ESystemException;
begin
  Exception := ESystemException.Create('System error');
  try
    Assert.AreEqual('System error', Exception.Message);
    Assert.AreEqual('SYS_001', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_ESystemException_WithMessageAndCode_CreatesCorrectException;
var
  Exception: ESystemException;
begin
  Exception := ESystemException.Create('System error', 'SYS_CUSTOM');
  try
    Assert.AreEqual('System error', Exception.Message);
    Assert.AreEqual('SYS_CUSTOM', Exception.ErrorCode);
  finally
    Exception.Free;
  end;
end;

// Error handling tests

procedure TExceptionsTests.Test_CreateBusinessRuleError_ReturnsCorrectErrorInfo;
var
  ErrorInfo: TErrorInfo;
begin
  ErrorInfo := CreateBusinessRuleError('Business rule violated', 'Rule details');
  
  Assert.AreEqual('BUS_001', ErrorInfo.ErrorCode);
  Assert.AreEqual('Business rule violated', ErrorInfo.Message);
  Assert.AreEqual('Rule details', ErrorInfo.Details);
  Assert.AreEqual(TErrorSeverity.Warning, ErrorInfo.Severity);
  Assert.IsTrue(ErrorInfo.Timestamp > 0);
end;

procedure TExceptionsTests.Test_CreateValidationError_ReturnsCorrectErrorInfo;
var
  ErrorInfo: TErrorInfo;
begin
  ErrorInfo := CreateValidationError('Validation failed', 'Field: UserName');
  
  Assert.AreEqual('VAL_001', ErrorInfo.ErrorCode);
  Assert.AreEqual('Validation failed', ErrorInfo.Message);
  Assert.AreEqual('Field: UserName', ErrorInfo.Details);
  Assert.AreEqual(TErrorSeverity.Error, ErrorInfo.Severity);
  Assert.IsTrue(ErrorInfo.Timestamp > 0);
end;

procedure TExceptionsTests.Test_CreateAuthenticationError_ReturnsCorrectErrorInfo;
var
  ErrorInfo: TErrorInfo;
begin
  ErrorInfo := CreateAuthenticationError('Login failed', 'Invalid credentials');
  
  Assert.AreEqual('AUTH_001', ErrorInfo.ErrorCode);
  Assert.AreEqual('Login failed', ErrorInfo.Message);
  Assert.AreEqual('Invalid credentials', ErrorInfo.Details);
  Assert.AreEqual(TErrorSeverity.Warning, ErrorInfo.Severity);
  Assert.IsTrue(ErrorInfo.Timestamp > 0);
end;

procedure TExceptionsTests.Test_CreateSystemError_ReturnsCorrectErrorInfo;
var
  ErrorInfo: TErrorInfo;
begin
  ErrorInfo := CreateSystemError('System failure', 'Out of memory');
  
  Assert.AreEqual('SYS_001', ErrorInfo.ErrorCode);
  Assert.AreEqual('System failure', ErrorInfo.Message);
  Assert.AreEqual('Out of memory', ErrorInfo.Details);
  Assert.AreEqual(TErrorSeverity.Critical, ErrorInfo.Severity);
  Assert.IsTrue(ErrorInfo.Timestamp > 0);
end;

// Exception conversion tests

procedure TExceptionsTests.Test_ConvertExceptionToErrorInfo_WithValidationException_ReturnsCorrectInfo;
var
  Exception: EValidationException;
  ErrorInfo: TErrorInfo;
begin
  Exception := EValidationException.Create('Validation error', 'VAL_002', 'Field details');
  try
    ErrorInfo := ConvertExceptionToErrorInfo(Exception);
    
    Assert.AreEqual('VAL_002', ErrorInfo.ErrorCode);
    Assert.AreEqual('Validation error', ErrorInfo.Message);
    Assert.AreEqual('Field details', ErrorInfo.Details);
    Assert.AreEqual(TErrorSeverity.Error, ErrorInfo.Severity);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_ConvertExceptionToErrorInfo_WithBusinessRuleException_ReturnsCorrectInfo;
var
  Exception: EBusinessRuleException;
  ErrorInfo: TErrorInfo;
begin
  Exception := EBusinessRuleException.Create('Business rule error', 'BUS_002');
  try
    ErrorInfo := ConvertExceptionToErrorInfo(Exception);
    
    Assert.AreEqual('BUS_002', ErrorInfo.ErrorCode);
    Assert.AreEqual('Business rule error', ErrorInfo.Message);
    Assert.AreEqual(TErrorSeverity.Warning, ErrorInfo.Severity);
  finally
    Exception.Free;
  end;
end;

procedure TExceptionsTests.Test_ConvertExceptionToErrorInfo_WithGenericException_ReturnsCorrectInfo;
var
  Exception: Exception;
  ErrorInfo: TErrorInfo;
begin
  Exception := Exception.Create('Generic error');
  try
    ErrorInfo := ConvertExceptionToErrorInfo(Exception);
    
    Assert.AreEqual('SYS_001', ErrorInfo.ErrorCode);
    Assert.AreEqual('Generic error', ErrorInfo.Message);
    Assert.AreEqual(TErrorSeverity.Error, ErrorInfo.Severity);
  finally
    Exception.Free;
  end;
end;

// Error code validation tests

procedure TExceptionsTests.Test_IsValidErrorCode_WithValidCodes_ReturnsTrue;
begin
  Assert.IsTrue(IsValidErrorCode('AUTH_001'));
  Assert.IsTrue(IsValidErrorCode('VAL_002'));
  Assert.IsTrue(IsValidErrorCode('BUS_001'));
  Assert.IsTrue(IsValidErrorCode('DB_003'));
  Assert.IsTrue(IsValidErrorCode('SYS_001'));
end;

procedure TExceptionsTests.Test_IsValidErrorCode_WithInvalidCode_ReturnsFalse;
begin
  Assert.IsFalse(IsValidErrorCode(''));
  Assert.IsFalse(IsValidErrorCode('INVALID'));
  Assert.IsFalse(IsValidErrorCode('123'));
  Assert.IsFalse(IsValidErrorCode('AUTH'));
  Assert.IsFalse(IsValidErrorCode('_001'));
end;

// Severity level tests

procedure TExceptionsTests.Test_GetErrorSeverity_WithDifferentExceptions_ReturnsCorrectSeverity;
var
  ValidationEx: EValidationException;
  AuthenticationEx: EAuthenticationException;
  BusinessRuleEx: EBusinessRuleException;
  DatabaseEx: EDatabaseException;
  SystemEx: ESystemException;
  GenericEx: Exception;
begin
  ValidationEx := EValidationException.Create('Validation error');
  try
    Assert.AreEqual(TErrorSeverity.Error, GetErrorSeverity(ValidationEx));
  finally
    ValidationEx.Free;
  end;
  
  AuthenticationEx := EAuthenticationException.Create('Auth error');
  try
    Assert.AreEqual(TErrorSeverity.Warning, GetErrorSeverity(AuthenticationEx));
  finally
    AuthenticationEx.Free;
  end;
  
  BusinessRuleEx := EBusinessRuleException.Create('Business error');
  try
    Assert.AreEqual(TErrorSeverity.Warning, GetErrorSeverity(BusinessRuleEx));
  finally
    BusinessRuleEx.Free;
  end;
  
  DatabaseEx := EDatabaseException.Create('Database error');
  try
    Assert.AreEqual(TErrorSeverity.Critical, GetErrorSeverity(DatabaseEx));
  finally
    DatabaseEx.Free;
  end;
  
  SystemEx := ESystemException.Create('System error');
  try
    Assert.AreEqual(TErrorSeverity.Critical, GetErrorSeverity(SystemEx));
  finally
    SystemEx.Free;
  end;
  
  GenericEx := Exception.Create('Generic error');
  try
    Assert.AreEqual(TErrorSeverity.Error, GetErrorSeverity(GenericEx));
  finally
    GenericEx.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExceptionsTests);

end.
