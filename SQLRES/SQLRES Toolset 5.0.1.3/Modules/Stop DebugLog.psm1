#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Stop DebugLog.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Stop-DebugLog()
{ 
 <# 
   .Synopsis 
    Disables DebugLog
   .Description
    Enables DebugLog
	TestCaseLevel:@Admin	
   .Notes  
   .Example 
    Stop-DebugLog  
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$DebugLogPath = $(resolve-path .).ToString() + "\" + $global:ModuleName + "_Debug.log"
try {
	Stop-Transcript | Out-Null
	Write-Host "Stopping DebugLog file $DebugLogPath ..."
	$global:ToolsetDebug = $false
}
catch {
	if (!$global:ToolsetDebug) {
		Write-Host "DebugLog was not started." -ForegroundColor Yellow
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
}

}
