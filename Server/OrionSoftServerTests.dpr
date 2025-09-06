program OrionSoftServerTests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}
uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  // Test Base and Mocks
  Tests.TestBase in 'tests\Tests.TestBase.pas',
  Tests.Mocks.MockLogger in 'tests\Mocks\Tests.Mocks.MockLogger.pas',
  // Core Units (required by tests)
  OrionSoft.Core.Common.Types in 'src\Core\Common\OrionSoft.Core.Common.Types.pas',
  OrionSoft.Core.Common.Exceptions in 'src\Core\Common\OrionSoft.Core.Common.Exceptions.pas',
  OrionSoft.Core.Entities.User in 'src\Core\Entities\OrionSoft.Core.Entities.User.pas',
  OrionSoft.Core.Interfaces.Services.ILogger in 'src\Core\Interfaces\Services\OrionSoft.Core.Interfaces.Services.ILogger.pas',
  OrionSoft.Core.Interfaces.Repositories.IUserRepository in 'src\Core\Interfaces\Repositories\OrionSoft.Core.Interfaces.Repositories.IUserRepository.pas',
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase in 'src\Core\UseCases\Authentication\OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase.pas',
  // Application Layer
  OrionSoft.Application.Services.AuthenticationService in 'src\Application\Services\OrionSoft.Application.Services.AuthenticationService.pas',
  // Infrastructure Layer
  OrionSoft.Infrastructure.CrossCutting.DI.Container in 'src\Infrastructure\CrossCutting\DI\OrionSoft.Infrastructure.CrossCutting.DI.Container.pas',
  OrionSoft.Infrastructure.Services.FileLogger in 'src\Infrastructure\Services\OrionSoft.Infrastructure.Services.FileLogger.pas',
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository in 'src\Infrastructure\Data\Repositories\OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository.pas',
  // Test Units
  Tests.Core.Entities.UserTests in 'tests\Core\Entities\Tests.Core.Entities.UserTests.pas',
  Tests.Core.UseCases.AuthenticateUserUseCaseTests in 'tests\Core\UseCases\Tests.Core.UseCases.AuthenticateUserUseCaseTests.pas',
  Tests.Application.Services.AuthenticationServiceTests in 'tests\Application\Services\Tests.Application.Services.AuthenticationServiceTests.pas',
  Tests.Infrastructure.Data.InMemoryUserRepositoryTests in 'tests\Infrastructure\Data\Tests.Infrastructure.Data.InMemoryUserRepositoryTests.pas';

var
  runner : ITestRunner;
  results : IRunResults;
  logger : ITestLogger;
  nunitLogger : ITestLogger;
begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
{$ENDIF}
  try
    //Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    //Create the test runner
    runner := TDUnitX.CreateRunner;
    //Tell the runner to use RTTI to find Fixtures
    runner.UseRTTI := True;
    //tell the runner how we will log things
    //Log to the console window
    logger := TDUnitXConsoleLogger.Create(true);
    runner.AddLogger(logger);
    //Generate an NUnit compatible XML File
    nunitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    runner.AddLogger(nunitLogger);
    runner.FailsOnNoAsserts := False; //When true, Assertions must be made during tests;

    //Run tests
    results := runner.Execute;
    if not results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    //We don't want this happening when running under CI.
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
