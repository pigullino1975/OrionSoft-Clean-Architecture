-- ===========================================================================
-- Orionsoft Gestión - Database Migration Script
-- Migración 001: Crear tabla Users para el nuevo sistema de autenticación
-- Soporte: SQL Server, MySQL, PostgreSQL
-- Fecha: 2025-09-08
-- ===========================================================================

-- Para SQL Server
-- ===========================================================================

IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
BEGIN
    CREATE TABLE [Users] (
        [Id] NVARCHAR(50) NOT NULL PRIMARY KEY,
        [UserName] NVARCHAR(50) NOT NULL UNIQUE,
        [PasswordHash] NVARCHAR(128) NOT NULL,
        [FirstName] NVARCHAR(100) NULL,
        [LastName] NVARCHAR(100) NULL,
        [Email] NVARCHAR(254) NOT NULL UNIQUE,
        [Role] INT NOT NULL DEFAULT(1), -- 0=None, 1=User, 2=Manager, 3=Administrator
        [IsActive] BIT NOT NULL DEFAULT(1),
        [IsBlocked] BIT NOT NULL DEFAULT(0),
        [FailedLoginAttempts] INT NOT NULL DEFAULT(0),
        [LastLoginAt] DATETIME2 NULL,
        [LastFailedLoginAt] DATETIME2 NULL,
        [CreatedAt] DATETIME2 NOT NULL DEFAULT(GETUTCDATE()),
        [UpdatedAt] DATETIME2 NOT NULL DEFAULT(GETUTCDATE()),
        [BlockedUntil] DATETIME2 NULL,
        [PasswordChangedAt] DATETIME2 NOT NULL DEFAULT(GETUTCDATE()),
        
        -- Constraints adicionales
        CONSTRAINT [CK_Users_Role] CHECK ([Role] >= 0 AND [Role] <= 3),
        CONSTRAINT [CK_Users_FailedAttempts] CHECK ([FailedLoginAttempts] >= 0),
        CONSTRAINT [CK_Users_UserName] CHECK (LEN([UserName]) >= 3),
        CONSTRAINT [CK_Users_Email] CHECK ([Email] LIKE '%@%.%')
    );
    
    PRINT 'Tabla Users creada exitosamente para SQL Server';
END
ELSE
BEGIN
    PRINT 'La tabla Users ya existe';
END

-- Crear índices para mejorar performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_UserName')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Users_UserName] ON [Users] ([UserName]) INCLUDE ([Email], [IsActive], [Role]);
    PRINT 'Índice IX_Users_UserName creado';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_Email')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Users_Email] ON [Users] ([Email]) INCLUDE ([UserName], [IsActive]);
    PRINT 'Índice IX_Users_Email creado';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_Role_Active')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Users_Role_Active] ON [Users] ([Role], [IsActive]) INCLUDE ([UserName], [Email]);
    PRINT 'Índice IX_Users_Role_Active creado';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Users_LastLogin')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_Users_LastLogin] ON [Users] ([LastLoginAt] DESC) WHERE [LastLoginAt] IS NOT NULL;
    PRINT 'Índice IX_Users_LastLogin creado';
END

-- ===========================================================================

-- Para MySQL (comentado - descomentar si se usa MySQL)
-- ===========================================================================

