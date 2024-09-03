#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Who dropped the table.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 1.3 Included support for availability groups
# 1.4 Included support for availability groups on secondary replica
# 1.5 Included support for mirrored databases
# 1.6 Fix: Changed Servername to UPPERcase for Availability Groups on case sensitive instances
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 4.1 Fix: CEIP restart
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-WhoDroppedTable
{ 
 <# 
   .Synopsis 
    Executes the test case Who dropped the table
   .Description
    This function connects to the target instance
	and drops the smallest table in the target database.
	The table name will be displayed.
	Students should try to find out who dropped the table.
	TestCaseLevel:Database
   .Notes  
	
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Parameter Databasename
	The name of the target database. Leave empty if it is the AdventureWorks
   .Example 
    Execute-WhoDroppedTable   
   .Example 
    Execute-WhoDroppedTable -IgnoreScoping -Computername Computer1 -Instancename Inst1
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
   [Parameter(Mandatory=$false)]
   [string]$Databasename = "Adventureworks"
 ,
   [Switch]$IgnoreScoping
)
Set-StrictMode -Version 2.0

$DatabaseArray = $FALSE
If ($IgnoreScoping.IsPresent -eq $FALSE)
{
	If ($global:ScopingCompleted -eq $TRUE) {
		$Computername = $global:Computername
		$Instancename = $global:Instancename
		$InstancePort = $global:InstancePort
		if (!$MyInvocation.BoundParameters["Databasename"]) {
			$Databasename = $global:Databasename[0]
			if (@($global:Databasename).Length -gt 1) {
					$DatabaseArray = $TRUE
			}
		}
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

if ($DatabaseArray -eq $TRUE) {
		ForEach ($db in $global:Databasename) {
			Write-Host "Performing test case on database: $db ..." -BackgroundColor Gray -ForegroundColor Black
			Invoke-Expression "$($MyInvocation.MyCommand) -Databasename $db"
		}
		return
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

$returncode = Invoke-Command -Session $sess -ArgumentList $Instancename, $InstancePort, $Servername, $Databasename, $Global:ModuleName, $Authentication, $SQL_Username, $SQL_Password, ($PSBoundParameters['Verbose']) -ScriptBlock {
param($Instancename, $InstancePort, $Servername, $Databasename, $ModuleName, $Authentication, $SQL_Username, $SQL_Password, $VerboseLogging)
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

	$command.CommandText = "SELECT top 1 value FROM [$Databasename].sys.extended_properties WHERE class_desc = 'DATABASE' and name = '$ModuleName'" 
	$Scoping_check = $command.ExecuteScalar()
}
catch [System.Data.SqlClient.SqlException] {
	if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
		Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
		return -1
	}
	if ($_.Exception.Errors[0].Number -eq 976) {
		Write-Host "Database $Databasename is currently not accessible on $Servername." -ForegroundColor Yellow
		Write-Host "Either failover the Availability Group or configure read access on secondary." -ForegroundColor Yellow
	}
	elseif ($_.Exception.Errors[0].Number -eq 983) {
		Write-Host "Availability Group for database $Databasename is in RESOLVING state." -ForegroundColor Yellow
	}
	elseif ($_.Exception.Errors[0].Number -eq 954) {
		Write-Host "Database $Databasename is mirrored. Please connect to the PRINCIPAL server." -ForegroundColor Yellow
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
    Write-Host "This database has no scoping flag. The execution will be aborted!" -ForegroundColor Red
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

try {
	$command.CommandText = "SELECT dhars.role_desc FROM sys.dm_hadr_database_replica_states dhdrs INNER JOIN 
		sys.dm_hadr_availability_replica_states dhars ON dhdrs.replica_id = dhars.replica_id
		WHERE dhdrs.database_id = DB_ID('$Databasename') AND dhdrs.is_local = 1"
	[String]$DatabaseReplicaRole = $command.ExecuteScalar()
	if ($DatabaseReplicaRole -eq 'SECONDARY') {
		write-host "Database $Databasename is a read-only $DatabaseReplicaRole replica. Test case execution not possible." -foregroundcolor Yellow		
		return -1
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
	return -1
}

If ($IsClustered -eq 1) {
	$resourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'SQL Server'} | Where-Object {$_.PrivateProperties.Instancename -eq $Instancename}).name
	$agentresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'SQL Server Agent'} | Where-Object {$_.PrivateProperties.Instancename -eq $Instancename}).name
	if ($ProductMinorVersion -ge 13) {
		if ($Instancename -eq "MSSQLSERVER") {
			$ceipresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'Generic Service'} | Where-Object {$_.PrivateProperties.Servicename -eq "SQLTELEMETRY"}).name
		}
		else {
			$ceipresourcename = $(Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.Type -eq 'Generic Service'} | Where-Object {$_.PrivateProperties.Servicename -eq "SQLTELEMETRY`$$($Instancename)"}).name
		}
	}
	else {
		$ceipresourcename = ""
	}
}

