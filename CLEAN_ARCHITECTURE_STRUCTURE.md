# Clean Architecture Structure for Orionsoft Gestión

## Directory Structure

```
OrionSoft.Desktop/
├── src/
│   ├── Core/                           # Domain & Application Layer
│   │   ├── Entities/                   # Domain Entities
│   │   │   ├── Customer.pas
│   │   │   ├── Product.pas
│   │   │   ├── Invoice.pas
│   │   │   ├── Order.pas
│   │   │   ├── Payment.pas
│   │   │   └── Stock.pas
│   │   │
│   │   ├── ValueObjects/               # Value Objects
│   │   │   ├── Money.pas
│   │   │   ├── Address.pas
│   │   │   ├── Email.pas
│   │   │   └── TaxId.pas
│   │   │
│   │   ├── Interfaces/                 # Repository & Service Interfaces
│   │   │   ├── Repositories/
│   │   │   │   ├── ICustomerRepository.pas
│   │   │   │   ├── IProductRepository.pas
│   │   │   │   ├── IInvoiceRepository.pas
│   │   │   │   └── IStockRepository.pas
│   │   │   │
│   │   │   └── Services/
│   │   │       ├── IEmailService.pas
│   │   │       ├── IReportService.pas
│   │   │       └── ITaxService.pas
│   │   │
│   │   ├── UseCases/                   # Application Business Rules
│   │   │   ├── Customer/
│   │   │   │   ├── CreateCustomerUseCase.pas
│   │   │   │   ├── UpdateCustomerUseCase.pas
│   │   │   │   └── GetCustomerUseCase.pas
│   │   │   │
│   │   │   ├── Sales/
│   │   │   │   ├── CreateInvoiceUseCase.pas
│   │   │   │   ├── ProcessPaymentUseCase.pas
│   │   │   │   └── CancelInvoiceUseCase.pas
│   │   │   │
│   │   │   ├── Inventory/
│   │   │   │   ├── UpdateStockUseCase.pas
│   │   │   │   ├── TransferStockUseCase.pas
│   │   │   │   └── AdjustStockUseCase.pas
│   │   │   │
│   │   │   └── Purchasing/
│   │   │       ├── CreatePurchaseOrderUseCase.pas
│   │   │       └── ReceivePurchaseUseCase.pas
│   │   │
│   │   ├── Specifications/             # Business Rule Specifications
│   │   │   ├── CustomerSpecifications.pas
│   │   │   └── ProductSpecifications.pas
│   │   │
│   │   └── Common/                     # Common domain logic
│   │       ├── Exceptions.pas
│   │       ├── Enums.pas
│   │       └── Constants.pas
│   │
│   ├── Infrastructure/                 # Infrastructure Layer
│   │   ├── Data/                       # Data Access
│   │   │   ├── Repositories/
│   │   │   │   ├── CustomerRepository.pas
│   │   │   │   ├── ProductRepository.pas
│   │   │   │   ├── InvoiceRepository.pas
│   │   │   │   └── StockRepository.pas
│   │   │   │
│   │   │   ├── Context/
│   │   │   │   ├── OrionDbContext.pas
│   │   │   │   └── Migrations/
│   │   │   │
│   │   │   └── UnitOfWork/
│   │   │       └── UnitOfWork.pas
│   │   │
│   │   ├── Services/                   # External Services
│   │   │   ├── EmailService.pas
│   │   │   ├── TaxService.pas
│   │   │   └── ExternalApiService.pas
│   │   │
│   │   ├── Reports/                    # Report Generation
│   │   │   ├── FastReportsService.pas
│   │   │   └── ReportTemplates/
│   │   │
│   │   ├── Configuration/              # Configuration Management
│   │   │   ├── Settings.pas
│   │   │   └── ConnectionStrings.pas
│   │   │
│   │   └── CrossCutting/              # Cross-cutting Concerns
│   │       ├── Logging/
│   │       ├── Security/
│   │       └── Caching/
│   │
│   ├── Presentation/                   # Presentation Layer
│   │   ├── Desktop/                    # Desktop UI (VCL/FMX)
│   │   │   ├── Forms/
│   │   │   │   ├── Customers/
│   │   │   │   │   ├── CustomerListForm.pas
│   │   │   │   │   └── CustomerEditForm.pas
│   │   │   │   │
│   │   │   │   ├── Sales/
│   │   │   │   │   ├── InvoiceForm.pas
│   │   │   │   │   └── PaymentForm.pas
│   │   │   │   │
│   │   │   │   ├── Inventory/
│   │   │   │   │   ├── ProductListForm.pas
│   │   │   │   │   └── StockMovementForm.pas
│   │   │   │   │
│   │   │   │   └── Main/
│   │   │   │       └── MainForm.pas
│   │   │   │
│   │   │   └── Components/             # Reusable UI Components
│   │   │       ├── GridComponents.pas
│   │   │       └── ValidationComponents.pas
│   │   │
│   │   ├── ViewModels/                 # MVVM ViewModels
│   │   │   ├── CustomerViewModel.pas
│   │   │   ├── InvoiceViewModel.pas
│   │   │   └── ProductViewModel.pas
│   │   │
│   │   ├── Controllers/                # UI Controllers
│   │   │   ├── CustomerController.pas
│   │   │   └── InvoiceController.pas
│   │   │
│   │   └── Mappers/                    # DTO Mappers
│   │       ├── CustomerMapper.pas
│   │       └── ProductMapper.pas
│   │
│   ├── Mobile/                         # Mobile-specific modules
│   │   ├── Sales/
│   │   │   ├── MobileSalesForm.pas
│   │   │   └── MobilePaymentForm.pas
│   │   │
│   │   └── Inventory/
│   │       ├── MobileStockForm.pas
│   │       └── MobileInventoryForm.pas
│   │
│   └── Shared/                         # Shared Components
│       ├── DTOs/                       # Data Transfer Objects
│       │   ├── CustomerDTO.pas
│       │   └── ProductDTO.pas
│       │
│       ├── Validation/                 # Validation Logic
│       │   └── ValidationRules.pas
│       │
│       └── Utils/                      # Utility Classes
│           ├── DateUtils.pas
│           └── StringUtils.pas
│
├── tests/                              # Unit Tests
│   ├── Core/
│   │   ├── Entities/
│   │   ├── UseCases/
│   │   └── Specifications/
│   │
│   ├── Infrastructure/
│   │   └── Repositories/
│   │
│   └── Presentation/
│       └── ViewModels/
│
├── docs/                               # Documentation
│   ├── api/
│   ├── architecture/
│   └── user-guides/
│
└── tools/                              # Migration & Build Tools
    ├── MigrationTool/
    ├── CodeGenerator/
    └── BuildScripts/
```

