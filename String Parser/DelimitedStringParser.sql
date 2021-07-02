USE [BeyondDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION [General].[udf_DelimitedStringParser] (@String VARCHAR(MAX),@Separator CHAR(1))
RETURNS TABLE
-- =============================================
-- Author:		ELV
-- Create date: 20140306
-- Description:	Parse delimited string into table ouput
--				Sebagai alternative menggunakan recursive CTE (inline TVF)
--				Dari function yg sudah ada yaitu udf_splitstring 
-- =============================================
AS
RETURN
	WITH a AS(
		SELECT CAST(0 AS BIGINT) as idx1,CHARINDEX(@Separator,@String) idx2
		UNION ALL
		SELECT idx2+1,CHARINDEX(@Separator,@String,idx2+1)
		FROM a
		WHERE idx2>0
	)
	SELECT ROW_NUMBER() OVER(ORDER BY idx1 ASC) as ID
		 , RTRIM(LTRIM(SUBSTRING(@String,idx1,COALESCE(NULLIF(idx2,0),LEN(@String)+1)-idx1))) as Data
	FROM a
    
GO


