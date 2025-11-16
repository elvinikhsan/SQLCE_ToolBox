USE master;
GO
CREATE OR ALTER PROCEDURE [dbo].[sp_GetTableClone] 
(@tableName VARCHAR(255)
,@cloneTableName VARCHAR(255) = NULL
,@includePartition BIT = 0
,@output VARCHAR(MAX) OUT
,@outputIndex VARCHAR(MAX) OUT)
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE     @TBLNAME                VARCHAR(255),
              @SCHEMANAME             VARCHAR(255),
              @TABLE_ID               INT,
              @FINALSQL               VARCHAR(MAX),
              @CONSTRAINTSQLS         VARCHAR(MAX),
              @CHECKCONSTSQLS         VARCHAR(MAX),
              @FKSQLS                 VARCHAR(MAX),
              @INDEXSQLS              VARCHAR(MAX),
              @vbCrLf                 CHAR(2),
              @PROCNAME               VARCHAR(256)

--##############################################################################
-- INITIALIZE
--##############################################################################
  SET @output = '';
    SET @PROCNAME = '##sp_GetTableClone';
  SET @vbCrLf =  CHAR(13) + CHAR(10);
  SELECT @SCHEMANAME = ISNULL(PARSENAME(@tableName,2),'dbo') ,
         @TBLNAME    = PARSENAME(@tableName,1);

  IF ISNULL(@cloneTableName,'') = ''
	SET @cloneTableName = @TBLNAME;

  SELECT
    @TBLNAME    = [OBJS].[name],
    @TABLE_ID   = [OBJS].[object_id]
  FROM [sys].[objects] [OBJS]
  WHERE [OBJS].[type]          IN ('S','U')
    AND [OBJS].[name]          <>  'dtproperties'
    AND [OBJS].[name]           =  @TBLNAME
    AND [OBJS].[schema_id] =  SCHEMA_ID(@SCHEMANAME) ;

--##############################################################################
-- Check If TEMP TableName is Valid
--##############################################################################
  IF LEFT(@TBLNAME,1) = '#'  COLLATE SQL_Latin1_General_CP1_CI_AS
    BEGIN
		PRINT 'Temp table is not supported!';
		RETURN -1;
    END;
  ELSE
    BEGIN
      PRINT '--Non-Temp Table, ' + quotename(@TBLNAME) + ' continue Processing';
    END;

--##############################################################################
-- Check If TableName is Valid
--##############################################################################
  IF ISNULL(@TABLE_ID,0) = 0 
	BEGIN
		PRINT 'Invalid table name!'
		RETURN -1;
	END

--##############################################################################
-- Check If Index's column name is Valid 
-- Must not contain 'ASC' or 'DESC'
--##############################################################################
	IF EXISTS (SELECT 1
	FROM
		sys.tables AS t
	INNER JOIN 
		sys.schemas sch ON t.[schema_id]= sch.[schema_id]
	INNER JOIN
		sys.indexes AS ind ON t.object_id = ind.object_id
	INNER JOIN
		sys.index_columns AS ic ON ind.object_id = ic.object_id AND ind.index_id = ic.index_id
	INNER JOIN
		sys.columns AS col ON ic.object_id = col.object_id AND ic.column_id = col.column_id
	WHERE
		t.is_ms_shipped = 0 -- Exclude system tables
		AND sch.name = @SCHEMANAME
		AND t.name = @TBLNAME
		AND ind.name IS NOT NULL -- Exclude heap (no index name)
		AND ((CHARINDEX(col.name,'ASC',0) = 1) OR (CHARINDEX(col.name,'DESC',0) = 1)))
	BEGIN
		PRINT 'Invalid column name found in one of the indexes! Column name cannot contain "ASC" or "DESC" characters!'
		RETURN -1;
	END

--##############################################################################
-- Valid Table, Continue Processing
--##############################################################################
 SELECT 
   @FINALSQL = 'CREATE TABLE ' + QUOTENAME(@SCHEMANAME) + '.' + QUOTENAME(@cloneTableName) + ' ( ';