## Implementation Examples

### 1. Core Domain Entity

```pascal
// src/Core/Entities/Customer.pas
unit OrionSoft.Core.Entities.Customer;

interface

uses
  System.SysUtils,
  OrionSoft.Core.ValueObjects.Email,
  OrionSoft.Core.ValueObjects.Address,
  OrionSoft.Core.Common.Enums;

type
  TCustomer = class
  private
    FId: Integer;
    FName: string;
    FEmail: TEmail;
    FAddress: TAddress;
    FCustomerType: TCustomerType;
    FIsActive: Boolean;
    FCreatedAt: TDateTime;
    FLastModified: TDateTime;
    
    procedure ValidateName(const Name: string);
  public
    constructor Create(const Name: string; Email: TEmail; Address: TAddress);
    
    // Business logic methods
    procedure UpdateContactInfo(Email: TEmail; Address: TAddress);
    procedure Activate;
    procedure Deactivate;
    function CanCreateInvoice: Boolean;
    
    // Properties
    property Id: Integer read FId write FId;
    property Name: string read FName;
    property Email: TEmail read FEmail;
    property Address: TAddress read FAddress;
    property CustomerType: TCustomerType read FCustomerType write FCustomerType;
    property IsActive: Boolean read FIsActive;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastModified: TDateTime read FLastModified;
  end;

implementation

constructor TCustomer.Create(const Name: string; Email: TEmail; Address: TAddress);
begin
  ValidateName(Name);
  FName := Name;
  FEmail := Email;
  FAddress := Address;
  FIsActive := True;
  FCreatedAt := Now;
  FLastModified := Now;
end;

procedure TCustomer.ValidateName(const Name: string);
begin
  if Trim(Name) = '' then
    raise Exception.Create('Customer name cannot be empty');
    
  if Length(Name) > 100 then
    raise Exception.Create('Customer name cannot exceed 100 characters');
end;

procedure TCustomer.UpdateContactInfo(Email: TEmail; Address: TAddress);
begin
  FEmail := Email;
  FAddress := Address;
  FLastModified := Now;
end;

procedure TCustomer.Activate;
begin
  FIsActive := True;
  FLastModified := Now;
end;

procedure TCustomer.Deactivate;
begin
  FIsActive := False;
  FLastModified := Now;
end;

function TCustomer.CanCreateInvoice: Boolean;
begin
  Result := FIsActive and (FCustomerType <> ctBlocked);
end;

end.
```

