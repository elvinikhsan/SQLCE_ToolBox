CREATE FUNCTION [dbo].[udf_ParseStringPivot] (@String NVARCHAR(MAX), @Separator CHAR(1))
RETURNS TABLE
AS
RETURN
    WITH a AS(
        SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS Id, [value]
        FROM string_split(@String,@Separator)
    )
    SELECT * FROM a
    PIVOT (MAX([value])
    FOR Id IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10], [11], [12], [13], [14], [15], [16], [17], [18], [19], [20]) )
    AS P;
  
GO