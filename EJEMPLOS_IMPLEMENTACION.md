# Ejemplos de Implementación - Clean Architecture Cliente-Servidor

## Migración Práctica del Servicio de Clientes

### **1. Estado Actual (Legacy)**

#### Servidor - Servicio Actual
```pascal
// Server 2012/Services/ClienteService_Impl.pas
unit ClienteService_Impl;

interface

uses
  uROServerIntf, uDADataModule, FireDAC.Comp.Client, DB;

type
  TClienteService = class(TDataAbstractService)
  private
    FDMClientes: TDataModule; // DataModule con lógica mezclada
  public
    function GetClientes: OleVariant; override;
    function SaveCliente(const ClienteData: OleVariant): Boolean; override;
    function DeleteCliente(ClienteId: Integer): Boolean; override;
  end;

implementation

function TClienteService.GetClientes: OleVariant;
var
  Query: TFDQuery;
begin
  // Lógica de negocio mezclada con acceso a datos
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := DMConnection.Connection;
    Query.SQL.Text := 'SELECT * FROM Clientes WHERE Activo = 1';
    Query.Open;
    
    // Lógica de validación mezclada aquí
    while not Query.Eof do
    begin
      if Query.FieldByName('Email').AsString = '' then
        Query.Next; // Skip clientes sin email
      // ... más lógica mezclada
    end;
    
    Result := Query.Data; // Exposición directa de datos
  finally
    Query.Free;
  end;
end;
```

#### Cliente - Formulario Actual
```pascal
// Client 2012/Clientes/UClientes.pas  
unit UClientes;

interface

uses
  Forms, Controls, StdCtrls, DBCtrls, DB, DBClient, Provider;

type
  TFormClientes = class(TForm)
    DataSource1: TDataSource;
    ClientDataSet1: TClientDataSet;
    DataSetProvider1: TDataSetProvider;
    EditNombre: TDBEdit;
    EditEmail: TDBEdit;
    // ... otros controles acoplados a DB
  private
    procedure LoadClientes; // Lógica mezclada en UI
    procedure ValidateCliente; // Validación en UI
  public
    procedure ShowModal;
  end;

implementation

procedure TFormClientes.LoadClientes;
begin
  // Llamada directa al servicio desde UI
  ClientDataSet1.Data := RemoteServer.ClienteService.GetClientes;
  
  // Lógica de negocio en la UI (!!)
  ClientDataSet1.First;
  while not ClientDataSet1.Eof do
  begin
    if ClientDataSet1.FieldByName('Saldo').AsCurrency < 0 then
      // Marcar cliente moroso
      ClientDataSet1.Edit;
      ClientDataSet1.FieldByName('Estado').AsString := 'MOROSO';
      ClientDataSet1.Post;
    end;
    ClientDataSet1.Next;
  end;
end;
```

### **2. Nueva Implementación (Clean Architecture)**

#### **Servidor - Clean Implementation**

