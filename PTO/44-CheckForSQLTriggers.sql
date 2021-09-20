DECLARE @QRY VARCHAR(MAX) ='';

SELECT @QRY =@QRY + ' select  ' + QUOTENAME(name,'''') + ' COLLATE SQL_Latin1_General_CP1_CI_AS AS database_name 
    ,OBJECT_NAME(TR.parent_id) COLLATE SQL_Latin1_General_CP1_CI_AS AS table_name 
	,name COLLATE SQL_Latin1_General_CP1_CI_AS AS trigger_name
	,parent_class_desc
	,type_desc
	,create_date
	,is_disabled
FROM ['+name+'].SYS.TRIGGERS TR
UNION ALL
' 
FROM SYS.DATABASES
WHERE name not IN ('master', 'model', 'msdb', 'tempdb', 'resource',
       'distribution' , 'reportserver', 'reportservertempdb','jiradb')

SELECT @QRY = SUBSTRING(@QRY,1,LEN(@QRY)-12)

EXEC( @QRY)