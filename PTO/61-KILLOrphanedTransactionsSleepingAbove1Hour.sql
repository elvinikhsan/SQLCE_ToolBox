USE master;
GO
SET NOCOUNT ON;

DECLARE @temp AS TABLE 
		(ID INT
		,[Duration] INT 
		,[SessionId] INT
		,[DatabaseName] SYSNAME
		,[HostName] SYSNAME
		,[SQLText] VARCHAR(MAX) NULL
		,[ProgramName] SYSNAME NULL
		,[Status] SYSNAME NULL
		,[OpenTranCount] INT
		,[KillCommand] NVARCHAR(100));

DECLARE @count INT = 0;
DECLARE @j INT =1;

INSERT INTO @temp  
select row_number() OVER (order by s.session_id ASC) AS ID, 
datediff(minute, s.last_request_end_time, getdate()) as minutes_asleep,
s.session_id,
s.login_name,
db_name(s.database_id) as database_name,
s.host_name,
t.text as last_sql,
s.program_name,
s.open_transaction_count,
'KILL ' + CAST(s.session_id AS VARCHAR) + ';' as kill_command
from sys.dm_exec_connections c
join sys.dm_exec_sessions s
on c.session_id = s.session_id
outer apply sys.dm_exec_sql_text(c.most_recent_sql_handle) t
where s.is_user_process = 1 and s.open_transaction_count >= 1
and s.status = 'sleeping'
and datediff(minute, s.last_request_end_time, getdate()) >= 60 -- only when duration >= 1 hour
order by s.last_request_end_time;

SELECT @count=COUNT(*) FROM @temp;

--execute the commands
WHILE @j<= @count
BEGIN
	DECLARE @sqlcmd NVARCHAR(100)=N'';
	SELECT @sqlcmd = [KillCommand] FROM @temp WHERE ID=@j;
	EXEC (@sqlcmd);
	SET @j=@j+1;
END

GO

--SELECT * FROM @temp ORDER BY ID;