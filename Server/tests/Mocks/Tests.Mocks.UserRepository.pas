unit Tests.Mocks.UserRepository;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Entities.User,
  OrionSoft.Core.Common.Types;

type
  TMockUserRepository = class(TInterfacedObject, IUserRepository)
  private
    FUsers: TObjectList<TUser>;
    FShouldFailOnNextOperation: Boolean;
    FLastMethodCalled: string;
    FCallCount: Integer;
    
    function FindUserByPredicate(Predicate: TFunc<TUser, Boolean>): TUser;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    // IUserRepository implementation
    function GetById(const Id: string): TUser;
    function GetByUserName(const UserName: string): TUser;
    function GetByEmail(const Email: string): TUser;
    function GetAll: TObjectList<TUser>;
    
    function Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>;
    function SearchPaged(const Criteria: TUserSearchCriteria; PageNumber, PageSize: Integer): TUserPagedResult;
    
    function Save(User: TUser): Boolean;
    function Delete(const Id: string): Boolean;
    function ExistsByUserName(const UserName: string): Boolean;
    function ExistsById(const Id: string): Boolean;
    
    function GetActiveUsers: TObjectList<TUser>;
    function GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
    function GetBlockedUsers: TObjectList<TUser>;
    function GetUsersWithExpiredPasswords(ExpirationDays: Integer): TObjectList<TUser>;
    
    function IsUserNameTaken(const UserName: string): Boolean; overload;
    function IsUserNameTaken(const UserName: string; const ExcludeId: string): Boolean; overload;
    function IsEmailTaken(const Email: string): Boolean; overload;
    function IsEmailTaken(const Email: string; const ExcludeId: string): Boolean; overload;
    
    procedure BeginTransaction;
    procedure CommitTransaction;
    procedure RollbackTransaction;
    function SaveBatch(Users: TObjectList<TUser>): Boolean;
    
    function GetTotalCount: Integer;
    function GetActiveCount: Integer;
    function GetCountByRole(Role: TUserRole): Integer;
    
    // Mock-specific methods for testing
    procedure AddTestUser(User: TUser);
    procedure ClearUsers;
    procedure SetShouldFailOnNextOperation(ShouldFail: Boolean);
    function GetLastMethodCalled: string;
    function GetCallCount: Integer;
    procedure ResetCallCount;
  end;

implementation

{ TMockUserRepository }

constructor TMockUserRepository.Create;
begin
  inherited Create;
  FUsers := TObjectList<TUser>.Create(True);
  FShouldFailOnNextOperation := False;
  FLastMethodCalled := '';
  FCallCount := 0;
end;

destructor TMockUserRepository.Destroy;
begin
  FUsers.Free;
  inherited Destroy;
end;

function TMockUserRepository.FindUserByPredicate(Predicate: TFunc<TUser, Boolean>): TUser;
var
  User: TUser;
begin
  Result := nil;
  for User in FUsers do
  begin
    if Predicate(User) then
    begin
      Result := User;
      Break;
    end;
  end;
end;

function TMockUserRepository.GetById(const Id: string): TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetById';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - GetById');
  end;
  
  Result := FindUserByPredicate(function(User: TUser): Boolean
  begin
    Result := User.Id = Id;
  end);
end;

function TMockUserRepository.GetByUserName(const UserName: string): TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetByUserName';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - GetByUserName');
  end;
  
  Result := FindUserByPredicate(function(User: TUser): Boolean
  begin
    Result := SameText(User.UserName, UserName);
  end);
end;

function TMockUserRepository.GetByEmail(const Email: string): TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetByEmail';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - GetByEmail');
  end;
  
  Result := FindUserByPredicate(function(User: TUser): Boolean
  begin
    Result := SameText(User.Email, Email);
  end);
end;

function TMockUserRepository.GetAll: TObjectList<TUser>;
var
  User: TUser;
  UserCopy: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetAll';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - GetAll');
  end;
  
  Result := TObjectList<TUser>.Create;
  for User in FUsers do
  begin
    UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
    UserCopy.FirstName := User.FirstName;
    UserCopy.LastName := User.LastName;
    UserCopy.IsActive := User.IsActive;
    UserCopy.CreatedAt := User.CreatedAt;
    UserCopy.UpdatedAt := User.UpdatedAt;
    UserCopy.PasswordChangedAt := User.PasswordChangedAt;
    Result.Add(UserCopy);
  end;
end;

