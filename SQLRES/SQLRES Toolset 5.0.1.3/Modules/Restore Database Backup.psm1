#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Restore Database Backup.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 1.3 Fix: error message if no backup exist
# 1.4 Fix: Only list backups of current database
# 1.5 Included support for Availability Groups
# 1.6 Fix: Restore to default Data and Log Dir
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Toolset-RestoreDatabase()
{ 
 <# 
   .Synopsis 
    Restores a backup you can select from a list
   .Description
    Lists all recent database backups taken from toolset
	TestCaseLevel:@Admin	
   .Notes  

   .Example 
    Toolset-RestoreDatabase   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

If ($global:ScopingCompleted -eq $FALSE) {
	Write-Host "Scoping is not completed yet. Please scope environment using Scope-Environment!" -ForegroundColor Yellow
	return
}

If ($global:ScopingCompleted -eq $TRUE) {
		$Computername = $global:Computername
		$Instancename = $global:Instancename
		$InstancePort = $global:InstancePort
		$Databasename = $global:Databasename[0]
		$AvailabilityGroup = $global:AvailabilityGroup
		if ($AvailabilityGroup) {
			$ReplicaInstances = @($global:ReplicaInstances)
			$ReplicaInstancePorts = @($global:ReplicaInstancePorts)
		}
		$IsClustered = $global:IsClustered
		$IsAzure = $global:IsAzure
		$ClusterNodes = $global:ClusterNodes
		$Authentication = $global:Authentication
		$Credentials = $global:Credentials
		If ($Authentication -eq 'SQL Server Authentication') {
			$SQL_Username = $global:SQL_Username
			$SQL_Password = $global:SQL_Password
		}
		else {
			$SQL_Username = $null
			$SQL_Password = $null
		}
}

if ($Computername -eq ".") {
	$Computername = "localhost"
}

if ($Instancename -ne "MSSQLSERVER") {
	$Servername = $Computername + "\" + $Instancename
}
else {
	$Servername = $Computername
}

#region CheckAGReplica_Primary
try {
	Write-Host "Checking if database is member of an Availability Group ..."
	if ($Authentication -eq 'SQL Server Authentication') {
		$connectionString      = "Data Source=$($Servername),$($InstancePort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
		$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
		[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
		$SQLPwd.MakeReadOnly()
		$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
		$Connection.credential = $cred
	}
	else {
		$ConnectionString      = "Data Source=$($Servername),$($InstancePort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
		$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
	}	
	$Connection.open()

	$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
	$command.Connection = $Connection
	$command.CommandTimeout = '300'

	$command.CommandText = "
		SELECT hags.primary_replica FROM sys.availability_databases_cluster adc INNER JOIN sys.dm_hadr_availability_group_states hags ON adc.group_id = hags.group_id WHERE adc.database_name = '$Databasename'
	" 
	$PrimaryReplica = $command.ExecuteScalar()
	$Connection.Close() | Out-Null
	
	if ([String]::IsNullOrEmpty($PrimaryReplica) -eq $false -and $PrimaryReplica.ToUpper() -ne $Servername.ToUpper()) {
		Write-Host "Primary Replica is $PrimaryReplica."

		$message = "Do you want to run the test case on primary replica?"
		$title = "primary"
		$choicePrimary = New-Object System.Management.Automation.Host.ChoiceDescription "&Primary", "Answer Primary."
		$choiceCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Answer Cancel."
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($choicePrimary, $choiceCancel)
		$result = $host.ui.PromptForChoice($title, $message, $options, 1)
		if ($result -eq 1) {
			return
		}
		if ($result -eq 0) {
			$Servername = $PrimaryReplica
		}
		$InstancePort = $ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$Servername)]

		if($Servername.Split("\").Length -gt 1) {
			$Computername = $Servername.Split("\")[0]
			$Instancename = $Servername.Split("\")[1]
		}
		else {
			$Computername = $Servername
			$Instancename = "MSSQLSERVER"
		}
	}
}
catch [System.Data.SqlClient.SqlException] {
	if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
		Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
	}
	else {
	    if ($PSBoundParameters['Verbose']) {
	        $ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
	    }
	    else {
	        Write-Host $_.Exception.Message -ForegroundColor Red
	    }
	}
	return
}
catch {
    if ($PSBoundParameters['Verbose']) {
        $ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
    }
    else {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
	return
}

#endregion CheckAGReplica_Primary

#For local execution on cluster node
$Computername = Get-HostnameFromServername -Servername $Computername

$returncode = 0

#Reading InstanceProperties
try {
	if ($Authentication -eq 'SQL Server Authentication') {
		$connectionString      = "Data Source=$($Servername),$($InstancePort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
		$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
		[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
		$SQLPwd.MakeReadOnly()
		$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
		$Connection.credential = $cred
	}
	else {
		$ConnectionString      = "Data Source=$($Servername),$($InstancePort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
		$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
	}	
	$Connection.open()

	$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
	$command.Connection = $Connection
	$command.CommandTimeout = '300'

	$command.CommandText = "
	DECLARE @ProductVersion VARCHAR(20)
	DECLARE @ProductMinorVersion DECIMAL(5,2)
	DECLARE @ProductLevel VARCHAR(20)
	DECLARE @EngineEdition INT
	DECLARE @IsClustered INT
	DECLARE @IsIntegratedSecurityOnly INT

	SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
	SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
	SET @ProductLevel = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductLevel'))
	SET @EngineEdition = CONVERT(INT,SERVERPROPERTY('EngineEdition'))
	SET @IsClustered = CONVERT(INT,SERVERPROPERTY('IsClustered'))
	SET @IsIntegratedSecurityOnly = CONVERT(INT,SERVERPROPERTY('IsIntegratedSecurityOnly'))

	SELECT @ProductVersion ProductVersion, @ProductMinorVersion ProductMinorVersion, @ProductLevel ProductLevel, @EngineEdition EngineEdition, @IsClustered IsClustered, @IsIntegratedSecurityOnly IsIntegratedSecurityOnly
	"
	$Reader = $command.ExecuteReader()
	
	while($Reader.Read())
	{		
		$ProductVersion = $Reader["ProductVersion"]
		$ProductMinorVersion = $Reader["ProductMinorVersion"]
		$ProductLevel = $Reader["ProductLevel"]
		$EngineEdition = $Reader["EngineEdition"]
		$IsClustered = $Reader["IsClustered"]
		$IsIntegratedSecurityOnly = $Reader["IsIntegratedSecurityOnly"]
	}
	$reader.Close()
}
catch [System.Data.SqlClient.SqlException] {
	if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
		Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
		return
	}
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	return
}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	return
}

try {
	[String]$AvailabilityGroupName = ''
	$command.CommandText = "SELECT ag.name FROM sys.databases d INNER JOIN
		sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
		sys.availability_groups ag ON ar.group_id = ag.group_id
		WHERE d.name = '$Databasename'"
	$AvailabilityGroupName = $command.ExecuteScalar()
}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	$returncode = -1
}

if ($AvailabilityGroupName) {
	Write-Host "This database is member of an availability group!" <# Restore of availability group databases is not available in the current toolset."#> -ForegroundColor Yellow
	$message = "Do you want to try to restore the database?"
	$title = "Restore database"
	$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
	$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1)
	if ($result -ne 0) {
		$returncode = -1
	}

	Write-Host "Removing the old database(s) from the primary node ..."
	try {
		$ReplicaInstances = @()
		$command.CommandText = "SELECT node_name, replica_server_name FROM sys.dm_hadr_availability_replica_cluster_nodes WHERE group_name = '$AvailabilityGroupName'"
		$reader = $command.ExecuteReader()
		while($Reader.Read())
		{
			#$NodeName = $Reader["node_name"].ToString()    
			$ReplicaInstance = $Reader["replica_server_name"].ToString()
			$ReplicaInstances  += @($ReplicaInstance)
		}  	
		$reader.Close()
		foreach ($db in $global:Databasename) {
			Write-Host "Removing database $db FROM Availability Group $AvailabilityGroupName ..."
			$command.CommandText = "ALTER AVAILABILITY GROUP [$AvailabilityGroupName] REMOVE DATABASE [$db]"
			$rs = $command.ExecuteNonQuery() | Out-Null
		}
		foreach ($ReplicaInstance in $ReplicaInstances) {
			Write-Host "Connecting to $ReplicaInstance ..."
			if ($Authentication -eq 'SQL Server Authentication') {
				$ReplicaConnectionString      = "Data Source=$ReplicaInstance;Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
				$ReplicaConnection = New-Object System.Data.SqlClient.SqlConnection($ReplicaConnectionString)
				[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
				$SQLPwd.MakeReadOnly()
				$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
				$ReplicaConnection.credential = $cred
			}
			else {
				$ReplicaConnectionString      = "Data Source=$ReplicaInstance;Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
				$ReplicaConnection = New-Object System.Data.SqlClient.SqlConnection($ReplicaConnectionString)
			}	
			$ReplicaConnection.open()
			$ReplicaCommand = New-Object system.Data.SqlClient.SqlCommand($sql,$ReplicaConnection)
			$ReplicaCommand.Connection = $ReplicaConnection
			$ReplicaCommand.CommandTimeout = '30'
			
			Write-Host "Removing database(s) ..."
			foreach ($db in $global:Databasename) {
				$ReplicaCommand.CommandText = "
				BEGIN TRY
				ALTER DATABASE [$db] SET OFFLINE WITH ROLLBACK IMMEDIATE
				END TRY
				BEGIN CATCH
				END CATCH
				"
				$rs = $ReplicaCommand.ExecuteNonQuery() | Out-Null
				$ReplicaCommand.CommandText = "
				--EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$db'
				USE [master]
				DROP DATABASE [$db]
				"
				$rs = $ReplicaCommand.ExecuteNonQuery() | Out-Null
			}
			$ReplicaConnection.close()
		}
	}
	catch {
		if ($PSBoundParameters['Verbose']) {
			$ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
		}
		else {
			Write-Host $_.Exception.Message -ForegroundColor Red
		}
	}
}

if ($returncode -eq 0) {
	$command.CommandText = "
	DECLARE @Backups TABLE (physical_device_name NVARCHAR(4000))
	DECLARE @FileExists TABLE ([File Exists] SMALLINT, [File is a Directoty] SMALLINT, [Parent Directory Exists] SMALLINT)
	INSERT INTO @Backups
	SELECT physical_device_name FROM msdb.dbo.backupmediafamily INNER JOIN msdb.dbo.backupset ON backupmediafamily.media_set_id = backupset.media_set_id WHERE database_name = '$Databasename' AND  physical_device_name LIKE '%[_]$Global:ModuleName[_]%' ORDER BY backupmediafamily.media_set_id DESC
	
	DECLARE @physical_device_name NVARCHAR(4000)
	DECLARE Backup_Crs CURSOR FOR SELECT physical_device_name FROM @Backups
	OPEN Backup_Crs
	FETCH NEXT FROM Backup_Crs INTO @physical_device_name
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DELETE @FileExists
		INSERT INTO @FileExists 
		EXEC xp_fileexist @physical_device_name
		
		IF EXISTS (SELECT * FROM @FileExists WHERE [File Exists] = 0)
			DELETE  @Backups WHERE physical_device_name = @physical_device_name

		FETCH NEXT FROM Backup_Crs INTO @physical_device_name
	END
	CLOSE Backup_Crs
	DEALLOCATE Backup_Crs
	
	SELECT physical_device_name FROM @Backups
	" 
	#Write-Host $command.CommandText
	$BackupInfos = @()
	try {
		Write-Host "Retrieving backup information ... "
		$reader = $command.ExecuteReader()
		while($Reader.Read())
		{
			$BackupInfo = $Reader["physical_device_name"].ToString()    
			$BackupInfos  += @($BackupInfo)
		}  
	$reader.Close()
	}
	catch {
		if ($PSBoundParameters['Verbose']) {
			$ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
		}
		else {
			Write-Host $_.Exception.Message -ForegroundColor Red
		}
		$returncode = -1
	}
}

if ($BackupInfos.Length -eq 0) {
	Write-Host "No backups from $Global:ModuleName are available."
}
else {	
	$SelectedBackup = Select-TextItem $BackupInfos
}

if ($SelectedBackup) {
	try {
		#Write-Host $SelectedBackup
		ForEach ($db in $global:Databasename) {
			$RestoreCommand = "
			IF EXISTS (SELECT * FROM sys.databases WHERE name = '" + $db + "')
				ALTER DATABASE [" + $db + "] SET OFFLINE WITH ROLLBACK IMMEDIATE 
			RESTORE DATABASE [" + $db + "] FROM DISK='" + $SelectedBackup + "' WITH REPLACE 
			"
			$command.CommandText = "
				declare @rc int, 
				@DataDir nvarchar(4000) 
				exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'DefaultData', @DataDir output, 'no_output' 
				if (@DataDir is null) 
				begin 
				exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @DataDir output, 'no_output' 
				select @DataDir = @DataDir + N'\Data' 
				end 
				SELECT @DataDir"
			$DefaultDataDir = $Command.ExecuteScalar()
			
			$command.CommandText = "
				declare @rc int, 
				@LogDir nvarchar(4000) 
				exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'DefaultLog', @LogDir output, 'no_output' 
				if (@LogDir is null) 
				begin 
				exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\Setup',N'SQLDataRoot', @LogDir output, 'no_output' 
				select @LogDir = @LogDir + N'\Data' 
				end 
				SELECT @LogDir"
			$DefaultLogDir = $Command.ExecuteScalar()
			
			$command.CommandText = "
			IF OBJECT_ID('tempdb..#FileList') <> 0
				DROP TABLE #FileList
			CREATE TABLE #FileList (LogicalName varchar(255), PhysicalName varchar(255), Type CHAR(1), FileGroupName VARCHAR(255), Size BIGINT, MaxSize BIGINT, FileId INT, CreateLSN VARCHAR(50), DropLSN VARCHAR(50), UniqueId uniqueidentifier, ReadONlyLSN VARCHAR(50), ReadWriteLSN VARCHAR(50), BackupSizeinBytes BIGINT, SourceBlockSize INT, FileGroupId INT, LogGroupGUID uniqueidentifier, DifferentialBaseLSN VARCHAR(50), DifferentialBaseGUID uniqueidentifier, IsReadOnly INT, IsPresent INT, TDEThumbprint VARCHAR(50))

			IF (SELECT LEFT(CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion')), CHARINDEX('.',CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion')))-1)) >= 13
				ALTER TABLE #FileList ADD SnapshotURL nvarchar(360)

			INSERT INTO #FileList
			EXEC ('RESTORE FILELISTONLY FROM DISK = ''" + $SelectedBackup + "''')
			SELECT LogicalName, PhysicalName, Type, FileId FROM #FileList ORDER BY FileId

			--DECLARE @FileList table (LogicalName varchar(255), PhysicalName varchar(255), Type CHAR(1), FileGroupName VARCHAR(255), Size BIGINT, MaxSize BIGINT, FileId INT, CreateLSN VARCHAR(50), DropLSN VARCHAR(50), UniqueId uniqueidentifier, ReadONlyLSN VARCHAR(50), ReadWriteLSN VARCHAR(50), BackupSizeinBytes BIGINT, SourceBlockSize INT, FileGroupId INT, LogGroupGUID uniqueidentifier, DifferentialBaseLSN VARCHAR(50), DifferentialBaseGUID uniqueidentifier, IsReadOnly INT, IsPresent INT, TDEThumbprint VARCHAR(50))
			--INSERT INTO @FileList 
			--EXEC ('RESTORE FILELISTONLY FROM DISK = ''" + $SelectedBackup + "''')
			--SELECT LogicalName, PhysicalName, Type, FileId FROM @FileList ORDER BY FileId
			"
			$reader = $command.ExecuteReader()
			while($Reader.Read())
			{
				$LogicalName = $Reader["LogicalName"].ToString()    
				#$PhysicalName = $Reader["PhysicalName"].ToString()    
				$Type = $Reader["Type"].ToString()    
				$FileId = $Reader["FileId"]
				if ($Type -eq "L") {
					$RestoreCommand = $RestoreCommand + ", MOVE '" + $LogicalName + "' TO N'" + $DefaultLogDir + "\" + $db + "_" 
				}
				else {
					$RestoreCommand = $RestoreCommand + ", MOVE '" + $LogicalName + "' TO N'" + $DefaultDataDir + "\" + $db + "_" 
				}
				if ($FileId -le 2) {
					switch ($Type) {
						"D" {$RestoreCommand = $RestoreCommand + "Data" + ".mdf'"}
						"L" {$RestoreCommand = $RestoreCommand + "Log" + ".ldf'"} 
						"F" {$RestoreCommand = $RestoreCommand + "FTData'"}
						"S" {$RestoreCommand = $RestoreCommand + "FSData'"}
						}
					}
				else {
					switch ($Type) {
						"D" {$RestoreCommand = $RestoreCommand + "Data" + $FileId.ToString() + ".ndf'"}
						"L" {$RestoreCommand = $RestoreCommand + "Log" + $FileId.ToString() + ".ldf'"}
						"F" {$RestoreCommand = $RestoreCommand + "FTData" + $FileId.ToString() + "'"}
						"S" {$RestoreCommand = $RestoreCommand + "FSData" + $FileId.ToString() + "'"}
						}
					}			
			}
			$reader.Close()
			#Write-Host $RestoreCommand
			Write-Host "Restoring database $db ... "
			$command.CommandTimeout = 0
			$command.CommandText = $RestoreCommand
			$rs = $command.ExecuteNonQuery()
			if ($AvailabilityGroupName) {
				$command.CommandText = "ALTER AVAILABILITY GROUP [$AvailabilityGroupName] ADD DATABASE [$db]"
				$rs = $command.ExecuteNonQuery()
			}
		}
	}
	catch {
		if ($PSBoundParameters['Verbose']) {
			$ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
		}
		else {
			Write-Host $_.Exception.Message -ForegroundColor Red
		}
		$returncode = -1
	}				
}
else {
	return
}

if ($error[0]) {
	$returncode = -1
}
	
if ($returncode -eq 0) {
	Write-Host "Database(s) restored successfully!" -ForegroundColor Green
}
else {
	Write-Host "Database(s) could not be restored!" -ForegroundColor Red
}

}
