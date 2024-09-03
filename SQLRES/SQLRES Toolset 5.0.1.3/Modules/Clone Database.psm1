#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Clone Database.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Integrated HashCode for configuration data
# 1.2 included test level logic
# 1.3 included sample code disclaimer
# 1.4 Fix: error message if no backup exist
# 1.5 Fix: Only list backups of current database
# 1.6 Included support for availability groups
# 3.0 Initial version for SQL 2016 release
# 3.1 FIPS compliance
# 3.2 Fix: Restore TLog file to default TLog folder
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Toolset-CloneDatabase()
{ 
 <# 
   .Synopsis 
    Creates additional database as a copy of the first database
   .Description
    Here you can create additional databases in case students want to work in parallel on the test cases.
	TestCaseLevel:@Admin	
   .Notes  
	You can decide if you want to use the backup/restore option or the detach/copy/attach option
   .Example 
    Toolset-CloneDatabase   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

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

$AnotherDB = 0
$BackupTaken = $FALSE
$returncode = 0
$Cancel = $FALSE

$message = "Do you want to use an existing $Global:ModuleName backup? (yes/no)"
$title = "Existing Backup"
$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
$TakeExistingBackup = $host.ui.PromptForChoice($title, $message, $options, 0)

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
	$message = "Do you want to try to clone the database and add it to the availability group?"
	$title = "Clone database"
	$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
	$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1)
	if ($result -ne 0) {
		$returncode = -1
	}
}

if (($returncode -eq 0) -and ($TakeExistingBackup -eq 0)) {
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

	$selectedBackup = ""
	if ($BackupInfos.Length -eq 0) {
		Write-Host "No backups from $Global:ModuleName are available."
	}
	else {	
		$SelectedBackup = Select-TextItem $BackupInfos
	}
		
	if ($SelectedBackup) {
		$GeneratedBackupFile = $SelectedBackup
		$BackupTaken = $TRUE
	}
	else {
		$AnotherDB = 1
		$Cancel = $TRUE
	}
}


