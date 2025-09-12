unit Tests.Application.Services.AuthenticationServiceTests;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  OrionSoft.Application.Services.AuthenticationService,
  OrionSoft.Infrastructure.CrossCutting.DI.Container,
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository,
  OrionSoft.Core.Interfaces.Repositories.IUserRepository,
  OrionSoft.Core.Interfaces.Services.ILogger,
  Tests.Mocks.MockLogger,
  Tests.TestBase;

type
  [TestFixture]
  TAuthenticationServiceTests = class(TTestBase)
  private
    FContainer: TDIContainer;
    FAuthService: TAuthenticationService;
    
  public
    [Setup]
    procedure Setup; override;
    [TearDown]
    procedure TearDown; override;
    
    [Test]
    procedure TestLogin_ValidCredentials_ShouldSucceed;
    
    [Test]
    procedure TestLogin_InvalidCredentials_ShouldFail;
  end;

implementation

{ TAuthenticationServiceTests }

procedure TAuthenticationServiceTests.Setup;
var
  UserRepo: TInMemoryUserRepository;
  MockLogger: TMockLogger;
begin
  inherited Setup;
  
  FContainer := TDIContainer.Create;
  
  // Setup dependencies
  UserRepo := TInMemoryUserRepository.Create;
  UserRepo.SeedWithTestData;
  FContainer.RegisterUserRepository(UserRepo);
  
  MockLogger := TMockLogger.Create;
  FContainer.RegisterLogger(MockLogger);
  
  FAuthService := TAuthenticationService.Create(FContainer);
end;

procedure TAuthenticationServiceTests.TearDown;
begin
  FAuthService.Free;
  FContainer.Free;
  inherited TearDown;
end;

procedure TAuthenticationServiceTests.TestLogin_ValidCredentials_ShouldSucceed;
var
  Request: TLoginRequest;
  Result: TAuthenticationResult;
begin
  // Arrange
  Request := TLoginRequest.Create('admin', '123456');
  
  // Act
  Result := FAuthService.Login(Request);
  
  // Assert
  try
    Assert.IsTrue(Result.Success);
    Assert.IsNotNull(Result.User);
    Assert.IsNotEmpty(Result.SessionId);
  finally
    Result.Free;
  end;
end;

procedure TAuthenticationServiceTests.TestLogin_InvalidCredentials_ShouldFail;
var
  Request: TLoginRequest;
  Result: TAuthenticationResult;
begin
  // Arrange
  Request := TLoginRequest.Create('admin', 'wrongpass');
  
  // Act
  Result := FAuthService.Login(Request);
  
  // Assert
  try
    Assert.IsFalse(Result.Success);
    Assert.IsNull(Result.User);
    Assert.IsEmpty(Result.SessionId);
    Assert.IsNotEmpty(Result.ErrorMessage);
  finally
    Result.Free;
  end;
end;

end.