##### Entidad de Dominio
```pascal
// Server/src/Core/Entities/Customer.pas
unit OrionSoft.Core.Entities.Customer;

interface

uses
  System.SysUtils, System.Generics.Collections,
  OrionSoft.Core.ValueObjects.Email,
  OrionSoft.Core.ValueObjects.Money,
  OrionSoft.Core.Common.Types;

type
  TCustomerStatus = (csActive, csInactive, csSuspended, csBlocked);
  
  TCustomer = class
  private
    FId: Integer;
    FCode: string;
    FName: string;
    FEmail: TEmail;
    FPhone: string;
    FAddress: string;
    FStatus: TCustomerStatus;
    FCurrentBalance: TMoney;
    FCreditLimit: TMoney;
    FCreatedAt: TDateTime;
    FLastModified: TDateTime;
    
    procedure ValidateBusinessRules;
  public
    constructor Create(const Code, Name: string; Email: TEmail);
    
    // Métodos de negocio
    procedure UpdateContactInfo(Email: TEmail; const Phone, Address: string);
    procedure Suspend(const Reason: string);
    procedure Activate;
    procedure Block(const Reason: string);
    function CanCreateInvoice: Boolean;
    function IsDelinquent: Boolean;
    procedure SetCreditLimit(NewLimit: TMoney);
    
    // Properties
    property Id: Integer read FId write FId;
    property Code: string read FCode;
    property Name: string read FName;
    property Email: TEmail read FEmail;
    property Phone: string read FPhone;
    property Address: string read FAddress;
    property Status: TCustomerStatus read FStatus;
    property CurrentBalance: TMoney read FCurrentBalance;
    property CreditLimit: TMoney read FCreditLimit;
    property CreatedAt: TDateTime read FCreatedAt;
    property LastModified: TDateTime read FLastModified;
  end;

implementation

constructor TCustomer.Create(const Code, Name: string; Email: TEmail);
begin
  if Trim(Code) = '' then
    raise EBusinessRuleException.Create('Código de cliente requerido');
    
  if Trim(Name) = '' then
    raise EBusinessRuleException.Create('Nombre de cliente requerido');
    
  if not Assigned(Email) then
    raise EBusinessRuleException.Create('Email requerido');

  FCode := Code;
  FName := Name;
  FEmail := Email;
  FStatus := csActive;
  FCurrentBalance := TMoney.Create(0);
  FCreditLimit := TMoney.Create(0);
  FCreatedAt := Now;
  FLastModified := Now;
  
  ValidateBusinessRules;
end;

function TCustomer.CanCreateInvoice: Boolean;
begin
  Result := (FStatus = csActive) and 
            (FCurrentBalance.Amount <= FCreditLimit.Amount);
end;

function TCustomer.IsDelinquent: Boolean;
begin
  Result := FCurrentBalance.Amount < 0; // Saldo negativo = debe dinero
end;

procedure TCustomer.ValidateBusinessRules;
begin
  if Length(FCode) > 20 then
    raise EBusinessRuleException.Create('Código muy largo (máx 20 caracteres)');
    
  if Length(FName) > 100 then
    raise EBusinessRuleException.Create('Nombre muy largo (máx 100 caracteres)');
end;
```

##### Repository Interface
```pascal
// Server/src/Core/Interfaces/Repositories/ICustomerRepository.pas
unit OrionSoft.Core.Interfaces.ICustomerRepository;

interface

uses
  System.Generics.Collections,
  OrionSoft.Core.Entities.Customer;

type
  ICustomerRepository = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    
    // CRUD básico
    function GetById(Id: Integer): TCustomer;
    function GetByCode(const Code: string): TCustomer;  
    function GetByEmail(const Email: string): TCustomer;
    function GetAll(ActiveOnly: Boolean = True): TList<TCustomer>;
    
    procedure Save(Customer: TCustomer);
    procedure Delete(Id: Integer);
    
    // Consultas de negocio
    function GetDelinquentCustomers: TList<TCustomer>;
    function GetCustomersWithCredit: TList<TCustomer>;
    function SearchByName(const PartialName: string): TList<TCustomer>;
    function GetTopCustomersBySales(Count: Integer): TList<TCustomer>;
    
    // Operaciones de lote
    procedure UpdateStatus(CustomerIds: TArray<Integer>; NewStatus: TCustomerStatus);
  end;

implementation

end.
```