function TMockUserRepository.Search(const Criteria: TUserSearchCriteria): TObjectList<TUser>;
var
  User: TUser;
  UserCopy: TUser;
  Matches: Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'Search';
  
  Result := TObjectList<TUser>.Create;
  
  for User in FUsers do
  begin
    Matches := True;
    
    if (Criteria.UserName <> '') and (Pos(Criteria.UserName, User.UserName) = 0) then
      Matches := False;
      
    if Matches and (Criteria.Email <> '') and (Pos(Criteria.Email, User.Email) = 0) then
      Matches := False;
      
    if Matches and (Criteria.Role <> TUserRole.None) and (User.Role <> Criteria.Role) then
      Matches := False;
      
    if Matches and (User.IsActive <> Criteria.IsActive) then
      Matches := False;
    
    if Matches then
    begin
      UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
      UserCopy.FirstName := User.FirstName;
      UserCopy.LastName := User.LastName;
      UserCopy.IsActive := User.IsActive;
      UserCopy.CreatedAt := User.CreatedAt;
      UserCopy.UpdatedAt := User.UpdatedAt;
      UserCopy.PasswordChangedAt := User.PasswordChangedAt;
      Result.Add(UserCopy);
    end;
  end;
end;

function TMockUserRepository.SearchPaged(const Criteria: TUserSearchCriteria; PageNumber, PageSize: Integer): TUserPagedResult;
var
  AllResults: TObjectList<TUser>;
  StartIndex, EndIndex, I: Integer;
  User: TUser;
begin
  AllResults := Search(Criteria);
  try
    Result.TotalCount := AllResults.Count;
    Result.PageNumber := PageNumber;
    Result.PageSize := PageSize;
    Result.TotalPages := (AllResults.Count + PageSize - 1) div PageSize;
    Result.Users := TObjectList<TUser>.Create;
    
    StartIndex := (PageNumber - 1) * PageSize;
    EndIndex := StartIndex + PageSize - 1;
    
    for I := StartIndex to EndIndex do
    begin
      if I < AllResults.Count then
      begin
        User := AllResults[I];
        Result.Users.Add(TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role));
      end;
    end;
  finally
    AllResults.Free;
  end;
end;

function TMockUserRepository.Save(User: TUser): Boolean;
var
  ExistingUser: TUser;
  UserCopy: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'Save';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - Save');
  end;
  
  ExistingUser := GetById(User.Id);
  if Assigned(ExistingUser) then
  begin
    // Update existing - use entity methods to maintain business rules
    // Note: UserName cannot be changed per business rules
    if ExistingUser.Email <> User.Email then
      ExistingUser.UpdateProfile(User.FirstName, User.LastName, User.Email);
    if ExistingUser.PasswordHash <> User.PasswordHash then
      ExistingUser.ChangePassword(User.PasswordHash);
    ExistingUser.FirstName := User.FirstName;
    ExistingUser.LastName := User.LastName;
    ExistingUser.IsActive := User.IsActive;
  end
  else
  begin
    // Add new
    UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
    UserCopy.FirstName := User.FirstName;
    UserCopy.LastName := User.LastName;
    UserCopy.IsActive := User.IsActive;
    UserCopy.CreatedAt := User.CreatedAt;
    UserCopy.UpdatedAt := User.UpdatedAt;
    UserCopy.PasswordChangedAt := User.PasswordChangedAt;
    FUsers.Add(UserCopy);
  end;
  
  Result := True;
end;

function TMockUserRepository.Delete(const Id: string): Boolean;
var
  User: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'Delete';
  
  if FShouldFailOnNextOperation then
  begin
    FShouldFailOnNextOperation := False;
    raise Exception.Create('Mock failure - Delete');
  end;
  
  User := GetById(Id);
  Result := Assigned(User);
  if Result then
    FUsers.Remove(User);
end;

function TMockUserRepository.ExistsByUserName(const UserName: string): Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExistsByUserName';
  Result := Assigned(GetByUserName(UserName));
end;

function TMockUserRepository.ExistsById(const Id: string): Boolean;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'ExistsById';
  Result := Assigned(GetById(Id));
end;

function TMockUserRepository.GetActiveUsers: TObjectList<TUser>;
var
  Criteria: TUserSearchCriteria;
begin
  Criteria.IsActive := True;
  Criteria.UserName := '';
  Criteria.Email := '';
  Criteria.Role := TUserRole.None;
  Criteria.CreatedAfter := 0;
  Criteria.CreatedBefore := 0;
  Result := Search(Criteria);
