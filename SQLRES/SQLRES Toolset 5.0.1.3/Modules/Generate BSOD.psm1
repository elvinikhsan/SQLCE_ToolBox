#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Generate BSOD.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 3.1 Show warning to fix quorum settings
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-GenerateBSOD()
{ 
 <# 
   .Synopsis 
    Executes the test case Generate BSOD
   .Description
    This function connects to the traget machine and generates a BSOD condition
	TestCaseLevel:Server
	TestCaseLevel:Cluster
	TestCaseLevel:Availability Groups
   .Notes  
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Example 
    Execute-GenerateBSOD   
   .Example 
    Execute-GenerateBSOD -IgnoreScoping -Computername Computer1 -Instancename Inst1
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
 ,
   [Switch]$WitnessLost_SecondaryLost_PrimaryExposed
 ,
   [Switch]$WitnessLost_PrimaryLost_SecondaryExposed
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

Write-Host "Attention!!!!!" -ForegroundColor Yellow
$message = "Are you sure that you want to crash the target server(s)? Test case will manipulate boot options. Please make sure that you have access to the server afterwards!"
$title = "Crash server"
$choiceOK = New-Object System.Management.Automation.Host.ChoiceDescription "&OK", "Answer OK."
$choiceSkip = New-Object System.Management.Automation.Host.ChoiceDescription "&Skip boot manipulation", "Answer skip boot manipulation."
$choiceCancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel", "Cancel."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceOK, $choiceSkip, $choiceCancel)

$CrashOption = $host.ui.PromptForChoice($title, $message, $options, 2)
If ($CrashOption -eq 2) {
	return
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
}

#endregion CheckAGReplica_Primary

#For local execution on cluster node
$Computername = Get-HostnameFromServername -Servername $Computername

#$ErrorActionPreference = $Last_ErrorActionPreference 

$BSODComputers = @()

if ($WitnessLost_SecondaryLost_PrimaryExposed.IsPresent -or $WitnessLost_PrimaryLost_SecondaryExposed.IsPresent) {

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

try {
	$quorum = Get-WmiObject -namespace 'root\mscluster' -Query "ASSOCIATORS OF {MSCluster_Cluster.Name='.'} WHERE AssocClass=MSCluster_ClusterToQuorumResource";
	if ($quorum) {
		Write-Host "Setting Quorum propperty RestartAction from $($quorum.RestartAction) to 0 ..."
		$quorum.RestartAction = 0
		$quorum.Put() | Out-Null
		Write-Host "Simulating failure on quorum $($quorum.Type) ($($quorum.Name)) ..."
		$quorum.FailResource() | Out-Null
		$nodes = Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | Select-Object -ExpandProperty name
	    Write-Host "Removing possible owners ..."
		foreach ($node in $nodes) {
			$quorum.RemovePossibleOwner($node) | Out-Null
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

return -1

}
$sess | Remove-PSSession

if ($returncode -ne -1) {
	return
}

if ($WitnessLost_SecondaryLost_PrimaryExposed.IsPresent) {

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
	
	Write-Host "Reading replica information ..."
	$command.CommandText = "SELECT arcs.node_name FROM sys.availability_groups ag
	INNER JOIN sys.dm_hadr_availability_group_states ags ON ag.group_id = ags.group_id
	INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
	LEFT JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
	LEFT JOIN sys.dm_hadr_availability_replica_cluster_nodes arcs ON ar.replica_server_name = arcs.replica_server_name
	WHERE UPPER(ag.name) = UPPER('$AvailabilityGroup') AND CASE WHEN ar.replica_server_name = ags.primary_replica THEN 'PRIMARY' ELSE 'SECONDARY' END = 'SECONDARY' 
	ORDER BY 1" 

	$Reader = $command.ExecuteReader()
	
	while($Reader.Read())
	{		
		$BSODComputers += $Reader["node_name"]
	}
	$Reader.Close()
	#$BSODComputers
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

}

if ($WitnessLost_PrimaryLost_SecondaryExposed.IsPresent) {
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
	
	Write-Host "Reading replica information ..."
	$command.CommandText = "SELECT arcs.node_name FROM sys.availability_groups ag
	INNER JOIN sys.dm_hadr_availability_group_states ags ON ag.group_id = ags.group_id
	INNER JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
	LEFT JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id
	LEFT JOIN sys.dm_hadr_availability_replica_cluster_nodes arcs ON ar.replica_server_name = arcs.replica_server_name
	WHERE UPPER(ag.name) = UPPER('$AvailabilityGroup') AND CASE WHEN ar.replica_server_name = ags.primary_replica THEN 'PRIMARY' ELSE 'SECONDARY' END = 'PRIMARY'
	ORDER BY 1" 

	$Reader = $command.ExecuteReader()
	
	while($Reader.Read())
	{		
		$BSODComputers += $Reader["node_name"]
	}
	$Reader.Close()
	#$BSODComputers
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

}
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
$IsRemoteCluster = Invoke-Command -Session $sess -ScriptBlock { Test-Path "HKLM:\Cluster" }
$sess | Remove-PSSession

If ($WitnessLost_SecondaryLost_PrimaryExposed.IsPresent -eq $false -and $WitnessLost_PrimaryLost_SecondaryExposed.IsPresent -eq $false) {
	If ($IsRemoteCluster) {
		$message = "The target machine is a cluster node, Do you want to run the test case on a different cluster node?"
		$title = "Cluster / Availability Group"
		$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
		$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
		$result = $host.ui.PromptForChoice($title, $message, $options, 1)
		$Computernames = @()
		if ($result -eq 0) {
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
			$ClusterNodes = Invoke-Command -Session $sess -ScriptBlock { Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | Select-Object -ExpandProperty Name }
			$sess | Remove-PSSession
			#$ClusterNodes
			$ClusterNode = Select-TextItem $ClusterNodes
			$Computernames += $ClusterNode
			
			#$Computernames
			
			$message = "Do you want to run the test case in parallel on another node?"
			$title = "Cluster / Availability Group"
			$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
			$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
			$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
			
			$result = $host.ui.PromptForChoice($title, $message, $options, 1)
			while ($result -eq 0) {
				If ($Credentials.PSObject.Properties.name -match $Computername) {
					$sess = New-PSSession -ComputerName $Computername -Credential $Credentials.($Computername)
				}
				else {
					$sess = New-PSSession -ComputerName $Computername
				}				
				$ClusterNodes = Invoke-Command -Session $sess -ArgumentList (,$Computernames) -ScriptBlock { param($Computernames); Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | Where-Object { $Computernames -notcontains $_.Name } | Select-Object -ExpandProperty Name }
				$sess | Remove-PSSession
				
				#$ClusterNodes
				$ClusterNode = Select-TextItem $ClusterNodes
				$Computernames += $ClusterNode
				$result = $host.ui.PromptForChoice($title, $message, $options, 1)
				
			}
		}
	}

	if ($Computernames) {
		$BSODComputers = $Computernames
		#Write-Host $Computername
	}
	else {
		$BSODComputers += $Computername
	}
}

$sessions = @()
foreach ($BSODComputer in $BSODComputers) {
	if ($Credentials.PSObject.Properties.name -match $BSODComputer) {
		$sess = New-PSSession -ComputerName $BSODComputer -Credential $Credentials.($BSODComputer) -SessionOption (New-PSSessionOption -OperationTimeout 5000)
	}
	else {
		$sess = New-PSSession -ComputerName $BSODComputer -SessionOption (New-PSSessionOption -OperationTimeout 5000)
	}
	$sessions += $sess
}

$returncode = Invoke-Command -Session $sessions -ErrorVariable rmerror -ErrorAction SilentlyContinue -ArgumentList $Instancename, $InstancePort, $Servername, $Global:ModuleName, $CrashOption -ScriptBlock {
param($Instancename, $InstancePort, $Servername, $ModuleName, $CrashOption)

$Scoping_check = [Environment]::GetEnvironmentVariable("$ModuleName", "MACHINE")
if ($Scoping_check -ne 'TRUE') {
    Write-Host "This server has no scoping flag. The execution will be aborted!" -ForegroundColor Red
    return
}
else {
    Write-Host "Scoping check succeeded..." -ForegroundColor DarkGreen
}

$MachineName = $(Get-WmiObject -Class Win32_ComputerSystem).Name

if ($CrashOption -eq 0) {
	Write-Host "Disabling auto-startup on $MachineName ..."

	$old_displaybootmenu = (invoke-command {bcdedit /enum bootmgr } | Where-Object { $_ -like "*displaybootmenu*" } | Out-String).Replace("displaybootmenu","").Trim()
	$old_timeout = (invoke-command {bcdedit /enum bootmgr } | Where-Object { $_ -like "*timeout*" } | Out-String).Replace("timeout","").Trim()

	Write-Host "Old boot settings on $MachineName ..."
	Write-Host "{bootmgr} displaybootmenu = $old_displaybootmenu"
	Write-Host "{bootmgr} timeout = $old_timeout"

	Invoke-Command -ScriptBlock {Start-Process C:\Windows\System32\bcdedit.exe -Verb RunAS -ArgumentList "/set {bootmgr} displaybootmenu yes"}
	Invoke-Command -ScriptBlock {Start-Process C:\Windows\System32\bcdedit.exe -Verb RunAS -ArgumentList "/set {bootmgr} timeout 999"}

	Write-Host "Disabling autostart SQL Server Service on $MachineName ..."
	$service = Get-WmiObject win32_service -filter "name = 'MSSQL`$$Instancename' or name = '$Instancename' and StartMode = 'Automatic'"
	if ($service) {
		$service.change($null,$null,$null,$null,'Disabled',$null,$null,$null) | Out-Null
	}

	Write-Host "Waiting for 90 seconds ..."

	Start-Sleep -Seconds 90
}

$error.Clear()

Write-Host "Crashing server $MachineName ..."

Start-Sleep -Seconds 2

Write-Host "Crashing server $MachineName ..... "

Start-Sleep -Seconds 2

#Start-Job -ScriptBlock {Get-Process  | where { $_.ProcessName -eq 'wininit' -or $_.ProcessName -eq 'wsmprovhost'} | Stop-Process -Force} | Out-null
#Start-Job -ScriptBlock {Get-Process 'wininit' | Stop-Process -Force} | Out-null
Invoke-Expression "wmic process where processid!=0 call terminate" -ErrorAction SilentlyContinue | Out-Null

Start-Sleep -Milliseconds 5000

$error.clear()

if ($error[0]) {
	return -1
	#$ErrorMessage = $error[0].ToString()
}
else {
	return 0
}

}
$sessions | Remove-PSSession -ErrorAction SilentlyContinue

if ($rmerror[0]) {
	If ($rmerror[0].Exception.Errorcode -eq -2144108250) {
		$returncode = 0
	}
	else {
		$returncode = -1
		$ErrorMessage = $rmerror[0].ToString()
	}
}

$error.clear()

if (!$returncode) {
	$returncode = 0
}

if ($CrashOption -eq 0) {
	Write-Host "Important: Please fix the boot settings on the target machines!" -ForegroundColor Yellow
	Write-Host "bcdedit /deletevalue {bootmgr} displaybootmenu" -ForegroundColor Yellow
	Write-Host "bcdedit /set {bootmgr} timeout 30" -ForegroundColor Yellow
}

if ($returncode -eq 0) {
	Write-Host "Test case execution successful!" -ForegroundColor Green
}
else {
	Write-Host $ErrorMessage -ForegroundColor Red
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}

