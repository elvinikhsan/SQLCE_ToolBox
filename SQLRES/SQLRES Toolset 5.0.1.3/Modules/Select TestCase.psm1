#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Select TestCase.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 1.3 extended test case selection to use alphabetical prefix and comment
# 1.4 Added Windows Server 2012 R2 compatibility
# 1.5 Updated menu order and integrate option to hide test cases not relevant for the current environment
# 1.6 Fix: Suppressing error messages when leaving a PSSession
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Launch-TestCase()
{ 
 <# 
   .Synopsis 
    Creates an easy way to navigate to the single test cases
   .Description
    Creates an easy way to navigate to the single test cases
   .Notes  

   .Example 
    Select-TestCase   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param(
   [Switch]$Loop
)
Set-StrictMode -Version 2.0

#$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

If ($global:ScopingCompleted -eq $TRUE) {
	$Computername = $global:Computername
	$Instancename = $global:Instancename
	$Databasename = $global:Databasename
	$AvailabilityGroup = $global:AvailabilityGroup
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

if ($Computername -eq ".") {
	$Computername = "localhost"
}

if ($Instancename -ne "MSSQLSERVER") {
	$Servername = $Computername + "\" + $Instancename
}
else {
	$Servername = $Computername
}

$returncode = 0
$SelectedTestCaseLevel = "-"

Do {

if ($Loop.IsPresent -and $Global:FirstStart -eq $false) {
	Clear-Host
	Show-Scoping
}
$Global:FirstStart = $false
if ($Loop.IsPresent) {
	$Global:IsInLoop = $true
}

Write-Host "Select level for test cases:"
$TestCaseLevels = @()
if ($global:IsAzure -eq $true) {
	$TestCaseLevel = New-Object System.Object
	$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'Z'
	$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Azure'
	$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
	$TestCaseLevels += $TestCaseLevel
}
$TestCaseLevel = New-Object System.Object
$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'S'
$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Server'
$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
$TestCaseLevels += $TestCaseLevel
if ($global:IsClustered -eq $true -or ($global:AvailabilityGroup -and $global:ClusterType -eq "WSFC" )) {
	$TestCaseLevel = New-Object System.Object
	$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'C'
	$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Cluster'
	$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
	$TestCaseLevels += $TestCaseLevel
}
$TestCaseLevel = New-Object System.Object
$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'I'
$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Instance'
$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
$TestCaseLevels += $TestCaseLevel
if ($global:AvailabilityGroup) {
	$TestCaseLevel = New-Object System.Object
	$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'A'
	$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Availability Group'
	$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
	$TestCaseLevels += $TestCaseLevel
}
$TestCaseLevel = New-Object System.Object
$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value 'D'
$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value 'Database'
$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
$TestCaseLevels += $TestCaseLevel
$TestCaseLevel = New-Object System.Object
$TestCaseLevel | Add-Member -type NoteProperty -name Prefix -Value '@'
$TestCaseLevel | Add-Member -type NoteProperty -name Label -Value '@Admin'
$TestCaseLevel | Add-Member -type NoteProperty -name Comment -Value $null
$TestCaseLevels += $TestCaseLevel

#$TestCaseLevels 

$SelectedTestCaseLevel = Select-TextItem $TestCaseLevels "Label" "Prefix" -NoSorting

if (!$SelectedTestCaseLevel) {
	$Global:IsInLoop = $false
	return
}

$CommandInfos = @()

$CommandList = Get-Command -Module $Global:ModuleName
foreach ($Command in $CommandList) {
	if ($($(Get-Help $Command.Name).Description) -like "*TestCaseLevel:$SelectedTestCaseLevel*") {
		$CommentStr = $null
		if ($($(Get-Help $Command.Name).Description) -like "*TestCaseComment:*") {
			$Comments = $($(Get-Help $Command.Name).Description).Text
			$Comments -Split "[\r\n]" | ForEach-Object {
				if ($_ -like "TestCaseComment:*") {
					$CommentStr = $_.Replace("TestCaseComment:","")
				}
			}
		}
		$InstanceDepStr = $null
		if ($($(Get-Help $Command.Name).Description) -like "*InstancenameDependency:*") {
			$Comments = $($(Get-Help $Command.Name).Description).Text
			$Comments -Split "[\r\n]" | ForEach-Object {
				if ($_ -like "InstancenameDependency:*") {
					$InstanceDepStr = $_.Replace("InstancenameDependency:","")
				}
			}
		}
		
		if (!$InstanceDepStr -or ($Instancename -eq 'MSSQLSERVER' -and $InstanceDepStr -eq 'Default') `
			-or ($Instancename -ne 'MSSQLSERVER' -and $InstanceDepStr -eq 'Named' ) `
			-or ($global:IsClustered -eq $true -and $InstanceDepStr -eq 'Clustered')) {
			$CommandInfo = New-Object PSObject
			$CommandInfo | Add-Member -type NoteProperty -name Name -Value $Command.Name
			$CommandInfo | Add-Member -type NoteProperty -name Comment -Value $CommentStr
			$CommandInfos += $CommandInfo
		}
		
		#$CommandInfos += @({Name=$($Command.Name); Comment = $($Command.Comment)})
	}
}

$TestInput = $(Select-TextItem $CommandInfos "Name")
if ($TestInput) {
	if ($TestInput.PSObject.Properties.Name -match 'Name') {
		$SelectedCommand = $TestInput.Name
	}
	else {
		$SelectedCommand = ""
	}
}
else {
	$SelectedCommand = ""
}

if ($SelectedCommand) {
	#Invoke-Expression "$SelectedCommand"
	
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
						try {
							(Get-PSSession -ComputerName $Node -Credential $Credentials.($Node) -ErrorAction SilentlyContinue) | Remove-PSSession -ErrorAction SilentlyContinue
						}
						catch {
						}
					}
					else {
						try {
							(Get-PSSession -ComputerName $Node -ErrorAction SilentlyContinue) | Remove-PSSession -ErrorAction SilentlyContinue
						}
						catch {
						}
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
	}

}
else {
	#return
}

if ($error[0]) {
	$returncode = -1
}

if ($SelectedCommand -and $Loop.IsPresent) {
	Write-Host "Press any key to continue with the next test case ..."
	$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

} while ($SelectedTestCaseLevel -and $Loop.IsPresent)

$Global:IsInLoop = $false

}

function Launch-TestCaseMenu()
{
	Launch-TestCase -Loop
}

Set-Alias ltc Launch-Testcase -Scope Global
Set-Alias ltm Launch-TestcaseMenu -Scope Global