--##############################################################################
--Get the columns, their definitions and defaults.
--##############################################################################
  SELECT
    @FINALSQL = @FINALSQL
    + CASE
        WHEN [COLS].[is_computed] = 1
        THEN @vbCrLf
             + QUOTENAME([COLS].[name])
             + ' '
             + 'AS ' + ISNULL([CALC].[definition],'')
             + CASE 
                 WHEN [CALC].[is_persisted] = 1 
                 THEN ' PERSISTED'
                 ELSE ''
               END
        ELSE @vbCrLf
             + QUOTENAME([COLS].[name])
             + ' '
             + UPPER(TYPE_NAME([COLS].[user_type_id]))
             + CASE
-- data types with precision and scale  IE DECIMAL(18,3), NUMERIC(10,2)
               WHEN TYPE_NAME([COLS].[user_type_id]) IN ('decimal','numeric')
               THEN '('
                    + CONVERT(VARCHAR,[COLS].[precision])
                    + ','
                    + CONVERT(VARCHAR,[COLS].[scale])
                    + ') '
                    + CASE
                        WHEN COLUMNPROPERTY ( @TABLE_ID , [COLS].[name] , 'IsIdentity' ) = 0
                        THEN ''
                        ELSE ' IDENTITY('
                               + CONVERT(VARCHAR,ISNULL(IDENT_SEED(@TBLNAME),1) )
                               + ','
                               + CONVERT(VARCHAR,ISNULL(IDENT_INCR(@TBLNAME),1) )
                               + ') '
                        END
                    + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                    + CASE
                        WHEN [COLS].[is_nullable] = 0
                        THEN 'NOT NULL'
                        ELSE 'NULL'
                      END
-- data types with scale  IE datetime2(7),TIME(7)
               WHEN TYPE_NAME([COLS].[user_type_id]) IN ('datetime2','datetimeoffset','time')
               THEN CASE 
                      WHEN [COLS].[scale] < 7 THEN
                      '('
                      + CONVERT(VARCHAR,[COLS].[scale])
                      + ') '
                    ELSE 
                      ' '
                    END
                    + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                    + CASE
                        WHEN [COLS].[is_nullable] = 0
                        THEN 'NOT NULL'
                        ELSE 'NULL'
                      END

--data types with no/precision/scale,IE  FLOAT
               WHEN  TYPE_NAME([COLS].[user_type_id]) IN ('float') --,'real')
               THEN
               --addition: if 53, no need to specifically say (53), otherwise display it
                    CASE
                      WHEN [COLS].[precision] = 53
                      THEN + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                           + CASE
                               WHEN [COLS].[is_nullable] = 0
                               THEN 'NOT NULL'
                               ELSE 'NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,[COLS].[precision])
                           + ') '
                           + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                           + CASE
                               WHEN [COLS].[is_nullable] = 0
                               THEN 'NOT NULL'
                               ELSE 'NULL'
                             END
                      END
--data type with max_length		ie CHAR (44), VARCHAR(40), BINARY(5000),
               WHEN  TYPE_NAME([COLS].[user_type_id]) IN ('char','varchar','binary','varbinary')
               THEN CASE
                      WHEN  [COLS].[max_length] = -1
                      THEN  '(MAX)'
                            + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                            + CASE
                                WHEN [COLS].[is_nullable] = 0
                                THEN 'NOT NULL'
                                ELSE 'NULL'
                              END
                      ELSE '('
                           + CONVERT(VARCHAR,[COLS].[max_length])
                           + ') '
                           + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                           + CASE
                               WHEN [COLS].[is_nullable] = 0
                               THEN 'NOT NULL'
                               ELSE 'NULL'
                             END
                    END
