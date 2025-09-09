unit OrionSoft.Infrastructure.Data.Repositories.SqlUserRepository;

{*
  Implementación del repositorio de usuarios usando FireDAC
  Soporte para SQL Server, MySQL, PostgreSQL
*}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Classes,
  System.Math,
  System.StrUtils,
  System.DateUtils,
  System.Hash,
  System.Variants,
  FireDAC.Comp.Client,
  FireDAC.Stan.Param,
  FireDAC.Stan.Error,
  FireDAC.DatS,
  FireDAC.Phys.Intf,
  Data.DB,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Exceptions,
  OrionSoft.Core.Interfaces.Services.ILogger,
  OrionSoft.Infrastructure.Data.Context.IDbConnection;

type
  TSqlUserRepository = class(TInterfacedObject, IUserRepository)
  private
    FConnection: IDbConnection;
    FLogger: ILogger;
    FInTransaction: Boolean;
    
    function MapToEntity(Query: TFDQuery): TUser;
    procedure MapToParameters(User: TUser; Query: TFDQuery; IsUpdate: Boolean = False);
    function BuildSelectSQL(const WhereClause: string = ''; const OrderBy: string = ''): string;
    function BuildInsertSQL: string;
    function BuildUpdateSQL: string;
    function ExecuteScalar(const SQL: string; const Params: array of Variant): Integer;
    procedure LogQuery(const Operation, SQL: string; const Params: array of Variant);
    function UserRoleToInt(Role: TUserRole): Integer;
    function IntToUserRole(Value: Integer): TUserRole;
    
  public
    constructor Create(Connection: IDbConnection; Logger: ILogger);
    
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
  end;

implementation

const
  // SQL Base queries
  SELECT_BASE = 'SELECT Id, UserName, PasswordHash, FirstName, LastName, Email, ' +
                'Role, IsActive, IsBlocked, FailedLoginAttempts, LastLoginAt, ' +
                'LastFailedLoginAt, CreatedAt, UpdatedAt, BlockedUntil, PasswordChangedAt ' +
                'FROM Users';

  INSERT_SQL = 'INSERT INTO Users (Id, UserName, PasswordHash, FirstName, LastName, Email, ' +
               'Role, IsActive, IsBlocked, FailedLoginAttempts, LastLoginAt, ' +
               'LastFailedLoginAt, CreatedAt, UpdatedAt, BlockedUntil, PasswordChangedAt) ' +
               'VALUES (:Id, :UserName, :PasswordHash, :FirstName, :LastName, :Email, ' +
               ':Role, :IsActive, :IsBlocked, :FailedLoginAttempts, :LastLoginAt, ' +
               ':LastFailedLoginAt, :CreatedAt, :UpdatedAt, :BlockedUntil, :PasswordChangedAt)';

  UPDATE_SQL = 'UPDATE Users SET UserName = :UserName, PasswordHash = :PasswordHash, ' +
               'FirstName = :FirstName, LastName = :LastName, Email = :Email, ' +
               'Role = :Role, IsActive = :IsActive, IsBlocked = :IsBlocked, ' +
               'FailedLoginAttempts = :FailedLoginAttempts, LastLoginAt = :LastLoginAt, ' +
               'LastFailedLoginAt = :LastFailedLoginAt, UpdatedAt = :UpdatedAt, ' +
               'BlockedUntil = :BlockedUntil, PasswordChangedAt = :PasswordChangedAt ' +
               'WHERE Id = :Id';

{ TSqlUserRepository }

constructor TSqlUserRepository.Create(Connection: IDbConnection; Logger: ILogger);
begin
  inherited Create;
  
  if not Assigned(Connection) then
    raise EArgumentException.Create('Connection cannot be nil');
    
  if not Assigned(Logger) then
    raise EArgumentException.Create('Logger cannot be nil');
    
  FConnection := Connection;
  FLogger := Logger;
  FInTransaction := False;
end;

