-- the database must have ALLOW_SNAPSHOT_ISOLATION to enable digest verification
-- ALTER DATABASE <dbname> SET ALLOW_SNAPSHOT_ISOLATION ON;
USE <database_name>;
GO
CREATE PROCEDURE sp_verify_manual_digest
@FileLocation NVARCHAR(256)
AS
BEGIN
    SET NOCOUNT ON
    CREATE TABLE #ManualDigests(
    Content NVARCHAR(1000)
    )

    Declare @Statement NVARCHAR(max)
    SET @Statement='
    BULK INSERT #ManualDigests
    FROM ''' + @FileLocation + '''
      WITH  
         (
            DATAFILETYPE = ''widechar'',
            ROWTERMINATOR =''\n''
         );'
    EXECUTE SP_EXECUTESQL @Statement
    DECLARE @Digest NVARCHAR(MAX)
    SELECT @Digest='[' + STRING_AGG(Content, ',') + ']' FROM #ManualDigests
    EXECUTE sp_verify_database_ledger @Digest
    DROP TABLE #ManualDigests
END
GO