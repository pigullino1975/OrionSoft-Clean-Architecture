unit OrionSoft.Core.Entities.User;

{*
  Entidad User para el dominio de autenticación
  Contiene la lógica de negocio relacionada con usuarios del sistema
*}

interface

uses
  System.SysUtils,
  System.DateUtils,
  OrionSoft.Core.Common.Types,
  OrionSoft.Core.Common.Exceptions;

type
  TUser = class
  private
    FId: string;
    FUserName: string;
    FPasswordHash: string;
    FFirstName: string;
    FLastName: string;
    FEmail: string;
    FRole: TUserRole;
    FIsActive: Boolean;
    FIsBlocked: Boolean;
    FFailedLoginAttempts: Integer;
    FLastLoginAt: TDateTime;
    FLastFailedLoginAt: TDateTime;
    FCreatedAt: TDateTime;
    FUpdatedAt: TDateTime;
    FBlockedUntil: TDateTime;
    FPasswordChangedAt: TDateTime;
    
    procedure ValidateUserName(const UserName: string);
    procedure ValidateFirstName(const FirstName: string);
    procedure ValidateLastName(const LastName: string);
    procedure ValidateEmail(const Email: string);
    procedure ResetFailedAttempts;
  public
    constructor Create(const Id, UserName, Email, PasswordHash: string; Role: TUserRole);
    
    // Métodos de negocio para autenticación
    function CanLogin: Boolean;
    procedure RecordSuccessfulLogin;
    procedure RecordFailedLogin(MaxAttempts: Integer; BlockDurationMinutes: Integer);
    procedure BlockUser(const Reason: string; DurationMinutes: Integer = 0);
    procedure UnblockUser;
    procedure ChangePassword(const NewPasswordHash: string);
    function IsPasswordExpired(MaxDaysValid: Integer): Boolean;
    
    // Métodos de negocio para autorización
    function HasRole(RequiredRole: TUserRole): Boolean;
    function CanAccessResource(const ResourceName: string): Boolean;
    
    // Métodos de validación
    procedure Activate;
    procedure Deactivate;
    procedure UpdateProfile(const NewFirstName, NewLastName, NewEmail: string);
    procedure PromoteToRole(NewRole: TUserRole);
    procedure DegradeRole(NewRole: TUserRole);
    procedure Block(DurationMinutes: Integer);
    procedure Unblock;
    procedure ResetPassword(const NewPasswordHash: string);
    
    // Clonación para isolamento de capas (Clean Architecture)
    function Clone: TUser;
    
    // Properties
    property Id: string read FId;
    property UserName: string read FUserName;
    property PasswordHash: string read FPasswordHash;
    property FirstName: string read FFirstName write FFirstName;
    property LastName: string read FLastName write FLastName;
    property Email: string read FEmail;
    property Role: TUserRole read FRole;
    property IsActive: Boolean read FIsActive write FIsActive;
    property IsBlocked: Boolean read FIsBlocked;
    property FailedLoginAttempts: Integer read FFailedLoginAttempts;
    property LastLoginAt: TDateTime read FLastLoginAt;
    property LastFailedLoginAt: TDateTime read FLastFailedLoginAt;
    property CreatedAt: TDateTime read FCreatedAt write FCreatedAt;
    property UpdatedAt: TDateTime read FUpdatedAt write FUpdatedAt;
    property BlockedUntil: TDateTime read FBlockedUntil;
    property PasswordChangedAt: TDateTime read FPasswordChangedAt write FPasswordChangedAt;
  end;

implementation

{ TUser }

constructor TUser.Create(const Id, UserName, Email, PasswordHash: string; Role: TUserRole);
begin
  if Trim(Id) = '' then
    raise CreateRequiredFieldError('Id');
    
  ValidateUserName(UserName);
  ValidateEmail(Email);
  
  if Trim(PasswordHash) = '' then
    raise CreateRequiredFieldError('PasswordHash');
  
  FId := Id;
  FUserName := UserName;
  FEmail := Email;
  FPasswordHash := PasswordHash;
  FRole := Role;
  FIsActive := True;
  FIsBlocked := False;
  FFailedLoginAttempts := 0;
  FCreatedAt := Now;
  FUpdatedAt := Now;
  FPasswordChangedAt := Now;
  FBlockedUntil := 0; // No blocked
  FFirstName := '';
  FLastName := '';