--data type with max_length ( BUT DOUBLED) ie NCHAR(33), NVARCHAR(40)
               WHEN TYPE_NAME([COLS].[user_type_id]) IN ('nchar','nvarchar')
               THEN CASE
                      WHEN  [COLS].[max_length] = -1
                      THEN '(MAX)'
                           + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                           + CASE
                               WHEN [COLS].[is_nullable] = 0
                               THEN  'NOT NULL'
                               ELSE 'NULL'
                             END
                      ELSE '('
                           + CONVERT(VARCHAR,([COLS].[max_length] / 2))
                           + ') '
                           + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                           + CASE
                               WHEN [COLS].[is_nullable] = 0
                               THEN 'NOT NULL'
                               ELSE 'NULL'
                             END
                    END

               WHEN TYPE_NAME([COLS].[user_type_id]) IN ('datetime','money','text','image','real')
               THEN + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                    + CASE
                        WHEN [COLS].[is_nullable] = 0
                        THEN 'NOT NULL'
                        ELSE 'NULL'
                      END

--  other data type 	IE INT, DATETIME, MONEY, CUSTOM DATA TYPE,...
               ELSE + CASE
                                WHEN COLUMNPROPERTY ( @TABLE_ID , [COLS].[name] , 'IsIdentity' ) = 0
                                THEN ' '
                                ELSE ' IDENTITY('
                                     + CONVERT(VARCHAR,ISNULL(IDENT_SEED(@TBLNAME),1) )
                                     + ','
                                     + CONVERT(VARCHAR,ISNULL(IDENT_INCR(@TBLNAME),1) )
                                     + ')'
                              END
                            + CASE  WHEN [COLS].[is_sparse] = 1 THEN ' sparse' ELSE ' ' END
                            + CASE
                                WHEN [COLS].[is_nullable] = 0
                                THEN 'NOT NULL'
                                ELSE 'NULL'
                              END
               END
             + CASE
                 WHEN [COLS].[default_object_id] = 0
                 THEN ''
                 ELSE '  CONSTRAINT ' + quotename(REPLACE([DEF].[name],@TBLNAME,@cloneTableName)) + ' DEFAULT ' + ISNULL([DEF].[definition] ,'')
               END  
      END --iscomputed
    + ','
    FROM [sys].[columns] [COLS]
      LEFT OUTER JOIN  [sys].[default_constraints]  [DEF]
        ON [COLS].[default_object_id] = [DEF].[object_id]
      LEFT OUTER JOIN [sys].[computed_columns] [CALC]
         ON  [COLS].[object_id] = [CALC].[object_id]
         AND [COLS].[column_id] = [CALC].[column_id]
    WHERE [COLS].[object_id]=@TABLE_ID
    ORDER BY [COLS].[column_id];

