USE [msdb]
GO

/****** Object:  Job [SendSQLFreeSpaceStatus]    Script Date: 06/17/2013 11:45:25 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 06/17/2013 11:45:25 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'SendSQLFreeSpaceStatus', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Exec Script]    Script Date: 06/17/2013 11:45:25 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Exec Script', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'PowerShell', 
		@command=N'# First lets create a text file, where we will later save the freedisk space info
$freeSpaceFileName = "C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\JOBS\FreeSpace.htm"
$serverlist = "C:\Program Files\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\JOBS\sl.txt"
$warning = 25
$critical = 10
New-Item -ItemType file $freeSpaceFileName -Force
# Getting the freespace info using WMI
# Get-WmiObject win32_logicaldisk  | Where-Object {$_.drivetype -eq 3} | format-table DeviceID, VolumeName,status,Size,FreeSpace | Out-File FreeSpace.txt
# Function to write the HTML Header to the file
Function writeHtmlHeader
{
param($fileName)
$date = ( get-date ).ToString(''yyyy/MM/dd'')
Add-Content $fileName "<html>"
Add-Content $fileName "<head>"
Add-Content $fileName "<meta http-equiv=''Content-Type'' content=''text/html; charset=iso-8859-1''>"
Add-Content $fileName ''<title>SQL Server Alert: DiskSpace Report</title>''
add-content $fileName ''<STYLE TYPE="text/css">''
add-content $fileName  "<!--"
add-content $fileName  "td {"
add-content $fileName  "font-family: Tahoma;"
add-content $fileName  "font-size: 11px;"
add-content $fileName  "border-top: 1px solid #999999;"
add-content $fileName  "border-right: 1px solid #999999;"
add-content $fileName  "border-bottom: 1px solid #999999;"
add-content $fileName  "border-left: 1px solid #999999;"
add-content $fileName  "padding-top: 0px;"
add-content $fileName  "padding-right: 0px;"
add-content $fileName  "padding-bottom: 0px;"
add-content $fileName  "padding-left: 0px;"
add-content $fileName  "}"
add-content $fileName  "body {"
add-content $fileName  "margin-left: 5px;"
add-content $fileName  "margin-top: 5px;"
add-content $fileName  "margin-right: 0px;"
add-content $fileName  "margin-bottom: 10px;"
add-content $fileName  ""
add-content $fileName  "table {"
add-content $fileName  "border: thin solid #000000;"
add-content $fileName  "}"
add-content $fileName  "-->"
add-content $fileName  "</style>"
Add-Content $fileName "</head>"
Add-Content $fileName "<body>"

add-content $fileName  "<table width=''100%''>"
add-content $fileName  "<tr bgcolor=''#CCCCCC''>"
add-content $fileName  "<td colspan=''7'' height=''25'' align=''center''>"
add-content $fileName  "<font face=''tahoma'' color=''#003399'' size=''4''><strong>SQL Server Alert: DiskSpace Report - $date</strong></font>"
add-content $fileName  "</td>"
add-content $fileName  "</tr>"
add-content $fileName  "</table>"

}

# Function to write the HTML Header to the file
Function writeTableHeader
{
param($fileName)

Add-Content $fileName "<tr bgcolor=#CCCCCC>"
Add-Content $fileName "<td width=''10%'' align=''center''>Drive</td>"
Add-Content $fileName "<td width=''50%'' align=''center''>Drive Label</td>"
Add-Content $fileName "<td width=''10%'' align=''center''>Total Capacity(GB)</td>"
Add-Content $fileName "<td width=''10%'' align=''center''>Used Capacity(GB)</td>"
Add-Content $fileName "<td width=''10%'' align=''center''>Free Space(GB)</td>"
Add-Content $fileName "<td width=''10%'' align=''center''>Freespace %</td>"
Add-Content $fileName "</tr>"
}

Function writeHtmlFooter
{
param($fileName)

Add-Content $fileName "</body>"
Add-Content $fileName "</html>"
}

Function writeDiskInfo
{
param($fileName,$devId,$volName,$frSpace,$totSpace)
$totSpace=[math]::Round(($totSpace/1073741824),2)
$frSpace=[Math]::Round(($frSpace/1073741824),2)
$usedSpace = $totSpace - $frspace
$usedSpace=[Math]::Round($usedSpace,2)
$freePercent = ($frspace/$totSpace)*100
$freePercent = [Math]::Round($freePercent,0)
 if ($freePercent -gt $warning)
 {
 Add-Content $fileName "<tr>"
 Add-Content $fileName "<td>$devid</td>"
 Add-Content $fileName "<td>$volName</td>"
 Add-Content $fileName "<td>$totSpace</td>"
 Add-Content $fileName "<td>$usedSpace</td>"
 Add-Content $fileName "<td>$frSpace</td>"
 Add-Content $fileName "<td bgcolor=''#00FF00'' align=center>$freePercent</td>"
 #<td bgcolor=''#00FF00'' align=center>
 Add-Content $fileName "</tr>"
 }
 elseif ($freePercent -le $critical)
 {
 Add-Content $fileName "<tr>"
 Add-Content $fileName "<td>$devid</td>"
 Add-Content $fileName "<td>$volName</td>"
 Add-Content $fileName "<td>$totSpace</td>"
 Add-Content $fileName "<td>$usedSpace</td>"
 Add-Content $fileName "<td>$frSpace</td>"
 Add-Content $fileName "<td bgcolor=''#FF0000'' align=center>$freePercent</td>"
 #<td bgcolor=''#FF0000'' align=center>
 Add-Content $fileName "</tr>"
 }
 else
 {
 Add-Content $fileName "<tr>"
 Add-Content $fileName "<td>$devid</td>"
 Add-Content $fileName "<td>$volName</td>"
 Add-Content $fileName "<td>$totSpace</td>"
 Add-Content $fileName "<td>$usedSpace</td>"
 Add-Content $fileName "<td>$frSpace</td>"
 Add-Content $fileName "<td bgcolor=''#FFFF00'' align=center>$freePercent</td>"
 #<td bgcolor=''#FFFF00'' align=center>
 Add-Content $fileName "</tr>"
 }
}

Function sendEmail
{ param($from,$to,$subject,$smtphost,$htmlFileName)
$body = Get-Content $htmlFileName
$smtp= New-Object System.Net.Mail.SmtpClient $smtphost
$msg = New-Object System.Net.Mail.MailMessage $from, $to, $subject, $body
$msg.isBodyhtml = $true
$smtp.send($msg)

}

writeHtmlHeader $freeSpaceFileName
foreach ($server in Get-Content $serverlist)
{
 Add-Content $freeSpaceFileName "<table width=''100%''><tbody>"
 Add-Content $freeSpaceFileName "<tr bgcolor=''#CCCCCC''>"
 Add-Content $freeSpaceFileName "<td width=''100%'' align=''center'' colSpan=6><font face=''tahoma'' color=''#003399'' size=''2''><strong> $server </strong></font></td>"
 Add-Content $freeSpaceFileName "</tr>"

 writeTableHeader $freeSpaceFileName
 $dp = Get-WmiObject win32_logicaldisk -ComputerName $server |  Where-Object {$_.drivetype -eq 3}

 foreach ($item in $dp)
 {
 Write-Output  $item.DeviceID  $item.VolumeName $item.FreeSpace $item.Size
 writeDiskInfo $freeSpaceFileName $item.DeviceID $item.VolumeName $item.FreeSpace $item.Size
 }
Add-Content $freeSpaceFileName "</table>"
}
writeHtmlFooter $freeSpaceFileName
$date = ( get-date ).ToString(''yyyy/MM/dd'')
sendEmail mail.admin@xxx.com dba@xxx.com "SERVER_NAME Disk Space Report - $Date" smptp.xxx.com $freeSpaceFileName


', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'SQLJobStatusNotification', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=6, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20130612, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'4dcd4502-0994-4546-b1ba-3c5f0b26a684'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


