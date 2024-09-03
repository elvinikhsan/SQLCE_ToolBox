#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Delete SQLServer Cluster Resource.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 1.3 added additional messages about progress
# 1.4 Fix: Wrong name of quorum disk resource
# 1.5 Error handling adjusted
# 1.6 New implementation -> Failing Quorum Resource
# 3.0 Initial version for SQL 2016 release
# 3.1 Show warning to fix quorum settings
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-ClusterQuorumLoss()
{ 
 <# 
   .Synopsis 
    Executes the test case Cluster Quorum Loss
   .Description
    This function connects to all cluster nodes and stops the cluster service.
	Before the function offlines the quorum disk if exsists.
	Students need to restore the cluster service.
	TestCaseLevel:Cluster
	TestCaseLevel:Availability Group
   .Notes  
	This test case is easy to repair on a cluster
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Example 
    Execute-ClusterQuorumLoss   
   .Example 
    Execute-ClusterQuorumLoss -IgnoreScoping -Computername Computer1 -Instancename Inst1
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

	$command.CommandText = "SELECT SERVERPROPERTY('IsClustered')" 
	$IsClustered = $command.ExecuteScalar()
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

$IsCluster = Test-Path "HKLM:\Cluster"
#if ($IsClustered -ne 1) {
#    Write-Host "This instance is not clustered. This test case is only intended for a clustered SQL Server instance!" -ForegroundColor Yellow
if ($IsCluster -ne $true) {
    Write-Host "This server does not belong to a cluster. This test case is only intended for a cluster environment!" -ForegroundColor Yellow
    return
}

try {
	$quorum = Get-WmiObject -namespace 'root\mscluster' -Query "ASSOCIATORS OF {MSCluster_Cluster.Name='.'} WHERE AssocClass=MSCluster_ClusterToQuorumResource";
	if ($quorum) {
		Write-Host "Setting Quorum propperty RestartAction from $($quorum.RestartAction) to 0 ..."
		$quorum.RestartAction = 0
		$quorum.Put() | Out-Null
		Write-Host "Simulating failure on quorum $($quorum.Type) ($($quorum.Name)) ..."
		$quorum.FailResource() | Out-Null
		Write-Host "Please make sure to fix Restart action after test case execution!" -ForegroundColor Yellow
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
	try {
		$error.Clear()
		
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
		$ClusterNodes = Invoke-Command -Session $sess -ScriptBlock { Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | Select-Object -ExpandProperty name }
		$sess | Remove-PSSession

		foreach ($Node in $ClusterNodes) {
			Write-Host "Stopping Cluster service on $Node ...."
			try {
				if ($Credentials.PSObject.Properties.name -match $Node) {
					$(Get-WmiObject Win32_Service -ComputerName $Node -Credential $Credentials.($Node) | Where-Object {$_.Name -eq 'ClusSvc'}).StopService() | Out-Null
				}
				else {
					$(Get-WmiObject Win32_Service -ComputerName $Node | Where-Object {$_.Name -eq 'ClusSvc'}).StopService() | Out-Null
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

if ($error[0]) {
$returncode = -1
}

if ($returncode -eq 0) {
	Write-Host "Test case execution successful!" -ForegroundColor Green
	Write-Host "Student task: What happened to the cluster? Try to repair" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
