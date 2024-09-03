#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Stop HADR endpoint.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Fix: Check if endpoint was renamed <> Hadr_endpoint
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-StopHADREndpoint()
{ 
 <# 
   .Synopsis 
    Executes the test case Revoke Connect on HADR endpoint
   .Description
    This function connects to the target instance
	and stops the HADR endpoint.
	Availability Groups will stop synchronizing.
	TestCaseLevel:Availability Group
   .Notes  
	This test case only works with SQL Server Availability Groups
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Parameter AvailabilityGroup
	The name of the target Availability Group.
   .Example 
    Execute-StopHADREndpoint   
   .Example 
    Execute-StopHADREndpoint -IgnoreScoping -Computername Computer1 -Instancename Inst1 -AvailabilityGroup AG1
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
   [string]$AvailabilityGroup
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

#Find primary replica
try {

	$message = "Do you want to stop the endpoint on primary or secondary replica?"
	$title = "primary / secondary"
	$choicePrimary = New-Object System.Management.Automation.Host.ChoiceDescription "&Primary", "Answer Primary."
	$choiceSecondary = New-Object System.Management.Automation.Host.ChoiceDescription "&Secondary", "Answer Secondary."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($choicePrimary, $choiceSecondary)
	$result = $host.ui.PromptForChoice($title, $message, $options, 0)

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
	
	if ($result -eq 0) {	
		$command.CommandText = "SELECT primary_replica FROM sys.dm_hadr_availability_group_states dhags
		INNER JOIN sys.availability_groups ag ON dhags.group_id = ag.group_id
		WHERE ag.name = '$AvailabilityGroup'" 
		$PrimaryReplica = $command.ExecuteScalar()
		$Servername = $PrimaryReplica
		
		if ($PrimaryReplica.IndexOf("\") -ge 0) {
			$Computername = $PrimaryReplica.Split("\")[0]
			$Instancename = $PrimaryReplica.Split("\")[1]
		}
		else {
			$Computername = $PrimaryReplica
			$Instancename = "MSSQLSERVER"
		}
	}
	else {
		$command.CommandText = "SELECT replica_server_name FROM sys.dm_hadr_availability_group_states dhags
		INNER JOIN sys.availability_groups ag ON dhags.group_id = ag.group_id
		INNER JOIN sys.availability_replicas ar ON dhags.group_id = ar.group_id
		WHERE ag.name = '$AvailabilityGroup' AND primary_replica <> replica_server_name" 
		
		$ReplicaServers = @()
		$reader = $command.ExecuteReader()
		while($Reader.Read())
		{
			$ReplicaServer = $Reader["replica_server_name"].ToString()    
			$ReplicaServers += @($ReplicaServer)
		}  
		$reader.Close()

		if ($ReplicaServers.Length -eq 0) {
			Write-Host "No secondary replicas are available."
		}
		else {	
			$SelectedReplica = Select-TextItem $ReplicaServers
		}

		if ($SelectedReplica) {
			$Servername = $SelectedReplica
			$InstancePort = $ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$Servername)]
			if ($SelectedReplica.IndexOf("\") -ge 0) {
				$Computername = $SelectedReplica.Split("\")[0]
				$Instancename = $SelectedReplica.Split("\")[1]
			}
			else {
				$Computername = $SelectedReplica
				$Instancename = "MSSQLSERVER"
			}
		}
		else {
			Write-Host "No secondary replica selected. Exiting ..."
			return
		}
	}
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

#For local execution on cluster node
$Computername = Get-HostnameFromServername -Servername $Computername

if ($result -eq 0) {
	Write-Host "Selected replica is $Servername (PRIMARY) on node $Computername."
}
else {
	Write-Host "Selected replica is $Servername (SECONDARY) on node $Computername."
}

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

$returncode = Invoke-Command -Session $sess -ArgumentList $Instancename, $InstancePort, $Servername, $AvailabilityGroup, $Global:ModuleName, $Authentication, $SQL_Username, $SQL_Password, ($PSBoundParameters['Verbose'])  -ScriptBlock {
param($Instancename, $InstancePort, $Servername, $AvailabilityGroup, $ModuleName, $Authentication, $SQL_Username, $SQL_Password, $VerboseLogging)
$PSBoundParameters['Verbose'] = $VerboseLogging

$error.Clear()

$Scoping_check = [Environment]::GetEnvironmentVariable("$ModuleName", "MACHINE")
if ($Scoping_check -ne 'TRUE') {
    Write-Host "This server has no scoping flag. The execution will be aborted!" -ForegroundColor Red
    return
}

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
    Write-Host "This server has no scoping flag. The execution will be aborted!" -ForegroundColor Red
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


#$SQLRevokeText = ""
try {
	Write-Host "Stopping local endpoint"
	$command.CommandText = "
		SELECT top 1 name FROM sys.tcp_endpoints WHERE type = 4
	"
	$EndPointName = $command.ExecuteScalar()
	$command.CommandText = "
		ALTER ENDPOINT [$EndPointName] STATE=STOPPED
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

if ($error[0]) {
	return -1
}
else {
	return 0
}

}
$sess | Remove-PSSession

$error.clear()

if (!$returncode) {
	$returncode = 0
}

if ($returncode -eq 0) {
	Write-Host "Test case execution successful!" -ForegroundColor Green
	Write-Host "Student task: What happend to the HADR replica synchronization? Try to repair!" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}

