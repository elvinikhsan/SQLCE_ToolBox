#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: MAX Server Memory too low.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Fix: Need to adjust MIN SERVER MEMORY as well
# 1.2 Updated: Toolset will consume memory, test case duration configurable
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 4.1 Fix: CEIP restart
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-MaxServerMemoryTooLow
{ 
 <# 
   .Synopsis 
    Executes the test case Max Server Memory too low
   .Description
    This function connects to the target instance
	and reads the minimum value for MAX SERVER MEMORY.
	MAX SERVER MEMORY will then be set to the minimum possible value.
	Students shall execute a memory consuming query.
	Students will receive memory errors (701). On SQL Server versions 2012 and above
	it will be hard to set this value back. Students may have to start SQL Server with minimal configuration (-f).
	TestCaseLevel:Instance
   .Notes  
	
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Example 
    Execute-MaxServerMemoryTooLow   
   .Example 
    Execute-MaxServerMemoryTooLow -IgnoreScoping -Computername Computer1 -Instancename Inst1
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param(
   [Parameter(Mandatory=$false)]
   [string]$Computername
 ,
   [Parameter(Mandatory=$false)]
   [string]$Instancename = "MSSQLSERVER"
 ,
   [Switch]$IgnoreScoping
)
Set-StrictMode -Version 2.0

If ($IgnoreScoping.IsPresent -eq $FALSE)
{
	If ($global:ScopingCompleted -eq $TRUE) {
		$Computername = $global:Computername
		$Instancename = $global:Instancename
		$InstancePort = $global:InstancePort
		$Databasename = $global:Databasename
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
	else {
		Write-Host "Warning! Test case execution without scoping only possible by using IgnoreScoping switch." -ForegroundColor Yellow
		return
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

#region CheckAGReplica
try {
	Write-Host "Checking if server is member of an Availability Group ..."
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
	
	if ($PrimaryReplica) {
		Write-Host "Primary Replica is $PrimaryReplica."
		Write-Host "Connecting to primary replica to read replica information ..."
		$PrimaryReplicaPort=$ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$PrimaryReplica.ToUpper())]
		if ($Authentication -eq 'SQL Server Authentication') {
			$connectionString      = "Data Source=$($PrimaryReplica),$($PrimaryReplicaPort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
			$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
			[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
			$SQLPwd.MakeReadOnly()
			$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
			$Connection.credential = $cred
		}
		else {
			$ConnectionString      = "Data Source=$($PrimaryReplica),$($PrimaryReplicaPort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
			$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
		}	
		$Connection.open()

		$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
		$command.Connection = $Connection
		$command.CommandTimeout = '300'

		$command.CommandText = "
		SELECT ar.replica_server_name FROM sys.dm_hadr_database_replica_states dhdrs 
		INNER JOIN sys.dm_hadr_availability_replica_states dhars ON dhdrs.replica_id = dhars.replica_id
		INNER JOIN sys.availability_replicas ar ON dhars.replica_id = ar.replica_id
		WHERE dhdrs.database_id = DB_ID('$Databasename') AND secondary_role_allow_connections > 1 AND dhars.role = 2
		" 
		
		$ReplicaSelection = @()
		$Reader = $command.ExecuteReader()
		
		while($Reader.Read())
		{		
			$ReplicaServerName = $Reader["replica_server_name"]
			$ReplicaSelection += @($ReplicaServerName) 
			
		}
		$reader.Close()
		$Connection.Close() | Out-Null
		#$ReplicaSelection
		if ($ReplicaSelection.Length -gt 0) {
			$message = "Do you want to run the test case on primary or secondary replica?"
			$title = "primary / secondary"
			$choicePrimary = New-Object System.Management.Automation.Host.ChoiceDescription "&Primary", "Answer Primary."
			$choiceSecondary = New-Object System.Management.Automation.Host.ChoiceDescription "&Secondary", "Answer Secondary."
			$choiceCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Answer Cancel."
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($choicePrimary, $choiceSecondary, $choiceCancel)
			$result = $host.ui.PromptForChoice($title, $message, $options, 2)
			if ($result -eq 2) {
				return
			}
			if ($result -eq 0) {
				$Servername = $PrimaryReplica
			}
			if ($result -eq 1) {
				if ($ReplicaSelection.Length -gt 1) {
					$Servername = Select-TextItem $ReplicaSelection
					if (!$Servername) {
						Write-Host "Exiting test case ..."
						return
					}
					Write-Host "You have selected replica $Servername."
				}
				else {
					$Servername = $ReplicaSelection[0]
					Write-Host "$Servername is the only available secondary read-only replica."
				}
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
		else {
			Write-Host "No secondary read-only replica available."
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

#endregion CheckAGReplica

#For local execution on cluster node
$Computername = Get-HostnameFromServername -Servername $Computername

Write-Host "Connecting to computer $Computername ..."
try {
	If ($Credentials.PSObject.Properties.name -match $Computername) {
		$sess = New-PSSession -ComputerName $Computername -Credential $Credentials.($Computername)
	}
	else {
		$sess = New-PSSession -ComputerName $Computername
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
	Write-Host "Test case execution failed!" -ForegroundColor Red
	return
}

$returncode = Invoke-Command -Session $sess -ArgumentList $Instancename, $InstancePort, $Servername, $Global:ModuleName, $Authentication, $SQL_Username, $SQL_Password, ($PSBoundParameters['Verbose']) -ScriptBlock {
param($Instancename, $InstancePort, $Servername, $ModuleName, $Authentication, $SQL_Username, $SQL_Password, $VerboseLogging)
$PSBoundParameters['Verbose'] = $VerboseLogging

$error.Clear()

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

	$command.CommandText = "SELECT top 1 value FROM [master].sys.extended_properties WHERE class_desc = 'DATABASE' and name = '$ModuleName'" 
	$Scoping_check = $command.ExecuteScalar()
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
	return -1
}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	return -1
}

if ($Scoping_check -ne 'TRUE') {
    Write-Host "This instance has no scoping flag. The execution will be aborted!" -ForegroundColor Red
    return
}
else {
    Write-Host "Scoping check succeeded..." -ForegroundColor DarkGreen
}

$error.Clear()

#Reading InstanceProperties
try {
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
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	return -1
}

# If ($IsClustered -eq 1) {
# 	$resourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'SQL Server'} | Where-Object {$_.PrivateProperties.Instancename -eq $Instancename}).name
# 	$agentresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'SQL Server Agent'} | Where-Object {$_.PrivateProperties.Instancename -eq $Instancename}).name
# 	if ($ProductMinorVersion -ge 13) {
# 		if ($Instancename -eq "MSSQLSERVER") {
# 			$ceipresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'Generic Service'} | Where-Object {$_.PrivateProperties.Servicename -eq "SQLTELEMETRY"}).name
# 		}
# 		else {
# 			$ceipresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'Generic Service'} | Where-Object {$_.PrivateProperties.Servicename -eq "SQLTELEMETRY`$$($Instancename)"}).name
# 		}
# 	}
# 	else {
# 		$ceipresourcename = ""
# 	}
# }

try {
	$command.CommandText = "SELECT minimum FROM master.sys.configurations WHERE name = 'max server memory (MB)'" 
	$MinValue = $command.ExecuteScalar()

	# Write-Host "Enable scan for startup procs ..."	
	# $command.CommandText = "
	# DECLARE @ShowAdvanced BIT
	# IF (SELECT value FROM master.sys.configurations WHERE name = 'show advanced options') = 0
	# 	SET @ShowAdvanced = 0
	# ELSE
	# 	SET @ShowAdvanced = 1
	# IF @ShowAdvanced = 0
	# 	EXEC sys.sp_configure N'show advanced options', N'1' RECONFIGURE WITH OVERRIDE

	# EXEC sys.sp_configure 'scan for startup', 1
	# RECONFIGURE WITH OVERRIDE
	# IF @ShowAdvanced = 0
	# 	EXEC sys.sp_configure N'show advanced options', N'0' RECONFIGURE WITH OVERRIDE
	# " 
	# $rs = $command.ExecuteNonQuery()

	# Write-Host "Create startup proc that consumes memory ..."	
	# $command.CommandText = "
	# IF EXISTS (SELECT * FROM master.sys.sysobjects WHERE name = 'EatMemory')
	# 	DROP PROC dbo.EatMemory
	# "
	# $rs = $command.ExecuteNonQuery()
	# $command.CommandText = "
	# CREATE PROC dbo.EatMemory
	# AS
	# BEGIN
	# 	DECLARE @a NVARCHAR(MAX)
	# 	DECLARE @b NVARCHAR(MAX)
	# 	DECLARE @i INT
	# 	DECLARE @errormessage NVARCHAR(255)
	# 	DECLARE @RAM_MB INT
	# 	BEGIN TRY
	# 		SELECT @RAM_MB = CONVERT(INT,minimum) FROM sys.configurations WHERE name = 'max server memory (MB)'
	# 		IF @RAM_MB > 1024
	# 			SET @RAM_MB = 1024
	# 		IF SUSER_SID() <> 0x01 --sa
	# 			SET @RAM_MB = 10
	# 		SET @errormessage = 'Started Eating memory (' + SUSER_SNAME() + ' - ' + CONVERT(NVARCHAR(10),@RAM_MB) + ') ...'
	# 		RAISERROR(@errormessage, 10, 1) WITH LOG
	# 		SET @a = REPLICATE('a', 512)
	# 		SET @b = ''
	# 		SET @i = 1
	# 		WHILE @i < (@RAM_MB * 512)
	# 		BEGIN
	# 			SET @b = @b + @a
	# 			IF @i % 1024 = 0
	# 			BEGIN
	# 				SET @errormessage = 'Eating memory (' + SUSER_SNAME() + ' ' + CONVERT(NVARCHAR(10),DATALENGTH(@b) / 1024) + 'KB) ...'
	# 				RAISERROR(@errormessage, 10, 1) WITH LOG
	# 			END
	# 			SET @i = @i + 1
	# 		END
	# 	END TRY
	# 	BEGIN CATCH
	# 		PRINT ''
	# 	END CATCH
	# 	IF SUSER_SID() = 0x01 -- sa
	# 		WHILE 1=1
	# 		BEGIN
	# 			WAITFOR DELAY '00:01:00'
	# 			RAISERROR('Eating memory - Sleeping', 10, 1) WITH LOG  
	# 		END
	# END
	# "
	# $rs = $command.ExecuteNonQuery()
	
	# $command.CommandText = "
	# EXEC sp_procoption 'dbo.EatMemory' , 'STARTUP', 'ON'
	# GRANT EXECUTE ON dbo.EatMemory TO guest
	# " 
	# $rs = $command.ExecuteNonQuery()

	# Write-Host "Create a logon trigger that calls EatMemory ..."	
	# $command.CommandText = "
	# IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'Trig_EatMemory')
	# 	DROP TRIGGER Trig_EatMemory ON ALL SERVER
	# " 
	# $rs = $command.ExecuteNonQuery()
	# $command.CommandText = "
	# CREATE TRIGGER Trig_EatMemory ON ALL SERVER
	# FOR LOGON
	# AS
	# BEGIN
	# 	IF SUSER_SID() = 0x010100000000000512000000
	# 		return
	# 	EXEC master.dbo.EatMemory
	# END
	# " 
	# $rs = $command.ExecuteNonQuery()

	Write-Host "Setting MAX SERVER MEMORY to $MinValue MB ..."	
	$command.CommandText = "
	DECLARE @ShowAdvanced BIT
	IF (SELECT value FROM master.sys.configurations WHERE name = 'show advanced options') = 0
		SET @ShowAdvanced = 0
	ELSE
		SET @ShowAdvanced = 1
	IF @ShowAdvanced = 0
		EXEC sys.sp_configure N'show advanced options', N'1' RECONFIGURE WITH OVERRIDE
	EXEC sys.sp_configure N'min server memory (MB)', N'$MinValue'
	EXEC sys.sp_configure N'max server memory (MB)', N'$MinValue'
	--EXEC sys.sp_configure N'min memory per query (KB)', N'$MaxValue'
	RECONFIGURE WITH OVERRIDE
	IF @ShowAdvanced = 0
		EXEC sys.sp_configure N'show advanced options', N'0' RECONFIGURE WITH OVERRIDE
	" 
	$command.ExecuteNonQuery() | Out-Null

}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	return -1
}

# try {	
# 	Write-Host "Stopping ..."
# 	If ($IsClustered -eq 1) {
# 		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
# 		$timeout = 60
# 		$service.TakeOffline($timeout) | Out-null
# 	}
# 	else {
# 		$StopStarted = Get-Date
# 		$ServicePID = (get-wmiobject win32_service | Where-Object { $_.DisplayName -eq "SQL Server ($Instancename)" }).processID
# 		$(Get-Service "SQL Server ($Instancename)").Stop() | Out-null
# 		do { 
# 			if ((New-TimeSpan -Start $StopStarted -End (Get-Date)).Seconds -gt 15) {
# 				Stop-Process $ServicePID -Force
# 			}
# 			Start-Sleep -Milliseconds 200 	
# 		}
# 		until ((get-service "SQL Server ($Instancename)").status -eq 'Stopped')
# 		Start-Sleep -Milliseconds 200
# 	}
	
# 	Write-Host "Starting ..."
# 	If ($IsClustered -eq 1) {
# 		$timeout = 60
# 		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
# 		$service.BringOnline($timeout) | Out-null
# 		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $agentresourcename}
# 		Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
# 		if ($ceipresourcename) {
# 			$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $ceipresourcename}
# 			Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
# 		}
# 	}
# 	else {
# 		$(Get-Service "SQL Server ($Instancename)").Start() | Out-null
# 		do { Start-Sleep -Milliseconds 200 }
# 		until ((get-service "SQL Server ($Instancename)").status -eq 'Running')
# 		Start-Sleep -Milliseconds 200
# 		Get-Service "SQL Server Agent ($Instancename)" | Start-Service -ErrorAction "SilentlyContinue"
# 		if ($ProductMinorVersion -ge 13) {
#			Get-Service "SQL Server CEIP service ($Instancename)" -ErrorAction "SilentlyContinue"  | Start-Service -ErrorAction "SilentlyContinue"
#		}
# 	}

# }
# catch {
# 	if ($PSBoundParameters['Verbose']) {
# 		$ErrorString = $_ | format-list -force | Out-String
# 		Write-Host $ErrorString -ForegroundColor Red
# 	}
# 	else {
# 		Write-Host $_.Exception.Message -ForegroundColor Red
# 	}
# 	return -1
# }

if ($error[0]) {
	return -1
}
else {
	return 0
}

}
$sess | Remove-PSSession

if ($returncode -eq 0) {
	Write-Host "Test case execution successful!" -ForegroundColor Green
	Write-Host "Student task: Have a look at backup history (select * from msdb.dbo.backupset)." -ForegroundColor Cyan
	Write-Host "Student task: What happens to SQL Server. Try to repair!" -ForegroundColor Cyan
	# Write-Host "Warning: Remove auto-startup proc EatMemory and logon trigger Trig_EatMemory!" -ForegroundColor Yellow
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
