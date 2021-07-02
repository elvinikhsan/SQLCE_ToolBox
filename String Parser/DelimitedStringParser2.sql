CREATE FUNCTION [dbo].[udf_DelimitedStringParser2] (@String NVARCHAR(MAX),@Pos INT, @Separator CHAR(1))
RETURNS TABLE
AS
RETURN
    WITH a AS(
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS Id, [value]
        FROM string_split(@String,'|')
    )
    SELECT [value] AS [Data] FROM a WHERE ID = @Pos;