end;

function TMockUserRepository.GetUsersByRole(Role: TUserRole): TObjectList<TUser>;
var
  Criteria: TUserSearchCriteria;
begin
  Criteria.IsActive := True;
  Criteria.UserName := '';
  Criteria.Email := '';
  Criteria.Role := Role;
  Criteria.CreatedAfter := 0;
  Criteria.CreatedBefore := 0;
  Result := Search(Criteria);
end;

function TMockUserRepository.GetBlockedUsers: TObjectList<TUser>;
var
  User: TUser;
  UserCopy: TUser;
begin
  Result := TObjectList<TUser>.Create;
  for User in FUsers do
  begin
    if User.IsBlocked then
    begin
      UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
      Result.Add(UserCopy);
    end;
  end;
end;

function TMockUserRepository.GetUsersWithExpiredPasswords(ExpirationDays: Integer): TObjectList<TUser>;
var
  User: TUser;
  UserCopy: TUser;
  ExpirationDate: TDateTime;
begin
  Result := TObjectList<TUser>.Create;
  ExpirationDate := Now - ExpirationDays;
  
  for User in FUsers do
  begin
    if User.PasswordChangedAt < ExpirationDate then
    begin
      UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
      Result.Add(UserCopy);
    end;
  end;
end;

function TMockUserRepository.IsUserNameTaken(const UserName: string): Boolean;
begin
  Result := Assigned(GetByUserName(UserName));
end;

function TMockUserRepository.IsUserNameTaken(const UserName: string; const ExcludeId: string): Boolean;
var
  User: TUser;
begin
  User := GetByUserName(UserName);
  Result := Assigned(User) and (User.Id <> ExcludeId);
end;

function TMockUserRepository.IsEmailTaken(const Email: string): Boolean;
begin
  Result := Assigned(GetByEmail(Email));
end;

function TMockUserRepository.IsEmailTaken(const Email: string; const ExcludeId: string): Boolean;
var
  User: TUser;
begin
  User := GetByEmail(Email);
  Result := Assigned(User) and (User.Id <> ExcludeId);
end;

procedure TMockUserRepository.BeginTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'BeginTransaction';
end;

procedure TMockUserRepository.CommitTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'CommitTransaction';
end;

procedure TMockUserRepository.RollbackTransaction;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'RollbackTransaction';
end;

function TMockUserRepository.SaveBatch(Users: TObjectList<TUser>): Boolean;
var
  User: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'SaveBatch';
  
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
    raise;
  end;
end;

function TMockUserRepository.GetTotalCount: Integer;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetTotalCount';
  Result := FUsers.Count;
end;

function TMockUserRepository.GetActiveCount: Integer;
var
  User: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetActiveCount';
  Result := 0;
  for User in FUsers do
  begin
    if User.IsActive then
      Inc(Result);
  end;
end;

function TMockUserRepository.GetCountByRole(Role: TUserRole): Integer;
var
  User: TUser;
begin
  Inc(FCallCount);
  FLastMethodCalled := 'GetCountByRole';
  Result := 0;
  for User in FUsers do
  begin
    if User.Role = Role then
      Inc(Result);
  end;
end;

// Mock-specific methods
procedure TMockUserRepository.AddTestUser(User: TUser);
var
  UserCopy: TUser;
begin
  UserCopy := TUser.Create(User.Id, User.UserName, User.Email, User.PasswordHash, User.Role);
  UserCopy.FirstName := User.FirstName;
  UserCopy.LastName := User.LastName;
  UserCopy.IsActive := User.IsActive;
  UserCopy.CreatedAt := User.CreatedAt;
  UserCopy.UpdatedAt := User.UpdatedAt;
  UserCopy.PasswordChangedAt := User.PasswordChangedAt;
  FUsers.Add(UserCopy);
end;

procedure TMockUserRepository.ClearUsers;
begin
  FUsers.Clear;
end;

procedure TMockUserRepository.SetShouldFailOnNextOperation(ShouldFail: Boolean);
begin
  FShouldFailOnNextOperation := ShouldFail;
end;

function TMockUserRepository.GetLastMethodCalled: string;
begin
  Result := FLastMethodCalled;
end;

function TMockUserRepository.GetCallCount: Integer;
begin
  Result := FCallCount;
end;

procedure TMockUserRepository.ResetCallCount;
begin
  FCallCount := 0;
end;

end.