function TSqlUserRepository.BuildSelectSQL(const WhereClause, OrderBy: string): string;
begin
  Result := SELECT_BASE;
  
  if WhereClause <> '' then
    Result := Result + ' ' + WhereClause;
    
  if OrderBy <> '' then
    Result := Result + ' ORDER BY ' + OrderBy
  else
    Result := Result + ' ORDER BY UserName';
end;

function TSqlUserRepository.BuildInsertSQL: string;
begin
  Result := INSERT_SQL;
end;

function TSqlUserRepository.BuildUpdateSQL: string;
begin
  Result := UPDATE_SQL;
end;

function TSqlUserRepository.UserRoleToInt(Role: TUserRole): Integer;
begin
  Result := Integer(Role);
end;

function TSqlUserRepository.IntToUserRole(Value: Integer): TUserRole;
begin
  case Value of
    0: Result := TUserRole.None;
    1: Result := TUserRole.User;
    2: Result := TUserRole.Manager;
    3: Result := TUserRole.Administrator;
  else
    Result := TUserRole.None;
  end;
end;

function TSqlUserRepository.MapToEntity(Query: TFDQuery): TUser;
var
  User: TUser;
  Email: string;
  PasswordHash: string;
  Role: TUserRole;
begin
  if Query.Eof then
    Exit(nil);
    
  Email := Query.FieldByName('Email').AsString;
  PasswordHash := Query.FieldByName('PasswordHash').AsString;
  Role := IntToUserRole(Query.FieldByName('Role').AsInteger);
  
  User := TUser.Create(
    Query.FieldByName('Id').AsString,
    Query.FieldByName('UserName').AsString,
    Email,
    PasswordHash,
    Role
  );
  
  // Setear propiedades adicionales
  User.FirstName := Query.FieldByName('FirstName').AsString;
  User.LastName := Query.FieldByName('LastName').AsString;
  User.IsActive := Query.FieldByName('IsActive').AsBoolean;
  User.CreatedAt := Query.FieldByName('CreatedAt').AsDateTime;
  User.UpdatedAt := Query.FieldByName('UpdatedAt').AsDateTime;
  User.PasswordChangedAt := Query.FieldByName('PasswordChangedAt').AsDateTime;
  
  // Note: Las propiedades de solo lectura como IsBlocked, FailedLoginAttempts, etc.
  // requerirían reflexión o un constructor más complejo para ser asignadas correctamente
  // Por ahora mantenemos la funcionalidad básica
  
  Result := User;
end;

procedure TSqlUserRepository.MapToParameters(User: TUser; Query: TFDQuery; IsUpdate: Boolean);
begin
  Query.ParamByName('Id').AsString := User.Id;
  Query.ParamByName('UserName').AsString := User.UserName;
  Query.ParamByName('PasswordHash').AsString := User.PasswordHash;
  Query.ParamByName('FirstName').AsString := User.FirstName;
  Query.ParamByName('LastName').AsString := User.LastName;
  Query.ParamByName('Email').AsString := User.Email;
  Query.ParamByName('Role').AsInteger := UserRoleToInt(User.Role);
  Query.ParamByName('IsActive').AsBoolean := User.IsActive;
  Query.ParamByName('IsBlocked').AsBoolean := User.IsBlocked;
  Query.ParamByName('FailedLoginAttempts').AsInteger := User.FailedLoginAttempts;
  
  // Fechas - manejo de NULL/0
  if User.LastLoginAt > 0 then
    Query.ParamByName('LastLoginAt').AsDateTime := User.LastLoginAt
  else
    Query.ParamByName('LastLoginAt').Value := Null;
    
  if User.LastFailedLoginAt > 0 then
    Query.ParamByName('LastFailedLoginAt').AsDateTime := User.LastFailedLoginAt
  else
    Query.ParamByName('LastFailedLoginAt').Value := Null;
    
  if User.BlockedUntil > 0 then
    Query.ParamByName('BlockedUntil').AsDateTime := User.BlockedUntil
  else
    Query.ParamByName('BlockedUntil').Value := Null;
  
  Query.ParamByName('PasswordChangedAt').AsDateTime := User.PasswordChangedAt;
  Query.ParamByName('UpdatedAt').AsDateTime := Now;
  
  if not IsUpdate then
    Query.ParamByName('CreatedAt').AsDateTime := User.CreatedAt;