##### Use Case
```pascal
// Server/src/Core/UseCases/Customer/CreateCustomerUseCase.pas
unit OrionSoft.Core.UseCases.Customer.CreateCustomerUseCase;

interface

uses
  OrionSoft.Core.Entities.Customer,
  OrionSoft.Core.Interfaces.ICustomerRepository,
  OrionSoft.Core.ValueObjects.Email;

type
  TCreateCustomerRequest = record
    Code: string;
    Name: string;
    Email: string;
    Phone: string;
    Address: string;
    CreditLimit: Currency;
  end;
  
  TCreateCustomerResponse = record
    CustomerId: Integer;
    Success: Boolean;
    ErrorMessage: string;
  end;

  TCreateCustomerUseCase = class
  private
    FCustomerRepository: ICustomerRepository;
    FLogger: ILogger;
    
    procedure ValidateRequest(const Request: TCreateCustomerRequest);
    function CheckDuplicates(const Request: TCreateCustomerRequest): Boolean;
  public
    constructor Create(CustomerRepository: ICustomerRepository; Logger: ILogger);
    function Execute(const Request: TCreateCustomerRequest): TCreateCustomerResponse;
  end;

implementation

uses
  System.SysUtils,
  OrionSoft.Core.ValueObjects.Money;

constructor TCreateCustomerUseCase.Create(CustomerRepository: ICustomerRepository; Logger: ILogger);
begin
  if not Assigned(CustomerRepository) then
    raise Exception.Create('CustomerRepository requerido');
    
  if not Assigned(Logger) then
    raise Exception.Create('Logger requerido');
    
  FCustomerRepository := CustomerRepository;
  FLogger := Logger;
end;

function TCreateCustomerUseCase.Execute(const Request: TCreateCustomerRequest): TCreateCustomerResponse;
var
  Customer: TCustomer;
  Email: TEmail;
  CreditLimit: TMoney;
begin
  try
    FLogger.Info('Iniciando creación de cliente: ' + Request.Code);
    
    // Validar request
    ValidateRequest(Request);
    
    // Verificar duplicados
    if CheckDuplicates(Request) then
    begin
      Result.Success := False;
      Result.ErrorMessage := 'Cliente ya existe con ese código o email';
      Exit;
    end;
    
    // Crear objetos de valor
    Email := TEmail.Create(Request.Email);
    CreditLimit := TMoney.Create(Request.CreditLimit);
    
    try
      // Crear entidad de dominio
      Customer := TCustomer.Create(Request.Code, Request.Name, Email);
      Customer.UpdateContactInfo(Email, Request.Phone, Request.Address);
      Customer.SetCreditLimit(CreditLimit);
      
      // Guardar via repositorio
      FCustomerRepository.Save(Customer);
      
      // Respuesta exitosa
      Result.CustomerId := Customer.Id;
      Result.Success := True;
      Result.ErrorMessage := '';
      
      FLogger.Info(Format('Cliente creado exitosamente. ID: %d', [Customer.Id]));
      
    finally
      Customer.Free;
    end;
    
  except
    on E: EBusinessRuleException do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
      FLogger.Warning('Regla de negocio violada: ' + E.Message);
    end;
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := 'Error interno del sistema';
      FLogger.Error('Error creando cliente: ' + E.Message);
    end;
  end;
end;

procedure TCreateCustomerUseCase.ValidateRequest(const Request: TCreateCustomerRequest);
begin
  if Trim(Request.Code) = '' then
    raise EBusinessRuleException.Create('Código requerido');
    
  if Trim(Request.Name) = '' then
    raise EBusinessRuleException.Create('Nombre requerido');
    
  if Trim(Request.Email) = '' then
    raise EBusinessRuleException.Create('Email requerido');
    
  if Request.CreditLimit < 0 then
    raise EBusinessRuleException.Create('Límite de crédito no puede ser negativo');
end;

function TCreateCustomerUseCase.CheckDuplicates(const Request: TCreateCustomerRequest): Boolean;
var
  ExistingCustomer: TCustomer;
begin
  Result := False;
  
  // Verificar código duplicado
  ExistingCustomer := FCustomerRepository.GetByCode(Request.Code);
  if Assigned(ExistingCustomer) then
  begin
    ExistingCustomer.Free;
    Exit(True);
  end;
  
  // Verificar email duplicado  
  ExistingCustomer := FCustomerRepository.GetByEmail(Request.Email);
  if Assigned(ExistingCustomer) then
  begin
    ExistingCustomer.Free;
    Exit(True);
  end;
end;

end.
```