--##############################################################################
--PK/Unique Constraints and Indexes, using the 2005/08 INCLUDE syntax
--##############################################################################
	DECLARE @Results  TABLE (
						[SCHEMA_ID]             INT,
						[SCHEMA_NAME]           VARCHAR(255),
						[OBJECT_ID]             INT,
						[OBJECT_NAME]           VARCHAR(255),
						[index_id]              INT,
						[index_name]            VARCHAR(255),
						[TYPE]                  INT,
						[type_desc]             VARCHAR(30),
						[fill_factor]           INT,
						[is_unique]             INT,
						[is_primary_key]        INT ,
						[is_unique_constraint]  INT,
						[index_columns_key]     VARCHAR(MAX),
						[index_columns_include] VARCHAR(MAX),
						[has_filter] bit ,
						[filter_definition] VARCHAR(MAX),
						[currentFilegroupName]  varchar(128),
						[CurrentCompression]    varchar(128),
						[PartitionStatus] VARCHAR(128),
						[PartitionSchemeName] VARCHAR(255),
						[PartitionFunctionName] VARCHAR(255));
	WITH CTE AS (
	SELECT SCH.schema_id, SCH.name AS [Schema_Name], t.object_id, t.name AS [OBJECT_NAME],
	i.index_id, ISNULL(i.name,'---') AS index_name, i.type, i.type_desc, i.fill_factor, i.is_unique, i.is_primary_key, i.is_unique_constraint,
		ISNULL(STUFF((
			SELECT ', ' + COL_NAME(ic.object_id, ic.column_id) +
				   CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
			FROM sys.index_columns ic
			WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
			ORDER BY ic.key_ordinal
			FOR XML PATH('')
		), 1, 2, ''),'---') AS [index_columns_key],
		ISNULL(STUFF((
			SELECT ', ' + COL_NAME(ic.object_id, ic.column_id)
			FROM sys.index_columns ic
			WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
			ORDER BY ic.column_id
			FOR XML PATH('')
		), 1, 2, ''),'---') AS [index_columns_include],
		i.has_filter, i.filter_definition, fg.name as FilegroupName,
		ISNULL([p].[data_compression_desc],'') AS compression_desc,
		-- Partitioning Information
		CASE
			WHEN ps.name IS NOT NULL THEN 'Partitioned'
			ELSE 'Not Partitioned'
		END AS PartitionStatus,
		ps.name AS PartitionSchemeName,
		pf.name AS PartitionFunctionName
	FROM
		sys.tables t
	INNER JOIN [sys].[schemas] [SCH] ON t.[schema_id]=[SCH].[schema_id]
	LEFT JOIN
		sys.indexes i ON t.object_id = i.object_id
	LEFT JOIN
		sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
	LEFT JOIN
		sys.partition_functions pf ON ps.function_id = pf.function_id
	LEFT JOIN
		sys.partitions p ON t.object_id = p.object_id AND i.index_id = p.index_id
	LEFT JOIN 
		sys.filegroups fg ON i.[data_space_id] = fg.[data_space_id]
	WHERE
		t.is_ms_shipped = 0 -- Exclude system tables
		AND [SCH].[name]  LIKE CASE 
										 WHEN @SCHEMANAME = ''   COLLATE SQL_Latin1_General_CP1_CI_AS
										 THEN [SCH].[name] 
										 ELSE @SCHEMANAME 
									   END
		AND [t].[name] LIKE CASE 
									  WHEN @TBLNAME = ''   COLLATE SQL_Latin1_General_CP1_CI_AS 
									  THEN [t].[name] 
									  ELSE @TBLNAME 
									END)
	INSERT INTO @Results
	SELECT DISTINCT schema_id, [Schema_Name], object_id, [OBJECT_NAME], index_id, index_name,
	type, type_desc, fill_factor, is_unique, is_primary_key, is_unique_constraint,
	[index_columns_key], [index_columns_include], has_filter, filter_definition, FilegroupName,
	compression_desc, PartitionStatus, PartitionSchemeName, PartitionFunctionName
	FROM CTE
	ORDER BY
		[Schema_Name], [OBJECT_NAME], index_id;

  SET @CONSTRAINTSQLS = '';
  SET @INDEXSQLS      = '';

--##############################################################################
--CONSTRAINTS
--column store indexes are different: the "include" columns for normal indexes as scripted above are the columnstores indexed columns
--add a CASE for that situation.
--##############################################################################
  SELECT @CONSTRAINTSQLS = @CONSTRAINTSQLS 
         + CASE
             WHEN [is_primary_key] = 1 OR [is_unique] = 1
             THEN @vbCrLf
                  + 'CONSTRAINT '  COLLATE SQL_Latin1_General_CP1_CI_AS 
				  + CASE 
						WHEN [is_primary_key] = 1
						THEN QUOTENAME(REPLACE([index_name],@TBLNAME,@cloneTableName)) + ' '
						ELSE QUOTENAME([index_name]) + ' '
					END
                  + CASE  
                      WHEN [is_primary_key] = 1 
                      THEN ' PRIMARY KEY ' 
                      ELSE CASE  
                             WHEN [is_unique] = 1     
                             THEN ' UNIQUE '      
                             ELSE '' 
                           END 
                    END
                  + [type_desc] 
                  + CASE 
                      WHEN [type_desc]='NONCLUSTERED' 
                      THEN '' 
                      ELSE ' ' 
                    END
                  + ' (' + [index_columns_key] + ')'
                  + CASE 
                      WHEN [index_columns_include] <> '---' 
                      THEN ' INCLUDE (' + [index_columns_include] + ')' 
                      ELSE '' 
                    END
                  + CASE
                      WHEN [has_filter] = 1 
                      THEN ' ' + [filter_definition]
                      ELSE ' '
                    END
                  + CASE WHEN [fill_factor] <> 0 OR [CurrentCompression] <> 'NONE'
                  THEN ' WITH (' + CASE
                                    WHEN [fill_factor] <> 0 
                                    THEN 'FILLFACTOR = ' + CONVERT(VARCHAR(30),[fill_factor]) 
                                    ELSE '' 
                                  END
                                + CASE
                                    WHEN [fill_factor] <> 0  AND [CurrentCompression] <> 'NONE' THEN ',DATA_COMPRESSION = ' + [CurrentCompression] + ' '
                                    WHEN [fill_factor] <> 0  AND [CurrentCompression]  = 'NONE' THEN ''
                                    WHEN [fill_factor]  = 0  AND [CurrentCompression] <> 'NONE' THEN 'DATA_COMPRESSION = ' + [CurrentCompression] + ' '
                                    ELSE '' 
                                  END
                                  + ')'

                  ELSE '' 
                  END 
				  + CASE WHEN @includePartition = 1 AND [PartitionStatus] = 'Partitioned' COLLATE SQL_Latin1_General_CP1_CI_AS
				  THEN ' ON ' + QUOTENAME([PartitionSchemeName]) + '(' + REPLACE(REPLACE([index_columns_key],'ASC',''),'DESC','') + ')' 
				  ELSE ''
				  END
                      
             ELSE ''
           END + ','
  FROM @Results
  WHERE [type_desc] != 'HEAP'
    AND [is_primary_key] = 1 
    OR  [is_unique] = 1
  ORDER BY 
    [is_primary_key] DESC,
    [is_unique] DESC;

