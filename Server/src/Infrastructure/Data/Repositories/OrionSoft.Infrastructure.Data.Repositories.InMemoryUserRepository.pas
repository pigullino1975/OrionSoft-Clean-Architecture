unit OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository;

{*
  Implementación en memoria del repositorio de usuarios
  Para testing y desarrollo inicial
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  System.Math,
  System.StrUtils,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Exceptions;

type
  TInMemoryUserRepository = class(TInterfacedObject, IUserRepository)
  private
    FUsers: TObjectDictionary<string, TUser>;
    FInTransaction: Boolean;
    
    function CloneUser(User: TUser): TUser;
    function MatchesCriteria(User: TUser; const Criteria: TUserSearchCriteria): Boolean;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // Operaciones básicas CRUD
    function GetById(const Id: string): TUser;
    function GetByUserName(const UserName: string): TUser;
    function GetByEmail(const Email: string): TUser;
    function GetAll: TObjectList<TUser>;
    
    // Búsquedas avanzadas
    function Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>;
    function SearchPaged(const Criteria: TUserSearchCriteria; PageNumber, PageSize: Integer): TUserPagedResult;
    
    // Persistencia
    function Save(User: TUser): Boolean;
    function Delete(const Id: string): Boolean;
    function ExistsByUserName(const UserName: string): Boolean;
    function ExistsById(const Id: string): Boolean;
    
    // Operaciones específicas de usuarios
    function GetActiveUsers: TObjectList<TUser>;
    function GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
    function GetBlockedUsers: TObjectList<TUser>;
    function GetUsersWithExpiredPasswords(ExpirationDays: Integer): TObjectList<TUser>;
    
    // Validaciones
    function IsUserNameTaken(const UserName: string): Boolean; overload;
    function IsUserNameTaken(const UserName: string; const ExcludeId: string): Boolean; overload;
    function IsEmailTaken(const Email: string): Boolean; overload;
    function IsEmailTaken(const Email: string; const ExcludeId: string): Boolean; overload;
    
    // Transacciones y batch operations
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function SaveBatch(Users: TObjectList<TUser>): Boolean;
    
    // Estadísticas
    function GetTotalCount: Integer;
    function GetActiveCount: Integer;
    function GetCountByRole(Role: TUserRole): Integer;
    
    // Métodos adicionales para testing
    procedure Clear;
    procedure SeedWithTestData;
  end;

implementation

uses
  System.DateUtils,
  System.Hash;

{ TInMemoryUserRepository }

constructor TInMemoryUserRepository.Create;
begin
  inherited Create;
  FUsers := TObjectDictionary<string, TUser>.Create([doOwnsValues]);
  FInTransaction := False;
end;

destructor TInMemoryUserRepository.Destroy;
begin
  FUsers.Free;
  inherited Destroy;
end;

function TInMemoryUserRepository.CloneUser(User: TUser): TUser;
begin
  if not Assigned(User) then
    Exit(nil);
    
  // Crear una nueva instancia con los datos básicos
  Result := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
  
  // Asignar solo las propiedades que tienen setter
  Result.FirstName := User.FirstName;
  Result.LastName := User.LastName;
  Result.IsActive := User.IsActive;
  Result.CreatedAt := User.CreatedAt;
  Result.UpdatedAt := User.UpdatedAt;
  Result.PasswordChangedAt := User.PasswordChangedAt;
  
  // Para las propiedades de solo lectura, tendríamos que usar reflexión o
  // crear un constructor más completo, pero por simplicidad mantenemos
  // los valores por defecto del constructor
end;

function TInMemoryUserRepository.GetById(const Id: string): TUser;
var
  User: TUser;
begin
  if FUsers.TryGetValue(Id, User) then
    Result := CloneUser(User)
  else
    Result := nil;
end;

function TInMemoryUserRepository.GetByUserName(const UserName: string): TUser;
var
  User: TUser;
begin
  Result := nil;
  for User in FUsers.Values do
  begin
    if SameText(User.UserName, UserName) then
    begin
      Result := CloneUser(User);
      Break;
    end;
  end;
end;

function TInMemoryUserRepository.GetByEmail(const Email: string): TUser;
var
  User: TUser;
begin
  Result := nil;
  for User in FUsers.Values do
  begin
    if SameText(User.Email, Email) then
    begin
      Result := CloneUser(User);
      Break;
    end;
  end;
end;

function TInMemoryUserRepository.GetAll: TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers.Values do
    Result.Add(CloneUser(User));
end;

function TInMemoryUserRepository.Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  
  for User in FUsers.Values do
  begin
    if MatchesCriteria(User, Criteria) then
      Result.Add(CloneUser(User));
  end;
end;

function TInMemoryUserRepository.SearchPaged(const Criteria: TUserSearchCriteria; PageNumber, PageSize: Integer): TUserPagedResult;
var
  AllResults: TObjectList<TUser>;
  StartIndex, EndIndex, I: Integer;
begin
  AllResults := Search(Criteria);
  try
    Result.TotalCount := AllResults.Count;
    Result.PageNumber := PageNumber;
    Result.PageSize := PageSize;
    Result.TotalPages := Trunc((Result.TotalCount + PageSize - 1) / PageSize);
    Result.Users := TObjectList<TUser>.Create;
    
    StartIndex := (PageNumber - 1) * PageSize;
    EndIndex := Min(StartIndex + PageSize - 1, AllResults.Count - 1);
    
    for I := StartIndex to EndIndex do
      Result.Users.Add(CloneUser(AllResults[I]));
  finally
    AllResults.Free;
  end;
end;

function TInMemoryUserRepository.Save(User: TUser): Boolean;
var
  ExistingUser: TUser;
begin
  Result := False;
  
  try
    // Validar datos básicos
    if Trim(User.Id) = '' then
      raise EValidationException.Create('User ID cannot be empty', 'VALIDATION_ERROR');
      
    if Trim(User.UserName) = '' then
      raise EValidationException.Create('Username cannot be empty', 'VALIDATION_ERROR');
      
    if Trim(User.Email) = '' then
      raise EValidationException.Create('Email cannot be empty', 'VALIDATION_ERROR');
    
    // Verificar duplicados
    if IsUserNameTaken(User.UserName, User.Id) then
      raise EBusinessRuleException.Create('Username is already taken', 'DUPLICATE_USERNAME');
      
    if IsEmailTaken(User.Email, User.Id) then
      raise EBusinessRuleException.Create('Email is already taken', 'DUPLICATE_EMAIL');
    
    // Si existe, actualizar; si no, crear nuevo
    if FUsers.TryGetValue(User.Id, ExistingUser) then
    begin
      // Para este repositorio en memoria, reemplazamos completamente el usuario
      FUsers.Remove(User.Id);
      ExistingUser := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
      ExistingUser.FirstName := User.FirstName;
      ExistingUser.LastName := User.LastName;
      ExistingUser.IsActive := User.IsActive;
      ExistingUser.CreatedAt := User.CreatedAt;
      ExistingUser.UpdatedAt := Now;
      ExistingUser.PasswordChangedAt := User.PasswordChangedAt;
      
      FUsers.Add(User.Id, ExistingUser);
    end
    else
    begin
      // Crear nuevo usuario
      ExistingUser := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
      ExistingUser.FirstName := User.FirstName;
      ExistingUser.LastName := User.LastName;
      ExistingUser.IsActive := User.IsActive;
      ExistingUser.CreatedAt := User.CreatedAt;
      ExistingUser.UpdatedAt := Now;
      ExistingUser.PasswordChangedAt := User.PasswordChangedAt;
      
      FUsers.Add(User.Id, ExistingUser);
    end;
    
    Result := True;
    
  except
    on E: Exception do
      raise;
  end;
end;

function TInMemoryUserRepository.Delete(const Id: string): Boolean;
begin
  Result := FUsers.ContainsKey(Id);
  if Result then
    FUsers.Remove(Id);
end;

function TInMemoryUserRepository.ExistsByUserName(const UserName: string): Boolean;
var
  User: TUser;
begin
  Result := False;
  for User in FUsers.Values do
  begin
    if SameText(User.UserName, UserName) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TInMemoryUserRepository.ExistsById(const Id: string): Boolean;
begin
  Result := FUsers.ContainsKey(Id);
end;

function TInMemoryUserRepository.GetActiveUsers: TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers.Values do
  begin
    if User.IsActive then
      Result.Add(CloneUser(User));
  end;
end;

function TInMemoryUserRepository.GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers.Values do
  begin
    if User.Role = Role then
      Result.Add(CloneUser(User));
  end;
end;

function TInMemoryUserRepository.GetBlockedUsers: TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers.Values do
  begin
    if User.IsBlocked then
      Result.Add(CloneUser(User));
  end;
end;

function TInMemoryUserRepository.GetUsersWithExpiredPasswords(ExpirationDays: Integer): TObjectList<TUser>;
var
  User: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers.Values do
  begin
    if User.IsPasswordExpired(ExpirationDays) then
      Result.Add(CloneUser(User));
  end;
end;

function TInMemoryUserRepository.IsUserNameTaken(const UserName: string): Boolean;
begin
  Result := ExistsByUserName(UserName);
end;

function TInMemoryUserRepository.IsUserNameTaken(const UserName: string; const ExcludeId: string): Boolean;
var
  User: TUser;
begin
  Result := False;
  for User in FUsers.Values do
  begin
    if SameText(User.UserName, UserName) and (User.Id <> ExcludeId) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TInMemoryUserRepository.IsEmailTaken(const Email: string): Boolean;
var
  User: TUser;
begin
  Result := False;
  for User in FUsers.Values do
  begin
    if SameText(User.Email, Email) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TInMemoryUserRepository.IsEmailTaken(const Email: string; const ExcludeId: string): Boolean;
var
  User: TUser;
begin
  Result := False;
  for User in FUsers.Values do
  begin
    if SameText(User.Email, Email) and (User.Id <> ExcludeId) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

procedure TInMemoryUserRepository.BeginTransaction;
begin
  FInTransaction := True;
end;

procedure TInMemoryUserRepository.CommitTransaction;
begin
  FInTransaction := False;
end;

procedure TInMemoryUserRepository.RollbackTransaction;
begin
  FInTransaction := False;
end;

function TInMemoryUserRepository.SaveBatch(Users: TObjectList<TUser>): Boolean;
var
  User: TUser;
begin
  Result := True;
  
  BeginTransaction;
  try
    for User in Users do
    begin
      if not Save(User) then
      begin
        Result := False;
        RollbackTransaction;
        Exit;
      end;
    end;
    
    CommitTransaction;
  except
    RollbackTransaction;
    Result := False;
    raise;
  end;
end;

function TInMemoryUserRepository.GetTotalCount: Integer;
begin
  Result := FUsers.Count;
end;

function TInMemoryUserRepository.GetActiveCount: Integer;
var
  User: TUser;
begin
  Result := 0;
  for User in FUsers.Values do
  begin
    if User.IsActive then
      Inc(Result);
  end;
end;

function TInMemoryUserRepository.GetCountByRole(Role: TUserRole): Integer;
var
  User: TUser;
begin
  Result := 0;
  for User in FUsers.Values do
  begin
    if User.Role = Role then
      Inc(Result);
  end;
end;

function TInMemoryUserRepository.MatchesCriteria(User: TUser; const Criteria: TUserSearchCriteria): Boolean;
begin
  Result := True;
  
  if (Criteria.UserName <> '') and not ContainsText(User.UserName, Criteria.UserName) then
    Result := False;
    
  if (Criteria.Email <> '') and not ContainsText(User.Email, Criteria.Email) then
    Result := False;
    
  if (Criteria.Role <> TUserRole.None) and (User.Role <> Criteria.Role) then
    Result := False;
    
  if (User.IsActive <> Criteria.IsActive) then
    Result := False;
    
  if (Criteria.CreatedAfter > 0) and (User.CreatedAt < Criteria.CreatedAfter) then
    Result := False;
    
  if (Criteria.CreatedBefore > 0) and (User.CreatedAt > Criteria.CreatedBefore) then
    Result := False;
end;

procedure TInMemoryUserRepository.Clear;
begin
  FUsers.Clear;
end;

procedure TInMemoryUserRepository.SeedWithTestData;
var
  AdminUser, RegularUser, ManagerUser: TUser;
  PasswordHash: string;
begin
  Clear;
  
  // Hash para password "123456"
  PasswordHash := THashSHA2.GetHashString('123456' + 'ORION_SALT_2024', SHA256);
  
  // Usuario Administrador
  AdminUser := TUser.Create('admin-001', 'admin', 'admin@orionsoft.com', PasswordHash, TUserRole.Administrator);
  AdminUser.FirstName := 'System';
  AdminUser.LastName := 'Administrator';
  AdminUser.IsActive := True;
  AdminUser.CreatedAt := Now;
  
  // Usuario Regular
  RegularUser := TUser.Create('user-001', 'jperez', 'juan.perez@orionsoft.com', PasswordHash, TUserRole.User);
  RegularUser.FirstName := 'Juan';
  RegularUser.LastName := 'Pérez';
  RegularUser.IsActive := True;
  RegularUser.CreatedAt := Now;
  
  // Usuario Manager
  ManagerUser := TUser.Create('mgr-001', 'mlopez', 'maria.lopez@orionsoft.com', PasswordHash, TUserRole.Manager);
  ManagerUser.FirstName := 'María';
  ManagerUser.LastName := 'López';
  ManagerUser.IsActive := True;
  ManagerUser.CreatedAt := Now;
  
  FUsers.Add(AdminUser.Id, AdminUser);
  FUsers.Add(RegularUser.Id, RegularUser);
  FUsers.Add(ManagerUser.Id, ManagerUser);
end;

end.