while (($AnotherDB -eq 0) -and ($returncode -eq 0)) {

	$Skip = $FALSE
	
	Write-Host "Please enter a unique postfix for an additional database"
	$Postfix = Read-Host -Prompt "Postfix"
	$NewDatabasename = $global:Databasename[0] + "_" + $Postfix
	
	If ($global:Databasename -contains $Databasename + "_$Postfix" -or $Postfix -eq "") {
		Write-Host "A database with the postfix $Postfix already exists." -ForegroundColor Yellow
		$Skip = $TRUE
	}

	if ($Skip -eq $FALSE) {
		#Only Backup currently available
		#$message = "Please choose cloning option (&copy or &backup)"
		#$title = "Cloning-Type"
		#$choiceCopy = New-Object System.Management.Automation.Host.ChoiceDescription "&Copy", "Answer Copy."
		#$choiceBackup = New-Object System.Management.Automation.Host.ChoiceDescription "&Backup", "Answer Backup."
		#$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceCopy, $choiceBackup)
		#$CloningType = $host.ui.PromptForChoice($title, $message, $options, 1)
		
		if ($returncode -eq 0) {
			try {
				$command.CommandText = "SELECT CONVERT(INT,SERVERPROPERTY('EngineEdition'))"
				[int16]$EngineEdition = $command.ExecuteScalar()
				$command.CommandText = "SELECT CONVERT(NUMERIC(5,2),LEFT(CONVERT(VARCHAR(128),SERVERPROPERTY('ProductVersion')), CHARINDEX('.',CONVERT(VARCHAR(128),SERVERPROPERTY('ProductVersion')),4)-1))"
				[decimal]$ProductVersion = $command.ExecuteScalar()
				
				if (($EngineEdition -eq 3) -and ($ProductVersion -ge 10.5)) {
					$command.CommandText = "
					BACKUP DATABASE [$Databasename] TO DISK = N'##generated-backup-file##' WITH COPY_ONLY, COMPRESSION, INIT
					"
				}
				else {
					$command.CommandText = "
					BACKUP DATABASE [$Databasename] TO DISK = N'##generated-backup-file##' WITH COPY_ONLY, INIT
					"
				}
				if ($BackupTaken -eq $FALSE) {
					$GeneratedBackupFile = $Databasename +  "_" + $Global:ModuleName + "_" + $(get-date -format "yyyy-MM-dd HHmm") + ".bak"
				}
				$command.CommandText = $command.CommandText.Replace("##generated-backup-file##", $GeneratedBackupFile)
				#Write-Host $command.CommandText
				if ($BackupTaken -eq $FALSE) {
					Write-Host "Backing up database $Databasename ... "
					$rs = $command.ExecuteNonQuery()
					$BackupTaken = $TRUE
				}
				$RestoreCommand = "
				RESTORE DATABASE [" + $NewDatabasename + "] FROM DISK='" + $GeneratedBackupFile + "' WITH REPLACE 
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
					exec @rc = master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer',N'DefaultData', @LogDir output, 'no_output' 
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
				EXEC ('RESTORE FILELISTONLY FROM DISK = ''" + $GeneratedBackupFile + "''')
				SELECT LogicalName, PhysicalName, Type, FileId FROM #FileList ORDER BY FileId
				"
				$reader = $command.ExecuteReader()
				while($Reader.Read())
				{
					$LogicalName = $Reader["LogicalName"].ToString()    
					#$PhysicalName = $Reader["PhysicalName"].ToString()    
					$Type = $Reader["Type"].ToString()    
					$FileId = $Reader["FileId"]
					if ($Type -eq "L") {
						$RestoreCommand = $RestoreCommand + ", MOVE '" + $LogicalName + "' TO N'" + $DefaultLogDir + "\" + $Databasename + "_" + $Postfix + "_" 
					}
					else {
						$RestoreCommand = $RestoreCommand + ", MOVE '" + $LogicalName + "' TO N'" + $DefaultDataDir + "\" + $Databasename + "_" + $Postfix + "_" 
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
				Write-Host "Restoring database $NewDatabasename ... "
				$command.CommandText = $RestoreCommand
				$rs = $command.ExecuteNonQuery()
				
				if ($AvailabilityGroupName) {
					$command.CommandText = "ALTER AVAILABILITY GROUP [$AvailabilityGroupName] ADD DATABASE [$NewDatabasename]"
					$rs = $command.ExecuteNonQuery()
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

		if ($returncode -eq 0) {
			try {
				[xml]$ToolsetConfig = Get-Content $ScopingFilePath
				
				$newDatabase = $ToolsetConfig.CreateElement("Databasename")
				$ToolsetConfig.RootElement.($Global:ModuleName).AppendChild($newDatabase) | Out-Null
				$newDatabase.Set_InnerText($NewDatabasename);
				
				$HashValue = Get-StringHash $ToolsetConfig.RootElement.($Global:ModuleName).InnerXML "SHA256"
				$ToolsetConfig.RootElement.ConfigHash = $HashValue

				$ToolsetConfig.Save($ScopingFilePath)
				$global:Databasename += @($NewDatabasename)
			}
			catch {
				if ($PSBoundParameters['Verbose']) {
					$ErrorString = $_ | format-list -force | Out-String
					Write-Host $ErrorString -ForegroundColor Red
				}
				else {
					Write-Host $_.Exception.Message -ForegroundColor Red
				}
				Write-Host "Error writing to Scoping File." -ForegroundColor Red
				return
			}
		}

		if ($returncode -eq 0) {
			$message = "Do you want to create another copy of the database?"
			$title = "Confirm"
			$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
			$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
			$AnotherDB = $host.ui.PromptForChoice($title, $message, $options, 0)
		}
	}
}

if ($error[0]) {
	$returncode = -1
}

if ($Cancel -eq $FALSE) {	
	if ($returncode -eq 0) {
		Write-Host "Additional database copies created!" -ForegroundColor Green
	}
	else {
		Write-Host "Errors occurred during database copy creation!" -ForegroundColor Red
	}
}
	
}

