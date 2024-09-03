#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Load Scoping.ps1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Integrated HashCode for configuration data
# 1.2 included test level logic
# 1.3 included sample code disclaimer
# 1.4 Extend load scoping for check
# 1.5 FIPS compliance
# 1.6 Added Support for other cluster types WSFC, EXTERNAL, NONE
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Load-Scoping() {
 <# 
   .Synopsis 
    Loads scoping information from soping.xml file
   .Description
    Load-Scoping is the first action that the toolset performs
   .Notes  
   .Example 
    Load-Scoping
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

$error.clear()

If (Test-Path $ScopingFilePath) {
	Write-Host "Reading Scoping information ..." -ForegroundColor DarkGreen
	}
else {
	Write-Host "Scoping not completed. Please execute Scope-Environment!" -ForegroundColor Yellow
	$global:ScopingCompleted = $FALSE
	return
}

if (!(Get-Content $ScopingFilePath)) {
	Write-Host "Scoping file is empty. Please execute Scope-Environment!" -ForegroundColor Yellow
	$global:ScopingCompleted = $FALSE
	return
}

try {
	[xml]$ToolsetConfig = Get-Content $ScopingFilePath

	if ($ToolsetConfig.RootElement.($Global:ModuleName).InnerText.Length -eq 0) {
		Write-Host "Scoping information is not available. Please execute Scope-Environment!" -ForegroundColor Yellow
		$global:ScopingCompleted = $FALSE
		return
	}

	$global:Computername = $ToolsetConfig.RootElement.($Global:ModuleName).Computername
	$global:Instancename = $ToolsetConfig.RootElement.($Global:ModuleName).Instancename
	$global:InstancePort = $ToolsetConfig.RootElement.($Global:ModuleName).InstancePort
	$global:IsClustered = $ToolsetConfig.RootElement.($Global:ModuleName).IsClustered
	$global:Databasename = @($ToolsetConfig.RootElement.($Global:ModuleName).Databasename)
	$NodeExists = $ToolsetConfig.RootElement.($Global:ModuleName).SelectSingleNode("./AvailabilityGroup")
	if ($NodeExists) {
		$global:AvailabilityGroup = $ToolsetConfig.RootElement.($Global:ModuleName).AvailabilityGroup
	}
	else {
		$global:AvailabilityGroup = ""		
	}
	if ($global:AvailabilityGroup) {
		$global:ReplicaInstances = $ToolsetConfig.RootElement.($Global:ModuleName).ReplicaInstances
		$global:ReplicaInstancePorts = $ToolsetConfig.RootElement.($Global:ModuleName).ReplicaInstancePorts
	}
	else {
		$global:ReplicaInstances = $null
		$global:ReplicaInstancePorts = $null
	}
	#$global:AvailabilityGroupResource = $ToolsetConfig.RootElement.$Global:ModuleName.AvailabilityGroupResource
	$global:IsAzure = $ToolsetConfig.RootElement.($Global:ModuleName).Azure
	$global:ToolsMachine = $ToolsetConfig.RootElement.($Global:ModuleName).ToolsMachine
	$global:ScopingDate = $ToolsetConfig.RootElement.($Global:ModuleName).ScopingDate
	$global:ClusterNodes = $ToolsetConfig.RootElement.($Global:ModuleName).ClusterNodes
	$global:ClusterType = $ToolsetConfig.RootElement.($Global:ModuleName).ClusterType
	$culture = New-Object System.Globalization.CultureInfo("en-us")
	$dtScopingDate = [DateTime]::Parse($global:ScopingDate, $culture)
	$global:Authentication = $ToolsetConfig.RootElement.($Global:ModuleName).Authentication
	If ($global:Authentication -eq 'SQL Server Authentication') {
		$global:SQL_Username = $ToolsetConfig.RootElement.($Global:ModuleName).SQL_Username
		$global:SQL_Password = $($ToolsetConfig.RootElement.($Global:ModuleName).SQL_Password | ConvertTo-SecureString -ErrorAction Stop)
	}
	else {
		$global:SQL_Username = $null
		$global:SQL_Password = $null
	}
	$global:Credentials = New-Object PSObject
	$global:Credentials  | Add-Member NoteProperty "-" $null
	#$global:MacAddresses = New-Object PSObject
	foreach ($ClusterNode in $global:ClusterNodes) 
	{ 
		#if ($ToolsetConfig.RootElement.($Global:ModuleName).Credentials.($ClusterNode)) {
		if ($ToolsetConfig.RootElement.($Global:ModuleName).SelectSingleNode("./Credentials/$ClusterNode")) {
			$cred = New-Object System.Management.Automation.PSCredential($ToolsetConfig.RootElement.($Global:ModuleName).Credentials.($ClusterNode).Username, ($ToolsetConfig.RootElement.($Global:ModuleName).Credentials.($ClusterNode).Password | ConvertTo-SecureString -ErrorAction Stop))
			$global:Credentials  | Add-Member NoteProperty $ClusterNode $cred
		}
		#else {
		#	$global:Credentials  | Add-Member NoteProperty $ClusterNode $null
		#}
	}
	
	$ConfigHash = $ToolsetConfig.RootElement.ConfigHash
	$StringBuilder = New-Object System.Text.StringBuilder 
	[System.Security.Cryptography.HashAlgorithm]::Create("SHA256").ComputeHash([System.Text.Encoding]::UTF8.GetBytes($ToolsetConfig.RootElement.($Global:ModuleName).InnerXML))| ForEach-Object { 
		[Void]$StringBuilder.Append($_.ToString("x2")) 
	} 
	$CalculatedHash = $StringBuilder.ToString() 
}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	else {
		Write-Host $_.Exception.Message -ForegroundColor Red
	}
	Write-Host 'Could not read scoping information.' -ForegroundColor Yellow
	Write-Host 'If the scoping was performed by using different credentials, ' -ForegroundColor Yellow
	Write-Host 'please repeat the scoping of the target environment ' -ForegroundColor Yellow
	Write-Host 'by using the Scope-Environment commandlet.' -ForegroundColor Yellow
	return
}