### 2. Repository Interface

```pascal
// src/Core/Interfaces/Repositories/ICustomerRepository.pas
unit OrionSoft.Core.Interfaces.Repositories.ICustomerRepository;

interface

uses
  System.Generics.Collections,
  OrionSoft.Core.Entities.Customer;

type
  ICustomerRepository = interface
    ['{B8F4C567-8D2F-4A1E-9C3B-7E5F1A9B2C4D}']
    
    // Basic CRUD operations
    function GetById(Id: Integer): TCustomer;
    function GetAll: TList<TCustomer>;
    function GetByEmail(const Email: string): TCustomer;
    function GetActiveCustomers: TList<TCustomer>;
    
    procedure Save(Customer: TCustomer);
    procedure Delete(Id: Integer);
    
    // Query methods
    function FindByName(const Name: string): TList<TCustomer>;
    function GetCustomersByType(CustomerType: TCustomerType): TList<TCustomer>;
    
    // Business specific queries
    function GetCustomersWithPendingInvoices: TList<TCustomer>;
    function GetTopCustomersByRevenue(Count: Integer): TList<TCustomer>;
  end;

implementation

end.
```

### 3. Use Case Implementation

```pascal
// src/Core/UseCases/Customer/CreateCustomerUseCase.pas
unit OrionSoft.Core.UseCases.Customer.CreateCustomerUseCase;

interface

uses
  OrionSoft.Core.Entities.Customer,
  OrionSoft.Core.Interfaces.Repositories.ICustomerRepository,
  OrionSoft.Core.ValueObjects.Email,
  OrionSoft.Core.ValueObjects.Address;

type
  TCreateCustomerRequest = record
    Name: string;
    Email: string;
    Street: string;
    City: string;
    Country: string;
  end;

  TCreateCustomerUseCase = class
  private
    FCustomerRepository: ICustomerRepository;
  public
    constructor Create(CustomerRepository: ICustomerRepository);
    function Execute(const Request: TCreateCustomerRequest): TCustomer;
  end;

implementation

uses
  System.SysUtils;

constructor TCreateCustomerUseCase.Create(CustomerRepository: ICustomerRepository);
begin
  if not Assigned(CustomerRepository) then
    raise Exception.Create('CustomerRepository cannot be nil');
    
  FCustomerRepository := CustomerRepository;
end;

function TCreateCustomerUseCase.Execute(const Request: TCreateCustomerRequest): TCustomer;
var
  Email: TEmail;
  Address: TAddress;
  Customer: TCustomer;
  ExistingCustomer: TCustomer;
begin
  // Validate request
  if Trim(Request.Name) = '' then
    raise Exception.Create('Customer name is required');
    
  if Trim(Request.Email) = '' then
    raise Exception.Create('Customer email is required');
  
  // Check if customer already exists
  ExistingCustomer := FCustomerRepository.GetByEmail(Request.Email);
  if Assigned(ExistingCustomer) then
  begin
    ExistingCustomer.Free;
    raise Exception.Create('Customer with this email already exists');
  end;
  
  // Create value objects
  Email := TEmail.Create(Request.Email);
  try
    Address := TAddress.Create(Request.Street, Request.City, Request.Country);
    try
      // Create customer entity
      Customer := TCustomer.Create(Request.Name, Email, Address);
      
      // Save to repository
      FCustomerRepository.Save(Customer);
      
      Result := Customer;
    except
      Address.Free;
      raise;
    end;
  except
    Email.Free;
    raise;
  end;
end;

end.
```