##### Repository Implementation
```pascal
// Server/src/Infrastructure/Data/Repositories/CustomerRepository.pas
unit OrionSoft.Infrastructure.Data.CustomerRepository;

interface

uses
  System.SysUtils, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  OrionSoft.Core.Entities.Customer,
  OrionSoft.Core.Interfaces.ICustomerRepository,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TCustomerRepository = class(TInterfacedObject, ICustomerRepository)
  private
    FConnection: IDbConnection;
    FLogger: ILogger;
    
    function MapToEntity(Query: TFDQuery): TCustomer;
    procedure MapToParams(Customer: TCustomer; Query: TFDQuery);
    function BuildSelectSQL(const WhereClause: string = ''): string;
  public
    constructor Create(Connection: IDbConnection; Logger: ILogger);
    
    // ICustomerRepository
    function GetById(Id: Integer): TCustomer;
    function GetByCode(const Code: string): TCustomer;
    function GetByEmail(const Email: string): TCustomer;
    function GetAll(ActiveOnly: Boolean = True): TList<TCustomer>;
    
    procedure Save(Customer: TCustomer);
    procedure Delete(Id: Integer);
    
    function GetDelinquentCustomers: TList<TCustomer>;
    function GetCustomersWithCredit: TList<TCustomer>;
    function SearchByName(const PartialName: string): TList<TCustomer>;
    function GetTopCustomersBySales(Count: Integer): TList<TCustomer>;
    
    procedure UpdateStatus(CustomerIds: TArray<Integer>; NewStatus: TCustomerStatus);
  end;

implementation

uses
  OrionSoft.Core.ValueObjects.Email,
  OrionSoft.Core.ValueObjects.Money;

constructor TCustomerRepository.Create(Connection: IDbConnection; Logger: ILogger);
begin
  if not Assigned(Connection) then
    raise Exception.Create('Connection requerida');
    
  FConnection := Connection;
  FLogger := Logger;
end;

function TCustomerRepository.GetById(Id: Integer): TCustomer;
var
  Query: TFDQuery;
begin
  Result := nil;
  Query := FConnection.CreateQuery;
  try
    Query.SQL.Text := BuildSelectSQL('WHERE c.Id = :Id');
    Query.ParamByName('Id').AsInteger := Id;
    Query.Open;
    
    if not Query.Eof then
      Result := MapToEntity(Query)
    else
      FLogger.Warning(Format('Cliente no encontrado: ID %d', [Id]));
      
  except
    on E: Exception do
    begin
      FLogger.Error(Format('Error obteniendo cliente %d: %s', [Id, E.Message]));
      raise;
    end;
  finally
    Query.Free;
  end;
end;

procedure TCustomerRepository.Save(Customer: TCustomer);
var
  Query: TFDQuery;
begin
  if not Assigned(Customer) then
    raise Exception.Create('Customer no puede ser nil');
    
  Query := FConnection.CreateQuery;
  try
    FConnection.BeginTransaction;
    try
      if Customer.Id = 0 then
      begin
        // INSERT
        Query.SQL.Text := 
          'INSERT INTO Customers (Code, Name, Email, Phone, Address, Status, ' +
          'CurrentBalance, CreditLimit, CreatedAt, LastModified) ' +
          'VALUES (:Code, :Name, :Email, :Phone, :Address, :Status, ' +
          ':CurrentBalance, :CreditLimit, :CreatedAt, :LastModified)';
      end
      else
      begin
        // UPDATE
        Query.SQL.Text := 
          'UPDATE Customers SET Name = :Name, Email = :Email, Phone = :Phone, ' +
          'Address = :Address, Status = :Status, CurrentBalance = :CurrentBalance, ' +
          'CreditLimit = :CreditLimit, LastModified = :LastModified ' +
          'WHERE Id = :Id';
        Query.ParamByName('Id').AsInteger := Customer.Id;
      end;
      
      MapToParams(Customer, Query);
      Query.ExecSQL;
      
      // Obtener ID para INSERT
      if Customer.Id = 0 then
      begin
        Query.Close;
        Query.SQL.Text := 'SELECT LAST_INSERT_ID() as NewId';
        Query.Open;
        Customer.Id := Query.FieldByName('NewId').AsInteger;
      end;
      
      FConnection.CommitTransaction;
      FLogger.Info(Format('Cliente guardado: %s (ID: %d)', [Customer.Name, Customer.Id]));
      
    except
      FConnection.RollbackTransaction;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

function TCustomerRepository.MapToEntity(Query: TFDQuery): TCustomer;
var
  Email: TEmail;
begin
  Email := TEmail.Create(Query.FieldByName('Email').AsString);
  
  Result := TCustomer.Create(
    Query.FieldByName('Code').AsString,
    Query.FieldByName('Name').AsString,
    Email
  );
  
  Result.Id := Query.FieldByName('Id').AsInteger;
  // Mapear otros campos...
end;

function TCustomerRepository.BuildSelectSQL(const WhereClause: string): string;
begin
  Result := 
    'SELECT c.Id, c.Code, c.Name, c.Email, c.Phone, c.Address, c.Status, ' +
    'c.CurrentBalance, c.CreditLimit, c.CreatedAt, c.LastModified ' +
    'FROM Customers c ' + WhereClause;
end;

end.
```

