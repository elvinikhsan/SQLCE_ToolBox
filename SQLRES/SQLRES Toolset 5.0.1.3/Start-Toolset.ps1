#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Start-Toolset.ps1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.1
# Keywords: 
# comments: 
# 1.1 included test level logic
# 1.2 included sample code disclaimer
# 5.0 Initial version for SQL 2019 release
# 5.1 Enforcing StrictMode 2.0
# ----------------------------------------------------------------------------- 
[CmdletBinding()]
param(
   [Parameter(Mandatory=$true)]
   [string]$ModuleName
)
Set-StrictMode -Version 2.0
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Set-Location $dir

$Global:ModuleName = $ModuleName
Import-Module .\$ModuleName.psd1 -Force -DisableNameChecking

$ToolsMachine = Get-Content env:computername
$EULAAccepted = 0
$EULAAcceptedDate = $null

#$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, $ToolsMachine)
$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, 0)
$regKey = $reg.OpenSubKey("SOFTWARE", $FALSE)
$regSubKeys = $regKey.GetSubKeyNames()
if ($regSubKeys -contains 'MicrosoftServices') {
	$regKey = $reg.OpenSubKey("SOFTWARE\\MicrosoftServices", $FALSE)
	$regSubKeys = $regKey.GetSubKeyNames()
	if ($regSubKeys -contains $Global:ModuleName) {
		$regKey = $reg.OpenSubKey("SOFTWARE\\MicrosoftServices\\$($Global:ModuleName)", $TRUE)
		$EULAAccepted = $regkey.GetValue("EULA-Accepted")
		$EULAAcceptedDate = $regkey.GetValue("EULA-AcceptedDate")
	}
}

If (!($EULAAccepted)) {
	$EULAAccepted = 0
}

If ($EULAAcceptedDate -eq $null -or $EULAAcceptedDate -eq '') {
	$dtEULAAcceptedDate = Get-Date(0)
	}
else {
	$culture = New-Object System.Globalization.CultureInfo("en-us")
	$dtEULAAcceptedDate = [DateTime]::Parse($EULAAcceptedDate, $culture)
}

If ($EULAAccepted -eq 0 -or $dtEULAAcceptedDate -lt ($(Get-Date).AddDays(-30))) { 
	$AcceptedEULA = Show-EULA
	If ($AcceptedEULA -ne "OK") {
		Write-Host "EULA not accepted. Exiting ..." -ForegroundColor Yellow
		return
	}
	else {
		Write-Host "EULA accepted ..."
		#$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, $ToolsMachine)
		$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::CurrentUser, 0)
		$regKey = $reg.OpenSubKey("SOFTWARE", $TRUE)
		$regSubKeys = $regKey.GetSubKeyNames()
		if (!($regSubKeys -contains 'MicrosoftServices')) {
			$regKey.CreateSubKey('MicrosoftServices') | Out-Null
		}
		$regKey = $reg.OpenSubKey("SOFTWARE\\MicrosoftServices", $TRUE)
		$regSubKeys = $regKey.GetSubKeyNames()
		if (!($regSubKeys -contains $Global:ModuleName)) {
			$regKey.CreateSubKey($Global:ModuleName) | Out-Null
		}
		$regKey = $reg.OpenSubKey("SOFTWARE\\MicrosoftServices\\$($Global:ModuleName)", $TRUE)
		$regkey.SetValue("EULA-Accepted", 1)
		$en = New-Object system.globalization.cultureinfo("en-us")
		$regkey.SetValue("EULA-AcceptedDate", $(get-date -format ($en.DateTimeFormat.ShortDatePattern)))
	}	
}

$a = (Get-Host).UI.RawUI
$WindowWidth = $a.WindowSize.Width
$a.WindowTitle = $ModuleName
$Heading = "Welcome to $ModuleName!"
$Module_Version = $(Get-Module $ModuleName).Version.ToString()
$Heading_Version = "Version: $Module_Version"
Clear-Host
Write-Host " " -NoNewline 
Write-Host ("*" * ($WindowWidth - 2))
#Write-Host " ******************************************************************************"
Write-Host " **" -NoNewline
Write-Host (" " * [Math]::Floor(($WindowWidth - 6 - $Heading.Length) / 2)) -NoNewline
Write-Host $Heading -NoNewline
Write-Host (" " * [Math]::Ceiling(($WindowWidth - 6 - $Heading.Length) / 2)) -NoNewline
Write-Host "**"
Write-Host " **" -NoNewline
Write-Host (" " * [Math]::Floor(($WindowWidth - 6 - $Heading_Version.Length) / 2)) -NoNewline
Write-Host $Heading_Version -NoNewline
Write-Host (" " * [Math]::Ceiling(($WindowWidth - 6 - $Heading_Version.Length) / 2)) -NoNewline
Write-Host "**"
#Write-Host " ******************************************************************************"
Write-Host " " -NoNewline 
Write-Host ("*" * ($WindowWidth - 2))

$Global:FirstStart = $true
$Global:IsInLoop = $false

Load-Scoping
#Write-Host ""

If ($global:ScopingCompleted -eq $true) {
	Launch-TestcaseMenu
}
