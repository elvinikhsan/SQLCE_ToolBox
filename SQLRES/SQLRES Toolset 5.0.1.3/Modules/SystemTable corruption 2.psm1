#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: SystemTable corruption 2.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Correction: Changed from FileID 1 to actual FileID
# 1.2 included test level logic
# 1.3 included sample code disclaimer
# 1.4 Fix for database names with special characters
# 1.5 Included support for availability groups
# 1.6 Included support for availability groups on secondary replica
# 1.7 Included support for mirrored databases
# 1.8 Error handling adjusted
# 1.9 Fix: Changed Servername to UPPERcase for Availability Groups on case sensitive instances
# 3.0 Initial version for SQL 2016 release
# 3.1 Fix: Start and Stop logic breakes on Mirroring
# 4.0 Initial version for SQL 2017 release
# 4.1 Fix: CEIP restart
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-SystemTableCorruption2
{ 
 <# 
   .Synopsis 
    Executes the test case System Table Corruption 2
   .Description
    This function connects to the target instance
	and creates corruption on a data page of system table
	sys.sysallocunits of the target database.
	Students shall set the target database ONLINE.
	During this action students will face the corruption.
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
    Execute-SystemTableCorruption2   
   .Example 
    Execute-SystemTableCorruption2 -IgnoreScoping -Computername Computer1 -Instancename Inst1
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

#region CheckAGReplica
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
		write-host "Database $Databasename is a read-only $DatabaseReplicaRole replica."
		#return -1
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
	$command.CommandText = "
	USE [$Databasename];
	DECLARE @TAB table (
	PageFID INT, 
	PagePID INT, 
	IAMFID INT, 
	IAMPID INT, 
	ObjectID BIGINT,
	IndexID INT, 
	PartionNumber INT, 
	PartitionID BIGINT, 
	iam_chain_type NVARCHAR(20), 
	PageType INT, 
	IndexLevel INT, 
	NextPageFID INT, 
	NextPagePID INT, 
	PrevPageFID INT, 
	PrevPagePID INT
	)

	INSERT INTO @TAB
	EXEC ('DBCC IND (''$Databasename'', ''sys.sysallocunits'', 1)')

	SELECT TOP (1) NextPagePID, NextPageFID FROM @TAB WHERE PageType = 1 AND ISNULL(NextPagePID,0) > 0 order by PagePID 
	" 
	$Reader = $command.ExecuteReader()
	
	while($Reader.Read())
	{		
		$PagePID = $Reader["NextPagePID"]
		$PageFID = $Reader["NextPageFID"]
	}
	$reader.Close()

	$command.CommandText = "SELECT top 1 physical_name FROM sys.master_files WHERE database_id=DB_ID('$Databasename') and file_id = $PageFID" 
	$filename = $command.ExecuteScalar()
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

	if (!$AvailabilityGroupName -and !$MirroringRole) { 	
		$command.CommandText = "ALTER DATABASE [$Databasename] SET OFFLINE WITH ROLLBACK IMMEDIATE" 
		$rs = $command.ExecuteNonQuery()
	}
	else {
		Write-Host "Stopping ..."
		if ($AvailabilityGroupName) {
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
		}
		
		if ($WitnessName) {
			$command.CommandText = "USE [master]; ALTER DATABASE [$Databasename] SET WITNESS OFF" 
			$rs = $command.ExecuteNonQuery()
		}
		
		If ($IsClustered -eq 1) {
			$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
			$timeout = 60
			$service.TakeOffline($timeout) | Out-null
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

if ($Error.Count -gt 0) {
    Write-Host "There was a problem to OFFLINE the database." -ForegroundColor Red
    return -1
}

try {
	$SystemTableAddress = ($PagePID*8192) + 200

	Write-Host "SystemTable: sys.sysallocunits"
	$fs = New-Object System.IO.FileStream ($filename), Open
	$bw = New-Object System.IO.BinaryWriter($fs)

	#$sz = $fs.Length
	$bValue = [byte]255

	$i = 0

	while ($i -lt 100) {
		$bw.BaseStream.Seek($SystemTableAddress+$i, [System.IO.SeekOrigin]::Begin) | Out-Null
		$bw.Write($bValue)
		$i++
	}

	$bw.Flush()

	$bw.Close()
	$fs.Close()
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
	if (!$AvailabilityGroupName -and !$MirroringRole) {
		#$command.CommandText = "ALTER DATABASE [$Databasename] SET ONLINE" 
		#$rs = $command.ExecuteNonQuery()
	}
	else {
		Write-Host "Starting ..."
		If ($IsClustered -eq 1) {
			$timeout = 60
			$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $resourcename}
			$service.BringOnline($timeout) | Out-null
			$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $agentresourcename}
			Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
			if ($ceipresourcename) {
				$service = Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource | Where-Object {$_.name -eq $ceipresourcename}
				Invoke-Expression "$service.BringOnline($timeout) | Out-null" -ErrorAction "SilentlyContinue"
			}
		}
		else {
			$(Get-Service "SQL Server ($Instancename)").Start() | Out-null
			do { Start-Sleep -Milliseconds 200 }
			until ((get-service "SQL Server ($Instancename)").status -eq 'Running')
			Start-Sleep -Milliseconds 200
			Get-Service "SQL Server Agent ($Instancename)" | Start-Service -ErrorAction "SilentlyContinue"
			if ($ProductMinorVersion -ge 13) {
				Get-Service "SQL Server CEIP service ($Instancename)" -ErrorAction "SilentlyContinue"  | Start-Service -ErrorAction "SilentlyContinue"
			}
		}

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

		if ($AvailabilityGroupName) {
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
	Write-Host "Student task: Set database $Databasename ONLINE'!" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
