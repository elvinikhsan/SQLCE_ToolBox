#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Remove Scoping.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Fix: $Servername variable not initialized
# 3.0 Initial version for SQL 2016 release
# 3.1 Fix: Scoping CleanUp not working
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Remove-Scoping()
{ 
 <# 
   .Synopsis 
    Removes scoping information in the environment
   .Description
    This function removes all scoping flags in the environment
	TestCaseLevel:@Admin	
   .Notes  
   .Example 
    Remove-Scoping   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

$DatabaseArray = $FALSE
If ($global:ScopingCompleted -eq $TRUE) {
	$Computername = $global:Computername
	$Instancename = $global:Instancename
	$InstancePort = $global:InstancePort
	if (!$MyInvocation.BoundParameters["Databasename"]) {
		$Databasename = $global:Databasename[0]
		if (@($global:Databasename).Length -gt 1) {
				$DatabaseArray = $TRUE
		}
	}
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
	Write-Host "Scoping is not completed yet." -ForegroundColor Yellow
	return
}

$message = "Do you really want to remove the scoping information?"
$title = "Confirm"
$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
$result = $host.ui.PromptForChoice($title, $message, $options, 1)

If ($result -ne 0) {
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
	return
}
#endregion CheckAGReplica_Primary

#For local execution on cluster node
$Computername = Get-HostnameFromServername -Servername $Computername

$returncode = 0
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

$error.Clear()

if ($returncode -eq 0) {
	#Reading InstanceProperties
	try {
		$command.CommandText = "
		DECLARE @ProductVersion VARCHAR(20)
		DECLARE @ProductMinorVersion DECIMAL(5,2)
		DECLARE @ProductLevel VARCHAR(20)
		DECLARE @EngineEdition INT
		DECLARE @IsClustered INT
		DECLARE @IsIntegratedSecurityOnly INT
		DECLARE @ComputernamePhysicalNetbios VARCHAR(255)

		SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
		SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
		SET @ProductLevel = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductLevel'))
		SET @EngineEdition = CONVERT(INT,SERVERPROPERTY('EngineEdition'))
		SET @IsClustered = CONVERT(INT,SERVERPROPERTY('IsClustered'))
		SET @IsIntegratedSecurityOnly = CONVERT(INT,SERVERPROPERTY('IsIntegratedSecurityOnly'))
		SET @ComputernamePhysicalNetbios = CONVERT(VARCHAR(255),SERVERPROPERTY('ComputernamePhysicalNetbios'))

		SELECT @ProductVersion ProductVersion, @ProductMinorVersion ProductMinorVersion, @ProductLevel ProductLevel, @EngineEdition EngineEdition, @IsClustered IsClustered, @IsIntegratedSecurityOnly IsIntegratedSecurityOnly, @ComputernamePhysicalNetbios ComputernamePhysicalNetbios
		"
		$Reader = $command.ExecuteReader()
		
		while($Reader.Read())
		{		
			$ProductVersion = $Reader["ProductVersion"]
			$ProductMinorVersion = $Reader["ProductMinorVersion"]
			$ProductLevel = $Reader["ProductLevel"]
			$EngineEdition = $Reader["EngineEdition"]
			$IsClustered = $Reader["IsClustered"]
			$IsIntegratedSecurityOnly = $Reader["IsIntegratedSecurityOnly"]
			$ComputernamePhysicalNetbios = $Reader["ComputernamePhysicalNetbios"]
		}
		$reader.Close()
	}
	catch {
		if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
			Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
		}
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

#Include Availability Groups
if ($returncode -eq 0) {
	try {
		[String]$AG_Name = $AvailabilityGroup
		if ($AG_Name) {
			$ReplicaInstances = @()
			$command.CommandText = "SELECT node_name, replica_server_name FROM sys.dm_hadr_availability_replica_cluster_nodes WHERE group_name = '$AG_Name'"
			$reader = $command.ExecuteReader()
			while($Reader.Read())
			{
				#$NodeName = $Reader["node_name"].ToString()    
				$ReplicaInstance = $Reader["replica_server_name"].ToString()    
				#$ClusterNodes  += @($NodeName)
				$ReplicaInstances  += @($ReplicaInstance)
			}  	
			$reader.Close()
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

$localComputername = $(Get-WmiObject -Class Win32_ComputerSystem -ComputerName .).Name
$remoteComputername = $ComputernamePhysicalNetbios

if (($ClusterNodes -contains $localComputername) -or ($remoteComputername -eq $localComputername))
{
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
# Check to see if we are currently running "as Administrator"
if (!$myWindowsPrincipal.IsInRole($adminRole)) {
	Write-Host "You are executing $Global:ModuleName on the target machine." -ForegroundColor Yellow
	Write-Host "In this case $Global:ModuleName needs to be launched in an elevated mode." -ForegroundColor Yellow
	Write-Host "Run $Global:ModuleName.bat with (run as Administrator) or create a new administrative shortcut!" -ForegroundColor Yellow
	$message = "Shall I create an administrative shortcut for you."
	$title = "Admin shortcut"
	$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
	$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1)
	if ($result -ne 0) {
		return
	}
	else {
		$shortcut = $(resolve-path .).ToString() + "\" + "$Global:ModuleName.lnk"
		$result = Create-AdminShortCut $shortcut
		if ($result -eq 0) {
			Write-Host "Successfully created administrative shortcut $Global:ModuleName(Admin). Please close this window and open $Global:ModuleName(Admin)!"
		}
		else {
			Write-Host "Unable to create administrative shortcut."
		}
		return
		}
	}
}

if ($returncode -eq 0) {
	$command.CommandText = "
	IF (SELECT COUNT(*) FROM [$Databasename].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
		EXEC [$Databasename].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
	--EXEC [$Databasename].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
	" 
	try {
		$rs = $command.ExecuteNonQuery()
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

if ($returncode -eq 0) {
	foreach ($db in $global:Databasename) {
		$command.CommandText = "
		IF (SELECT COUNT(*) FROM [$db].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
			EXEC [$db].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
		--EXEC [$Databasename].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
		" 
		try {
			$rs = $command.ExecuteNonQuery()
		}
		catch {
			if ($PSBoundParameters['Verbose']) {
				$ErrorString = $_ | format-list -force | Out-String
				Write-Host $ErrorString -ForegroundColor Red
			}
		}
	}
}

if ($returncode -eq 0) {
	$command.CommandText = "
	IF (SELECT COUNT(*) FROM [master].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
		EXEC [master].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
	--EXEC [master].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
	"
	try {
		$rs = $command.ExecuteNonQuery()
	}
	catch [System.Data.SqlClient.SqlException] {
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

$Connection.Close()

If ($returncode -ne -1) {
	If (($IsClustered -eq 0) -and (!$AG_Name)) {
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
			returncode = -1
		}

		$returncode = Invoke-Command -Session $sess -ArgumentList $Global:ModuleName -ScriptBlock {
			param($ModuleName)
			[Environment]::SetEnvironmentVariable("$ModuleName", $null, "MACHINE")
			if ($error[0]) {
				return -1
			}
			else {
				return 0
			}
		}
		Remove-PSSession -Session $sess -ErrorAction SilentlyContinue
	}
	else {
		if ($AG_Name) {
			foreach ($ReplicaInstance in $ReplicaInstances) {
				if ($ReplicaInstance -ne $Servername) {
					try {
						$ReplicaInstancePort=$ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$ReplicaInstance.ToUpper())]
						if ($Authentication -eq 'SQL Server Authentication') {
							$connectionString2      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
							$Connection2 = New-Object System.Data.SqlClient.SqlConnection($connectionString2)
							[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
							$SQLPwd.MakeReadOnly()
							$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
							$Connection2.credential = $cred
						}
						else {
							$ConnectionString2      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
							$Connection2 = New-Object System.Data.SqlClient.SqlConnection($connectionString2)
						}	
						$Connection2.open()
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
					if ($returncode -eq 0) {
						$command2 = New-Object system.Data.SqlClient.SqlCommand($Connection2)
						$command2.CommandTimeout = '300'
						$command2.Connection = $Connection2
						$command2.CommandText = "
						IF (SELECT COUNT(*) FROM [master].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
							EXEC [master].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
						--EXEC [master].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
						"
						try {
							$rs = $command2.ExecuteNonQuery()
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
					try {
						$Connection2.close()
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
			}
		}
		foreach ($Node in $ClusterNodes) {
			#Write-Host $Node
			If ($Credentials.PSObject.Properties.name -match $Node) {
				$sess = New-PSSession -ComputerName $Node -Credential $Credentials.($Node)
			}
			else {
				$sess = New-PSSession -ComputerName $Node
			}

			$returncode = Invoke-Command -Session $sess -ArgumentList $Global:ModuleName -ScriptBlock {
				param($ModuleName)
				[Environment]::SetEnvironmentVariable("$ModuleName", $null, "MACHINE")
				if ($error[0]) {
					return -1
				}
				else {
					return 0
				}
			}
			Remove-PSSession -Session $sess -ErrorAction SilentlyContinue
			if ($returncode -ne 0) {
				break
			}
		}
	}
}

if ($error[0]) {
	$returncode = -1
}
	
if ($returncode -eq 0) {
	#Write-Host "Scoping information successfully removed!" -ForegroundColor Green
}
else {
	Write-Host "Failed to remove scoping information!" -ForegroundColor Red
	return
}

if (!$error[0]) {
	$message = "Shall I remove the scoping file scoping.xml?"
	$title = "Remove scoping.xml?"
	$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
	$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
	$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
	$result = $host.ui.PromptForChoice($title, $message, $options, 1)
	if ($result -eq 0) {
		try {
			Remove-Item $ScopingFilePath -Force | Out-Null
		}
		catch {
			if ($PSBoundParameters['Verbose']) {
				$ErrorString = $_ | format-list -force | Out-String
				Write-Host $ErrorString -ForegroundColor Red
			}
			else {
				Write-Host $_.Exception.Message -ForegroundColor Red
			}
			Write-Host "Failed to remove scoping file!" -ForegroundColor Red
			return
		}
	}
	$global:ScopingCompleted = $FALSE	
	Write-Host "Scoping information successfully removed!" -ForegroundColor Green
	Write-Host "Leaving toolset ..."
	Start-Sleep -Seconds 3
	Exit
}

}