try {
	$command.CommandText = "DECLARE @LoginMode INT
	EXEC xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', @LoginMode OUTPUT
	SELECT @LoginMode LoginMode
	"
	$LoginMode = $command.ExecuteScalar()
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

try {
	$command.CommandText = "
	IF EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'EvilLogin')
		DROP LOGIN [EvilLogin]
	CREATE LOGIN [EvilLogin] WITH PASSWORD=N'Password1', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
	EXEC master..sp_addsrvrolemember 'EvilLogin', 'sysadmin'
	"
	$rs = $command.ExecuteNonQuery()
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

try {
	[String]$AvailabilityGroupName = ''
	$command.CommandText = "SELECT ag.name FROM sys.databases d INNER JOIN
		sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
		sys.availability_groups ag ON ar.group_id = ag.group_id
		WHERE d.name = '$Databasename'"
	$AvailabilityGroupName = $command.ExecuteScalar()

	[String]$MirroringRole = ""
	$command.CommandText = "SELECT dm.mirroring_role_desc FROM sys.databases d INNER JOIN
		sys.database_mirroring dm on d.database_id = dm.database_id
		WHERE d.name = '$Databasename'"
	$MirroringRole = $command.ExecuteScalar()

	[String]$WitnessName = ""
	$command.CommandText = "SELECT dm.mirroring_witness_name FROM sys.databases d INNER JOIN
		sys.database_mirroring dm on d.database_id = dm.database_id
		WHERE d.name = '$Databasename'"
	$WitnessName = $command.ExecuteScalar()	
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

try {
	$command.CommandText = "
	USE [$Databasename];
	SELECT TOP 1 SCHEMA_NAME(objects.schema_id) + '.' + OBJECT_NAME(objects.object_id) TableName FROM sys.partitions 
		INNER JOIN sys.objects ON partitions.object_id = objects.object_id
	WHERE index_id IN (0,1)
	AND objects.object_id NOT IN (SELECT DISTINCT referenced_object_id FROM sys.foreign_keys)
	AND OBJECTPROPERTY(objects.object_id, 'IsUserTable') = 1
	GROUP BY objects.schema_id, objects.object_id 
	HAVING SUM(rows) >= 0
	ORDER BY SUM(rows), LEN(SCHEMA_NAME(objects.schema_id) + '.' + OBJECT_NAME(objects.object_id))
	" 
	$TableName = $command.ExecuteScalar()
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

if (!$TableName) {
	write-host "Could not find any table that can be deleted!" -foregroundcolor Yellow		
	return -1
}

If ($LoginMode -eq 1) {
	try {
		$command.CommandText = "
		EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2
		"
		$rs = $command.ExecuteNonQuery()
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

	Write-Host "Restarting ..."
	try {
		if ($AvailabilityGroupName -or $MirroringRole) {
			$command.CommandText = "
			SELECT dhar.role_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhar ON ar.replica_id = dhar.replica_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			$ReplicaRole = $command.ExecuteScalar()
			if ($ReplicaRole -eq 'PRIMARY') {
				$command.CommandText = "
				SELECT ar.replica_server_name FROM sys.availability_groups ag
				INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
				WHERE ag.name = '$AvailabilityGroupName'
				AND ar.failover_mode_desc = 'AUTOMATIC'
				"
				$Replicas = @()
				$Reader = $command.ExecuteReader()
				while($Reader.Read())
				{		
					$Replica = $Reader["replica_server_name"]
					$Replicas  += @($Replica)
				}
				$reader.Close()

				foreach ($Replica in $Replicas)
				{		
					#Write-Host $Replica
					$command.CommandText = "USE [master]; ALTER AVAILABILITY GROUP [$AvailabilityGroupName] MODIFY REPLICA ON N'$Replica' WITH (FAILOVER_MODE = MANUAL)" 
					$rs = $command.ExecuteNonQuery()
				}
			}
			$ReplicaSyncState = ""
			$command.CommandText = "
			SELECT operational_state_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhars ON ar.replica_id = dhars.replica_id
			INNER JOIN sys.dm_hadr_availability_group_states dhags ON ag.group_id = dhags.group_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			$ReplicaSyncState = $command.ExecuteScalar()
			while ($ReplicaSyncState -ne 'ONLINE') {
				Start-Sleep -Seconds 1
				$ReplicaSyncState = $command.ExecuteScalar()
			}
			
			if ($WitnessName) {
				$command.CommandText = "USE [master]; ALTER DATABASE [$Databasename] SET WITNESS OFF" 
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
		return -1
	}
	
	If ($IsClustered -eq 1) {
		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
		$timeout = 60
		$service.TakeOffline($timeout) | Out-null
		$service.BringOnline($timeout) | Out-null
	}
	else {
		$StopStarted = Get-Date
		$ServicePID = (get-wmiobject win32_service | Where-Object { $_.DisplayName -eq "SQL Server ($Instancename)" }).processID
		$(Get-Service "SQL Server ($Instancename)").Stop() | Out-null
		do { 
			if ((New-TimeSpan -Start $StopStarted -End (Get-Date)).Seconds -gt 15) {
				Stop-Process $ServicePID -Force
			}
			Start-Sleep -Milliseconds 200 	
		}
		until ((get-service "SQL Server ($Instancename)").status -eq 'Stopped')
		Start-Sleep -Milliseconds 200
		$(Get-Service "SQL Server ($Instancename)").Start() | Out-null
		do { Start-Sleep -Milliseconds 200 }
		until ((get-service "SQL Server ($Instancename)").status -eq 'Running')
	}

	try {
		if ($AvailabilityGroupName -or $MirroringRole) { 
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

			$ReplicaSyncState = ""
			$command.CommandText = "
			SELECT operational_state_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhars ON ar.replica_id = dhars.replica_id
			INNER JOIN sys.dm_hadr_availability_group_states dhags ON ag.group_id = dhags.group_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			while ($ReplicaSyncState -ne 'ONLINE') {
				Start-Sleep -Seconds 1
				$ReplicaSyncState = $command.ExecuteScalar()
			}

			if ($ReplicaRole -eq 'PRIMARY') {
				foreach ($Replica in $Replicas)
				{		
					#Write-Host $Replica
					$command.CommandText = "USE [master]; ALTER AVAILABILITY GROUP [$AvailabilityGroupName] MODIFY REPLICA ON N'$Replica' WITH (FAILOVER_MODE = AUTOMATIC)" 
					$rs = $command.ExecuteNonQuery()
				}
			}
			
			if ($WitnessName) {
				$MirroringState = ""
				$command.CommandText = "
				SELECT ISNULL(dm.mirroring_state_desc,'UNKNOWN') + '|' + d.state_desc FROM sys.databases d
				LEFT JOIN sys.database_mirroring dm ON d.database_id = dm.database_id 
				WHERE d.name = '$Databasename'
				"
				$MirroringAndDBState = $command.ExecuteScalar()
				$MirroringState = $MirroringAndDBState.Split('|')[0]
				$DBState = $MirroringAndDBState.Split('|')[1]
				if ($MirroringState -ne 'SYNCHRONIZED') {
					Write-Host "Waiting until database mirroring is synchronized ..."
				}
				while ($MirroringState -ne 'SYNCHRONIZED' -and ($DBState -ne 'SUSPECT' -and $DBState -ne 'RECOVERY_PENDING')) {
					Start-Sleep -Seconds 1
					$MirroringAndDBState = $command.ExecuteScalar()
					$MirroringState = $MirroringAndDBState.Split('|')[0]
					$DBState = $MirroringAndDBState.Split('|')[1]
				}
				if ($DBState -eq 'ONLINE') {
					$command.CommandText = "USE [master]; ALTER DATABASE [$Databasename] SET WITNESS='$WitnessName'" 
					$rs = $command.ExecuteNonQuery()
				}
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
		return -1
	}
}

Write-Host "Connecting as EvilLogin ..."
try {
	$EvilConnectionString = "Data Source=$($Servername),$($InstancePort);Initial Catalog=master;Application Name=EvilApp;User ID=EvilLogin;Pooling=false;Password=Password1"
	$EvilConnection  = New-Object System.Data.SqlClient.SQLConnection($EvilConnectionString)
	$EvilConnection.open()

	$EvilCommand = New-Object System.Data.SqlClient.SqlCommand($sql,$EvilConnection)
	$EvilCommand.Connection = $EvilConnection
	$EvilCommand.CommandTimeout = '300'
	
	$EvilCommand.CommandText = "select state_desc from sys.databases where name = 'tempdb' and create_date > (select sqlserver_start_time from sys.dm_os_sys_info)" 
	$TempDBState = $EvilCommand.ExecuteScalar()
	while ($TempDBState -ne 'ONLINE') {
		Start-Sleep -Seconds 1
		$TempDBState = $EvilCommand.ExecuteScalar()
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
	return -1
}
	
Write-Host "Going to drop table $TableName in database $Databasename."

try {
	$EvilCommand.CommandText = "USE [$Databasename];DROP TABLE $TableName"
	$rs = $EvilCommand.ExecuteNonQuery()
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

$EvilConnection.Close()
[System.Data.SqlClient.SqlConnection]::ClearAllPools() 

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
	IF EXISTS (SELECT * FROM sys.sql_logins WHERE name = 'EvilLogin')
		DROP LOGIN [EvilLogin]
	"
	$rs = $command.ExecuteNonQuery()
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

If ($LoginMode -eq 1) {

	try {
		$command.CommandText = "
		EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 1
		"
		$rs = $command.ExecuteNonQuery()
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

	Write-Host "Restarting ..."
	try {
		if ($AvailabilityGroupName -or $MirroringRole) {
			$command.CommandText = "
			SELECT dhar.role_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhar ON ar.replica_id = dhar.replica_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			$ReplicaRole = $command.ExecuteScalar()
			if ($ReplicaRole -eq 'PRIMARY') {
				$command.CommandText = "
				SELECT ar.replica_server_name FROM sys.availability_groups ag
				INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
				WHERE ag.name = '$AvailabilityGroupName'
				AND ar.failover_mode_desc = 'AUTOMATIC'
				"
				$Replicas = @()
				$Reader = $command.ExecuteReader()
				while($Reader.Read())
				{		
					$Replica = $Reader["replica_server_name"]
					$Replicas  += @($Replica)
				}
				$reader.Close()

				foreach ($Replica in $Replicas)
				{		
					#Write-Host $Replica
					$command.CommandText = "USE [master]; ALTER AVAILABILITY GROUP [$AvailabilityGroupName] MODIFY REPLICA ON N'$Replica' WITH (FAILOVER_MODE = MANUAL)" 
					$rs = $command.ExecuteNonQuery()
				}
			}
			$ReplicaSyncState = ""
			$command.CommandText = "
			SELECT operational_state_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhars ON ar.replica_id = dhars.replica_id
			INNER JOIN sys.dm_hadr_availability_group_states dhags ON ag.group_id = dhags.group_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			$ReplicaSyncState = $command.ExecuteScalar()
			while ($ReplicaSyncState -ne 'ONLINE') {
				Start-Sleep -Seconds 1
				$ReplicaSyncState = $command.ExecuteScalar()
			}
			
			if ($WitnessName) {
				$command.CommandText = "USE [master]; ALTER DATABASE [$Databasename] SET WITNESS OFF" 
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
		return -1
	}
	
	If ($IsClustered -eq 1) {
		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
		$timeout = 60
		$service.TakeOffline($timeout) | Out-null
		$service.BringOnline($timeout) | Out-null
		$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $agentresourcename}
		Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
		if ($ceipresourcename) {
			$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $ceipresourcename}
			Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
		}
	}
	else {
		$StopStarted = Get-Date
		$ServicePID = (get-wmiobject win32_service | Where-Object { $_.DisplayName -eq "SQL Server ($Instancename)" }).processID
		$(Get-Service "SQL Server ($Instancename)").Stop() | Out-null
		do { 
			if ((New-TimeSpan -Start $StopStarted -End (Get-Date)).Seconds -gt 15) {
				Stop-Process $ServicePID -Force
			}
			Start-Sleep -Milliseconds 200 	
		}
		until ((get-service "SQL Server ($Instancename)").status -eq 'Stopped')
		Start-Sleep -Milliseconds 200
		$(Get-Service "SQL Server ($Instancename)").Start() | Out-null
		do { Start-Sleep -Milliseconds 200 }
		until ((get-service "SQL Server ($Instancename)").status -eq 'Running')
		Start-Sleep -Milliseconds 200
		Get-Service "SQL Server Agent ($Instancename)" | Start-Service -ErrorAction "SilentlyContinue"
		if ($ProductMinorVersion -ge 13) {
			Get-Service "SQL Server CEIP service ($Instancename)" -ErrorAction "SilentlyContinue"  | Start-Service -ErrorAction "SilentlyContinue"
		}
	}

	try {
		if ($AvailabilityGroupName -or $MirroringRole) { 
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

			$ReplicaSyncState = ""
			$command.CommandText = "
			SELECT operational_state_desc FROM sys.availability_groups ag
			INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
			INNER JOIN sys.dm_hadr_availability_replica_states dhars ON ar.replica_id = dhars.replica_id
			INNER JOIN sys.dm_hadr_availability_group_states dhags ON ag.group_id = dhags.group_id
			WHERE ag.name = '$AvailabilityGroupName'
			AND ar.replica_server_name = UPPER('$Servername')
			"
			while ($ReplicaSyncState -ne 'ONLINE') {
				Start-Sleep -Seconds 1
				$ReplicaSyncState = $command.ExecuteScalar()
			}

			if ($ReplicaRole -eq 'PRIMARY') {
				foreach ($Replica in $Replicas)
				{		
					#Write-Host $Replica
					$command.CommandText = "USE [master]; ALTER AVAILABILITY GROUP [$AvailabilityGroupName] MODIFY REPLICA ON N'$Replica' WITH (FAILOVER_MODE = AUTOMATIC)" 
					$rs = $command.ExecuteNonQuery()
				}
			}
			
			if ($WitnessName) {
				$MirroringState = ""
				$command.CommandText = "
				SELECT ISNULL(dm.mirroring_state_desc,'UNKNOWN') + '|' + d.state_desc FROM sys.databases d
				LEFT JOIN sys.database_mirroring dm ON d.database_id = dm.database_id 
				WHERE d.name = '$Databasename'
				"
				$MirroringAndDBState = $command.ExecuteScalar()
				$MirroringState = $MirroringAndDBState.Split('|')[0]
				$DBState = $MirroringAndDBState.Split('|')[1]
				if ($MirroringState -ne 'SYNCHRONIZED') {
					Write-Host "Waiting until database mirroring is synchronized ..."
				}
				while ($MirroringState -ne 'SYNCHRONIZED' -and ($DBState -ne 'SUSPECT' -and $DBState -ne 'RECOVERY_PENDING')) {
					Start-Sleep -Seconds 1
					$MirroringAndDBState = $command.ExecuteScalar()
					$MirroringState = $MirroringAndDBState.Split('|')[0]
					$DBState = $MirroringAndDBState.Split('|')[1]
				}
				if ($DBState -eq 'ONLINE') {
					$command.CommandText = "USE [master]; ALTER DATABASE [$Databasename] SET WITNESS='$WitnessName'" 
					$rs = $command.ExecuteNonQuery()
				}
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
		return -1
	}
}

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
	Write-Host "Student task: Find out who dropped the table in database $Databasename!" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