end;

procedure TSqlUserRepository.LogQuery(const Operation, SQL: string; const Params: array of Variant);
var
  Context: TLogContext;
  LogMessage: string;
  I: Integer;
begin
  Context := CreateLogContext('SqlUserRepository', Operation);
  LogMessage := Format('SQL: %s', [SQL]);
  
  if Length(Params) > 0 then
  begin
    LogMessage := LogMessage + ' | Params: ';
    for I := Low(Params) to High(Params) do
    begin
      if I > Low(Params) then
        LogMessage := LogMessage + ', ';
      LogMessage := LogMessage + VarToStr(Params[I]);
    end;
  end;
  
  FLogger.Debug(LogMessage, Context);
end;

function TSqlUserRepository.GetById(const Id: string): TUser;
var
  Query: TFDQuery;
  SQL: string;
  Context: TLogContext;
begin
  Result := nil;
  Context := CreateLogContext('SqlUserRepository', 'GetById');
  Context.UserId := Id;
  
  try
    SQL := BuildSelectSQL('WHERE Id = :Id');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('Id').AsString := Id;
      
      LogQuery('GetById', SQL, [Id]);
      Query.Open;
      
      Result := MapToEntity(Query);
      
      if Assigned(Result) then
        FLogger.Debug(Format('User found: %s', [Result.UserName]), Context)
      else
        FLogger.Debug('User not found', Context);
        
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting user by Id', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetByUserName(const UserName: string): TUser;
var
  Query: TFDQuery;
  SQL: string;
  Context: TLogContext;
begin
  Result := nil;
  Context := CreateLogContext('SqlUserRepository', 'GetByUserName');
  Context.UserId := UserName;
  
  try
    SQL := BuildSelectSQL('WHERE UserName = :UserName');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('UserName').AsString := UserName;
      
      LogQuery('GetByUserName', SQL, [UserName]);
      Query.Open;
      
      Result := MapToEntity(Query);
      
      if Assigned(Result) then
        FLogger.Debug(Format('User found: %s (ID: %s)', [Result.UserName, Result.Id]), Context)
      else
        FLogger.Debug('User not found', Context);
        
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting user by UserName', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetByEmail(const Email: string): TUser;
var
  Query: TFDQuery;
  SQL: string;
  Context: TLogContext;
