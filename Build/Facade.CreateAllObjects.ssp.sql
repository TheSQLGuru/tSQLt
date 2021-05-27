EXEC tSQLt.DropClass 'Facade';
GO
CREATE SCHEMA Facade;
GO
CREATE PROCEDURE Facade.CreateSchemaIfNotExists
  @FacadeDbName NVARCHAR(MAX), 
  @SchemaName NVARCHAR(MAX) 
AS
BEGIN
  DECLARE @ExecInRemoteDb NVARCHAR(MAX) = QUOTENAME(@FacadeDbName)+'.sys.sp_executesql';
  DECLARE @RemoteStatement NVARCHAR(MAX);

  DECLARE @RemoteSchemaId INT;
  SET @RemoteStatement = N'SET @RemoteSchemaId = SCHEMA_ID(''' + REPLACE(PARSENAME(@SchemaName,1),'''','''''') +''');'
  EXEC @ExecInRemoteDb @RemoteStatement, N'@RemoteSchemaId INT OUTPUT',@RemoteSchemaId OUT; 
  IF(@RemoteSchemaId IS NULL)
  BEGIN
    SET @RemoteStatement = 'EXEC(''CREATE SCHEMA ' + REPLACE(@SchemaName,'''','''''') +';'');';
    EXEC @ExecInRemoteDb @RemoteStatement,N'';
  END;   
END;
GO
CREATE PROCEDURE Facade.CreateSSPFacade
  @FacadeDbName NVARCHAR(MAX), 
  @ProcedureObjectId INT
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = QUOTENAME(OBJECT_SCHEMA_NAME(@ProcedureObjectId));
  DECLARE @ProcedureName NVARCHAR(MAX) = @SchemaName+'.'+QUOTENAME(OBJECT_NAME(@ProcedureObjectId));
  DECLARE @CreateProcedureStatement NVARCHAR(MAX);

  EXEC tSQLt.Private_GenerateCreateProcedureSpyStatement 
         @ProcedureObjectId = @ProcedureObjectId,
         @OriginalProcedureName = @ProcedureName,
         @CreateProcedureStatement = @CreateProcedureStatement OUT,
         @LogTableName = NULL,
         @CommandToExecute = NULL,
         @CreateLogTableStatement = NULL;
  
  EXEC Facade.CreateSchemaIfNotExists @FacadeDbName = @FacadeDbName, @SchemaName = @SchemaName;

  DECLARE @ExecInRemoteDb NVARCHAR(MAX) = QUOTENAME(@FacadeDbName)+'.sys.sp_executesql';
  DECLARE @RemoteStatement NVARCHAR(MAX);

  SET @RemoteStatement = 'EXEC(''' + REPLACE(@CreateProcedureStatement,'''','''''') + ''');';
  EXEC @ExecInRemoteDb @RemoteStatement,N'';
END;
GO
CREATE PROCEDURE Facade.CreateTBLorVWFacade
  @FacadeDbName NVARCHAR(MAX), 
  @TableObjectId INT
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = QUOTENAME(OBJECT_SCHEMA_NAME(@TableObjectId));
  DECLARE @TableName NVARCHAR(MAX) = QUOTENAME(OBJECT_NAME(@TableObjectId));
  DECLARE @OrigTableFullName NVARCHAR(MAX) = @SchemaName+'.'+@TableName
  DECLARE @CreateTableStatement NVARCHAR(MAX) = 
     (SELECT CreateTableStatement FROM tSQLt.Private_CreateFakeTableStatement(@OrigTableFullName,@OrigTableFullName,1,1,1,1));
  
  EXEC Facade.CreateSchemaIfNotExists @FacadeDbName = @FacadeDbName, @SchemaName = @SchemaName;

  DECLARE @ExecInRemoteDb NVARCHAR(MAX) = QUOTENAME(@FacadeDbName)+'.sys.sp_executesql';
  DECLARE @RemoteStatement NVARCHAR(MAX);

  SET @RemoteStatement = 'EXEC(''' + REPLACE(@CreateTableStatement,'''','''''') + ''');';
  EXEC @ExecInRemoteDb @RemoteStatement,N'';
END;
GO
CREATE VIEW Facade.[sys.tables] AS SELECT * FROM sys.tables;
GO
CREATE VIEW Facade.[sys.views] AS SELECT * FROM sys.views;
GO
CREATE VIEW Facade.[sys.procedures] AS SELECT * FROM sys.procedures;
GO
CREATE VIEW Facade.[sys.objects] AS SELECT * FROM sys.objects;
GO
CREATE PROCEDURE Facade.CreateSSPFacades
  @FacadeDbName NVARCHAR(MAX)
AS
BEGIN
  DECLARE @cmd NVARCHAR(MAX) = 
    (
      SELECT 'EXEC Facade.CreateSSPFacade @FacadeDbName = @FacadeDbName, @ProcedureObjectId = '+CAST(object_id AS NVARCHAR(MAX))+';'
        FROM Facade.[sys.procedures]
       WHERE schema_id = SCHEMA_ID('tSQLt')
         AND name NOT LIKE 'Private%'
         FOR XML PATH(''),TYPE
    ).value('.','NVARCHAR(MAX)');

	EXEC sys.sp_executesql @cmd, N'@FacadeDbName NVARCHAR(MAX)', @FacadeDbName;

END;
GO
CREATE PROCEDURE Facade.CreateSFNFacade
  @FacadeDbName NVARCHAR(MAX), 
  @FunctionObjectId INT
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = QUOTENAME(OBJECT_SCHEMA_NAME(@FunctionObjectId));

  EXEC Facade.CreateSchemaIfNotExists @FacadeDbName = @FacadeDbName, @SchemaName = @SchemaName;

  DECLARE @ExecInRemoteDb NVARCHAR(MAX) = QUOTENAME(@FacadeDbName)+'.sys.sp_executesql';
  DECLARE @RemoteStatement NVARCHAR(MAX) = (SELECT CreateStatement FROM tSQLt.Private_CreateFakeFunctionStatement(@FunctionObjectId, NULL));

  SET @RemoteStatement = 'EXEC('''+REPLACE(@RemoteStatement,'''','''''')+''');';

  EXEC @ExecInRemoteDb @RemoteStatement,N'';
END;
GO
CREATE PROCEDURE Facade.CreateTBLorVWFacades
  @FacadeDbName NVARCHAR(MAX)
AS
BEGIN
	DECLARE @cmd NVARCHAR(MAX) = 
 (
   SELECT 'EXEC Facade.CreateTBLorVWFacade @FacadeDbName = @FacadeDbName, @TableObjectId = ' + CAST(object_id AS NVARCHAR(MAX)) + ';'
     FROM (SELECT object_id, name, schema_id FROM Facade.[sys.tables] UNION ALL SELECT object_id, name, schema_id FROM Facade.[sys.views]) T
    WHERE T.name NOT LIKE 'Private%'
      AND T.schema_id = SCHEMA_ID('tSQLt')
      FOR XML PATH (''),TYPE
 ).value('.','NVARCHAR(MAX)');
    
	EXEC sys.sp_executesql @cmd, N'@FacadeDbName NVARCHAR(MAX)', @FacadeDbName;

	RETURN;
END;
GO
CREATE PROCEDURE Facade.CreateSFNFacades
  @FacadeDbName NVARCHAR(MAX)
AS
BEGIN
	DECLARE @cmd NVARCHAR(MAX) = 
 (
   SELECT 'EXEC Facade.CreateSFNFacade @FacadeDbName = @FacadeDbName, @FunctionObjectId = ' + CAST(object_id AS NVARCHAR(MAX)) + ';'
     FROM Facade.[sys.objects] O
    WHERE O.name NOT LIKE 'Private%'
      AND O.schema_id = SCHEMA_ID('tSQLt')
      AND O.type IN ('IF', 'TF', 'FS', 'FT', 'FN')
      FOR XML PATH (''),TYPE
 ).value('.','NVARCHAR(MAX)');

	EXEC sys.sp_executesql @cmd, N'@FacadeDbName NVARCHAR(MAX)', @FacadeDbName;
END;
GO
CREATE PROCEDURE Facade.CreateAllFacadeObjects
  @FacadeDbName NVARCHAR(MAX)
AS
BEGIN

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = @FacadeDbName;
  EXEC Facade.CreateSSPFacades @FacadeDbName = @FacadeDbName;
  EXEC Facade.CreateSFNFacades @FacadeDbName = @FacadeDbName;

END;
GO