end;

procedure TUser.ValidateUserName(const UserName: string);
begin
  if Trim(UserName) = '' then
    raise CreateRequiredFieldError('UserName');
    
  if Length(UserName) > MAX_USERNAME_LENGTH then
    raise CreateValidationError('UserName', 
      Format('Username cannot exceed %d characters', [MAX_USERNAME_LENGTH]));
      
  // Validar caracteres permitidos
  for var c in UserName do
  begin
    if not (CharInSet(c, ['a'..'z', 'A'..'Z', '0'..'9', '_', '.', '-'])) then
      raise CreateValidationError('UserName', 
        'Username can only contain letters, numbers, underscore, period, and hyphen');
  end;
end;

procedure TUser.ValidateFirstName(const FirstName: string);
begin
  if Trim(FirstName) = '' then
    raise CreateRequiredFieldError('FirstName');
    
  if Length(FirstName) > MAX_NAME_LENGTH then
    raise CreateValidationError('FirstName', 
      Format('First name cannot exceed %d characters', [MAX_NAME_LENGTH]));
end;

procedure TUser.ValidateLastName(const LastName: string);
begin
  if Trim(LastName) = '' then
    raise CreateRequiredFieldError('LastName');
    
  if Length(LastName) > MAX_NAME_LENGTH then
    raise CreateValidationError('LastName', 
      Format('Last name cannot exceed %d characters', [MAX_NAME_LENGTH]));
end;

procedure TUser.ValidateEmail(const Email: string);
begin
  if Trim(Email) = '' then
    raise CreateRequiredFieldError('Email');
    
  if Length(Email) > MAX_EMAIL_LENGTH then
    raise CreateValidationError('Email', 
      Format('Email cannot exceed %d characters', [MAX_EMAIL_LENGTH]));
      
  // Validación básica de formato de email
  if (Pos('@', Email) = 0) or (Pos('.', Email) = 0) then
    raise CreateValidationError('Email', 'Invalid email format');
end;

function TUser.CanLogin: Boolean;
begin
  Result := FIsActive and 
            not FIsBlocked and 
            ((FBlockedUntil = 0) or (Now >= FBlockedUntil));
end;

procedure TUser.RecordSuccessfulLogin;
begin
  if not CanLogin then
    raise CreateBusinessRuleError('User cannot login at this time');
    
  FLastLoginAt := Now;
  FUpdatedAt := Now;
  ResetFailedAttempts;
end;

procedure TUser.RecordFailedLogin(MaxAttempts: Integer; BlockDurationMinutes: Integer);
begin
  // Solo incrementar si no está ya bloqueado y no ha excedido el máximo
  if not FIsBlocked and (FFailedLoginAttempts < MaxAttempts) then
    Inc(FFailedLoginAttempts);
    
  FLastFailedLoginAt := Now;
  FUpdatedAt := Now;
  
  if FFailedLoginAttempts >= MaxAttempts then
  begin
    FIsBlocked := True;
    if BlockDurationMinutes > 0 then
      FBlockedUntil := IncMinute(Now, BlockDurationMinutes)
    else
      FBlockedUntil := 0; // Permanent block
  end;
end;

procedure TUser.ResetFailedAttempts;
begin
  FFailedLoginAttempts := 0;
  FLastFailedLoginAt := 0;
  FUpdatedAt := Now;
end;

procedure TUser.ChangePassword(const NewPasswordHash: string);
begin
  if Trim(NewPasswordHash) = '' then
    raise CreateRequiredFieldError('Password');
    
  FPasswordHash := NewPasswordHash;
  FPasswordChangedAt := Now;
  FUpdatedAt := Now;
  
  // Reset failed attempts on password change
  ResetFailedAttempts;
end;

procedure TUser.ResetPassword(const NewPasswordHash: string);
begin
  if Trim(NewPasswordHash) = '' then
    raise CreateRequiredFieldError('Password');
    
  FPasswordHash := NewPasswordHash;
  FPasswordChangedAt := Now;
  FUpdatedAt := Now;
  
  // Reset failed attempts on password reset
  ResetFailedAttempts;