##### RemObjects Service Adapter
```pascal
// Server/src/Application/Services/CustomerService.pas  
unit OrionSoft.Application.Services.CustomerService;

interface

uses
  uROServerIntf, uDADataModule,
  OrionSoft.Core.UseCases.Customer.CreateCustomerUseCase,
  OrionSoft.Core.UseCases.Customer.UpdateCustomerUseCase,
  OrionSoft.Core.UseCases.Customer.GetCustomerUseCase,
  OrionSoft.Application.DTOs.CustomerDTO,
  OrionSoft.Application.Mappers.CustomerMapper;

type
  TCustomerService = class(TDataAbstractService)
  private
    FCreateCustomerUseCase: TCreateCustomerUseCase;
    FUpdateCustomerUseCase: TUpdateCustomerUseCase;
    FGetCustomerUseCase: TGetCustomerUseCase;
    FMapper: TCustomerMapper;
  protected
    procedure InitializeUseCases; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    
    // RemObjects interface methods
    function GetCustomers(ActiveOnly: Boolean): OleVariant; override;
    function GetCustomerById(Id: Integer): OleVariant; override;
    function CreateCustomer(const CustomerData: OleVariant): OleVariant; override;
    function UpdateCustomer(const CustomerData: OleVariant): OleVariant; override;
    function DeleteCustomer(Id: Integer): Boolean; override;
    function SearchCustomers(const SearchTerm: string): OleVariant; override;
  end;

implementation

uses
  System.Variants, System.SysUtils,
  OrionSoft.Infrastructure.DI.Container; // Dependency Injection

constructor TCustomerService.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  InitializeUseCases;
  FMapper := TCustomerMapper.Create;
end;

destructor TCustomerService.Destroy;
begin
  FMapper.Free;
  inherited Destroy;
end;

procedure TCustomerService.InitializeUseCases;
begin
  // Resolver dependencias via DI Container
  FCreateCustomerUseCase := DIContainer.Resolve<TCreateCustomerUseCase>;
  FUpdateCustomerUseCase := DIContainer.Resolve<TUpdateCustomerUseCase>;
  FGetCustomerUseCase := DIContainer.Resolve<TGetCustomerUseCase>;
end;

function TCustomerService.GetCustomers(ActiveOnly: Boolean): OleVariant;
var
  Customers: TList<TCustomer>;
  CustomerDTOs: TArray<TCustomerDTO>;
  i: Integer;
begin
  try
    Customers := FGetCustomerUseCase.GetAllCustomers(ActiveOnly);
    try
      SetLength(CustomerDTOs, Customers.Count);
      
      for i := 0 to Customers.Count - 1 do
        CustomerDTOs[i] := FMapper.EntityToDTO(Customers[i]);
        
      Result := FMapper.ArrayToVariant(CustomerDTOs);
      
    finally
      // Liberar entidades
      for i := 0 to Customers.Count - 1 do
        Customers[i].Free;
      Customers.Free;
    end;
    
  except
    on E: Exception do
    begin
      LogError('GetCustomers', E.Message);
      raise;
    end;
  end;
end;

function TCustomerService.CreateCustomer(const CustomerData: OleVariant): OleVariant;
var
  Request: TCreateCustomerRequest;
  Response: TCreateCustomerResponse;
begin
  try
    // Mapear variant a request
    Request := FMapper.VariantToCreateRequest(CustomerData);
    
    // Ejecutar caso de uso
    Response := FCreateCustomerUseCase.Execute(Request);
    
    // Mapear response a variant
    Result := FMapper.CreateResponseToVariant(Response);
    
  except
    on E: Exception do
    begin
      LogError('CreateCustomer', E.Message);
      raise;
    end;
  end;
end;

end.
```

#### **Cliente - Clean Implementation**