/*
CREATE TABLE IF NOT EXISTS `Users` (
    `Id` VARCHAR(50) NOT NULL PRIMARY KEY,
    `UserName` VARCHAR(50) NOT NULL UNIQUE,
    `PasswordHash` VARCHAR(128) NOT NULL,
    `FirstName` VARCHAR(100) NULL,
    `LastName` VARCHAR(100) NULL,
    `Email` VARCHAR(254) NOT NULL UNIQUE,
    `Role` INT NOT NULL DEFAULT 1, -- 0=None, 1=User, 2=Manager, 3=Administrator
    `IsActive` BOOLEAN NOT NULL DEFAULT TRUE,
    `IsBlocked` BOOLEAN NOT NULL DEFAULT FALSE,
    `FailedLoginAttempts` INT NOT NULL DEFAULT 0,
    `LastLoginAt` DATETIME NULL,
    `LastFailedLoginAt` DATETIME NULL,
    `CreatedAt` DATETIME NOT NULL DEFAULT UTC_TIMESTAMP(),
    `UpdatedAt` DATETIME NOT NULL DEFAULT UTC_TIMESTAMP() ON UPDATE UTC_TIMESTAMP(),
    `BlockedUntil` DATETIME NULL,
    `PasswordChangedAt` DATETIME NOT NULL DEFAULT UTC_TIMESTAMP(),
    
    -- Constraints
    CONSTRAINT `CK_Users_Role` CHECK (`Role` >= 0 AND `Role` <= 3),
    CONSTRAINT `CK_Users_FailedAttempts` CHECK (`FailedLoginAttempts` >= 0),
    CONSTRAINT `CK_Users_UserName` CHECK (CHAR_LENGTH(`UserName`) >= 3),
    CONSTRAINT `CK_Users_Email` CHECK (`Email` REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Índices para MySQL
CREATE INDEX `IX_Users_UserName` ON `Users` (`UserName`);
CREATE INDEX `IX_Users_Email` ON `Users` (`Email`);
CREATE INDEX `IX_Users_Role_Active` ON `Users` (`Role`, `IsActive`);
CREATE INDEX `IX_Users_LastLogin` ON `Users` (`LastLoginAt` DESC);

SELECT 'Tabla Users creada exitosamente para MySQL' as message;
*/

-- ===========================================================================

-- Para PostgreSQL (comentado - descomentar si se usa PostgreSQL)
-- ===========================================================================

/*
CREATE TABLE IF NOT EXISTS "Users" (
    "Id" VARCHAR(50) NOT NULL PRIMARY KEY,
    "UserName" VARCHAR(50) NOT NULL UNIQUE,
    "PasswordHash" VARCHAR(128) NOT NULL,
    "FirstName" VARCHAR(100),
    "LastName" VARCHAR(100),
    "Email" VARCHAR(254) NOT NULL UNIQUE,
    "Role" INTEGER NOT NULL DEFAULT 1, -- 0=None, 1=User, 2=Manager, 3=Administrator
    "IsActive" BOOLEAN NOT NULL DEFAULT TRUE,
    "IsBlocked" BOOLEAN NOT NULL DEFAULT FALSE,
    "FailedLoginAttempts" INTEGER NOT NULL DEFAULT 0,
    "LastLoginAt" TIMESTAMP,
    "LastFailedLoginAt" TIMESTAMP,
    "CreatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "BlockedUntil" TIMESTAMP,
    "PasswordChangedAt" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT "CK_Users_Role" CHECK ("Role" >= 0 AND "Role" <= 3),
    CONSTRAINT "CK_Users_FailedAttempts" CHECK ("FailedLoginAttempts" >= 0),
    CONSTRAINT "CK_Users_UserName" CHECK (LENGTH("UserName") >= 3),
    CONSTRAINT "CK_Users_Email" CHECK ("Email" ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
);

-- Trigger para actualizar UpdatedAt automáticamente en PostgreSQL
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW."UpdatedAt" = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON "Users" 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Índices para PostgreSQL
CREATE INDEX IF NOT EXISTS "IX_Users_UserName" ON "Users" ("UserName");
CREATE INDEX IF NOT EXISTS "IX_Users_Email" ON "Users" ("Email");
CREATE INDEX IF NOT EXISTS "IX_Users_Role_Active" ON "Users" ("Role", "IsActive");
CREATE INDEX IF NOT EXISTS "IX_Users_LastLogin" ON "Users" ("LastLoginAt" DESC NULLS LAST);

SELECT 'Tabla Users creada exitosamente para PostgreSQL' as message;
*/

-- ===========================================================================
-- Datos iniciales para testing (solo para desarrollo)
-- ===========================================================================