end;

function TUser.IsPasswordExpired(MaxDaysValid: Integer): Boolean;
begin
  if MaxDaysValid <= 0 then
    Result := False
  else
    Result := DaysBetween(Now, FPasswordChangedAt) > MaxDaysValid;
end;

function TUser.HasRole(RequiredRole: TUserRole): Boolean;
begin
  // Los roles de mayor nivel incluyen los permisos de los menores
  Result := FRole >= RequiredRole;
end;

function TUser.CanAccessResource(const ResourceName: string): Boolean;
begin
  if not FIsActive or FIsBlocked then
    Exit(False);
  
  // Reglas básicas de autorización por recurso
  // En una implementación real, esto estaría en un sistema de permisos más sofisticado
  case FRole of
    TUserRole.None:
      Result := False;
    TUserRole.User:
      Result := Pos('READ_', UpperCase(ResourceName)) = 1;
    TUserRole.Manager:
      Result := (Pos('READ_', UpperCase(ResourceName)) = 1) or
                (Pos('WRITE_', UpperCase(ResourceName)) = 1);
    TUserRole.Administrator:
      Result := True;
  else
    Result := False;
  end;
end;

procedure TUser.Activate;
begin
  if FIsActive then
    raise CreateBusinessRuleError('User is already active');
    
  FIsActive := True;
  FUpdatedAt := Now;
end;

procedure TUser.Deactivate;
begin
  if not FIsActive then
    raise CreateBusinessRuleError('User is already inactive');
    
  FIsActive := False;
  FUpdatedAt := Now;
end;

procedure TUser.UpdateProfile(const NewFirstName, NewLastName, NewEmail: string);
begin
  ValidateFirstName(NewFirstName);
  ValidateLastName(NewLastName);
  ValidateEmail(NewEmail);
  
  FFirstName := NewFirstName;
  FLastName := NewLastName;
  FEmail := NewEmail;
  FUpdatedAt := Now;
end;

procedure TUser.PromoteToRole(NewRole: TUserRole);
begin
  if NewRole <= FRole then
    raise CreateBusinessRuleError(
      Format('Cannot promote to same or lower role. Current: %s, New: %s', 
        [UserRoleToString(FRole), UserRoleToString(NewRole)]));
        
  FRole := NewRole;
  FUpdatedAt := Now;
end;

procedure TUser.DegradeRole(NewRole: TUserRole);
begin
  if NewRole >= FRole then
    raise CreateBusinessRuleError(
      Format('Cannot demote to same or higher role. Current: %s, New: %s', 
        [UserRoleToString(FRole), UserRoleToString(NewRole)]));
        
  FRole := NewRole;
  FUpdatedAt := Now;
end;

procedure TUser.BlockUser(const Reason: string; DurationMinutes: Integer);
begin
  FIsBlocked := True;
  if DurationMinutes > 0 then
    FBlockedUntil := IncMinute(Now, DurationMinutes)
  else
    FBlockedUntil := 0; // Permanent block
  FUpdatedAt := Now;
end;

procedure TUser.UnblockUser;
begin
  FIsBlocked := False;
  FBlockedUntil := 0;
  FUpdatedAt := Now;
end;

procedure TUser.Block(DurationMinutes: Integer);
begin
  BlockUser('Manual block', DurationMinutes);
end;

procedure TUser.Unblock;
begin
  UnblockUser;
end;

function TUser.Clone: TUser;
begin
  Result := TUser.Create(FId, FUserName, FEmail, FPasswordHash, FRole);
  
  // Copiar todos los campos
  Result.FFirstName := FFirstName;
  Result.FLastName := FLastName;
  Result.FIsActive := FIsActive;
  Result.FIsBlocked := FIsBlocked;
  Result.FFailedLoginAttempts := FFailedLoginAttempts;
  Result.FLastLoginAt := FLastLoginAt;
  Result.FLastFailedLoginAt := FLastFailedLoginAt;
  Result.FCreatedAt := FCreatedAt;
  Result.FUpdatedAt := FUpdatedAt;
  Result.FBlockedUntil := FBlockedUntil;
  Result.FPasswordChangedAt := FPasswordChangedAt;
end;

end.
