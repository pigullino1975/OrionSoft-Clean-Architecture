unit OrionSoft.Core.Interfaces.Repositories.IUserRepository;

{*
  Interfaz del repositorio para la entidad User
  Define las operaciones de persistencia para usuarios
*}

interface

uses
  System.Generics.Collections,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Entities.User;

type
  // Criterios de búsqueda para usuarios
  TUserSearchCriteria = record
    UserName: string;
    Email: string;
    Role: TUserRole;
    IsActive: Boolean;
    CreatedAfter: TDateTime;
    CreatedBefore: TDateTime;
    
    procedure Clear;
    function HasCriteria: Boolean;
  end;

  // Resultado paginado
  TUserPagedResult = record
    Users: TObjectList<TUser>;
    TotalCount: Integer;
    PageNumber: Integer;
    PageSize: Integer;
    TotalPages: Integer;
    
    procedure Free;
  end;

  // Interfaz principal del repositorio
  IUserRepository = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-123456789012}']
    
    // Operaciones básicas CRUD
    function GetById(const Id: string): TUser;
    function GetByUserName(const UserName: string): TUser;
    function GetByEmail(const Email: string): TUser;
    function GetAll: TObjectList<TUser>;
    
    // Búsquedas avanzadas
    function Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>; overload;
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
  end;

implementation

{ TUserSearchCriteria }

procedure TUserSearchCriteria.Clear;
begin
  UserName := '';
  Email := '';
  Role := TUserRole.None;
  IsActive := False;
  CreatedAfter := 0;
  CreatedBefore := 0;
end;

function TUserSearchCriteria.HasCriteria: Boolean;
begin
  Result := (UserName <> '') or 
            (Email <> '') or 
            (Role <> TUserRole.None) or
            (CreatedAfter > 0) or 
            (CreatedBefore > 0);
end;

{ TUserPagedResult }

procedure TUserPagedResult.Free;
begin
  if Assigned(Users) then
    Users.Free;
end;

end.