begin
  Result := nil;
  Context := CreateLogContext('SqlUserRepository', 'GetByEmail');
  
  try
    SQL := BuildSelectSQL('WHERE Email = :Email');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('Email').AsString := Email;
      
      LogQuery('GetByEmail', SQL, [Email]);
      Query.Open;
      
      Result := MapToEntity(Query);
      
      if Assigned(Result) then
        FLogger.Debug(Format('User found: %s', [Result.UserName]), Context)
      else
        FLogger.Debug('User not found', Context);
        
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting user by Email', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetAll: TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  User: TUser;
  Context: TLogContext;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'GetAll');
  
  try
    SQL := BuildSelectSQL;
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      
      LogQuery('GetAll', SQL, []);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Retrieved %d users', [Result.Count]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting all users', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  WhereClause: string;
  User: TUser;
  ParamCount: Integer;
  Context: TLogContext;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'Search');
  
  try
    // Construir WHERE clause dinámicamente
    WhereClause := '';
    ParamCount := 0;
    
    if Criteria.UserName <> '' then
    begin
      if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 'UserName LIKE :UserName';
      Inc(ParamCount);
    end;
    
    if Criteria.Email <> '' then
    begin
      if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 'Email LIKE :Email';
      Inc(ParamCount);
    end;
    
    if Criteria.Role <> TUserRole.None then
    begin
      if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 'Role = :Role';
      Inc(ParamCount);
    end;
    
    if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
    WhereClause := WhereClause + 'IsActive = :IsActive';
    Inc(ParamCount);
    
    if Criteria.CreatedAfter > 0 then
    begin
      if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 'CreatedAt >= :CreatedAfter';
      Inc(ParamCount);
    end;
    
    if Criteria.CreatedBefore > 0 then
    begin
      if WhereClause <> '' then WhereClause := WhereClause + ' AND ';
      WhereClause := WhereClause + 'CreatedAt <= :CreatedBefore';
      Inc(ParamCount);
    end;
    
    if WhereClause <> '' then
      WhereClause := 'WHERE ' + WhereClause;
    
    SQL := BuildSelectSQL(WhereClause);
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      
      // Asignar parámetros
      if Criteria.UserName <> '' then
        Query.ParamByName('UserName').AsString := '%' + Criteria.UserName + '%';
        
      if Criteria.Email <> '' then
        Query.ParamByName('Email').AsString := '%' + Criteria.Email + '%';
        
      if Criteria.Role <> TUserRole.None then
        Query.ParamByName('Role').AsInteger := UserRoleToInt(Criteria.Role);
        
      Query.ParamByName('IsActive').AsBoolean := Criteria.IsActive;
      
      if Criteria.CreatedAfter > 0 then
        Query.ParamByName('CreatedAfter').AsDateTime := Criteria.CreatedAfter;
        
      if Criteria.CreatedBefore > 0 then
        Query.ParamByName('CreatedBefore').AsDateTime := Criteria.CreatedBefore;
      
      LogQuery('Search', SQL, []);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Search returned %d users', [Result.Count]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error searching users', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.SearchPaged(const Criteria: TUserSearchCriteria; PageNumber, PageSize: Integer): TUserPagedResult;
var
  AllResults: TObjectList<TUser>;
  StartIndex, EndIndex, I: Integer;
begin
  // Para simplicidad, usamos la búsqueda completa y luego paginamos en memoria
  // En una implementación de producción, deberíamos usar OFFSET/LIMIT en la consulta SQL
  AllResults := Search(Criteria);
  try
    Result.TotalCount := AllResults.Count;
    Result.PageNumber := PageNumber;
    Result.PageSize := PageSize;
    Result.TotalPages := Max(1, Trunc((Result.TotalCount + PageSize - 1) / PageSize));
    Result.Users := TObjectList<TUser>.Create;
    
    StartIndex := (PageNumber - 1) * PageSize;
    EndIndex := Min(StartIndex + PageSize - 1, AllResults.Count - 1);
    
    for I := StartIndex to EndIndex do
    begin
      if (I >= 0) and (I < AllResults.Count) then
      begin
        // Crear copia del usuario
        var SourceUser := AllResults[I];
        var CopiedUser := TUser.Create(SourceUser.Id, SourceUser.UserName, 
          SourceUser.Email, SourceUser.PasswordHash, SourceUser.Role);
        CopiedUser.FirstName := SourceUser.FirstName;
        CopiedUser.LastName := SourceUser.LastName;
        CopiedUser.IsActive := SourceUser.IsActive;
        CopiedUser.CreatedAt := SourceUser.CreatedAt;
        CopiedUser.UpdatedAt := SourceUser.UpdatedAt;
        CopiedUser.PasswordChangedAt := SourceUser.PasswordChangedAt;
        Result.Users.Add(CopiedUser);
      end;
    end;
  finally
    AllResults.Free;
  end;
end;

function TSqlUserRepository.Save(User: TUser): Boolean;
var
  Query: TFDQuery;
  SQL: string;
  Context: TLogContext;
  IsUpdate: Boolean;
