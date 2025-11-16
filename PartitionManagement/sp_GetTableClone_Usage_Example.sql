DECLARE @outSql VARCHAR(MAX);
DECLARE @outIndexSql VARCHAR(MAX);
EXEC [dbo].[sp_GetTableClone]  'dbo.Fact4GHourlyNSN', 'DATA', 'Fact4GHourlyNSN_Temp', 0, @output = @outSql OUT, @outputIndex = @outIndexSql OUT;
PRINT @outSql;
PRINT @outIndexSql;
--EXEC (@outSql);
--EXEC (@outIndexSql);
GO