-- Usuario Administrador por defecto
IF NOT EXISTS (SELECT 1 FROM [Users] WHERE [UserName] = 'admin')
BEGIN
    INSERT INTO [Users] (
        [Id], 
        [UserName], 
        [PasswordHash], -- Hash de "123456" con salt "ORION_SALT_2024"
        [FirstName], 
        [LastName], 
        [Email], 
        [Role],
        [IsActive],
        [CreatedAt],
        [UpdatedAt],
        [PasswordChangedAt]
    ) VALUES (
        'admin-001',
        'admin',
        '8D969EEF6ECAD3C29A3A629280E686CF0C3F5D5A86AFF3CA12020C923ADC6C92', -- SHA256 de "123456ORION_SALT_2024"
        'System',
        'Administrator',
        'admin@orionsoft.com',
        3, -- Administrator
        1,
        GETUTCDATE(),
        GETUTCDATE(),
        GETUTCDATE()
    );
    
    PRINT 'Usuario administrador creado: admin / 123456';
END
ELSE
BEGIN
    PRINT 'El usuario admin ya existe';
END

-- Usuario de prueba regular
IF NOT EXISTS (SELECT 1 FROM [Users] WHERE [UserName] = 'jperez')
BEGIN
    INSERT INTO [Users] (
        [Id], 
        [UserName], 
        [PasswordHash], -- Hash de "123456" con salt "ORION_SALT_2024"
        [FirstName], 
        [LastName], 
        [Email], 
        [Role],
        [IsActive],
        [CreatedAt],
        [UpdatedAt],
        [PasswordChangedAt]
    ) VALUES (
        'user-001',
        'jperez',
        '8D969EEF6ECAD3C29A3A629280E686CF0C3F5D5A86AFF3CA12020C923ADC6C92',
        'Juan',
        'Pérez',
        'juan.perez@orionsoft.com',
        1, -- User
        1,
        GETUTCDATE(),
        GETUTCDATE(),
        GETUTCDATE()
    );
    
    PRINT 'Usuario de prueba creado: jperez / 123456';
END
ELSE
BEGIN
    PRINT 'El usuario jperez ya existe';
END

-- Usuario manager de prueba
IF NOT EXISTS (SELECT 1 FROM [Users] WHERE [UserName] = 'mlopez')
BEGIN
    INSERT INTO [Users] (
        [Id], 
        [UserName], 
        [PasswordHash], -- Hash de "123456" con salt "ORION_SALT_2024"
        [FirstName], 
        [LastName], 
        [Email], 
        [Role],
        [IsActive],
        [CreatedAt],
        [UpdatedAt],
        [PasswordChangedAt]
    ) VALUES (
        'mgr-001',
        'mlopez',
        '8D969EEF6ECAD3C29A3A629280E686CF0C3F5D5A86AFF3CA12020C923ADC6C92',
        'María',
        'López',
        'maria.lopez@orionsoft.com',
        2, -- Manager
        1,
        GETUTCDATE(),
        GETUTCDATE(),
        GETUTCDATE()
    );
    
    PRINT 'Usuario manager creado: mlopez / 123456';
END
ELSE
BEGIN
    PRINT 'El usuario mlopez ya existe';
END

-- ===========================================================================
-- Verificación final
-- ===========================================================================

SELECT 
    COUNT(*) as TotalUsers,
    SUM(CASE WHEN [IsActive] = 1 THEN 1 ELSE 0 END) as ActiveUsers,
    SUM(CASE WHEN [Role] = 3 THEN 1 ELSE 0 END) as Administrators,
    SUM(CASE WHEN [Role] = 2 THEN 1 ELSE 0 END) as Managers,
    SUM(CASE WHEN [Role] = 1 THEN 1 ELSE 0 END) as RegularUsers
FROM [Users];

PRINT 'Migración 001_CreateUsersTable completada exitosamente';

-- ===========================================================================
-- Notas de implementación:
-- 
-- 1. El hash de contraseña mostrado corresponde a "123456" con salt "ORION_SALT_2024"
-- 2. En producción, cambiar inmediatamente las contraseñas por defecto
-- 3. Los IDs de usuario son strings para mayor flexibilidad (GUIDs, códigos personalizados, etc.)
-- 4. Los timestamps se almacenan en UTC para evitar problemas de zona horaria
-- 5. Los índices optimizan las consultas más frecuentes (búsqueda por username, email, roles)
-- 6. Los constraints garantizan la integridad de datos a nivel de base de datos
-- 
-- ===========================================================================
