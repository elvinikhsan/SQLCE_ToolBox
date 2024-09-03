#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: NoRights on Quorum.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Error handling adjusted
# 3.0 Initial version for SQL 2016 release
# 3.1 Fix: Access Denied because of double-hop issue
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-NoRightsOnQuorum()
{ 
 <# 
   .Synopsis 
    Executes the test case No Rights on Quorum
   .Description
    This function connects to the cluster node owning the quorum
	and removes the ACL from Quorum (file share / disk witness).
	If Disk Witness does not have a drive letter, this test case will cancel.
	Students need to restore the computer account (CNO).
	TestCaseLevel:Cluster
	TestCaseLevel:Availability Group
	TestCaseComment:Experimental
   .Notes  
	This test case is easy to repair on a cluster
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Parameter Instancename
	The name of the target instance. Leave empty if it is the default instance
   .Example 
    Execute-DeleteClusterComputerAccount   
   .Example 
    Execute-DeleteClusterComputerAccount -IgnoreScoping -Computername Computer1 -Instancename Inst1
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
	$IsCluster = Test-Path "HKLM:\Cluster"
	#if ($IsClustered -ne 1) {
	#    Write-Host "This instance is not clustered. This test case is only intended for a clustered SQL Server instance!" -ForegroundColor Yellow
	if ($IsCluster -ne $true) {
		Write-Host "This server does not belong to a cluster. This test case is only intended for a cluster environment!" -ForegroundColor Yellow
		return
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
	Write-Host "Retrieving clustername ..."
	try {
		If ($Credentials.PSObject.Properties.name -match $Computername) {
			$Clustername = $(Get-WmiObject -ComputerName $Computername -Credential $Credentials.($Computername)  -Authentication PacketPrivacy -Impersonation Impersonate -namespace 'root\mscluster' MSCluster_Cluster).Name
		}
		else {
			$Clustername = $(Get-WmiObject -ComputerName $Computername -Authentication PacketPrivacy -Impersonation Impersonate -namespace 'root\mscluster' MSCluster_Cluster).Name
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

if ($returncode -eq 0){
	#For local execution on cluster node
	$ClusterOwnerNode = Get-HostnameFromServername -Servername $Clustername
	Write-Host "Cluster node that owns the quorum is $ClusterOwnerNode"

	$Toolsmachine = $env:computername
	Write-Host "Connecting to computer $ClusterOwnerNode ..."
	If ($Credentials.PSObject.Properties.name -match $ClusterOwnerNode) {
		$sess = New-PSSession -ComputerName $ClusterOwnerNode -Credential $Credentials.($ClusterOwnerNode)
	}
	else {
		$sess = New-PSSession -ComputerName $ClusterOwnerNode
	}
	#$sharepath = Invoke-Command -Computername $Clustername -ArgumentList $Toolsmachine, $Clustername -ScriptBlock {
	$sharepath = Invoke-Command -Session $sess -ArgumentList $Toolsmachine, $Clustername, ($PSBoundParameters['Verbose']) -ScriptBlock {
	param ($Toolsmachine, $Clustername, $VerboseLogging)
	$PSBoundParameters['Verbose'] = $VerboseLogging
		try {
			Import-Module FailoverClusters
			$QuorumResource = Get-ClusterQuorum | Select-Object -ExpandProperty QuorumResource
			If (!($QuorumResource)) {
				Write-Host 'Cluster does not have a quorum disk or file share. Test cases will be aborted ...' -ForegroundColor Yellow
			}
			else {
				If ($QuorumResource.ResourceType.Name -eq 'File Share Witness') {
					$sharePath = $QuorumResource | Get-ClusterParameter -Name 'SharePath' | Select-Object -ExpandProperty Value
					return $sharePath
				}
				else {
					write-host "Witness disk is currently not implemented." -ForegroundColor Yellow
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
			return -1
		}
	}
	$sess | Remove-PSSession
}

if ($sharepath -and $sharepath -ne -1 -and $returncode -eq 0) {
	Write-Host "File share witness is on $sharePath"
	try {
		
		$DomainName = (Get-WmiObject Win32_ComputerSystem).Domain
		$wmiDomain = Get-WmiObject Win32_NTDomain -Filter "DnsForestName = '$DomainName'"
		$domain = $wmiDomain.DomainName
		$CNO = "$domain\$Clustername" + "$"
		$Acl = Get-Acl $sharePath
		
		$inherit = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
		$propagation = [system.security.accesscontrol.PropagationFlags]"None"
		$accessrule = New-Object system.security.AccessControl.FileSystemAccessRule($CNO, "FullControl", $inherit, $propagation, "Deny")
		$Acl.SetAccessRule($AccessRule)
		Set-Acl $sharepath $Acl 
		#}
		#$sess | Remove-PSSession
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
	$returncode = -1
}

if ($returncode -eq 0) {
	Write-Host "Test case execution successful!" -ForegroundColor Green
	Write-Host "Student task: Wait roughly 30 seconds. What happend to the Quorum?" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
	if ($sharepath) {
		Write-Host "Test case execution failed! Check if you have the necessary Quoum access rights" -ForegroundColor Red
	}
}

}
