DECLARE @outSql VARCHAR(MAX);
DECLARE @outIndexSql VARCHAR(MAX);
EXEC [dbo].[sp_GetTableClone]  'dbo.NSN_5G_Cell_PMQAP_Raw_Hourly', 'NSN_5G_Cell_PMQAP_Raw_Hourly_Staging', @output = @outSql OUT, @outputIndex = @outIndexSql OUT;
--PRINT @outSql;
EXEC (@outSql);
EXEC (@outIndexSql);
GO