### 4. Repository Implementation

```pascal
// src/Infrastructure/Data/Repositories/CustomerRepository.pas
unit OrionSoft.Infrastructure.Data.Repositories.CustomerRepository;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  OrionSoft.Core.Entities.Customer,
  OrionSoft.Core.Interfaces.Repositories.ICustomerRepository,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TCustomerRepository = class(TInterfacedObject, ICustomerRepository)
  private
    FConnection: IDbConnection;
    
    function MapToEntity(Query: TFDQuery): TCustomer;
    procedure MapToQuery(Customer: TCustomer; Query: TFDQuery);
  public
    constructor Create(Connection: IDbConnection);
    
    // ICustomerRepository implementation
    function GetById(Id: Integer): TCustomer;
    function GetAll: TList<TCustomer>;
    function GetByEmail(const Email: string): TCustomer;
    function GetActiveCustomers: TList<TCustomer>;
    
    procedure Save(Customer: TCustomer);
    procedure Delete(Id: Integer);
    
    function FindByName(const Name: string): TList<TCustomer>;
    function GetCustomersByType(CustomerType: TCustomerType): TList<TCustomer>;
    function GetCustomersWithPendingInvoices: TList<TCustomer>;
    function GetTopCustomersByRevenue(Count: Integer): TList<TCustomer>;
  end;

implementation

uses
  OrionSoft.Core.ValueObjects.Email,
  OrionSoft.Core.ValueObjects.Address;

constructor TCustomerRepository.Create(Connection: IDbConnection);
begin
  if not Assigned(Connection) then
    raise Exception.Create('Connection cannot be nil');
    
  FConnection := Connection;
end;

function TCustomerRepository.GetById(Id: Integer): TCustomer;
var
  Query: TFDQuery;
begin
  Result := nil;
  Query := FConnection.CreateQuery;
  try
    Query.SQL.Text := 'SELECT * FROM Customers WHERE Id = :Id';
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;
    
    if not Query.Eof then
      Result := MapToEntity(Query);
  finally
    Query.Free;
  end;
end;

function TCustomerRepository.GetAll: TList<TCustomer>;
var
  Query: TFDQuery;
  Customers: TList<TCustomer>;
begin
  Customers := TList<TCustomer>.Create;
  Query := FConnection.CreateQuery;
  try
    Query.SQL.Text := 'SELECT * FROM Customers ORDER BY Name';
    Query.Open;
    
    while not Query.Eof do
    begin
      Customers.Add(MapToEntity(Query));
      Query.Next;
    end;
    
    Result := Customers;
  finally
    Query.Free;
  end;
end;

procedure TCustomerRepository.Save(Customer: TCustomer);
var
  Query: TFDQuery;
begin
  Query := FConnection.CreateQuery;
  try
    if Customer.Id = 0 then
    begin
      // Insert new customer
      Query.SQL.Text := 
        'INSERT INTO Customers (Name, Email, Street, City, Country, CustomerType, IsActive, CreatedAt) ' +
        'VALUES (:Name, :Email, :Street, :City, :Country, :CustomerType, :IsActive, :CreatedAt)';
    end
    else
    begin
      // Update existing customer
      Query.SQL.Text := 
        'UPDATE Customers SET Name = :Name, Email = :Email, Street = :Street, ' +
        'City = :City, Country = :Country, CustomerType = :CustomerType, ' +
        'IsActive = :IsActive, LastModified = :LastModified WHERE Id = :Id';
      Query.ParamByName('Id').AsInteger := Customer.Id;
      Query.ParamByName('LastModified').AsDateTime := Customer.LastModified;
    end;
    
    MapToQuery(Customer, Query);
    Query.ExecSQL;
    
    // Get the ID for new customers
    if Customer.Id = 0 then
    begin
      Query.Close;
      Query.SQL.Text := 'SELECT LAST_INSERT_ID() as NewId';
      Query.Open;
      Customer.Id := Query.FieldByName('NewId').AsInteger;
    end;
  finally
    Query.Free;
  end;
end;

function TCustomerRepository.MapToEntity(Query: TFDQuery): TCustomer;
var
  Email: TEmail;
  Address: TAddress;
begin
  Email := TEmail.Create(Query.FieldByName('Email').AsString);
  Address := TAddress.Create(
    Query.FieldByName('Street').AsString,
    Query.FieldByName('City').AsString,
    Query.FieldByName('Country').AsString
  );
  
  Result := TCustomer.Create(Query.FieldByName('Name').AsString, Email, Address);
  Result.Id := Query.FieldByName('Id').AsInteger;
  Result.CustomerType := TCustomerType(Query.FieldByName('CustomerType').AsInteger);
  // Map other fields...
end;

procedure TCustomerRepository.MapToQuery(Customer: TCustomer; Query: TFDQuery);
begin
  Query.ParamByName('Name').AsString := Customer.Name;
  Query.ParamByName('Email').AsString := Customer.Email.Value;
  Query.ParamByName('Street').AsString := Customer.Address.Street;
  Query.ParamByName('City').AsString := Customer.Address.City;
  Query.ParamByName('Country').AsString := Customer.Address.Country;
  Query.ParamByName('CustomerType').AsInteger := Integer(Customer.CustomerType);
  Query.ParamByName('IsActive').AsBoolean := Customer.IsActive;
  
  if Customer.Id = 0 then
    Query.ParamByName('CreatedAt').AsDateTime := Customer.CreatedAt;
end;

end.
```