##### ViewModel
```pascal
// Client/src/Presentation/ViewModels/CustomerListViewModel.pas
unit OrionSoft.Presentation.ViewModels.CustomerListViewModel;

interface

uses
  System.SysUtils, System.Generics.Collections, System.Classes,
  OrionSoft.Core.Models.Customer,
  OrionSoft.Infrastructure.RemObjects.ICustomerServiceProxy,
  OrionSoft.Presentation.Common.BaseViewModel,
  OrionSoft.Presentation.Common.ICommand;

type
  TCustomerListViewModel = class(TBaseViewModel)
  private
    FCustomerService: ICustomerServiceProxy;
    FCustomers: TObservableList<TCustomer>;
    FSelectedCustomer: TCustomer;
    FSearchTerm: string;
    FIsLoading: Boolean;
    FActiveOnly: Boolean;
    
    // Commands
    FLoadCustomersCommand: ICommand;
    FSearchCommand: ICommand;
    FCreateCustomerCommand: ICommand;
    FEditCustomerCommand: ICommand;
    FDeleteCustomerCommand: ICommand;
    
    procedure DoLoadCustomers;
    procedure DoSearch;
    procedure DoCreateCustomer;
    procedure DoEditCustomer;
    procedure DoDeleteCustomer;
    
    function CanExecuteEdit: Boolean;
    function CanExecuteDelete: Boolean;
  protected
    procedure InitializeCommands; override;
  public
    constructor Create(CustomerService: ICustomerServiceProxy);
    destructor Destroy; override;
    
    // Properties
    property Customers: TObservableList<TCustomer> read FCustomers;
    property SelectedCustomer: TCustomer read FSelectedCustomer write FSelectedCustomer;
    property SearchTerm: string read FSearchTerm write FSearchTerm;
    property IsLoading: Boolean read FIsLoading;
    property ActiveOnly: Boolean read FActiveOnly write FActiveOnly;
    
    // Commands
    property LoadCustomersCommand: ICommand read FLoadCustomersCommand;
    property SearchCommand: ICommand read FSearchCommand;
    property CreateCustomerCommand: ICommand read FCreateCustomerCommand;
    property EditCustomerCommand: ICommand read FEditCustomerCommand;
    property DeleteCustomerCommand: ICommand read FDeleteCustomerCommand;
    
    // Methods
    procedure LoadCustomers;
    procedure RefreshCustomers;
    procedure SelectCustomer(Customer: TCustomer);
  end;

implementation

uses
  OrionSoft.Presentation.Common.Command,
  OrionSoft.Presentation.Common.AsyncCommand;

constructor TCustomerListViewModel.Create(CustomerService: ICustomerServiceProxy);
begin
  inherited Create;
  
  if not Assigned(CustomerService) then
    raise Exception.Create('CustomerService requerido');
    
  FCustomerService := CustomerService;
  FCustomers := TObservableList<TCustomer>.Create;
  FActiveOnly := True;
  
  InitializeCommands;
end;

destructor TCustomerListViewModel.Destroy;
begin
  FCustomers.Free;
  inherited Destroy;
end;

procedure TCustomerListViewModel.InitializeCommands;
begin
  FLoadCustomersCommand := TAsyncCommand.Create(DoLoadCustomers);
  FSearchCommand := TAsyncCommand.Create(DoSearch);
  FCreateCustomerCommand := TCommand.Create(DoCreateCustomer);
  FEditCustomerCommand := TCommand.Create(DoEditCustomer, CanExecuteEdit);
  FDeleteCustomerCommand := TCommand.Create(DoDeleteCustomer, CanExecuteDelete);
end;

procedure TCustomerListViewModel.DoLoadCustomers;
begin
  SetIsLoading(True);
  try
    var CustomerList := FCustomerService.GetCustomers(FActiveOnly);
    
    FCustomers.Clear;
    for var Customer in CustomerList do
      FCustomers.Add(Customer);
      
    NotifyPropertyChanged('Customers');
    
  except
    on E: Exception do
      ShowError('Error cargando clientes: ' + E.Message);
  finally
    SetIsLoading(False);
  end;
end;

procedure TCustomerListViewModel.DoSearch;
begin
  if Trim(FSearchTerm) = '' then
  begin
    LoadCustomers;
    Exit;
  end;
  
  SetIsLoading(True);
  try
    var SearchResults := FCustomerService.SearchCustomers(FSearchTerm);
    
    FCustomers.Clear;
    for var Customer in SearchResults do
      FCustomers.Add(Customer);
      
    NotifyPropertyChanged('Customers');
    
  except
    on E: Exception do
      ShowError('Error en búsqueda: ' + E.Message);
  finally
    SetIsLoading(False);
  end;
end;

function TCustomerListViewModel.CanExecuteEdit: Boolean;
begin
  Result := Assigned(FSelectedCustomer);
end;

function TCustomerListViewModel.CanExecuteDelete: Boolean;
begin
  Result := Assigned(FSelectedCustomer) and 
           (FSelectedCustomer.Status <> csBlocked);
end;

procedure TCustomerListViewModel.LoadCustomers;
begin
  FLoadCustomersCommand.Execute;
end;

procedure TCustomerListViewModel.SelectCustomer(Customer: TCustomer);
begin
  FSelectedCustomer := Customer;
  NotifyPropertyChanged('SelectedCustomer');
  
  // Notificar que cambió la disponibilidad de comandos
  FEditCustomerCommand.RaiseCanExecuteChanged;
  FDeleteCustomerCommand.RaiseCanExecuteChanged;
end;

end.
```

