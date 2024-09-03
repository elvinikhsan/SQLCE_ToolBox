#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Remove Database.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Integrated HashCode for configuration data
# 1.2 included test level logic
# 1.3 included sample code disclaimer
# 3.0 Initial version for SQL 2016 release
# 3.1 FIPS compliance
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Toolset-RemoveDatabase()
{ 
 <# 
   .Synopsis 
    Removes additional databases
   .Description
	TestCaseLevel:@Admin	
   .Notes  
   .Example 
    Toolset-RemoveDatabase   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

If ($global:ScopingCompleted -eq $FALSE) {
	Write-Host "Scoping is not completed yet. Please scope environment using Scope-Environment!" -ForegroundColor Yellow
	return
}

If ($global:ScopingCompleted -eq $TRUE) {
		$Computername = $global:Computername
		$Instancename = $global:Instancename
		$InstancePort = $global:InstancePort
		$Databasename = $global:Databasename[0]
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

$AnotherDB = 0
#$BackupTaken = $FALSE
$returncode = 0

while (($AnotherDB -eq 0) -and ($returncode -eq 0)) {

	$Skip = $FALSE
	
	Write-Host "Please enter a unique postfix for an additional database"
	$Postfix = Read-Host -Prompt "Postfix"
	$NewDatabasename = $global:Databasename[0] + "_" + $Postfix
	
	If (($global:Databasename -notcontains $NewDatabasename) -or ($Postfix -eq "")) {
		Write-Host "A database with the postfix $Postfix was not found." -ForegroundColor Yellow
		$Skip = $TRUE
	}

	if ($Skip -eq $FALSE) {
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
		}
		catch [System.Data.SqlClient.SqlException] {
			if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
				Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
				returncode = -1
			}
			else {
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
			$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
			$command.Connection = $Connection
			$command.CommandTimeout = '300'

			$command.CommandText = "
			DECLARE @ProductVersion VARCHAR(20)
			DECLARE @ProductMinorVersion DECIMAL(5,2)
			DECLARE @ProductLevel VARCHAR(20)
			DECLARE @EngineEdition INT
			DECLARE @IsClustered INT
			DECLARE @IsIntegratedSecurityOnly INT

			SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
			SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
			SET @ProductLevel = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductLevel'))
			SET @EngineEdition = CONVERT(INT,SERVERPROPERTY('EngineEdition'))
			SET @IsClustered = CONVERT(INT,SERVERPROPERTY('IsClustered'))
			SET @IsIntegratedSecurityOnly = CONVERT(INT,SERVERPROPERTY('IsIntegratedSecurityOnly'))

			SELECT @ProductVersion ProductVersion, @ProductMinorVersion ProductMinorVersion, @ProductLevel ProductLevel, @EngineEdition EngineEdition, @IsClustered IsClustered, @IsIntegratedSecurityOnly IsIntegratedSecurityOnly
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
			}
			$reader.Close()

			[String]$AvailabilityGroupName = ''
			$command.CommandText = "SELECT ag.name FROM sys.databases d INNER JOIN
				sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
				sys.availability_groups ag ON ar.group_id = ag.group_id
				WHERE d.name = '$NewDatabasename'"
			$AvailabilityGroupName = $command.ExecuteScalar()
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
			#Write-Host $command.CommandText
			try {
				Write-Host "Dropping database $NewDatabasename ... "
				
				if ($AvailabilityGroupName) {
					$command.CommandText = "ALTER AVAILABILITY GROUP [$AvailabilityGroupName] REMOVE DATABASE [" + $NewDatabasename + "]"
					$rs = $command.ExecuteNonQuery()
				}
				
				$command.CommandText = "
				ALTER DATABASE [" + $NewDatabasename + "] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
				DROP DATABASE [" + $NewDatabasename + "]
				"
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

		if ($returncode -eq 0) {
			try {
				$TempDB = @()
				ForEach ($db in $global:Databasename) {
					if( $db -ne $NewDatabasename) {
						$TempDB += @($db)
					}
				}
				$global:Databasename = $TempDB
				
				[xml]$ToolsetConfig = Get-Content $ScopingFilePath
				
				$removeDatabases = $ToolsetConfig.RootElement.($Global:ModuleName).GetElementsByTagname("Databasename")
				foreach ($removeDatabase in $removeDatabases) {
					if ($removeDatabase.("#text") -eq $NewDatabasename) {
						$ToolsetConfig.RootElement.($Global:ModuleName).RemoveChild($removeDatabase) | Out-Null
						break
					}
				}
								
				$HashValue = Get-StringHash $ToolsetConfig.RootElement.($Global:ModuleName).InnerXML "SHA256"
				$ToolsetConfig.RootElement.ConfigHash = $HashValue
				$ToolsetConfig.Save($ScopingFilePath)
			}
			catch {
				Write-Host "Error writing to Scoping File." -ForegroundColor Red
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

		$message = "Do you want to drop another copy of the database?"
		$title = "Confirm"
		$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
		$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
		$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
		$AnotherDB = $host.ui.PromptForChoice($title, $message, $options, 0)
	}
}

if ($error[0]) {
	$returncode = -1
}
	
if ($returncode -eq 0) {
	Write-Host "Additional database copies dropped!" -ForegroundColor Green
}
else {
	Write-Host "Errors occurred during database copy deletion!" -ForegroundColor Red
}

}