### 5. ViewModel Implementation

```pascal
// src/Presentation/ViewModels/CustomerViewModel.pas
unit OrionSoft.Presentation.ViewModels.CustomerViewModel;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Entities.Customer,
  OrionSoft.Core.UseCases.Customer.CreateCustomerUseCase,
  OrionSoft.Core.UseCases.Customer.UpdateCustomerUseCase,
  OrionSoft.Core.UseCases.Customer.GetCustomerUseCase,
  OrionSoft.Shared.DTOs.CustomerDTO;

type
  TCustomerViewModel = class
  private
    FCreateCustomerUseCase: TCreateCustomerUseCase;
    FUpdateCustomerUseCase: TUpdateCustomerUseCase;
    FGetCustomerUseCase: TGetCustomerUseCase;
    
    FCustomers: TList<TCustomerDTO>;
    FSelectedCustomer: TCustomerDTO;
    FIsLoading: Boolean;
    FErrorMessage: string;
    
    // Events
    FOnCustomersChanged: TNotifyEvent;
    FOnErrorOccurred: TNotifyEvent;
  public
    constructor Create(
      CreateCustomerUseCase: TCreateCustomerUseCase;
      UpdateCustomerUseCase: TUpdateCustomerUseCase;
      GetCustomerUseCase: TGetCustomerUseCase
    );
    destructor Destroy; override;
    
    // Commands
    procedure LoadCustomers;
    procedure CreateCustomer(const Name, Email, Street, City, Country: string);
    procedure UpdateCustomer(CustomerId: Integer; const Name, Email, Street, City, Country: string);
    procedure SelectCustomer(CustomerId: Integer);
    procedure ClearSelection;
    
    // Properties
    property Customers: TList<TCustomerDTO> read FCustomers;
    property SelectedCustomer: TCustomerDTO read FSelectedCustomer;
    property IsLoading: Boolean read FIsLoading;
    property ErrorMessage: string read FErrorMessage;
    
    // Events
    property OnCustomersChanged: TNotifyEvent read FOnCustomersChanged write FOnCustomersChanged;
    property OnErrorOccurred: TNotifyEvent read FOnErrorOccurred write FOnErrorOccurred;
  end;

implementation

uses
  OrionSoft.Presentation.Mappers.CustomerMapper;

constructor TCustomerViewModel.Create(
  CreateCustomerUseCase: TCreateCustomerUseCase;
  UpdateCustomerUseCase: TUpdateCustomerUseCase;
  GetCustomerUseCase: TGetCustomerUseCase);
begin
  FCreateCustomerUseCase := CreateCustomerUseCase;
  FUpdateCustomerUseCase := UpdateCustomerUseCase;
  FGetCustomerUseCase := GetCustomerUseCase;
  
  FCustomers := TList<TCustomerDTO>.Create;
  FSelectedCustomer := nil;
  FIsLoading := False;
  FErrorMessage := '';
end;

destructor TCustomerViewModel.Destroy;
begin
  FCustomers.Free;
  inherited;
end;

procedure TCustomerViewModel.LoadCustomers;
var
  CustomerEntities: TList<TCustomer>;
  Customer: TCustomer;
  CustomerDTO: TCustomerDTO;
begin
  FIsLoading := True;
  FErrorMessage := '';
  
  try
    CustomerEntities := FGetCustomerUseCase.GetAllCustomers;
    try
      FCustomers.Clear;
      
      for Customer in CustomerEntities do
      begin
        CustomerDTO := TCustomerMapper.EntityToDTO(Customer);
        FCustomers.Add(CustomerDTO);
      end;
      
      if Assigned(FOnCustomersChanged) then
        FOnCustomersChanged(Self);
        
    finally
      // Free customer entities
      for Customer in CustomerEntities do
        Customer.Free;
      CustomerEntities.Free;
    end;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      if Assigned(FOnErrorOccurred) then
        FOnErrorOccurred(Self);
    end;
  end;
  
  FIsLoading := False;
end;

procedure TCustomerViewModel.CreateCustomer(const Name, Email, Street, City, Country: string);
var
  Request: TCreateCustomerRequest;
  Customer: TCustomer;
  CustomerDTO: TCustomerDTO;
begin
  FErrorMessage := '';
  
  try
    Request.Name := Name;
    Request.Email := Email;
    Request.Street := Street;
    Request.City := City;
    Request.Country := Country;
    
    Customer := FCreateCustomerUseCase.Execute(Request);
    try
      CustomerDTO := TCustomerMapper.EntityToDTO(Customer);
      FCustomers.Add(CustomerDTO);
      
      if Assigned(FOnCustomersChanged) then
        FOnCustomersChanged(Self);
        
    finally
      Customer.Free;
    end;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      if Assigned(FOnErrorOccurred) then
        FOnErrorOccurred(Self);
    end;
  end;
end;

end.
```

This Clean Architecture structure provides:

1. **Clear separation of concerns** - Each layer has a specific responsibility
2. **Dependency inversion** - Dependencies point inward toward business logic
3. **Testability** - Each layer can be tested in isolation
4. **Maintainability** - Easy to modify and extend
5. **Cross-platform support** - Business logic is platform-independent
6. **Scalability** - Easy to add new features and modules

The migration can proceed module by module, allowing for gradual transformation while maintaining system functionality.
