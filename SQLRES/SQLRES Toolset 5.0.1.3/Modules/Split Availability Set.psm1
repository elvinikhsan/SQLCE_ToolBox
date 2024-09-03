#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Offline Data Disk.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Execute-SplitAvailabilitySet()
{ 
 <# 
   .Synopsis 
    Executes the test case Split Availability Set
   .Description
    This function connects to the target machines
	and sets the data Disk offline.
	If the data disk os the operating system disk, the test case will cancel with a warning.
	Availability Groups will stop synchronizing.
	TestCaseLevel:A-z-u-r-e
	TestCaseComment:Manual
   .Notes  
	This is a manual test case
   .Parameter Computername
	The name of the target machine. Write "." for localhost
	In a cluster always use the virtual servername
   .Example 
    Execute-SplitAvailabilitySet   
   .Example 
    Execute-SplitAvailabilitySet -IgnoreScoping -Computername Computer1
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param(
   [Parameter(Mandatory=$false)]
   [string]$Computername
 ,
   [Switch]$IgnoreScoping
)
Set-StrictMode -Version 2.0

If ($IgnoreScoping.IsPresent -eq $FALSE)
{
	If ($global:ScopingCompleted -eq $TRUE) {
		$Computername = $global:Computername
	}
	else {
		Write-Host "Warning! Test case execution without scoping only possible by using IgnoreScoping switch." -ForegroundColor Yellow
		return
	}
}

if ($Computername -eq ".") {
	$Computername = "localhost"
}

Write-Host "Checking Azure compatibility ..."
$IsAzure = Confirm-Azure -Computername $Computername

If ($IsAzure -ne -$true) {
	Write-Host "Warning! The target machine does not seem to be an Azure machine" -ForegroundColor Yellow
	#return
}

Write-Host "We will show the commands step-by-step. Please press any key after each step!"
Write-Host "-----------------------------------------------------------------------------"
Write-Host "1. Step: Connect to Azure Portal"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host "2. Step: Goto Network Settings"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host "3. Step: Open Endpoint"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host "4. Step: Goto Availability Sets"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host "5. Step: Select the Availability Set"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
Write-Host "6. Step: Delete the Availability Set and confirm"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")


$error.clear()

if (!$returncode) {
	$returncode = 0
}

if ($returncode -eq 0) {
	Write-Host "Test case execution completed!" -ForegroundColor Green
	Write-Host "Student task: What happens to the Availability Group in Azure?" -ForegroundColor Cyan
}
else {
	Write-Host "Test case execution failed!" -ForegroundColor Red
}

}
