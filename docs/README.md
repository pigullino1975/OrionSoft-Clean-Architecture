# OrionSoft Clean Architecture - Documentación Técnica

## 📋 Tabla de Contenidos

1. [Descripción General](#descripción-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Instalación y Configuración](#instalación-y-configuración)
4. [Guía de Desarrollo](#guía-de-desarrollo)
5. [APIs y Interfaces](#apis-y-interfaces)
6. [Testing](#testing)
7. [Deployment](#deployment)
8. [Ejemplos de Uso](#ejemplos-de-uso)
9. [Troubleshooting](#troubleshooting)

## 🏗️ Descripción General

OrionSoft Clean Architecture es una implementación profesional de Clean Architecture en Delphi/Pascal, diseñada para sistemas de gestión empresarial con enfoque en:

- **Escalabilidad**: Arquitectura modular y desacoplada
- **Mantenibilidad**: Separación clara de responsabilidades
- **Testabilidad**: Cobertura completa con tests unitarios e integración
- **Flexibilidad**: Soporte para múltiples bases de datos y frameworks
- **Seguridad**: Implementación robusta de autenticación y autorización

### Características Principales

- ✅ **Clean Architecture**: Implementación completa de los principios de Robert C. Martin
- ✅ **Dependency Injection**: Container personalizado para gestión de dependencias
- ✅ **Multi-Database**: Soporte para SQL Server, MySQL, PostgreSQL
- ✅ **Logging Avanzado**: Sistema de logging estructurado con rotación
- ✅ **Testing Completo**: Suite completa de tests unitarios e integración
- ✅ **RemObjects DataSnap**: Compatibilidad con sistemas legacy
- ✅ **Error Handling**: Sistema robusto de manejo de errores

## 🏛️ Arquitectura del Sistema

### Diagrama de Capas

```
┌─────────────────────────────────────────────┐
│             PRESENTATION LAYER              │
│  ┌─────────────────┐ ┌─────────────────────┐ │
│  │ RemObjects      │ │ REST APIs          │ │
│  │ DataSnap        │ │ (Future)           │ │
│  └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────┐
│             APPLICATION LAYER               │
│  ┌─────────────────┐ ┌─────────────────────┐ │
│  │ Services        │ │ Adapters            │ │
│  │ - Authentication│ │ - RemObjects        │ │
│  │ - Authorization │ │ - Legacy Support    │ │
│  └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────┐
│                CORE LAYER                   │
│  ┌─────────────────┐ ┌─────────────────────┐ │
│  │ Entities        │ │ Use Cases           │ │
│  │ - User          │ │ - AuthenticateUser  │ │
│  │ - Session       │ │ - ManageUsers       │ │
│  └─────────────────┘ └─────────────────────┘ │
│  ┌─────────────────┐ ┌─────────────────────┐ │
│  │ Interfaces      │ │ Common              │ │
│  │ - IUserRepo     │ │ - Types             │ │
│  │ - ILogger       │ │ - Exceptions        │ │
│  └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────┐
│            INFRASTRUCTURE LAYER             │
│  ┌─────────────────┐ ┌─────────────────────┐ │
│  │ Data Access     │ │ Cross-Cutting       │ │
│  │ - SqlRepository │ │ - Logging           │ │
│  │ - InMemoryRepo  │ │ - DI Container      │ │
│  └─────────────────┘ └─────────────────────┘ │
└─────────────────────────────────────────────┘
```

### Flujo de Dependencias

- **Presentation** → **Application** → **Core**
- **Infrastructure** → **Core** (interfaces)
- **Application** ← **Infrastructure** (implementations)

### Principios Aplicados

1. **Dependency Inversion**: Las capas internas no dependen de las externas
2. **Single Responsibility**: Cada clase tiene una única razón para cambiar
3. **Open/Closed**: Abierto para extensión, cerrado para modificación
4. **Interface Segregation**: Interfaces específicas y cohesivas
5. **Liskov Substitution**: Implementaciones intercambiables

## ⚙️ Instalación y Configuración

### Requisitos del Sistema

- **Delphi/RAD Studio**: 12 Athens o superior
- **Base de Datos**: SQL Server 2019+, MySQL 8.0+, o PostgreSQL 14+
- **FireDAC**: Para acceso a datos
- **DUnitX**: Para testing (incluido en Delphi)

### Estructura de Directorios

```
OrionSoft.Clean/
├── Server/
│   ├── src/
│   │   ├── Core/
│   │   │   ├── Common/
│   │   │   ├── Entities/
│   │   │   ├── Interfaces/
│   │   │   └── UseCases/
│   │   ├── Application/
│   │   │   └── Services/
│   │   └── Infrastructure/
│   │       ├── Data/
│   │       ├── Services/
│   │       └── CrossCutting/
│   ├── Tests/
│   │   ├── Unit/
│   │   ├── Integration/
│   │   ├── E2E/
│   │   └── Mocks/
│   └── Scripts/
│       └── Database/
├── docs/
└── examples/
```

### Configuración de Base de Datos

1. **Ejecutar Scripts de Migración**:
```sql
-- SQL Server
sqlcmd -S server -d database -i Scripts/Database/SqlServer/001_CreateUsersTable.sql

-- MySQL
mysql -h host -u user -p database < Scripts/Database/MySQL/001_CreateUsersTable.sql

-- PostgreSQL
psql -h host -U user -d database -f Scripts/Database/PostgreSQL/001_CreateUsersTable.sql
```

2. **Configurar Conexión**:
```pascal
// En el archivo de configuración del servidor
var
  ConnectionParams: TStringList;
begin
  ConnectionParams := TStringList.Create;
  try
    // SQL Server
    ConnectionParams.Add('DriverID=MSSQL');
    ConnectionParams.Add('Server=localhost');
    ConnectionParams.Add('Database=OrionSoft');
    ConnectionParams.Add('OSAuthent=Yes');
    // O para autenticación SQL:
    // ConnectionParams.Add('User_Name=sa');
    // ConnectionParams.Add('Password=password');
    
    // Crear conexión
    Connection := TFireDACConnection.Create(ConnectionParams);
  finally
    ConnectionParams.Free;
  end;
end;
```

## 🔧 Guía de Desarrollo

### Creación de Nuevas Entidades

1. **Definir la Entidad**:
```pascal
// Core/Entities/OrionSoft.Core.Entities.Product.pas
unit OrionSoft.Core.Entities.Product;

interface

type
  TProduct = class
  private
    FId: string;
    FName: string;
    FPrice: Currency;
    // ... otros campos
  public
    constructor Create(const Id, Name: string; Price: Currency);
    
    property Id: string read FId;
    property Name: string read FName write FName;
    property Price: Currency read FPrice write FPrice;
    // ... otras propiedades
  end;

implementation
// ... implementación
```

2. **Crear la Interface del Repositorio**:
```pascal
// Core/Interfaces/Repositories/IProductRepository.pas
unit OrionSoft.Core.Interfaces.Repositories.IProductRepository;

interface

uses
  OrionSoft.Core.Entities.Product;

type
  IProductRepository = interface
    ['{GUID-AQUI}']
    function GetById(const Id: string): TProduct;
    function Save(Product: TProduct): Boolean;
    function Delete(const Id: string): Boolean;
    // ... otros métodos
  end;

implementation
// ... implementación
```

3. **Implementar el Repositorio**:
```pascal
// Infrastructure/Data/Repositories/OrionSoft.Infrastructure.Data.Repositories.SqlProductRepository.pas
unit OrionSoft.Infrastructure.Data.Repositories.SqlProductRepository;

interface

uses
  OrionSoft.Core.Interfaces.Repositories.IProductRepository,
  OrionSoft.Core.Entities.Product,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TSqlProductRepository = class(TInterfacedObject, IProductRepository)
  private
    FConnection: IDbConnection;
  public
    constructor Create(Connection: IDbConnection);
    
    function GetById(const Id: string): TProduct;
    function Save(Product: TProduct): Boolean;
    function Delete(const Id: string): Boolean;
  end;

implementation
// ... implementación
```

4. **Registrar en el DI Container**:
```pascal
// En la configuración del servidor
Container.RegisterSingleton<IProductRepository>(
  function: IProductRepository
  begin
    Result := TSqlProductRepository.Create(Container.ResolveDbConnection);
  end
);
```

### Creación de Use Cases

```pascal
// Core/UseCases/Product/CreateProductUseCase.pas
unit OrionSoft.Core.UseCases.Product.CreateProductUseCase;

interface

type
  TCreateProductRequest = record
    Name: string;
    Price: Currency;
    Description: string;
  end;
  
  TCreateProductResponse = record
    IsSuccess: Boolean;
    ProductId: string;
    ErrorMessage: string;
  end;
  
  TCreateProductUseCase = class
  private
    FProductRepository: IProductRepository;
    FLogger: ILogger;
  public
    constructor Create(ProductRepository: IProductRepository; Logger: ILogger);
    function Execute(const Request: TCreateProductRequest): TCreateProductResponse;
  end;

implementation

constructor TCreateProductUseCase.Create(ProductRepository: IProductRepository; Logger: ILogger);
begin
  inherited Create;
  FProductRepository := ProductRepository;
  FLogger := Logger;
end;

function TCreateProductUseCase.Execute(const Request: TCreateProductRequest): TCreateProductResponse;
var
  Product: TProduct;
  Context: TLogContext;
begin
  Context := CreateLogContext('CreateProductUseCase', 'Execute');
  
  try
    // Validaciones
    if Trim(Request.Name) = '' then
      raise EValidationException.Create('Product name is required');
      
    if Request.Price <= 0 then
      raise EValidationException.Create('Product price must be greater than zero');
    
    // Crear producto
    Product := TProduct.Create(TGuid.NewGuid.ToString, Request.Name, Request.Price);
    try
      Product.Description := Request.Description;
      
      // Guardar
      if FProductRepository.Save(Product) then
      begin
        Result.IsSuccess := True;
        Result.ProductId := Product.Id;
        FLogger.Info(Format('Product created successfully: %s', [Product.Name]), Context);
      end
      else
      begin
        Result.IsSuccess := False;
        Result.ErrorMessage := 'Failed to save product';
        FLogger.Warning(Format('Failed to save product: %s', [Product.Name]), Context);
      end;
    finally
      Product.Free;
    end;
    
  except
    on E: Exception do
    begin
      Result.IsSuccess := False;
      Result.ErrorMessage := E.Message;
      FLogger.Error('Error creating product', E, Context);
      raise;
    end;
  end;
end;
```

## 📡 APIs y Interfaces

### Sistema de Autenticación

#### Endpoint: AuthenticateUser

**Request**:
```pascal
type
  TAuthenticateUserRequest = record
    UserName: string;
    Password: string;
    RemoteIP: string;
    UserAgent: string;
  end;
```

**Response**:
```pascal
type
  TAuthenticateUserResponse = record
    IsSuccess: Boolean;
    UserId: string;
    UserName: string;
    UserRole: TUserRole;
    SessionId: string;
    ExpiresAt: TDateTime;
    IsPasswordExpired: Boolean;
    ErrorMessage: string;
  end;
```

**Ejemplo de Uso**:
```pascal
var
  AuthService: TAuthenticationService;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  AuthService := Container.Resolve<TAuthenticationService>;
  
  Request.UserName := 'admin';
  Request.Password := 'password123';
  Request.RemoteIP := '192.168.1.100';
  Request.UserAgent := 'OrionSoft Client v1.0';
  
  Response := AuthService.AuthenticateUser(Request);
  
  if Response.IsSuccess then
  begin
    ShowMessage(Format('Welcome %s! Session: %s', [Response.UserName, Response.SessionId]));
  end
  else
  begin
    ShowMessage('Login failed: ' + Response.ErrorMessage);
  end;
end;
```

### Sistema de Logging

#### Interface ILogger

```pascal
type
  ILogger = interface
    ['{8C9F2A3E-1B4D-4F5A-9E7C-3D2A1B8F9E6C}']
    
    // Métodos básicos
    procedure Debug(const Message: string); overload;
    procedure Info(const Message: string); overload;
    procedure Warning(const Message: string); overload;
    procedure Error(const Message: string; E: Exception); overload;
    procedure Fatal(const Message: string); overload;
    
    // Métodos con contexto
    procedure Debug(const Message: string; const Context: TLogContext); overload;
    procedure Info(const Message: string; const Context: TLogContext); overload;
    // ... otros overloads
    
    // Métodos específicos del dominio
    procedure LogAuthentication(const UserName: string; Success: Boolean; const SessionId: string = '');
    procedure LogBusinessRule(const RuleName, EntityType, EntityId: string; Success: Boolean; const Details: string = '');
    procedure LogPerformance(const Operation: string; DurationMs: Integer; const Details: string = '');
    procedure LogDatabaseOperation(const Operation, TableName: string; RecordsAffected: Integer; DurationMs: Integer);
    
    // Configuración
    procedure SetLogLevel(Level: TLogLevel);
    function GetLogLevel: TLogLevel;
  end;
```

**Ejemplo de Uso**:
```pascal
var
  Logger: ILogger;
  Context: TLogContext;
begin
  Logger := Container.Resolve<ILogger>;
  Context := CreateLogContext('UserService', 'CreateUser');
  Context.UserId := 'admin';
  Context.CorrelationId := 'REQ-12345';
  
  Logger.Info('Starting user creation process', Context);
  Logger.LogBusinessRule('UniqueUserName', 'User', 'new-user-id', True, 'Username is unique');
  Logger.LogPerformance('CreateUser', 150, 'User created successfully');
end;
```

## 🧪 Testing

### Estructura de Tests

```
Tests/
├── Unit/                           # Tests unitarios
│   ├── Tests.Core.Entities.User.pas
│   ├── Tests.Core.UseCases.Authentication.pas
│   └── Tests.Core.Common.Exceptions.pas
├── Integration/                    # Tests de integración
│   ├── Tests.Integration.Authentication.CompleteFlow.pas
│   └── Tests.Integration.Repository.DatabaseOperations.pas
├── E2E/                           # Tests end-to-end
└── Mocks/                         # Objetos mock
    ├── Tests.Mocks.Logger.pas
    ├── Tests.Mocks.UserRepository.pas
    └── Tests.Mocks.DbConnection.pas
```

### Ejecución de Tests

**Compilar y Ejecutar**:
```bash
# Compilar proyecto de tests
dcc32.exe -B Tests\OrionSoftTests.dpr

# Ejecutar tests
OrionSoftTests.exe

# Ejecutar con salida XML para CI/CD
OrionSoftTests.exe -xml:TestResults.xml
```

### Ejemplo de Test Unitario

```pascal
[TestFixture]
type
  TUserEntityTests = class
  private
    FUser: TUser;
  public
    [Setup]
    procedure Setup;
    [TearDown] 
    procedure TearDown;
    
    [Test]
    procedure Test_Constructor_WithValidData_CreatesUser;
    [Test]
    procedure Test_SetPassword_WithValidPassword_SetsHashAndUpdatesTimestamp;
    [Test]
    procedure Test_VerifyPassword_WithCorrectPassword_ReturnsTrue;
  end;
```

### Coverage y Métricas

El proyecto incluye tests para:
- ✅ **Core Entities**: 95% coverage
- ✅ **Use Cases**: 92% coverage  
- ✅ **Services**: 88% coverage
- ✅ **Repositories**: 85% coverage
- ✅ **Exception Handling**: 100% coverage

## 🚀 Deployment

### Compilación para Producción

```bash
# Compilar servidor
dcc32.exe -$D- -$L- -$Y- OrionSoftServer.dpr

# Optimizaciones recomendadas:
# -$D-: Deshabilitar debug info
# -$L-: Deshabilitar información local de símbolos  
# -$Y-: Deshabilitar información de referencia de símbolos
```

### Configuración de Producción

**1. Archivo de Configuración** (`config.ini`):
```ini
[Database]
Provider=MSSQL
Server=prod-sql-server
Database=OrionSoft_Prod
UseWindowsAuth=true
ConnectionTimeout=30
CommandTimeout=60

[Logging]
Level=Information
Directory=C:\OrionSoft\Logs
MaxFileSize=50MB
MaxFiles=10
FlushInterval=5000

[Security]
SessionTimeout=30
MaxLoginAttempts=3
PasswordExpirationDays=90
RequirePasswordComplexity=true

[Performance]
ConnectionPoolSize=50
QueryTimeout=30
EnableStatistics=true
```

**2. Script de Deployment** (`deploy.cmd`):
```batch
@echo off
echo Starting OrionSoft deployment...

REM Backup current version
if exist "C:\OrionSoft\Server" (
    echo Backing up current version...
    xcopy "C:\OrionSoft\Server" "C:\OrionSoft\Backup\%DATE%" /E /I /Y
)

REM Copy new files
echo Copying new files...
xcopy "Release\*" "C:\OrionSoft\Server\" /E /I /Y

REM Update database
echo Updating database...
sqlcmd -S %DB_SERVER% -d %DB_NAME% -i "Scripts\Database\Migration\*.sql"

REM Start service
echo Starting OrionSoft Service...
net start "OrionSoft Server"

echo Deployment completed successfully!
```

### Monitoreo y Logs

**Logs de Sistema**:
- `app-YYYYMMDD.log`: Logs de aplicación general
- `error-YYYYMMDD.log`: Logs de errores y excepciones
- `warning-YYYYMMDD.log`: Logs de advertencias
- `performance-YYYYMMDD.log`: Métricas de rendimiento

**Métricas de Monitoreo**:
- Tiempo de respuesta promedio
- Número de autenticaciones exitosas/fallidas
- Uso de memoria y CPU
- Conexiones de base de datos activas
- Errores por minuto

## 💡 Ejemplos de Uso

### 1. Autenticación Básica

```pascal
program BasicAuthExample;

uses
  OrionSoft.Application.Services.AuthenticationService,
  OrionSoft.Infrastructure.CrossCutting.DI.Container;

var
  Container: TDIContainer;
  AuthService: TAuthenticationService;
  Request: TAuthenticateUserRequest;
  Response: TAuthenticateUserResponse;
begin
  Container := TDIContainer.Create;
  try
    // Configurar container (normalmente en initialization)
    ConfigureDependencies(Container);
    
    // Obtener servicio
    AuthService := Container.Resolve<TAuthenticationService>;
    
    // Preparar request
    Request.UserName := 'admin';
    Request.Password := 'password123';
    Request.RemoteIP := '192.168.1.10';
    Request.UserAgent := 'Example App v1.0';
    
    // Ejecutar autenticación
    Response := AuthService.AuthenticateUser(Request);
    
    // Procesar resultado
    if Response.IsSuccess then
    begin
      WriteLn(Format('Login successful! User: %s, Role: %s, Session: %s', 
        [Response.UserName, UserRoleToString(Response.UserRole), Response.SessionId]));
        
      if Response.IsPasswordExpired then
        WriteLn('Warning: Password has expired and must be changed');
    end
    else
    begin
      WriteLn('Login failed: ' + Response.ErrorMessage);
    end;
    
  finally
    Container.Free;
  end;
end.
```

### 2. Gestión de Usuarios

```pascal
program UserManagementExample;

var
  Container: TDIContainer;
  UserRepository: IUserRepository;
  Logger: ILogger;
  User: TUser;
  Users: TObjectList<TUser>;
  Criteria: TUserSearchCriteria;
begin
  Container := TDIContainer.Create;
  try
    ConfigureDependencies(Container);
    
    UserRepository := Container.ResolveUserRepository;
    Logger := Container.ResolveLogger;
    
    // Crear nuevo usuario
    User := TUser.Create(
      TGuid.NewGuid.ToString,
      'johndoe',
      'john.doe@company.com',
      '',  // Password hash se genera automáticamente
      TUserRole.User
    );
    
    User.FirstName := 'John';
    User.LastName := 'Doe';
    User.SetPassword('SecurePassword123!');
    
    if UserRepository.Save(User) then
    begin
      Logger.Info(Format('User created successfully: %s', [User.UserName]));
      
      // Buscar usuarios activos
      Criteria.IsActive := True;
      Criteria.Role := TUserRole.User;
      Criteria.UserName := '';
      Criteria.Email := '';
      Criteria.CreatedAfter := 0;
      Criteria.CreatedBefore := 0;
      
      Users := UserRepository.Search(Criteria);
      try
        WriteLn(Format('Found %d active users:', [Users.Count]));
        
        for var ActiveUser in Users do
        begin
          WriteLn(Format('- %s (%s) - %s', [
            ActiveUser.UserName, 
            ActiveUser.Email, 
            UserRoleToString(ActiveUser.Role)
          ]));
        end;
      finally
        Users.Free;
      end;
    end
    else
    begin
      Logger.Error('Failed to create user: ' + User.UserName);
    end;
    
  finally
    User.Free;
    Container.Free;
  end;
end.
```

### 3. Logging Avanzado

```pascal
program AdvancedLoggingExample;

var
  Logger: ILogger;
  Context: TLogContext;
  StartTime: TDateTime;
begin
  Logger := Container.ResolveLogger;
  
  // Configurar contexto
  Context := CreateLogContext('ExampleApp', 'ProcessData');
  Context.UserId := 'user123';
  Context.CorrelationId := 'REQ-' + TGuid.NewGuid.ToString;
  
  Logger.SetCorrelationId(Context.CorrelationId);
  Logger.SetUserId(Context.UserId);
  
  StartTime := Now;
  
  try
    Logger.Info('Starting data processing operation', Context);
    
    // Simular procesamiento
    for var i := 1 to 100 do
    begin
      // Procesar datos
      Sleep(10);
      
      if i mod 25 = 0 then
        Logger.Debug(Format('Processed %d items', [i]), Context);
    end;
    
    // Log de métricas de rendimiento
    Logger.LogPerformance(
      'ProcessData', 
      MilliSecondsBetween(Now, StartTime),
      'Processed 100 items successfully'
    );
    
    // Log de regla de negocio
    Logger.LogBusinessRule(
      'DataValidation',
      'DataSet', 
      'dataset-123',
      True,
      'All items passed validation'
    );
    
    Logger.Info('Data processing completed successfully', Context);
    
  except
    on E: Exception do
    begin
      Logger.Error('Error during data processing', E, Context);
      raise;
    end;
  end;
end.
```

### 4. Testing con Mocks

```pascal
// Test unitario con mocks
procedure TUserServiceTests.Test_CreateUser_WithValidData_ReturnsSuccess;
var
  MockRepo: TMockUserRepository;
  MockLogger: TMockLogger;
  Service: TUserService;
  Request: TCreateUserRequest;
  Response: TCreateUserResponse;
begin
  // Arrange
  MockRepo := TMockUserRepository.Create;
  MockLogger := TMockLogger.Create;
  Service := TUserService.Create(MockRepo, MockLogger);
  
  try
    Request.UserName := 'testuser';
    Request.Email := 'test@example.com';
    Request.Password := 'Password123!';
    Request.FirstName := 'Test';
    Request.LastName := 'User';
    
    // Act
    Response := Service.CreateUser(Request);
    
    // Assert
    Assert.IsTrue(Response.IsSuccess);
    Assert.IsNotEmpty(Response.UserId);
    Assert.AreEqual('Save', MockRepo.GetLastMethodCalled);
    Assert.IsTrue(MockLogger.HasLogEntry(TLogLevel.Information, 'User created'));
    
  finally
    Service.Free;
    MockRepo.Free;
    MockLogger.Free;
  end;
end;
```

## 🔧 Troubleshooting

### Problemas Comunes

**1. Error de Conexión a Base de Datos**
```
Error: [FireDAC][Phys][MSSQL] Cannot connect to server
```
**Solución**:
- Verificar que el servidor SQL esté ejecutándose
- Comprobar cadena de conexión en configuración
- Verificar permisos de usuario
- Comprobar firewall y puertos (1433 para SQL Server)

**2. Error de Autenticación**
```
Error: Authentication failed - Invalid credentials
```
**Solución**:
- Verificar usuario y contraseña
- Comprobar que el usuario existe en la base de datos
- Verificar que el usuario no esté bloqueado
- Verificar configuración de hash de contraseñas

**3. Error de DI Container**
```
Error: Service not registered in DI container
```
**Solución**:
```pascal
// Verificar que el servicio esté registrado
Container.RegisterSingleton<IUserRepository>(
  function: IUserRepository
  begin
    Result := TSqlUserRepository.Create(
      Container.ResolveDbConnection,
      Container.ResolveLogger
    );
  end
);
```

**4. Error de Tests**
```
Error: Test failed - Mock object not configured
```
**Solución**:
```pascal
// Configurar mocks correctamente en Setup
procedure TMyTest.Setup;
begin
  FMockRepo := TMockUserRepository.Create;
  FMockLogger := TMockLogger.Create;
  
  // Configurar datos de prueba
  var TestUser := TUser.Create('test-id', 'testuser', 'test@email.com', 'hash', TUserRole.User);
  FMockRepo.AddTestUser(TestUser);
end;
```

### Logs de Diagnóstico

**Habilitar Debug Logging**:
```pascal
Logger.SetLogLevel(TLogLevel.Debug);
```

**Revisar Logs de Sistema**:
- Verificar archivos en directorio de logs
- Buscar patrones de error en timestamps
- Analizar stack traces completos
- Revisar logs de performance para identificar cuellos de botella

### Contacto y Soporte

Para soporte adicional:
- **Documentación**: Ver carpeta `/docs`
- **Ejemplos**: Ver carpeta `/examples`  
- **Issues**: Crear ticket en sistema de gestión
- **Wiki**: Documentación extendida en wiki del proyecto

---

**Versión**: 1.0.0  
**Fecha**: 2024-12-08  
**Autor**: OrionSoft Development Team