--##############################################################################
--INDEXES
--##############################################################################
  SELECT @INDEXSQLS = @INDEXSQLS 
         + CASE
             WHEN [is_primary_key] = 0 OR [is_unique] = 0
             THEN 'CREATE '  COLLATE SQL_Latin1_General_CP1_CI_AS + [type_desc] + ' INDEX '  COLLATE SQL_Latin1_General_CP1_CI_AS + quotename(REPLACE([index_name],@TBLNAME,@cloneTableName)) + ' '
                  + @vbCrLf
                  + '   ON '   COLLATE SQL_Latin1_General_CP1_CI_AS
                  + quotename([schema_name]) + '.' + quotename(@cloneTableName)
                  + CASE 
                        WHEN [CurrentCompression] = 'COLUMNSTORE'  COLLATE SQL_Latin1_General_CP1_CI_AS
                        THEN CASE WHEN [type_desc] = 'CLUSTERED COLUMNSTORE' COLLATE SQL_Latin1_General_CP1_CI_AS
								THEN '' 
								ELSE ' (' + [index_columns_include] + ')' 
							END
                        ELSE ' (' + [index_columns_key] + ')'
                    END
                  + CASE 
                      WHEN [CurrentCompression] = 'COLUMNSTORE'  COLLATE SQL_Latin1_General_CP1_CI_AS
                      THEN ''  COLLATE SQL_Latin1_General_CP1_CI_AS
                      ELSE
                        CASE
                     WHEN [index_columns_include] <> '---' 
                     THEN @vbCrLf + '   INCLUDE ('  COLLATE SQL_Latin1_General_CP1_CI_AS + [index_columns_include] + ')'   COLLATE SQL_Latin1_General_CP1_CI_AS
                     ELSE ''   COLLATE SQL_Latin1_General_CP1_CI_AS
                   END
                    END
                  --2008 filtered indexes syntax
                  + CASE 
                      WHEN [has_filter] = 1 
                      THEN @vbCrLf + '   WHERE '  COLLATE SQL_Latin1_General_CP1_CI_AS + [filter_definition]
                      ELSE ''
                    END
                  + CASE WHEN [fill_factor] <> 0 OR [CurrentCompression] <> 'NONE'  COLLATE SQL_Latin1_General_CP1_CI_AS
                  THEN ' WITH ('  COLLATE SQL_Latin1_General_CP1_CI_AS + CASE
                                    WHEN [fill_factor] <> 0 
                                    THEN 'FILLFACTOR = '  COLLATE SQL_Latin1_General_CP1_CI_AS + CONVERT(VARCHAR(30),[fill_factor]) 
                                    ELSE '' 
                                  END
                                + CASE
                                    WHEN [fill_factor] <> 0  AND [CurrentCompression] <> 'NONE' THEN ',DATA_COMPRESSION = ' + [CurrentCompression]+' '
                                    WHEN [fill_factor] <> 0  AND [CurrentCompression]  = 'NONE' THEN ''
                                    WHEN [fill_factor]  = 0  AND [CurrentCompression] <> 'NONE' THEN 'DATA_COMPRESSION = ' + [CurrentCompression]+' '
                                    ELSE '' 
                                  END
                                  + ') '

                  ELSE ' ' 
                  END 
				  + CASE WHEN @includePartition = 1 AND [PartitionStatus] = 'Partitioned' COLLATE SQL_Latin1_General_CP1_CI_AS
				  THEN ' ON ' + QUOTENAME([PartitionSchemeName]) + '(' + REPLACE(REPLACE([index_columns_key],'ASC',''),'DESC','') + ');' 
				  ELSE ';'
				  END
				+ @vbCrLf --+ 'GO' + @vbCrLf
           END
  FROM @RESULTS
  WHERE [type_desc] != 'HEAP'
    AND [is_primary_key] = 0 
    AND [is_unique] = 0
  ORDER BY 
    [is_primary_key] DESC,
    [is_unique] DESC;

  IF @INDEXSQLS <> ''  COLLATE SQL_Latin1_General_CP1_CI_AS
    SET @INDEXSQLS = @vbCrLf + @INDEXSQLS;

