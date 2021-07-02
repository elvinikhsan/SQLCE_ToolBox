	CREATE TABLE #TableName
	(Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
	,TableName SYSNAME 
	,SQLStr VARCHAR(MAX)
	);

	CREATE TABLE #TableNameMatch
	(Id INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
	,TableName SYSNAME
	,MatchTableName VARCHAR(MAX)
	);

	INSERT INTO #TableName (TableName, SQLStr)
	VALUES ('Customer', 'Update Staging.dbo SET '), ('Order', 'Update Staging.dbo SET ');

	INSERT INTO #TableNameMatch (TableName, MatchTableName)
	VALUES ('Customer', 'Name'), ('Customer', 'Address'), ('Customer', 'PostalCode'),
			('Order', 'OrderNo'), ('Order', 'SupplierName'), ('Order', 'Phone');

	SELECT * FROM #TableName;
	SELECT * FROM #TableNameMatch;

	--DECLARE @sqlstr AS VARCHAR(MAX) = 'Update Staging.dbo SET ';

	SELECT  STUFF((SELECT ', ' +  b.MatchTableName FROM #TableNameMatch AS b WHERE a.TableName = b.TableName FOR XML PATH('')),1,1,'') AS SQLStr
	FROM #TableName AS a ;

	UPDATE a
	SET a.SQLStr = a.SQLStr + STUFF((SELECT ', ' +  b.MatchTableName FROM #TableNameMatch AS b WHERE a.TableName = b.TableName FOR XML PATH('')),1,1,'') + 
					' FROM Staging.dbo.' + a.TableName + ' target ' + CHAR(13) + 
					' INNER JOIN (SELECT @DataId as DataIdMatch, * ' + CHAR(13) +
					' FROM CSF.dbo.' + a.TableName + CHAR(13) +
					' WHERE CustId = @CustIdMatch) match ' + CHAR(13) +
					' ON target.dataid = match.DataIdMatch ' + CHAR(13) +
					' WHERE target.DataId = @DataId'
	FROM #TableName AS a;

	SELECT * FROM #TableName;

	--PRINT @sqlstr;

	DROP TABLE #TableName;
	DROP TABLE #TableNameMatch;