begin
  Result := False;
  Context := CreateLogContext('SqlUserRepository', 'Save');
  Context.UserId := User.Id;
  
  try
    // Validaciones básicas
    if Trim(User.Id) = '' then
      raise EValidationException.Create('User ID cannot be empty', ERROR_VALIDATION_FAILED);
      
    if Trim(User.UserName) = '' then
      raise EValidationException.Create('Username cannot be empty', ERROR_VALIDATION_FAILED);
      
    if Trim(User.Email) = '' then
      raise EValidationException.Create('Email cannot be empty', ERROR_VALIDATION_FAILED);
    
    // Verificar duplicados
    if IsUserNameTaken(User.UserName, User.Id) then
      raise EBusinessRuleException.Create('Username is already taken', ERROR_DUPLICATE_VALUE);
      
    if IsEmailTaken(User.Email, User.Id) then
      raise EBusinessRuleException.Create('Email is already taken', ERROR_DUPLICATE_VALUE);
    
    // Determinar si es INSERT o UPDATE
    IsUpdate := ExistsById(User.Id);
    
    if IsUpdate then
    begin
      SQL := BuildUpdateSQL;
      FLogger.Debug('Updating existing user', Context);
    end
    else
    begin
      SQL := BuildInsertSQL;
      FLogger.Debug('Creating new user', Context);
    end;
    
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      MapToParameters(User, Query, IsUpdate);
      
      LogQuery('Save', SQL, [User.Id, User.UserName, User.Email]);
      Query.ExecSQL;
      
      Result := Query.RowsAffected > 0;
      
      if Result then
        FLogger.Info(Format('User %s %s successfully', [User.UserName, 
          IfThen(IsUpdate, 'updated', 'created')]), Context)
      else
        FLogger.Warning(Format('No rows affected when saving user %s', [User.UserName]), Context);
        
    finally
      Query.Free;
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error saving user', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.Delete(const Id: string): Boolean;
var
  Query: TFDQuery;
  SQL: string;
  Context: TLogContext;
begin
  Result := False;
  Context := CreateLogContext('SqlUserRepository', 'Delete');
  Context.UserId := Id;
  
  try
    SQL := 'DELETE FROM Users WHERE Id = :Id';
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('Id').AsString := Id;
      
      LogQuery('Delete', SQL, [Id]);
      Query.ExecSQL;
      
      Result := Query.RowsAffected > 0;
      
      if Result then
        FLogger.Info('User deleted successfully', Context)
      else
        FLogger.Warning('No user found to delete', Context);
        
    finally
      Query.Free;
    end;
    
  except
    on E: Exception do
    begin
      FLogger.Error('Error deleting user', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.ExistsByUserName(const UserName: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE UserName = ?', [UserName]) > 0;
end;

function TSqlUserRepository.ExistsById(const Id: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE Id = ?', [Id]) > 0;
end;

function TSqlUserRepository.ExecuteScalar(const SQL: string; const Params: array of Variant): Integer;
var
  Query: TFDQuery;
  I: Integer;
begin
  Result := 0;
  Query := FConnection.CreateQuery;
  try
    Query.SQL.Text := SQL;
    for I := Low(Params) to High(Params) do
      Query.Params[I].Value := Params[I];
      
    Query.Open;
    
    if not Query.Eof then
      Result := Query.Fields[0].AsInteger;
      
  finally
    Query.Free;
  end;
end;

function TSqlUserRepository.GetActiveUsers: TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  User: TUser;
  Context: TLogContext;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'GetActiveUsers');
  
  try
    SQL := BuildSelectSQL('WHERE IsActive = 1');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      
      LogQuery('GetActiveUsers', SQL, []);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Retrieved %d active users', [Result.Count]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting active users', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  User: TUser;
  Context: TLogContext;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'GetUsersByRole');
  
  try
    SQL := BuildSelectSQL('WHERE Role = :Role');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('Role').AsInteger := UserRoleToInt(Role);
      
      LogQuery('GetUsersByRole', SQL, [UserRoleToInt(Role)]);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Retrieved %d users with role %s', [Result.Count, UserRoleToString(Role)]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting users by role', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetBlockedUsers: TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  User: TUser;
  Context: TLogContext;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'GetBlockedUsers');
  
  try
    SQL := BuildSelectSQL('WHERE IsBlocked = 1');
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      
      LogQuery('GetBlockedUsers', SQL, []);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Retrieved %d blocked users', [Result.Count]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting blocked users', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetUsersWithExpiredPasswords(ExpirationDays: Integer): TObjectList<TUser>;