--##############################################################################
--CHECK Constraints
--##############################################################################
  SET @CHECKCONSTSQLS = ''  COLLATE SQL_Latin1_General_CP1_CI_AS;
  SELECT
    @CHECKCONSTSQLS = @CHECKCONSTSQLS
    + @vbCrLf
    + ISNULL('CONSTRAINT   ' + quotename([OBJS].[name]) + ' '
    + ' CHECK ' + ISNULL([CHECKS].[definition],'')
    + ',','')
  FROM [sys].[objects] [OBJS]
    INNER JOIN [sys].[check_constraints] [CHECKS] ON [OBJS].[object_id] = [CHECKS].[object_id]
  WHERE [OBJS].[type] = 'C'
    AND [OBJS].[parent_object_id] = @TABLE_ID;

--##############################################################################
--FOREIGN KEYS
--##############################################################################
  SET @FKSQLS = '' ;
    SELECT
    @FKSQLS=@FKSQLS
    + @vbCrLf + [MyAlias].[Command] FROM
(
SELECT
  DISTINCT
  --FK must be added AFTER the PK/unique constraints are added back.
  850 AS [ExecutionOrder],
  'CONSTRAINT ' 
  + QUOTENAME(REPLACE([conz].[name],@TBLNAME,@cloneTableName)) 
  + ' FOREIGN KEY (' 
  + [ChildCollection].[ChildColumns] 
  + ') REFERENCES ' 
  + QUOTENAME(SCHEMA_NAME([conz].[schema_id])) 
  + '.' 
  + QUOTENAME(OBJECT_NAME([conz].[referenced_object_id])) 
  + ' (' + [ParentCollection].[ParentColumns] 
  + ') ' 

  +  CASE [conz].[update_referential_action]
                                        WHEN 0 THEN '' --' ON UPDATE NO ACTION '
                                        WHEN 1 THEN ' ON UPDATE CASCADE '
                                        WHEN 2 THEN ' ON UPDATE SET NULL '
                                        ELSE ' ON UPDATE SET DEFAULT '
                                    END
                  + CASE [conz].[delete_referential_action]
                                        WHEN 0 THEN '' --' ON DELETE NO ACTION '
                                        WHEN 1 THEN ' ON DELETE CASCADE '
                                        WHEN 2 THEN ' ON DELETE SET NULL '
                                        ELSE ' ON DELETE SET DEFAULT '
                                    END
                  + CASE [conz].[is_not_for_replication]
                        WHEN 1 THEN ' NOT FOR REPLICATION '
                        ELSE ''
                    END
  + ',' AS [Command]
FROM   [sys].[foreign_keys] [conz]
       INNER JOIN [sys].[foreign_key_columns] [colz]
         ON [conz].[object_id] = [colz].[constraint_object_id]
      
       INNER JOIN (--gets my child tables column names   
SELECT
 [conz].[name],
 --technically, FK's can contain up to 16 columns, but real life is often a single column. coding here is for all columns
 [ChildColumns] = STUFF((SELECT 
                         ',' + QUOTENAME([REFZ].[name])
                       FROM   [sys].[foreign_key_columns] [fkcolz]
                              INNER JOIN [sys].[columns] [REFZ]
                                ON [fkcolz].[parent_object_id] = [REFZ].[object_id]
                                   AND [fkcolz].[parent_column_id] = [REFZ].[column_id]
                       WHERE [fkcolz].[parent_object_id] = [conz].[parent_object_id]
                           AND [fkcolz].[constraint_object_id] = [conz].[object_id]
                         ORDER  BY
                        [fkcolz].[constraint_column_id]
                      FOR XML PATH(''), TYPE).[value]('.','varchar(max)'),1,1,'')
FROM   [sys].[foreign_keys] [conz]
      INNER JOIN [sys].[foreign_key_columns] [colz]
        ON [conz].[object_id] = [colz].[constraint_object_id]
        WHERE [conz].[parent_object_id]= @TABLE_ID
GROUP  BY
[conz].[name],
[conz].[parent_object_id],--- without GROUP BY multiple rows are returned
 [conz].[object_id]
    ) [ChildCollection]
         ON [conz].[name] = [ChildCollection].[name]
       INNER JOIN (--gets the parent tables column names for the FK reference
                  SELECT
                     [conz].[name],
                     [ParentColumns] = STUFF((SELECT
                                              ',' + [REFZ].[name]
                                            FROM   [sys].[foreign_key_columns] [fkcolz]
                                                   INNER JOIN [sys].[columns] [REFZ]
                                                     ON [fkcolz].[referenced_object_id] = [REFZ].[object_id]
                                                        AND [fkcolz].[referenced_column_id] = [REFZ].[column_id]
                                            WHERE  [fkcolz].[referenced_object_id] = [conz].[referenced_object_id]
                                              AND [fkcolz].[constraint_object_id] = [conz].[object_id]
                                            ORDER BY [fkcolz].[constraint_column_id]
                                            FOR XML PATH(''), TYPE).[value]('.','varchar(max)'),1,1,'')
                   FROM   [sys].[foreign_keys] [conz]
                          INNER JOIN [sys].[foreign_key_columns] [colz]
                            ON [conz].[object_id] = [colz].[constraint_object_id]
                           -- AND colz.parent_column_id 
                   GROUP  BY
                    [conz].[name],
                    [conz].[referenced_object_id],--- without GROUP BY multiple rows are returned
                    [conz].[object_id]
                  ) [ParentCollection]
         ON [conz].[name] = [ParentCollection].[name]
)[MyAlias];

--##############################################################################
--FINAL CLEANUP AND PRESENTATION
--##############################################################################
--at this point, there is a trailing comma, or it blank
  SELECT
    @FINALSQL = @FINALSQL
                + @CONSTRAINTSQLS
                + @CHECKCONSTSQLS
                + @FKSQLS;
--note that this trims the trailing comma from the end of the statements
  SET @FINALSQL = SUBSTRING(@FINALSQL,1,LEN(@FINALSQL) -1) ;
  SET @FINALSQL = @FINALSQL + ');' COLLATE SQL_Latin1_General_CP1_CI_AS ;

  SET @output = @FINALSQL
  SET @outputIndex = @INDEXSQLS;

  RETURN 0;     

--##############################################################################
-- END Normal Table Processing
--############################################################################## 
END
GO
--#################################################################################################
--Mark as a system object
EXECUTE sp_ms_marksystemobject 'sp_GetTableClone';
GRANT EXECUTE ON dbo.sp_GetTableClone TO PUBLIC;
--#################################################################################################
GO