##### Form (UI Layer)
```pascal
// Client/src/Presentation/Forms/Customer/CustomerListForm.pas
unit OrionSoft.Presentation.Forms.Customer.CustomerListForm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.Grids, Vcl.DBGrids, Vcl.ExtCtrls, Vcl.ComCtrls,
  OrionSoft.Presentation.ViewModels.CustomerListViewModel,
  OrionSoft.Presentation.Common.BaseForm;

type
  TCustomerListForm = class(TBaseForm)
    PanelTop: TPanel;
    EditSearch: TEdit;
    ButtonSearch: TButton;
    ButtonNew: TButton;
    CheckActiveOnly: TCheckBox;
    GridCustomers: TStringGrid;
    PanelBottom: TPanel;
    ButtonEdit: TButton;
    ButtonDelete: TButton;
    ButtonRefresh: TButton;
    ProgressBar: TProgressBar;
    StatusBar: TStatusBar;
    
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure EditSearchKeyPress(Sender: TObject; var Key: Char);
    procedure ButtonSearchClick(Sender: TObject);
    procedure ButtonNewClick(Sender: TObject);
    procedure ButtonEditClick(Sender: TObject);
    procedure ButtonDeleteClick(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure CheckActiveOnlyClick(Sender: TObject);
    procedure GridCustomersClick(Sender: TObject);
    procedure GridCustomersDblClick(Sender: TObject);
    
  private
    FViewModel: TCustomerListViewModel;
    
    procedure BindViewModel;
    procedure UnbindViewModel;
    procedure OnCustomersChanged(Sender: TObject);
    procedure OnSelectedCustomerChanged(Sender: TObject);
    procedure OnIsLoadingChanged(Sender: TObject);
    procedure UpdateUI;
    procedure PopulateGrid;
    procedure UpdateButtonStates;
  public
    property ViewModel: TCustomerListViewModel read FViewModel write SetViewModel;
  end;

implementation

uses
  OrionSoft.Infrastructure.DI.Container,
  OrionSoft.Infrastructure.RemObjects.ICustomerServiceProxy,
  OrionSoft.Presentation.Forms.Customer.CustomerEditForm;

{$R *.dfm}

procedure TCustomerListForm.FormCreate(Sender: TObject);
var
  CustomerService: ICustomerServiceProxy;
begin
  inherited;
  
  // Resolver dependencias via DI
  CustomerService := DIContainer.Resolve<ICustomerServiceProxy>;
  FViewModel := TCustomerListViewModel.Create(CustomerService);
  
  BindViewModel;
  
  // Configurar grid
  SetupGrid;
  
  // Cargar datos inicial
  FViewModel.LoadCustomers;
end;

procedure TCustomerListForm.FormDestroy(Sender: TObject);
begin
  UnbindViewModel;
  FViewModel.Free;
  inherited;
end;

procedure TCustomerListForm.BindViewModel;
begin
  if not Assigned(FViewModel) then Exit;
  
  // Bind properties bidireccional
  CheckActiveOnly.Checked := FViewModel.ActiveOnly;
  EditSearch.Text := FViewModel.SearchTerm;
  
  // Bind events
  FViewModel.OnPropertyChanged.Add(Self, OnViewModelPropertyChanged);
  FViewModel.Customers.OnChanged.Add(Self, OnCustomersChanged);
  
  // Bind commands  
  ButtonSearch.OnClick := 
    procedure(Sender: TObject)
    begin
      FViewModel.SearchTerm := EditSearch.Text;
      FViewModel.SearchCommand.Execute;
    end;
    
  ButtonNew.OnClick := 
    procedure(Sender: TObject)
    begin
      FViewModel.CreateCustomerCommand.Execute;
    end;
    
  ButtonEdit.OnClick := 
    procedure(Sender: TObject)
    begin
      FViewModel.EditCustomerCommand.Execute;
    end;
    
  ButtonDelete.OnClick := 
    procedure(Sender: TObject)
    begin
      if MessageDlg('¿Confirma eliminar el cliente?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
        FViewModel.DeleteCustomerCommand.Execute;
    end;
    
  ButtonRefresh.OnClick := 
    procedure(Sender: TObject)
    begin
      FViewModel.LoadCustomersCommand.Execute;
    end;
    
  UpdateUI;
end;

procedure TCustomerListForm.OnCustomersChanged(Sender: TObject);
begin
  PopulateGrid;
  UpdateButtonStates;
  StatusBar.SimpleText := Format('%d clientes', [FViewModel.Customers.Count]);
end;

procedure TCustomerListForm.OnIsLoadingChanged(Sender: TObject);
begin
  ProgressBar.Visible := FViewModel.IsLoading;
  
  // Disable controls during loading
  PanelTop.Enabled := not FViewModel.IsLoading;
  PanelBottom.Enabled := not FViewModel.IsLoading;
  GridCustomers.Enabled := not FViewModel.IsLoading;
end;

procedure TCustomerListForm.PopulateGrid;
var
  i: Integer;
  Customer: TCustomer;
begin
  GridCustomers.RowCount := FViewModel.Customers.Count + 1; // +1 for header
  
  // Headers
  GridCustomers.Cells[0, 0] := 'Código';
  GridCustomers.Cells[1, 0] := 'Nombre';
  GridCustomers.Cells[2, 0] := 'Email';  
  GridCustomers.Cells[3, 0] := 'Estado';
  GridCustomers.Cells[4, 0] := 'Saldo';
  
  // Data
  for i := 0 to FViewModel.Customers.Count - 1 do
  begin
    Customer := FViewModel.Customers[i];
    GridCustomers.Cells[0, i + 1] := Customer.Code;
    GridCustomers.Cells[1, i + 1] := Customer.Name;
    GridCustomers.Cells[2, i + 1] := Customer.Email.Value;
    GridCustomers.Cells[3, i + 1] := CustomerStatusToString(Customer.Status);
    GridCustomers.Cells[4, i + 1] := FormatCurrency(Customer.CurrentBalance.Amount);
    
    // Color coding for delinquent customers
    if Customer.IsDelinquent then
      GridCustomers.Colors[i + 1] := clLtRed;
  end;
end;

procedure TCustomerListForm.UpdateButtonStates;
begin
  ButtonEdit.Enabled := FViewModel.EditCustomerCommand.CanExecute;
  ButtonDelete.Enabled := FViewModel.DeleteCustomerCommand.CanExecute;
end;

procedure TCustomerListForm.GridCustomersClick(Sender: TObject);
var
  SelectedRow: Integer;
  SelectedCustomer: TCustomer;
begin
  SelectedRow := GridCustomers.Row - 1; // -1 for header
  
  if (SelectedRow >= 0) and (SelectedRow < FViewModel.Customers.Count) then
  begin
    SelectedCustomer := FViewModel.Customers[SelectedRow];
    FViewModel.SelectCustomer(SelectedCustomer);
  end;
end;

end.
```

