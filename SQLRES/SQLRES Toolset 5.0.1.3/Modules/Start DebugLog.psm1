#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Start DebugLog.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Start-DebugLog()
{ 
 <# 
   .Synopsis 
    Enables DebugLog
   .Description
    Enables DebugLog
	TestCaseLevel:@Admin	
   .Notes  
   .Example 
    Start-DebugLog   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$DebugLogPath = $(resolve-path .).ToString() + "\" + $global:ModuleName + "_Debug.log"

try {
	If (Test-Path $DebugLogPath) {
		$message = "The file $DebugLogPath already exists. Do you want to append to the existing log file?"
		$title = "append / replace"
		$choiceAppend = New-Object System.Management.Automation.Host.ChoiceDescription "&Append", "Answer Append."
		$choiceReplace = New-Object System.Management.Automation.Host.ChoiceDescription "&Replace", "Answer Replace."
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceAppend, $choiceReplace)
		$result = $host.ui.PromptForChoice($title, $message, $options, 0)
		if ($result -eq 1) {
			Remove-Item $DebugLogPath | Out-Null
		}
	}

	Write-Host "Starting DebugLog file $DebugLogPath ..."
	if ($PSVersionTable.PSVersion.Major -ge 5) {
		Start-Transcript -Path $DebugLogPath -Debug -Append -Force -Confirm:$false -IncludeInvocationHeader | Out-Null
	}
	else {
		Start-Transcript -Path $DebugLogPath -Debug -Append -Force -Confirm:$false | Out-Null
	}
	$global:ToolsetDebug = $true
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

}
