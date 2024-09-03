#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Repair Previous TestCase.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Toolset-RepairPreviousTestCase()
{ 
 <# 
   .Synopsis 
    Shows a list of Repair function.
	You can pick one of those to repair a test case that was previously executed.
   .Description
    Repair previous test case.
	TestCaseLevel:@Admin	
   .Notes  
   .Example 
    Toolset-RepairPreviousTestCase
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
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

$CommandInfos = @()

$CommandList = Get-Command -Module $Global:ModuleName
foreach ($Command in $CommandList) {
	if ($($(Get-Help $Command.Name).Description).Text -like "*TestCaseLevel:Repair*") {
		$CommandInfo = New-Object PSObject
		$CommandInfo | Add-Member -type NoteProperty -name Name -Value $Command.Name
		$CommandInfo | Add-Member -type NoteProperty -name Comment -Value $CommentStr
		$CommandInfos += $CommandInfo
	}
}

$SelectedCommand = $(Select-TextItem $CommandInfos "Name").Name

if ($SelectedCommand) {
	$WasCancelled = $true
	try {		
		# Register-PsEvent ([System.Management.Automation.PsEngineEvent]::Exiting) 
    	# Do some processing and monitor for Ctrl-C 
		if ($global:ToolsetDebug) {
			Invoke-Expression "$SelectedCommand -Verbose"
		}
		else {
			Invoke-Expression "$SelectedCommand"
		}
		$WasCancelled = $false
	}
	catch {
		$WasCancelled = $false
	} finally {
		if ($WasCancelled) {
			try {
				#CleanUp PSS-Session
				foreach ($Node in $ClusterNodes) {
					Write-Host "Cleaning up PSS Session for node $Node ..."
					if ($Credentials.PSObject.Properties.name -match $Node) {
						(Get-PSSession -ComputerName $Node -Credential $Credentials.($Node)) | Remove-PSSession -ErrorAction SilentlyContinue
					}
					else {
						(Get-PSSession -ComputerName $Node) | Remove-PSSession -ErrorAction SilentlyContinue
					}
				}
			}
			catch {
				if ($PSBoundParameters['Verbose']) {
					$ErrorString = $_ | format-list -force | Out-String
					Write-Host $ErrorString -ForegroundColor Red
				}
			}
			if ($Loop.IsPresent) {
				$Error.Clear()
				#$Host.UI.RawUI.FlushInputBuffer()
				Write-Host "Toolset menu was left. Start menu again using Launch-TestcaseMenu (ltm)"
				$Global:IsInLoop = $false
				#Invoke-Expression "$($MyInvocation.MyCommand) -Loop" | Out-Null
			}
		}
   	# No matter what the user did, reset the console to process Ctrl-C inputs 'normally'
    #[console]::TreatControlCAsInput = $false
	}

}
else {
	#return
}

if ($SelectedCommand -and $Loop.IsPresent) {
	Write-Host "Press any key to continue with the next test case ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

$Global:IsInLoop = $false

}