### **3. Comparación Beneficios**

#### **Antes (Legacy)**
❌ **Lógica de negocio mezclada** en UI y servicios  
❌ **Testing complejo** - dependencias acopladas  
❌ **Mantenimiento difícil** - cambios afectan múltiples capas  
❌ **Reutilización imposible** - código específico a UI  
❌ **Performance impredecible** - consultas N+1, cache inadecuado  

#### **Después (Clean Architecture)**
✅ **Separación clara de responsabilidades**  
✅ **Testing fácil** - cada capa testeable independientemente  
✅ **Mantenimiento simple** - cambios localizados  
✅ **Reutilización alta** - lógica de negocio reutilizable  
✅ **Performance optimizada** - Repository pattern, caching estratégico  
✅ **Cross-platform ready** - lógica independiente de UI  

### **4. Plan de Testing**

```pascal
// Tests/Core/UseCases/Customer/Test_CreateCustomerUseCase.pas
unit Tests.Core.UseCases.Customer.Test_CreateCustomerUseCase;

interface

uses
  DUnitX.TestFramework,
  OrionSoft.Core.UseCases.Customer.CreateCustomerUseCase,
  Tests.Mocks.MockCustomerRepository,
  Tests.Mocks.MockLogger;

type
  [TestFixture]
  TCreateCustomerUseCaseTest = class
  private
    FUseCase: TCreateCustomerUseCase;
    FMockRepository: TMockCustomerRepository;
    FMockLogger: TMockLogger;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure CreateCustomer_ValidRequest_Success;
    
    [Test]
    procedure CreateCustomer_EmptyName_ThrowsException;
    
    [Test]
    procedure CreateCustomer_InvalidEmail_ThrowsException;
    
    [Test]
    procedure CreateCustomer_DuplicateCode_ReturnsFalse;
  end;
```

Esta implementación demuestra cómo transformar el código legacy en una arquitectura clean, manteniendo toda la funcionalidad pero con **mejor organización, testabilidad y mantenibilidad**.

<function_calls>
<invoke name="mark_todo_as_done">
<parameter name="todo_ids">["32efdb51-c711-4871-9382-efd22883beeb"]
