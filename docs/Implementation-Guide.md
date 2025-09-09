# Guía de Implementación OrionSoft Clean Architecture

## 📋 Índice

1. [Pre-requisitos y Preparación](#pre-requisitos-y-preparación)
2. [Configuración del Entorno de Desarrollo](#configuración-del-entorno-de-desarrollo)
3. [Setup de Base de Datos](#setup-de-base-de-datos)
4. [Configuración del Servidor](#configuración-del-servidor)
5. [Deployment en Desarrollo](#deployment-en-desarrollo)
6. [Deployment en Producción](#deployment-en-producción)
7. [Configuración de Monitoreo](#configuración-de-monitoreo)
8. [Procedimientos de Mantenimiento](#procedimientos-de-mantenimiento)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

## 🛠️ Pre-requisitos y Preparación

### Hardware Mínimo

#### Entorno de Desarrollo
- **CPU**: Intel i5 o AMD Ryzen 5 (4 cores)
- **RAM**: 8 GB mínimo, 16 GB recomendado
- **Storage**: 500 GB SSD
- **OS**: Windows 10/11 Pro

#### Entorno de Producción
- **Application Server**: 
  - CPU: Intel Xeon o AMD EPYC (8 cores)
  - RAM: 16 GB mínimo, 32 GB recomendado
  - Storage: 1 TB SSD NVMe
- **Database Server**:
  - CPU: Intel Xeon o AMD EPYC (16 cores)
  - RAM: 32 GB mínimo, 64 GB recomendado
  - Storage: 2 TB SSD NVMe + backup storage

### Software Requerido

```table
| Software | Versión | Propósito | Mandatory |
|----------|---------|-----------|-----------|
| RAD Studio Delphi | 12 Athens+ | Desarrollo y compilación | ✅ |
| SQL Server | 2019+ / Express | Base de datos principal | ✅ |
| RemObjects SDK | Latest | Comunicación cliente-servidor | ✅ |
| Git | 2.40+ | Control de versiones | ✅ |
| FireDAC Components | Included in Delphi | Acceso a datos | ✅ |
| DUnitX | Included in Delphi | Framework de testing | ✅ |
| SQL Server Management Studio | Latest | Administración de BD | 📋 |
| MySQL/PostgreSQL | 8.0+/14+ | Base de datos alternativa | 📋 |
| Windows Performance Monitor | Built-in | Monitoreo básico | 📋 |
```

## ⚙️ Configuración del Entorno de Desarrollo

### Paso 1: Configuración de Delphi

1. **Instalar RAD Studio Delphi 12 Athens**
```batch
# Ejecutar instalador como administrador
RADStudio_12_esd.exe

# Configurar rutas de biblioteca
# Tools -> Options -> Environment Options -> Delphi Options -> Library
# Agregar rutas del proyecto:
C:\OrionSoft\Clean\Server\src
C:\OrionSoft\Clean\Server\src\Core
C:\OrionSoft\Clean\Server\src\Application  
C:\OrionSoft\Clean\Server\src\Infrastructure
```

2. **Configurar Opciones del Proyecto**
```pascal
// En Project -> Options -> Delphi Compiler
{$IFDEF DEBUG}
  {$D+} // Debug information
  {$L+} // Local symbols
  {$Y+} // Symbol reference info
  {$OPTIMIZATION OFF}
  {$OVERFLOWCHECKS ON}
  {$RANGECHECKS ON}
{$ELSE}
  {$D-} // No debug information
  {$L-} // No local symbols
  {$Y-} // No symbol reference info
  {$OPTIMIZATION ON}
  {$OVERFLOWCHECKS OFF}
  {$RANGECHECKS OFF}
{$ENDIF}
```

### Paso 2: Configuración de Control de Versiones

```bash
# Clonar repositorio
git clone https://github.com/company/orionsoft-clean.git
cd orionsoft-clean

# Configurar usuario
git config user.name "Developer Name"
git config user.email "developer@company.com"

# Crear branch de desarrollo
git checkout -b develop
git push -u origin develop

# Configurar .gitignore
echo "__history/" >> .gitignore
echo "*.dcu" >> .gitignore
echo "*.exe" >> .gitignore
echo "*.dsk" >> .gitignore
echo "*.identcache" >> .gitignore
echo "*.local" >> .gitignore
echo "*.deployproj" >> .gitignore
```

### Paso 3: Configuración del IDE

1. **Template de Código**
```pascal
// Tools -> Options -> Editor Options -> Code Templates
// Crear template "cleanunit"

unit $MODULENAME$;

{*
  $DESCRIPTION$
  
  Author: $AUTHOR$
  Created: $DATE$
  Version: 1.0
*}

interface

uses
  System.SysUtils;

type
  T$CLASSNAME$ = class
  private
    
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

{ T$CLASSNAME$ }

constructor T$CLASSNAME$.Create;
begin
  inherited Create;
end;

destructor T$CLASSNAME$.Destroy;
begin
  inherited Destroy;
end;

end.
```

2. **Configurar Code Insight y Error Insight**
```
Tools -> Options -> Editor Options -> Code Insight
✅ Automatic code completion
✅ Automatic class completion  
✅ Automatic invoke code completion
✅ Error Insight
```

## 🗄️ Setup de Base de Datos

### Paso 1: Instalación de SQL Server

```batch
# Descargar SQL Server 2019 Developer Edition
# https://www.microsoft.com/sql-server/sql-server-downloads

# Instalación silenciosa (ejemplo)
SQLEXPR_x64_ENU.exe /QUIET /IACCEPTSQLSERVERLICENSETERMS /ACTION=INSTALL /FEATURES=SQLENGINE /INSTANCENAME=SQLEXPRESS /SECURITYMODE=SQL /SAPWD="YourStrongPassword123!"

# Habilitar TCP/IP
# SQL Server Configuration Manager -> SQL Server Network Configuration -> Protocols for SQLEXPRESS
# Enable TCP/IP Protocol
```

### Paso 2: Crear Base de Datos

```sql
-- Conectar como sa o administrador
-- Crear base de datos
CREATE DATABASE OrionSoft_Dev
ON 
( 
    NAME = 'OrionSoft_Dev_Data',
    FILENAME = 'C:\OrionSoft\Database\OrionSoft_Dev_Data.mdf',
    SIZE = 100MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 10MB
)
LOG ON 
(
    NAME = 'OrionSoft_Dev_Log',
    FILENAME = 'C:\OrionSoft\Database\OrionSoft_Dev_Log.ldf',
    SIZE = 10MB,
    MAXSIZE = 100MB,
    FILEGROWTH = 5MB
);

-- Crear usuario de aplicación
CREATE LOGIN OrionSoftApp WITH PASSWORD = 'AppPassword123!';
USE OrionSoft_Dev;
CREATE USER OrionSoftApp FOR LOGIN OrionSoftApp;

-- Asignar permisos
ALTER ROLE db_datareader ADD MEMBER OrionSoftApp;
ALTER ROLE db_datawriter ADD MEMBER OrionSoftApp;
ALTER ROLE db_ddladmin ADD MEMBER OrionSoftApp;
```

### Paso 3: Ejecutar Scripts de Migración

```batch
# Ejecutar scripts en orden
cd C:\OrionSoft\Clean\Server\Scripts\Database\SqlServer

# Script principal de creación
sqlcmd -S localhost\SQLEXPRESS -d OrionSoft_Dev -U OrionSoftApp -P AppPassword123! -i 001_CreateUsersTable.sql

# Datos iniciales
sqlcmd -S localhost\SQLEXPRESS -d OrionSoft_Dev -U OrionSoftApp -P AppPassword123! -i 002_InsertInitialData.sql

# Verificar instalación
sqlcmd -S localhost\SQLEXPRESS -d OrionSoft_Dev -U OrionSoftApp -P AppPassword123! -Q "SELECT COUNT(*) as UserCount FROM Users"
```

### Paso 4: Configuración de Conexión

```ini
; Crear archivo config\database.ini
[Database]
Provider=MSSQL
Server=localhost\SQLEXPRESS
Database=OrionSoft_Dev
Username=OrionSoftApp
Password=AppPassword123!
ConnectionTimeout=30
CommandTimeout=60
PoolSize=10
```

## 🖥️ Configuración del Servidor

### Paso 1: Estructura de Directorios

```batch
# Crear estructura de directorios
mkdir C:\OrionSoft
mkdir C:\OrionSoft\Server
mkdir C:\OrionSoft\Config
mkdir C:\OrionSoft\Logs
mkdir C:\OrionSoft\Backup
mkdir C:\OrionSoft\Temp

# Asignar permisos
icacls C:\OrionSoft /grant "IIS_IUSRS":F /T
icacls C:\OrionSoft /grant "NETWORK SERVICE":F /T
```

### Paso 2: Archivo de Configuración Principal

```ini
; C:\OrionSoft\Config\server.ini
[General]
ServerName=OrionSoft Development Server
Version=1.0.0
Environment=Development
ListenPort=8080
MaxConnections=100

[Database]
Provider=MSSQL
Server=localhost\SQLEXPRESS
Database=OrionSoft_Dev
Username=OrionSoftApp
Password=AppPassword123!
ConnectionTimeout=30
CommandTimeout=60
PoolSize=10
RetryAttempts=3
RetryDelay=5000

[Logging]
LogLevel=Debug
LogDirectory=C:\OrionSoft\Logs
MaxFileSize=50MB
MaxFiles=10
FlushInterval=5000
EnableConsoleLogging=true
EnableFileLogging=true

[Security]
SessionTimeout=30
MaxLoginAttempts=3
PasswordExpirationDays=90
RequirePasswordComplexity=true
MinPasswordLength=6
MaxPasswordLength=50
AllowConcurrentSessions=true

[Performance]
ThreadPoolSize=25
ConnectionPoolSize=50
QueryTimeout=30
EnableStatistics=true
StatisticsInterval=60000

[RemObjects]
ServerPort=8090
MessageFormat=Binary
CompressionLevel=6
EnableSSL=false
```

### Paso 3: Configuración de Logging

```pascal
// En initialization del servidor principal
procedure ConfigureLogging;
var
  LogSettings: TLogFileSettings;
begin
  LogSettings := TLogFileSettings.Default;
  LogSettings.BaseDirectory := 'C:\OrionSoft\Logs';
  LogSettings.MaxFileSize := 50 * 1024 * 1024; // 50 MB
  LogSettings.MaxFiles := 10;
  LogSettings.FlushInterval := 5000;
  LogSettings.DatePattern := 'yyyymmdd';
  
  // Registrar en DI Container
  Container.RegisterSingleton<ILogger>(
    function: ILogger
    begin
      Result := TFileLogger.Create(LogSettings, TLogLevel.Debug);
    end
  );
end;
```

## 🚀 Deployment en Desarrollo

### Paso 1: Compilación

```batch
# Script de compilación para desarrollo
@echo off
echo Building OrionSoft Server for Development...

set DELPHI_PATH="C:\Program Files (x86)\Embarcadero\Studio\23.0\bin"
set PROJECT_PATH="C:\OrionSoft\Clean\Server"
set OUTPUT_PATH="C:\OrionSoft\Server"

cd %PROJECT_PATH%

REM Limpiar archivos anteriores
del *.dcu /s /q
del *.exe /s /q

REM Compilar proyecto
%DELPHI_PATH%\dcc32.exe -B -$D+ -$L+ OrionSoftServer.dpr

if errorlevel 1 (
    echo Compilation failed!
    pause
    exit /b 1
)

REM Copiar archivos
copy OrionSoftServer.exe %OUTPUT_PATH%\
copy config\*.ini %OUTPUT_PATH%\Config\

echo Build completed successfully!
pause
```

### Paso 2: Configuración de Servicio Windows (Opcional)

```batch
# Instalar como servicio Windows
sc create "OrionSoft Server" binPath= "C:\OrionSoft\Server\OrionSoftServer.exe -service" start= auto
sc description "OrionSoft Server" "OrionSoft Clean Architecture Server"

# Configurar recovery
sc failure "OrionSoft Server" reset= 86400 actions= restart/60000/restart/60000/restart/60000

# Iniciar servicio
sc start "OrionSoft Server"
```

### Paso 3: Testing y Verificación

```batch
# Script de verificación
@echo off
echo Testing OrionSoft Server...

REM Verificar que el servidor esté corriendo
tasklist /FI "IMAGENAME eq OrionSoftServer.exe" | find /I "OrionSoftServer.exe"
if errorlevel 1 (
    echo Server is not running!
    exit /b 1
)

REM Verificar conexión a base de datos
sqlcmd -S localhost\SQLEXPRESS -d OrionSoft_Dev -U OrionSoftApp -P AppPassword123! -Q "SELECT 'Database OK' as Status"
if errorlevel 1 (
    echo Database connection failed!
    exit /b 1
)

REM Verificar logs
if not exist "C:\OrionSoft\Logs\app-*.log" (
    echo Warning: No log files found
)

echo All tests passed!
```

## 🏭 Deployment en Producción

### Paso 1: Preparación del Entorno

```batch
# Script de preparación para producción
@echo off
echo Preparing Production Environment...

REM Crear usuario de servicio
net user OrionSoftService P@ssw0rd123! /add /comment:"OrionSoft Service Account"
net localgroup "Log on as a service" OrionSoftService /add

REM Crear estructura de directorios
mkdir C:\OrionSoft\Production
mkdir C:\OrionSoft\Production\Server
mkdir C:\OrionSoft\Production\Config  
mkdir C:\OrionSoft\Production\Logs
mkdir C:\OrionSoft\Production\Backup

REM Configurar permisos de seguridad
icacls C:\OrionSoft\Production /grant OrionSoftService:F /T
icacls C:\OrionSoft\Production\Logs /grant "Everyone":F
```

### Paso 2: Configuración de Base de Datos de Producción

```sql
-- Crear base de datos de producción
CREATE DATABASE OrionSoft_Prod
ON 
( 
    NAME = 'OrionSoft_Prod_Data',
    FILENAME = 'D:\Database\OrionSoft_Prod_Data.mdf',
    SIZE = 1GB,
    MAXSIZE = 10GB,
    FILEGROWTH = 100MB
)
LOG ON 
(
    NAME = 'OrionSoft_Prod_Log',
    FILENAME = 'D:\Database\OrionSoft_Prod_Log.ldf',
    SIZE = 100MB,
    MAXSIZE = 1GB,
    FILEGROWTH = 50MB
);

-- Configurar backup automático
EXEC sp_addumpdevice 'disk', 'OrionSoft_Backup_Device',
'D:\Backup\OrionSoft_Prod_Backup.bak';

-- Crear job de backup
EXEC msdb.dbo.sp_add_job
    @job_name = N'OrionSoft Daily Backup',
    @enabled = 1,
    @description = N'Daily backup of OrionSoft database';

-- Configurar mantenimiento
ALTER DATABASE OrionSoft_Prod SET RECOVERY FULL;
ALTER DATABASE OrionSoft_Prod SET AUTO_SHRINK OFF;
ALTER DATABASE OrionSoft_Prod SET AUTO_UPDATE_STATISTICS ON;
```

### Paso 3: Configuración de Producción

```ini
; C:\OrionSoft\Production\Config\server.ini
[General]
ServerName=OrionSoft Production Server
Version=1.0.0
Environment=Production
ListenPort=8080
MaxConnections=500

[Database]
Provider=MSSQL
Server=prod-sql-server
Database=OrionSoft_Prod
Username=OrionSoftProdUser
Password=<ENCRYPTED_PASSWORD>
ConnectionTimeout=30
CommandTimeout=60
PoolSize=50
RetryAttempts=5
RetryDelay=2000

[Logging]
LogLevel=Information
LogDirectory=C:\OrionSoft\Production\Logs
MaxFileSize=100MB
MaxFiles=30
FlushInterval=10000
EnableConsoleLogging=false
EnableFileLogging=true

[Security]
SessionTimeout=60
MaxLoginAttempts=5
PasswordExpirationDays=60
RequirePasswordComplexity=true
MinPasswordLength=8
MaxPasswordLength=50
AllowConcurrentSessions=false

[Performance]
ThreadPoolSize=50
ConnectionPoolSize=100
QueryTimeout=60
EnableStatistics=true
StatisticsInterval=300000
```

### Paso 4: Script de Deployment

```batch
@echo off
echo Starting OrionSoft Production Deployment...
set DEPLOYMENT_DATE=%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%
set BACKUP_DIR=C:\OrionSoft\Backup\%DEPLOYMENT_DATE%
set PROD_DIR=C:\OrionSoft\Production

REM 1. Crear backup
echo Creating backup...
mkdir %BACKUP_DIR%
xcopy %PROD_DIR%\* %BACKUP_DIR%\ /E /I /Y

REM 2. Detener servicio
echo Stopping service...
sc stop "OrionSoft Production Server"
timeout /t 30

REM 3. Backup de base de datos
echo Backing up database...
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "BACKUP DATABASE OrionSoft_Prod TO DISK = 'D:\Backup\OrionSoft_PreDeploy_%DEPLOYMENT_DATE%.bak'"

REM 4. Copiar nuevos archivos
echo Copying new files...
xcopy Release\* %PROD_DIR%\Server\ /E /I /Y

REM 5. Ejecutar migraciones de BD
echo Running database migrations...
for %%f in (Scripts\Database\Migration\*.sql) do (
    echo Executing %%f...
    sqlcmd -S prod-sql-server -d OrionSoft_Prod -i "%%f"
    if errorlevel 1 (
        echo Migration failed: %%f
        goto :rollback
    )
)

REM 6. Iniciar servicio
echo Starting service...
sc start "OrionSoft Production Server"
timeout /t 60

REM 7. Verificar deployment
echo Verifying deployment...
tasklist /FI "IMAGENAME eq OrionSoftServer.exe" | find /I "OrionSoftServer.exe"
if errorlevel 1 (
    echo Service failed to start!
    goto :rollback
)

echo Deployment completed successfully!
goto :end

:rollback
echo Deployment failed! Rolling back...
sc stop "OrionSoft Production Server"
xcopy %BACKUP_DIR%\* %PROD_DIR%\ /E /I /Y
sc start "OrionSoft Production Server"
echo Rollback completed.
exit /b 1

:end
echo Cleanup...
rmdir %BACKUP_DIR% /s /q
echo Deployment process finished.
```

## 📊 Configuración de Monitoreo

### Paso 1: Monitoreo de Sistema

```batch
# Configurar Performance Counters
@echo off
echo Configuring Performance Monitoring...

REM Crear data collector set
logman create counter OrionSoftCounters -f bincirc -v mmddhhmm -max 500 -c "\Processor(_Total)\% Processor Time" "\Memory\Available MBytes" "\Process(OrionSoftServer)\Private Bytes" "\Process(OrionSoftServer)\% Processor Time" -si 00:00:05

REM Iniciar recolección
logman start OrionSoftCounters

echo Performance monitoring configured.
```

### Paso 2: Script de Monitoreo de Logs

```batch
@echo off
REM Monitor de logs y alertas
set LOG_DIR=C:\OrionSoft\Production\Logs
set ALERT_LOG=%LOG_DIR%\alerts.log
set CURRENT_DATE=%date:~-4,4%%date:~-10,2%%date:~-7,2%

REM Buscar errores críticos
findstr /I "FATAL ERROR CRITICAL" %LOG_DIR%\error-%CURRENT_DATE%.log > nul
if not errorlevel 1 (
    echo %date% %time% - CRITICAL errors found in log >> %ALERT_LOG%
    REM Enviar notificación (configurar según necesidades)
    powershell -Command "Send-MailMessage -To 'admin@company.com' -From 'orionsoft@company.com' -Subject 'OrionSoft Critical Error Alert' -Body 'Critical errors detected in OrionSoft logs' -SmtpServer 'smtp.company.com'"
)

REM Verificar espacio en disco
for /f "tokens=3" %%a in ('dir C:\ ^| find "bytes free"') do set FREE_SPACE=%%a
if %FREE_SPACE% LSS 1073741824 (
    echo %date% %time% - Low disk space: %FREE_SPACE% bytes >> %ALERT_LOG%
)

REM Verificar estado del servicio
sc query "OrionSoft Production Server" | find "RUNNING" > nul
if errorlevel 1 (
    echo %date% %time% - Service is not running >> %ALERT_LOG%
    sc start "OrionSoft Production Server"
)
```

### Paso 3: Dashboard de Monitoreo (PowerShell)

```powershell
# OrionSoft-Monitor.ps1
param(
    [string]$ServerPath = "C:\OrionSoft\Production",
    [string]$LogPath = "C:\OrionSoft\Production\Logs"
)

function Get-OrionSoftStatus {
    $status = @{}
    
    # Estado del servicio
    $service = Get-Service -Name "OrionSoft Production Server" -ErrorAction SilentlyContinue
    $status.ServiceStatus = if ($service) { $service.Status } else { "Not Found" }
    
    # Uso de CPU y memoria
    $process = Get-Process -Name "OrionSoftServer" -ErrorAction SilentlyContinue
    if ($process) {
        $status.CPUUsage = [math]::Round($process.CPU, 2)
        $status.MemoryUsage = [math]::Round($process.WorkingSet64 / 1MB, 2)
    }
    
    # Espacio en disco
    $drive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"}
    $status.DiskFreeSpace = [math]::Round($drive.FreeSpace / 1GB, 2)
    
    # Errores recientes en logs
    $today = Get-Date -Format "yyyyMMdd"
    $errorLog = "$LogPath\error-$today.log"
    if (Test-Path $errorLog) {
        $errors = (Get-Content $errorLog | Where-Object {$_ -match "ERROR|FATAL"}).Count
        $status.ErrorCount = $errors
    } else {
        $status.ErrorCount = 0
    }
    
    return $status
}

# Mostrar status
$status = Get-OrionSoftStatus
Write-Host "OrionSoft Server Status Report" -ForegroundColor Green
Write-Host "================================"
Write-Host "Service Status: $($status.ServiceStatus)" -ForegroundColor $(if($status.ServiceStatus -eq "Running") {"Green"} else {"Red"})
Write-Host "CPU Usage: $($status.CPUUsage)%" -ForegroundColor $(if($status.CPUUsage -lt 80) {"Green"} else {"Yellow"})
Write-Host "Memory Usage: $($status.MemoryUsage) MB" -ForegroundColor $(if($status.MemoryUsage -lt 1024) {"Green"} else {"Yellow"})
Write-Host "Disk Free Space: $($status.DiskFreeSpace) GB" -ForegroundColor $(if($status.DiskFreeSpace -gt 5) {"Green"} else {"Red"})
Write-Host "Today's Errors: $($status.ErrorCount)" -ForegroundColor $(if($status.ErrorCount -eq 0) {"Green"} else {"Red"})

# Generar reporte HTML
$html = @"
<html>
<head><title>OrionSoft Status</title></head>
<body>
<h1>OrionSoft Server Status</h1>
<table border="1">
<tr><td>Service Status</td><td>$($status.ServiceStatus)</td></tr>
<tr><td>CPU Usage</td><td>$($status.CPUUsage)%</td></tr>
<tr><td>Memory Usage</td><td>$($status.MemoryUsage) MB</td></tr>
<tr><td>Disk Free</td><td>$($status.DiskFreeSpace) GB</td></tr>
<tr><td>Errors Today</td><td>$($status.ErrorCount)</td></tr>
</table>
<p>Generated: $(Get-Date)</p>
</body>
</html>
"@

$html | Out-File "$LogPath\status-report.html"
Write-Host "Report saved to: $LogPath\status-report.html"
```

## 🔧 Procedimientos de Mantenimiento

### Mantenimiento Diario

```batch
@echo off
REM Mantenimiento diario automatizado
echo Starting daily maintenance...

REM 1. Limpiar logs antiguos
forfiles /p C:\OrionSoft\Production\Logs /s /m *.log /d -30 /c "cmd /c del @path"

REM 2. Verificar integridad de la base de datos
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "DBCC CHECKDB('OrionSoft_Prod') WITH NO_INFOMSGS"

REM 3. Actualizar estadísticas
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "EXEC sp_updatestats"

REM 4. Backup incremental
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "BACKUP DATABASE OrionSoft_Prod TO DISK = 'D:\Backup\OrionSoft_Daily_%date:~-4,4%%date:~-10,2%%date:~-7,2%.bak' WITH DIFFERENTIAL"

REM 5. Reiniciar servicios si es necesario
tasklist /FI "IMAGENAME eq OrionSoftServer.exe" /FI "MEMUSAGE gt 2048000"
if not errorlevel 1 (
    echo High memory usage detected, restarting service...
    sc stop "OrionSoft Production Server"
    timeout /t 60
    sc start "OrionSoft Production Server"
)

echo Daily maintenance completed.
```

### Mantenimiento Semanal

```sql
-- Script de mantenimiento semanal de base de datos
USE OrionSoft_Prod;

-- Reorganizar índices
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql = @sql + 'ALTER INDEX ALL ON ' + SCHEMA_NAME(schema_id) + '.' + name + ' REORGANIZE;' + CHAR(13)
FROM sys.tables 
WHERE is_ms_shipped = 0;

EXEC sp_executesql @sql;

-- Limpiar datos antiguos (ejemplo: logs de más de 6 meses)
-- DELETE FROM SystemLogs WHERE CreatedAt < DATEADD(MONTH, -6, GETDATE());

-- Actualizar estadísticas con full scan
EXEC sp_updatestats;

-- Shrink log file si es necesario
DECLARE @LogSpaceUsed FLOAT;
SELECT @LogSpaceUsed = cntr_value 
FROM sys.dm_os_performance_counters 
WHERE counter_name = 'Percent Log Used' 
AND instance_name = 'OrionSoft_Prod';

IF @LogSpaceUsed > 80
BEGIN
    BACKUP LOG OrionSoft_Prod TO DISK = 'D:\Backup\OrionSoft_LogBackup.trn';
    DBCC SHRINKFILE(OrionSoft_Prod_Log, 100);
END

-- Generar reporte de mantenimiento
SELECT 
    'Database Maintenance Report' as Report,
    GETDATE() as ExecutionDate,
    @@SERVERNAME as ServerName,
    DB_NAME() as DatabaseName,
    @LogSpaceUsed as LogSpaceUsedPercent,
    (SELECT COUNT(*) FROM Users) as TotalUsers,
    (SELECT COUNT(*) FROM Users WHERE IsActive = 1) as ActiveUsers;
```

### Procedimiento de Backup y Restore

```batch
@echo off
REM Script de backup completo
set BACKUP_DATE=%date:~-4,4%%date:~-10,2%%date:~-7,2%
set BACKUP_PATH=\\backup-server\OrionSoft\%BACKUP_DATE%

REM Crear directorio de backup
mkdir %BACKUP_PATH%

REM Backup de base de datos
echo Creating database backup...
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "BACKUP DATABASE OrionSoft_Prod TO DISK = '%BACKUP_PATH%\OrionSoft_Prod_%BACKUP_DATE%.bak' WITH COMPRESSION, CHECKSUM"

REM Backup de archivos de aplicación
echo Backing up application files...
xcopy C:\OrionSoft\Production\* %BACKUP_PATH%\Application\ /E /I /Y

REM Backup de configuración
echo Backing up configuration...
xcopy C:\OrionSoft\Production\Config\* %BACKUP_PATH%\Config\ /E /I /Y

REM Verificar integridad del backup
echo Verifying backup integrity...
sqlcmd -S prod-sql-server -Q "RESTORE VERIFYONLY FROM DISK = '%BACKUP_PATH%\OrionSoft_Prod_%BACKUP_DATE%.bak'"

if errorlevel 1 (
    echo Backup verification failed!
    exit /b 1
) else (
    echo Backup completed successfully and verified.
)

REM Limpiar backups antiguos (mantener últimos 30 días)
forfiles /p \\backup-server\OrionSoft /m *.bak /d -30 /c "cmd /c del @path"
```

## 🚨 Troubleshooting

### Problemas Comunes y Soluciones

#### Error: "Cannot connect to database"

```batch
REM Diagnóstico de conexión a BD
echo Diagnosing database connection...

REM Verificar servicio SQL Server
sc query MSSQLSERVER
if errorlevel 1 (
    echo SQL Server service is not running
    sc start MSSQLSERVER
)

REM Verificar conectividad de red
telnet prod-sql-server 1433
if errorlevel 1 (
    echo Cannot connect to SQL Server port
    echo Check firewall and SQL Server configuration
)

REM Verificar configuración de TCP/IP
sqlcmd -L
echo Listed SQL Server instances above

REM Probar conexión con sqlcmd
sqlcmd -S prod-sql-server -U OrionSoftProdUser -P Password123!
if errorlevel 1 (
    echo Authentication failed
    echo Check username and password
)
```

#### Error: "Service won't start"

```batch
REM Diagnóstico de servicio
echo Diagnosing service startup issues...

REM Verificar logs del evento del sistema
wevtutil qe System /c:10 /rd:true /f:text | findstr OrionSoft

REM Verificar permisos de archivos
icacls C:\OrionSoft\Production\Server\OrionSoftServer.exe

REM Verificar dependencias
sc qc "OrionSoft Production Server"

REM Verificar usuario de servicio
sc qc "OrionSoft Production Server" | findstr SERVICE_START_NAME

REM Intentar iniciar manualmente
C:\OrionSoft\Production\Server\OrionSoftServer.exe -debug
```

#### Error: "High memory usage"

```powershell
# Análisis de uso de memoria
Get-Process OrionSoftServer | Select-Object Name, CPU, WorkingSet64, PagedMemorySize64

# Verificar memory leaks
$process = Get-Process OrionSoftServer
$initialMemory = $process.WorkingSet64
Start-Sleep -Seconds 300
$process.Refresh()
$finalMemory = $process.WorkingSet64
$memoryGrowth = ($finalMemory - $initialMemory) / 1MB

Write-Host "Memory growth in 5 minutes: $memoryGrowth MB"

if ($memoryGrowth -gt 50) {
    Write-Host "Possible memory leak detected!" -ForegroundColor Red
    Write-Host "Consider restarting the service" -ForegroundColor Yellow
}
```

### Logs de Diagnóstico

```batch
REM Recopilar información de diagnóstico
@echo off
set DIAG_DIR=C:\OrionSoft\Diagnostics\%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%
mkdir %DIAG_DIR%

REM Información del sistema
systeminfo > %DIAG_DIR%\systeminfo.txt
tasklist /svc > %DIAG_DIR%\processes.txt
netstat -an > %DIAG_DIR%\netstat.txt
ipconfig /all > %DIAG_DIR%\ipconfig.txt

REM Logs de eventos
wevtutil epl System %DIAG_DIR%\System.evtx
wevtutil epl Application %DIAG_DIR%\Application.evtx

REM Configuraciones
copy C:\OrionSoft\Production\Config\*.ini %DIAG_DIR%\

REM Logs de aplicación recientes
copy C:\OrionSoft\Production\Logs\*-%date:~-4,4%%date:~-10,2%%date:~-7,2%.log %DIAG_DIR%\

REM Información de SQL Server
sqlcmd -S prod-sql-server -Q "SELECT @@VERSION" > %DIAG_DIR%\sqlversion.txt
sqlcmd -S prod-sql-server -d OrionSoft_Prod -Q "EXEC sp_who2" > %DIAG_DIR%\sqlprocesses.txt

echo Diagnostic information collected in %DIAG_DIR%
```

## 📋 Best Practices

### Desarrollo

1. **Convenciones de Código**
```pascal
// Usar nomenclatura consistente
// Interfaces: I + PascalCase (IUserRepository)
// Clases: T + PascalCase (TAuthenticationService)
// Constantes: UPPER_CASE (MAX_LOGIN_ATTEMPTS)
// Variables locales: camelCase (userName)
// Campos privados: F + PascalCase (FUserName)
```

2. **Gestión de Dependencias**
```pascal
// Siempre inyectar dependencias en constructor
constructor TAuthenticationService.Create(
  UserRepository: IUserRepository;
  Logger: ILogger;
  ConfigService: IConfigService
);
begin
  inherited Create;
  
  // Validar parámetros
  if not Assigned(UserRepository) then
    raise EArgumentNilException.Create('UserRepository cannot be nil');
    
  if not Assigned(Logger) then
    raise EArgumentNilException.Create('Logger cannot be nil');
    
  FUserRepository := UserRepository;
  FLogger := Logger;
  FConfigService := ConfigService;
end;
```

3. **Manejo de Excepciones**
```pascal
function TUserService.CreateUser(const Request: TCreateUserRequest): TCreateUserResponse;
var
  Context: TLogContext;
begin
  Context := CreateLogContext('UserService', 'CreateUser');
  Context.CorrelationId := Request.CorrelationId;
  
  try
    FLogger.Info('Starting user creation', Context);
    
    // Lógica de negocio
    Result := ProcessUserCreation(Request, Context);
    
  except
    on E: EValidationException do
    begin
      FLogger.Warning('Validation failed during user creation', E, Context);
      Result.IsSuccess := False;
      Result.ErrorMessage := E.Message;
      Result.ErrorCode := E.ErrorCode;
    end;
    on E: EBusinessRuleException do
    begin
      FLogger.Warning('Business rule violated during user creation', E, Context);
      Result.IsSuccess := False;
      Result.ErrorMessage := E.Message;
      Result.ErrorCode := E.ErrorCode;
    end;
    on E: Exception do
    begin
      FLogger.Error('Unexpected error during user creation', E, Context);
      Result.IsSuccess := False;
      Result.ErrorMessage := 'Internal server error';
      Result.ErrorCode := 'SYS_001';
      raise; // Re-raise para permitir manejo en capas superiores
    end;
  end;
end;
```

### Producción

1. **Configuración de Seguridad**
```ini
[Security]
# Configurar timeouts apropiados
SessionTimeout=60
MaxLoginAttempts=5
PasswordExpirationDays=60
RequirePasswordComplexity=true

# Configurar encriptación de passwords
HashAlgorithm=SHA256
SaltLength=32
PasswordIterations=10000

# Configurar SSL/TLS
EnableSSL=true
SSLCertificatePath=C:\OrionSoft\Certificates\server.crt
SSLPrivateKeyPath=C:\OrionSoft\Certificates\server.key
```

2. **Optimización de Performance**
```ini
[Performance]
# Configurar pools de conexión
ConnectionPoolSize=50
ConnectionPoolTimeout=30
MaxConnectionLifetime=1800

# Configurar threading
ThreadPoolSize=25
MaxConcurrentRequests=100
RequestTimeout=60

# Configurar caching
EnableCaching=true
CacheTimeout=300
MaxCacheSize=100MB
```

3. **Monitoreo Proactivo**
```ini
[Monitoring]
EnablePerformanceCounters=true
EnableHealthChecks=true
HealthCheckInterval=60
AlertThresholds_CPU=80
AlertThresholds_Memory=85
AlertThresholds_DiskSpace=90
AlertThresholds_ResponseTime=2000
```

### Mantenimiento

1. **Rutinas Automatizadas**
   - Backup diario de base de datos
   - Rotación de logs cada semana
   - Limpieza de archivos temporales
   - Monitoreo de recursos del sistema
   - Verificación de integridad de datos

2. **Documentación**
   - Mantener documentación de APIs actualizada
   - Documentar cambios en base de datos
   - Registrar configuraciones de producción
   - Documentar procedimientos de emergencia

3. **Testing**
   - Ejecutar suite de tests antes de cada deployment
   - Realizar tests de carga periódicamente
   - Verificar backups con restore de prueba
   - Testing de disaster recovery mensualmente

---

**Última Actualización**: 2024-12-08  
**Versión del Documento**: 1.0.0  
**Equipo**: OrionSoft DevOps Team
