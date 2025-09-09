program OrionSoftTests;

{$IFNDEF TESTINSIGHT}
{$APPTYPE CONSOLE}
{$ENDIF}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  {$IFDEF TESTINSIGHT}
  TestInsight.DUnitX,
  {$ENDIF}
  DUnitX.Loggers.Console,
  DUnitX.Loggers.XML.NUnit,
  DUnitX.TestFramework,
  
  // Test Units - Core
  Tests.Core.Entities.User in 'Unit\Tests.Core.Entities.User.pas',
  Tests.Core.UseCases.Authentication in 'Unit\Tests.Core.UseCases.Authentication.pas',
  Tests.Core.Common.Exceptions in 'Unit\Tests.Core.Common.Exceptions.pas',
  
  // Test Units - Application
  Tests.Application.Services.AuthenticationService in 'Unit\Tests.Application.Services.AuthenticationService.pas',
  Tests.Application.Services.RemObjectsAdapter in 'Unit\Tests.Application.Services.RemObjectsAdapter.pas',
  
  // Test Units - Infrastructure
  Tests.Infrastructure.Data.InMemoryUserRepository in 'Unit\Tests.Infrastructure.Data.InMemoryUserRepository.pas',
  Tests.Infrastructure.Services.FileLogger in 'Unit\Tests.Infrastructure.Services.FileLogger.pas',
  Tests.Infrastructure.DI.Container in 'Unit\Tests.Infrastructure.DI.Container.pas',
  
  // Integration Tests
  Tests.Integration.Authentication.CompleteFlow in 'Integration\Tests.Integration.Authentication.CompleteFlow.pas',
  Tests.Integration.Repository.DatabaseOperations in 'Integration\Tests.Integration.Repository.DatabaseOperations.pas',
  
  // Mocks
  Tests.Mocks.Logger in 'Mocks\Tests.Mocks.Logger.pas',
  Tests.Mocks.UserRepository in 'Mocks\Tests.Mocks.UserRepository.pas',
  Tests.Mocks.DbConnection in 'Mocks\Tests.Mocks.DbConnection.pas',
  
  // Source units
  OrionSoft.Core.Common.Types in '..\src\Core\Common\OrionSoft.Core.Common.Types.pas',
  OrionSoft.Core.Common.Exceptions in '..\src\Core\Common\OrionSoft.Core.Common.Exceptions.pas',
  OrionSoft.Core.Entities.User in '..\src\Core\Entities\OrionSoft.Core.Entities.User.pas',
  OrionSoft.Core.Interfaces.Services.ILogger in '..\src\Core\Interfaces\Services\OrionSoft.Core.Interfaces.Services.ILogger.pas',
  OrionSoft.Core.Interfaces.Repositories.IUserRepository in '..\src\Core\Interfaces\Repositories\OrionSoft.Core.Interfaces.Repositories.IUserRepository.pas',
  OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase in '..\src\Core\UseCases\Authentication\OrionSoft.Core.UseCases.Authentication.AuthenticateUserUseCase.pas',
  OrionSoft.Application.Services.AuthenticationService in '..\src\Application\Services\OrionSoft.Application.Services.AuthenticationService.pas',
  OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository in '..\src\Infrastructure\Data\Repositories\OrionSoft.Infrastructure.Data.Repositories.InMemoryUserRepository.pas',
  OrionSoft.Infrastructure.Services.FileLogger in '..\src\Infrastructure\Services\OrionSoft.Infrastructure.Services.FileLogger.pas',
  OrionSoft.Infrastructure.CrossCutting.DI.Container in '..\src\Infrastructure\CrossCutting\DI\OrionSoft.Infrastructure.CrossCutting.DI.Container.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;

begin
{$IFDEF TESTINSIGHT}
  TestInsight.DUnitX.RunRegisteredTests;
  exit;
{$ENDIF}
  
  try
    // Check command line options, will exit if invalid
    TDUnitX.CheckCommandLine;
    
    // Create the test runner
    Runner := TDUnitX.CreateRunner;
    
    // Tell the runner to use RTTI to find Fixture Classes
    Runner.UseRTTI := True;
    
    // Tell the runner how we will log things
    // Log to the console window
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    
    // Generate an NUnit compatible XML File
    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);
    
    Runner.FailsOnNoAsserts := False; // When true, Assertions must be made during tests;

    // Run tests
    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    // We don't want this happening when running under CI.
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