Show-Scoping

#Write-Host "You can add copies of the scoped database using Scope-CloneDatabase"
Write-Host "You can navigate through the test cases using Launch-TestCase(Menu)"

If ($dtScopingDate -lt ($(get-date).AddDays(-7))) {
	Write-Host "Scoping information too old." -ForegroundColor Yellow
	Write-Host "Please Re-Scope your environment using Scope-Environment!" -ForegroundColor Yellow
	$global:ScopingCompleted = $FALSE
	return
}

If ($global:ToolsMachine -ne (Get-Content env:computername)) {
	Write-Host "Scoping information is from a different Tools-Machine!" -ForegroundColor Yellow
	Write-Host "Please Re-Scope your environment using Scope-Environment!" -ForegroundColor Yellow
	$global:ScopingCompleted = $FALSE
	return
}

If ($ConfigHash -ne $CalculatedHash) {
	Write-Host "Scoping information was manipulated!" -ForegroundColor Yellow
	Write-Host "Please Re-Scope your environment using Scope-Environment!" -ForegroundColor Yellow
	$global:ScopingCompleted = $FALSE
	#Write-Host $CalculatedHash
	return
}


if (!$error[0]) {
	Write-Host "Reading Scoping information succeeded!" -ForegroundColor Green
	$global:ScopingCompleted = $TRUE
}
else {
	Write-Host "Reading Scoping information  failed!" -ForegroundColor Red
	$global:ScopingCompleted = $FALSE
}	

}

function Show-Scoping() {
	Write-Host "Scoping summary:" #-ForegroundColor Green
	Write-Host "------------------------------------------------------------" 
	Write-Host "Servername:                  $global:Computername"  
	Write-Host "Instancename:                $global:Instancename"  
	Write-Host "Instanceport:                $global:InstancePort"  
	Write-Host "IsClustered:                 $global:IsClustered"  
	if ($global:AvailabilityGroup -or $global:IsClustered) {
	Write-Host "ClusterNodes:                $global:ClusterNodes"
	Write-Host "ClusterType:                 $global:ClusterType"
	}
	Write-Host "Databasename:                $global:Databasename"  
	if ($global:AvailabilityGroup) {
	Write-Host "------------------------------------------------------------" 
	Write-Host "AvailabilityGroup:           $global:AvailabilityGroup" 
	Write-Host "Replicas:                    $global:ReplicaInstances"  
	Write-Host "TCP-Ports:                   $global:ReplicaInstancePorts"  
	}
	Write-Host "Authentication:              $global:Authentication"  
	if ($global:Authentication -eq 'SQL Server Authentication') {
		Write-Host "Username:                    $global:SQL_Username"  
	}
	Write-Host "Azure detected:              $global:IsAzure"  
	Write-Host "------------------------------------------------------------" 
	Write-Host "Scoping Date:                $global:ScopingDate"  
	Write-Host "ToolsMachine:                $global:ToolsMachine"  
	Write-Host "============================================================" 
}