var
  Query: TFDQuery;
  SQL: string;
  User: TUser;
  Context: TLogContext;
  ExpirationDate: TDateTime;
begin
  Result := TObjectList<TUser>.Create;
  Context := CreateLogContext('SqlUserRepository', 'GetUsersWithExpiredPasswords');
  
  try
    ExpirationDate := IncDay(Now, -ExpirationDays);
    SQL := BuildSelectSQL('WHERE PasswordChangedAt < :ExpirationDate');
    
    Query := FConnection.CreateQuery;
    try
      Query.SQL.Text := SQL;
      Query.ParamByName('ExpirationDate').AsDateTime := ExpirationDate;
      
      LogQuery('GetUsersWithExpiredPasswords', SQL, [ExpirationDate]);
      Query.Open;
      
      while not Query.Eof do
      begin
        User := MapToEntity(Query);
        if Assigned(User) then
          Result.Add(User);
        Query.Next;
      end;
      
      FLogger.Debug(Format('Retrieved %d users with expired passwords', [Result.Count]), Context);
      
    finally
      Query.Free;
    end;
  except
    on E: Exception do
    begin
      FLogger.Error('Error getting users with expired passwords', E, Context);
      Result.Free;
      raise;
    end;
  end;
end;

function TSqlUserRepository.IsUserNameTaken(const UserName: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE UserName = ?', [UserName]) > 0;
end;

function TSqlUserRepository.IsUserNameTaken(const UserName: string; const ExcludeId: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE UserName = ? AND Id <> ?', [UserName, ExcludeId]) > 0;
end;

function TSqlUserRepository.IsEmailTaken(const Email: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE Email = ?', [Email]) > 0;
end;

function TSqlUserRepository.IsEmailTaken(const Email: string; const ExcludeId: string): Boolean;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE Email = ? AND Id <> ?', [Email, ExcludeId]) > 0;
end;

procedure TSqlUserRepository.BeginTransaction;
begin
  FConnection.BeginTransaction;
  FInTransaction := True;
end;

procedure TSqlUserRepository.CommitTransaction;
begin
  FConnection.CommitTransaction;
  FInTransaction := False;
end;

procedure TSqlUserRepository.RollbackTransaction;
begin
  FConnection.RollbackTransaction;
  FInTransaction := False;
end;

function TSqlUserRepository.SaveBatch(Users: TObjectList<TUser>): Boolean;
var
  User: TUser;
  Context: TLogContext;
begin
  Result := True;
  Context := CreateLogContext('SqlUserRepository', 'SaveBatch');
  
  BeginTransaction;
  try
    FLogger.Debug(Format('Starting batch save of %d users', [Users.Count]), Context);
    
    for User in Users do
    begin
      if not Save(User) then
      begin
        Result := False;
        FLogger.Error(Format('Failed to save user %s in batch', [User.UserName]), Context);
        RollbackTransaction;
        Exit;
      end;
    end;
    
    CommitTransaction;
    FLogger.Info(Format('Successfully saved %d users in batch', [Users.Count]), Context);
    
  except
    on E: Exception do
    begin
      Result := False;
      RollbackTransaction;
      FLogger.Error('Error during batch save operation', E, Context);
      raise;
    end;
  end;
end;

function TSqlUserRepository.GetTotalCount: Integer;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users', []);
end;

function TSqlUserRepository.GetActiveCount: Integer;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE IsActive = 1', []);
end;

function TSqlUserRepository.GetCountByRole(Role: TUserRole): Integer;
begin
  Result := ExecuteScalar('SELECT COUNT(*) FROM Users WHERE Role = ?', [UserRoleToInt(Role)]);
end;

end.
