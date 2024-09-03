#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: TempDB NoRights.psm1 
# Author: oliverha 
# Date: 05/15/2019 11:46:32
# Version:  5.1
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 1.3 Included support for availability groups
# 1.4 Changed deny rights to folder level
# 1.5 Deleted the primary tempdb data file in addition (SQL Server will accept the old file)
# 1.6 Only Deny Create Files on Folder (if TempDB coexists with other system databases)
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# 5.1 Added support for TempDB stored on root folder of mount point
# ----------------------------------------------------------------------------- 
function Execute-TempDBNoRights()
{ 
 <# 
   .Synopsis 
    Executes the test case TempDB no rights
   .Description
    This function connects to the target instance
	and reads the location of the primary TempDb data file.
	It stops SQL Server afterwards and configures the service account
	with deny create and delete on this file.
	When the students try to start the instance SQL Server will fail to start.
	TestCaseLevel:Server
   .Notes  
	This test case is really tricky 
	because the deny rights are not easy to find for the students.
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Example 
    Execute-TempDBNoRights   
   .Example 
    Execute-TempDBNoRights -IgnoreScoping -Computername Computer1 -Instancename Inst1
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

$Scoping_check = [Environment]::GetEnvironmentVariable("$ModuleName", "MACHINE")
if ($Scoping_check -ne 'TRUE') {
    Write-Host "This server has no scoping flag. The execution will be aborted!" -ForegroundColor Red
    return
}
else {
    Write-Host "Scoping check succeeded..." -ForegroundColor DarkGreen
}

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
	$command.CommandTimeout = '300'
	$command.Connection = $Connection

	$command.CommandText = "SELECT top 1 physical_name FROM sys.master_files WHERE database_id=DB_ID('tempdb') and type_desc = 'ROWS'" 
	$filename = $command.ExecuteScalar()
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

	$file = New-Object -TypeName System.IO.FileInfo $filename
	$folder = $file.Directory

	$ServiceAccount = $(get-wmiobject win32_service -filter "DisplayName = 'SQL Server ($Instancename)'").Startname

	Write-Host "Stopping ..."
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

	#$inherit = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
	#$propagation = [system.security.accesscontrol.PropagationFlags]"None"
	#
	#$Acl = Get-Acl $filename
	#$Ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule("$ServiceAccount", "Delete,CreateFiles", "Deny")
	#$Acl.SetAccessRule($Ar2)
	#Set-Acl $filename $Acl
	Write-Host "Setting Deny:CreatFiles on the TempDB folder $folder for $ServiceAccount ..."
	if ($folder.Target -like "Volume{*}\") {   #Root of Mount Point
		$aclfolder = "\\?\" + $folder.Target
	}
	else {
		$aclfolder = $folder.FullName
	}
	#$colRights = [System.Security.AccessControl.FileSystemRights]"FullControl" 
	$colRights = [System.Security.AccessControl.FileSystemRights]"CreateFiles" 
	#$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ObjectInherit 
	$InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::None 
	$PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None 
	$objType =[System.Security.AccessControl.AccessControlType]::Deny 
	
	$objUser = New-Object System.Security.Principal.NTAccount("$ServiceAccount") 
	#$Acl = Get-Acl $folder
	$Acl = [io.directory]::GetAccessControl($aclfolder)
	$Ar2 = New-Object System.Security.AccessControl.FileSystemAccessRule($objUser, $colRights, $InheritanceFlag, $PropagationFlag, $objType) 
	$Acl.SetAccessRule($Ar2)
	#Set-Acl $folder $Acl
	[io.directory]::SetAccessControl($aclfolder,$Acl)

	Write-Host "Deleting file $file (SQL Server shall not reuse the old file) ..."
	Remove-Item $file -Force | Out-Null
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
	Write-Host "Student task: Why does the instance not start on the current computer ($Computername)?" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
