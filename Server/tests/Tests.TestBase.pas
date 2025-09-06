unit Tests.TestBase;

{*
  Clase base para tests unitarios
  Proporciona funcionalidades comunes para todos los tests
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  OrionSoft.Infrastructure.CrossCutting.DI.Container,
  OrionSoft.Core.Interfaces.Services.ILogger,
  Tests.Mocks.MockLogger;

type
  [TestFixture]
  TTestBase = class
  protected
    FContainer: TDIContainer;
    FMockLogger: TMockLogger;
    
    // Setup común para todos los tests
    [SetupFixture]
    procedure GlobalSetup; virtual;
    
    [TearDownFixture]  
    procedure GlobalTearDown; virtual;
    
    [Setup]
    procedure Setup; virtual;
    
    [TearDown]
    procedure TearDown; virtual;
    
    // Helper methods para testing
    procedure RegisterCommonMocks; virtual;
    procedure VerifyNoErrors;
    procedure VerifyNoWarnings;
    procedure VerifyLoggedInfo(const MessageContains: string);
    procedure VerifyLoggedError(const MessageContains: string);
    procedure VerifyLoggedWarning(const MessageContains: string);
    
    // Properties para acceso fácil
    property Container: TDIContainer read FContainer;
    property MockLogger: TMockLogger read FMockLogger;
  end;

  // Clase base especializada para tests de Use Cases
  [TestFixture]
  TUseCaseTestBase = class(TTestBase)
  protected
    [Setup]
    procedure Setup; override;
    
    // Helper para crear requests de test
    function CreateTestCorrelationId: string;
    function CreateTestUserId: string;
    function CreateTestSessionId: string;
  end;

  // Clase base para tests de Repository
  [TestFixture]
  TRepositoryTestBase = class(TTestBase)
  protected
    [Setup]
    procedure Setup; override;
    
    // Helpers para testing de repositorios
    procedure VerifyDatabaseOperation(const Operation, TableName: string);
  end;

  // Atributos personalizados para categorizar tests
  TestCategoryAttribute = class(CategoryAttribute)
  public
    constructor Create(const Category: string);
  end;

  // Categorías de tests predefinidas
  UnitTestAttribute = class(TestCategoryAttribute)
  public
    constructor Create;
  end;

  IntegrationTestAttribute = class(TestCategoryAttribute)
  public
    constructor Create;
  end;

  SlowTestAttribute = class(TestCategoryAttribute)
  public
    constructor Create;
  end;

  DatabaseTestAttribute = class(TestCategoryAttribute)
  public
    constructor Create;
  end;

// Helper functions para tests
function CreateRandomString(Length: Integer = 10): string;
function CreateRandomEmail: string;
function CreateRandomInt(Min: Integer = 1; Max: Integer = 1000): Integer;
function CreateRandomBool: Boolean;

implementation

uses
  System.Math;

{ TTestBase }

procedure TTestBase.GlobalSetup;
begin
  // Setup que se ejecuta una vez por fixture
  // Aquí se pueden configurar recursos globales si es necesario
end;

procedure TTestBase.GlobalTearDown;
begin
  // Cleanup global
end;

procedure TTestBase.Setup;
begin
  // Setup que se ejecuta antes de cada test
  FContainer := TDIContainer.Create;
  FMockLogger := TMockLogger.Create;
  
  RegisterCommonMocks;
end;

procedure TTestBase.TearDown;
begin
  // Cleanup que se ejecuta después de cada test
  FContainer.Free;
  FMockLogger := nil; // Se libera automáticamente por reference counting
end;

procedure TTestBase.RegisterCommonMocks;
begin
  // Registrar mocks comunes que todos los tests necesitan
  FContainer.RegisterInstance<ILogger>(FMockLogger);
end;

procedure TTestBase.VerifyNoErrors;
begin
  FMockLogger.VerifyLogCount(llError, 0);
end;

procedure TTestBase.VerifyNoWarnings;
begin
  FMockLogger.VerifyLogCount(llWarning, 0);
end;

procedure TTestBase.VerifyLoggedInfo(const MessageContains: string);
begin
  FMockLogger.VerifyLogged(llInfo, MessageContains);
end;

procedure TTestBase.VerifyLoggedError(const MessageContains: string);
begin
  FMockLogger.VerifyLogged(llError, MessageContains);
end;

procedure TTestBase.VerifyLoggedWarning(const MessageContains: string);
begin
  FMockLogger.VerifyLogged(llWarning, MessageContains);
end;

{ TUseCaseTestBase }

procedure TUseCaseTestBase.Setup;
begin
  inherited Setup;
  
  // Setup específico para tests de Use Cases
  FMockLogger.SetUserId(CreateTestUserId);
  FMockLogger.SetSessionId(CreateTestSessionId);
  FMockLogger.SetCorrelationId(CreateTestCorrelationId);
end;

function TUseCaseTestBase.CreateTestCorrelationId: string;
begin
  Result := 'TEST-CORR-' + CreateRandomString(8);
end;

function TUseCaseTestBase.CreateTestUserId: string;
begin
  Result := 'TEST-USER-' + CreateRandomString(6);
end;

function TUseCaseTestBase.CreateTestSessionId: string;
begin
  Result := 'TEST-SESSION-' + CreateRandomString(10);
end;

{ TRepositoryTestBase }

procedure TRepositoryTestBase.Setup;
begin
  inherited Setup;
  
  // Setup específico para tests de Repository
  // Aquí se pueden registrar mocks específicos para base de datos
end;

procedure TRepositoryTestBase.VerifyDatabaseOperation(const Operation, TableName: string);
begin
  Assert.IsTrue(FMockLogger.HasLogEntry(llDebug, Format('DB Operation: %s en tabla %s', [Operation, TableName])),
    Format('Expected database operation not logged: %s on %s', [Operation, TableName]));
end;

{ TestCategoryAttribute }

constructor TestCategoryAttribute.Create(const Category: string);
begin
  inherited Create(Category);
end;

{ UnitTestAttribute }

constructor UnitTestAttribute.Create;
begin
  inherited Create('Unit');
end;

{ IntegrationTestAttribute }

constructor IntegrationTestAttribute.Create;
begin
  inherited Create('Integration');
end;

{ SlowTestAttribute }

constructor SlowTestAttribute.Create;
begin
  inherited Create('Slow');
end;

{ DatabaseTestAttribute }

constructor DatabaseTestAttribute.Create;
begin
  inherited Create('Database');
end;

// Helper functions implementation

function CreateRandomString(Length: Integer): string;
const
  Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length do
    Result := Result + Chars[Random(System.Length(Chars)) + 1];
end;

function CreateRandomEmail: string;
begin
  Result := CreateRandomString(8) + '@' + CreateRandomString(6) + '.com';
end;

function CreateRandomInt(Min, Max: Integer): Integer;
begin
  Result := RandomRange(Min, Max + 1);
end;

function CreateRandomBool: Boolean;
begin
  Result := Random(2) = 1;
end;

initialization
  // Inicializar generador de números aleatorios
  Randomize;

end.
