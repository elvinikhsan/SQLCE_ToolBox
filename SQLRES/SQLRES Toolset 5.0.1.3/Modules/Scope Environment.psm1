#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Scope Environment.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 Integrated HashCode for configuration data
# 1.2 included test level logic
# 1.3 included sample code disclaimer
# 1.4 Create shortcut with "Run as Administrator" for local test case execution
# 1.5 Included support for availability groups
# 1.6 Test and workaround for disabled SQL Browser or UDP Firewall issue
# 1.7 Fix: Scoping Date and ToolsMachine empty after Re-Scope
# 1.8 Block scoping for databases with page verify option set to NONE
# 1.9 Added information if target environment is clustered
# 3.0 Initial version for SQL 2016 release
# 3.1 Fix: Force IPv4 for Browser connectivity
# 3.2 FIPS compliance
# 3.3 Added support for other cluster types WSFC, EXTERNAL, NONE
# 3.4 Added support for Read-Scale Availability Group
# 4.0 Initial version for SQL 2017 release
# 4.1 Fix: Check PowerShell Remoting enabled
# 5.0 Storing TCP Port information for secure environments
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Scope-Environment()
{ 
 <# 
   .Synopsis 
    Performs scoping of the environment
   .Description
    Here you can enter the information for the target environment
	For the servername only enter the HOSTNAME not the FQDN
	For the instancename enter the instance name or leave it blank if it is the default instance
	For the databasename enter the name of the database
	On case sensitive instances the database name must match excactly
	TestCaseLevel:@Admin	
   .Notes  
	If you do not want to perform scoping it is still possible to execute the test cases
	using the -IgnoreScoping switch
   .Example 
    Scope-Environment   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param(
   [Switch]$ReScope
)
Set-StrictMode -Version 2.0

$ScopingFilePath = $(resolve-path .).ToString() + "\" + "Scoping.xml"

if ($ReScope.IsPresent -eq $false) {
	if ($PSBoundParameters['Verbose']) {
		$ConnectSuccess = Show-ConnectToSQLServer -Verbose
	} 
	else {
		$ConnectSuccess = Show-ConnectToSQLServer
	}
	If ($ConnectSuccess -eq "OK") {
		$SaveWindowsCredentials = $global:ScopingResults.SaveWindowsCredentials
		if ($SaveWindowsCredentials) {
			#$global:ClusterNodes = @("OLIVERHA4","localhost")
			if ($PSBoundParameters['Verbose']) {
				$CredentialsSaved = Show-SaveWindowsCredentials -Verbose
			}
			else {
				$CredentialsSaved = Show-SaveWindowsCredentials
			}
			if ($CredentialsSaved -eq "OK") {
				$Credentials = $global:ScopingResults.Credentials
			}
			else {
				return
			}
		}
		else {
			$global:ScopingResults | Add-Member NoteProperty Credentials (New-Object PSObject)
			#for ($i = 0; $i -lt $global:ScopingResults.ClusterNodes.Count; $i++) 
			#{ 
			#	$global:ScopingResults.Credentials | Add-Member NoteProperty $global:ScopingResults.ClusterNodes[$i] $null
			#}
			$global:ScopingResults.Credentials | Add-Member NoteProperty "-" $null
			$Credentials = $global:ScopingResults.Credentials
		}
		$Computername = $global:ScopingResults.Computername
		$Instancename = $global:ScopingResults.Instancename
		$InstancePort = $global:ScopingResults.InstancePort
		$Databasename = $global:ScopingResults.Databasename
		$AvailabilityGroup = $global:ScopingResults.AvailabilityGroup
		if ($AvailabilityGroup) {
			if (!(Get-Variable ReplicaInstances -Scope Global -ErrorAction SilentlyContinue)) {
				$Error.Clear()
				$global:ReplicaInstances = @()
			}
			$ReplicaInstances = @($global:ReplicaInstances)
			if (!(Get-Variable ReplicaInstancePorts -Scope Global -ErrorAction SilentlyContinue)) {
				$Error.Clear()
				$global:ReplicaInstancePorts = @()
			}
			$ReplicaInstancePorts = @($global:ReplicaInstancePorts)
		}
		$IsClustered = $global:ScopingResults.IsClustered
		$ClusterNodes = $global:ScopingResults.ClusterNodes
		$ClusterType = $global:ScopingResults.ClusterType
		$Authentication = $global:ScopingResults.Authentication
		If ($Authentication -eq 'SQL Server Authentication') {
			$SQL_Username = $global:ScopingResults.SQL_Username
			$SQL_Password = $global:ScopingResults.SQL_Password
		}
		else {
			$SQL_Username = $null
			$SQL_Password = $null
		}
	}
	else {
		return
	}
}
else {
	$Computername = $global:Computername
	$Instancename = $global:Instancename
	$InstancePort = $global:InstancePort
	$Databasename = $global:Databasename
	$AvailabilityGroup = $global:AvailabilityGroup
	if ($AvailabilityGroup) {
		if (!(Get-Variable ReplicaInstances -Scope Global -ErrorAction SilentlyContinue)) {
			$Error.Clear()
			$global:ReplicaInstances = @()
		}
		$ReplicaInstances = @($global:ReplicaInstances)
		if (!(Get-Variable ReplicaInstancePorts -Scope Global -ErrorAction SilentlyContinue)) {
			$Error.Clear()
			$global:ReplicaInstancePorts = @()
		}
		$ReplicaInstancePorts = @($global:ReplicaInstancePorts)
	}
	$IsClustered = $global:IsClustered
	$IsAzure = $global:IsAzure
	$ClusterNodes = $global:ClusterNodes
	$ClusterType = $global:ClusterType
	$Authentication = $global:Authentication
	$Credentials = $global:Credentials
	If ($Authentication -eq 'SQL Server Authentication') {
		$SQL_Username = $global:SQL_Username
		$SQL_Password = $global:SQL_Password
	}
}

if ($Instancename -eq "") {
	$Instancename = "MSSQLSERVER"
}

if ($Computername -eq "." -or $Computername -eq "") {
	$Computername = "localhost"
}

if ($Instancename -ne "MSSQLSERVER") {
	$Servername = $Computername + "\" + $Instancename
}
else {
	$Servername = $Computername
}

if ($Databasename -eq "") {
	$Databasename = "Adventureworks"
}

if ( !($Computername) -or !($Instancename) -or !($Databasename) -or !($Authentication) -or ($Authentication -eq 'SQL Server Authentication' -and ($SQL_Username -eq $null -or $SQL_Password -eq $null))) {
	Write-Host "The available data is not sufficient to scope the environment." -ForegroundColor Yellow
	Write-Host "Please re-enter the information!" -ForegroundColor Yellow
	return
}

Write-Host ""
Write-Host "Scoping summary:" #-ForegroundColor Blue
Write-Host "----------------" #-ForegroundColor Blue
Write-Host "You have entered the following information." 
Write-Host "Servername:       $Computername" #-ForegroundColor Blue
Write-Host "Instancename:     $Instancename" #-ForegroundColor Blue
Write-Host "InstancePort:     $InstancePort" #-ForegroundColor Blue
Write-Host "IsClustered:      $IsClustered" #-ForegroundColor Blue
Write-Host "ClusterNodes:     $ClusterNodes" #-ForegroundColor Blue
Write-Host "ClusterType:      $ClusterType"
Write-Host "Databasename:     $Databasename" #-ForegroundColor Blue
Write-Host "AvailabilitGroup: $AvailabilityGroup" #-ForegroundColor Blue
Write-Host "Authentication:   $Authentication" #-ForegroundColor Blue
If ($Authentication -eq 'SQL Server Authentication') {
	Write-Host "Username:         $SQL_Username" #-ForegroundColor Blue
}

$message = "During the delivery of $Global:ModuleName the scoped environment can get irrecoverable damaged. Please confirm that you are aware"
$title = "Confirm"
$choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Answer Yes."
$choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Answer No."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($choiceYes, $choiceNo)
$result = $host.ui.PromptForChoice($title, $message, $options, 1)

If ($result -ne 0) {
	return
}

$returncode = 0
$IsAzure = $false

if ($returncode -eq 0) {
	$localComputername = $(Get-WmiObject -Class Win32_ComputerSystem -ComputerName .).Name
	if ($ReScope.IsPresent -eq $false) {
		$remoteComputername = Get-HostnameFromServername -Servername $Computername -Credentials $global:ScopingResults.Credentials -ClusterNode $global:ScopingResults.ClusterNodes[0] -ClusterNodes $global:ScopingResults.ClusterNodes
	}
	else {
		$remoteComputername = Get-HostnameFromServername -Servername $Computername -Credentials $Credentials -ClusterNode $ClusterNodes[0] -ClusterNodes $ClusterNodes
	}
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
}

try {
	#If ($Credentials.PSObject.Properties.name -match $Computername) {
	if ($Credentials.PSObject.Properties.Name -match $Computername) {
		[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Computername -Credential $Credentials.($Computername) -Authentication Default -ErrorAction Stop)
		if ($PSRemotingEnabled) {
			[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Computername -Credential $Credentials.($Computername) -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
		}
	}
	else {
		[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Computername -ErrorAction Stop)
		if ($PSRemotingEnabled) {
			[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Computername -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
		}
	}
}
catch {
	if ($PSBoundParameters['Verbose']) {
		$ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
	}
	[bool]$PSRemotingEnabled = $false
}

#[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Computername -ErrorAction SilentlyContinue)
If ($PSRemotingEnabled -eq $false) {
	Write-Host "PowerShell Remoting seems not to be enabled or target machine is unavailable. Please make sure the target machine is available and enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
	$returncode = -1
}

if ($returncode -eq 0) {
	Write-Host "Test Connectivity to target instance ..."

	try {
		#If ($Credentials.PSObject.Properties.name -match $Computername) {
		if ($Credentials.PSObject.Properties.name -match $Computername) {
				$sess = New-PSSession -ComputerName $Computername -Credential $Credentials.($Computername)
		}
		else {
			$sess = New-PSSession -ComputerName $Computername
		}
		$InstancePort = Invoke-Command -Session $sess -ArgumentList $Instancename, $Servername -ScriptBlock {
		Param($Instancename, $Servername)
			try {
				#$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, '.')
				$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, 0)
				$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL", $FALSE)
				$InstanceKey = $regKey.GetValue($Instancename).ToString()
				$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\$InstanceKey\\MSSQLServer\\SuperSocketNetLib\\Tcp\IPAll", $FALSE)
				$InstancePort = $regKey.GetValue('TcpPort').ToString()
				if ($InstancePort -like '*,*') {
					$InstancePort = $InstancePort = $($InstancePort -split ',')[0].Trim()
				}
				if (!($InstancePort)) {
					$InstancePort = $regKey.GetValue('TcpDynamicPorts').ToString()
					if ($InstancePort -like '*,*') {
						$InstancePort = $InstancePort = $($InstancePort -split ',')[0].Trim()
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
			return $InstancePort
		}
		Remove-PSSession -Session $sess -ErrorAction SilentlyContinue
	
		if (!($InstancePort)) {
			Write-Host "Instance Port could not be determined!" -ForegroundColor Red
			return -1
		}

		$returncode = 0
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
		$Connection.Open()

		$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
		$command.CommandTimeout = '300'
		$command.Connection = $Connection

		$AliasClusterNodes = @()

		$command.CommandText = "SELECT NodeName FROM sys.dm_os_cluster_nodes WHERE CONVERT(VARCHAR(255),SERVERPROPERTY('ComputerNamePhysicalNetbios')) <> NodeName" 
		$reader = $command.ExecuteReader()

		while($Reader.Read())
		{
			$NodeName = $Reader["NodeName"].ToString()    
			$AliasClusterNodes  += @($NodeName)
		}
		$Connection.Close()
		
		foreach ( $Node in $AliasClusterNodes ) {
			try {
				if ($Credentials.PSObject.Properties.name -match $Node) {
						[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -Credential $Credentials.($Node) -Authentication Default -ErrorAction Stop)
					if ($PSRemotingEnabled) {
						[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Node -Credential $Credentials.($Node) -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
					}
				}
				else {
					[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction Stop)
					if ($PSRemotingEnabled) {
						[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Node -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
					}
				}
			}
			catch {
				if ($PSBoundParameters['Verbose']) {
					$ErrorString = $_ | format-list -force | Out-String
					Write-Host $ErrorString -ForegroundColor Red
				}
				[bool]$PSRemotingEnabled = $false
			}
			#[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction SilentlyContinue)
			If ($PSRemotingEnabled -eq $false) {
				#Write-Host "PowerShell Remoting seems not to be enabled on computer $node. Please enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
				Write-Host "PowerShell Remoting seems not to be enabled on computer $node or target machine is unavailable. Please make sure the target machine is available and enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
				returncode = -1
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
		$returncode = -1
	}	
}

if ($returncode -eq 0) {
	try {
		Write-Host "Connecting to the selected instance ..."
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
	catch [System.Data.SqlClient.SqlException] {
		if ($Connection.State.ToString().ToUpper() -ne 'OPEN') {
			if ($_.Exception.Number -ge 18400 -and $_.Exception.Number -le 18500) {
				Write-Host "Could not connect to SQL Server." -ForegroundColor Red
				Write-Host $_.Exception.Message -ForegroundColor Red
			}
			else {
				Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
			}
			$returncode = -1
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

		$Computername = $Computername.ToUpper()
		$command.CommandText = "SELECT SERVERPROPERTY('InstanceName')" 
		$Instancename = $command.ExecuteScalar()
		$command.CommandText = "SELECT TOP 1 name FROM sys.databases WHERE UPPER(name) = UPPER('$Databasename')" 
		$Databasename = $command.ExecuteScalar()
		If (!($Databasename)) {
			Write-Host "Database not found!. Please enter a correct database name!" -ForegroundColor Yellow
			$returncode = -1
		}
		if (!$Instancename.ToString()) {
			$Instancename = "MSSQLSERVER"
		}
		if ($Instancename -ne "MSSQLSERVER") {
			$Servername = $Computername + "\" + $Instancename
		}
		else {
			$Servername = $Computername
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

if ($returncode -eq 0) {
	#checking Updateability of target database
	$command.CommandText = "SELECT page_verify_option_desc FROM sys.databases WHERE name = '$Databasename'" 
	$page_verify_option_desc = $command.ExecuteScalar()
	If ($page_verify_option_desc -eq 'TORN_PAGE_DETECTION') {
		Write-Host "Database has page verify option set to TORN_PAGE_DETECTION. Some test cases might not work as expected." -ForegroundColor Yellow
	}
}

#Include Availability Groups
if ($returncode -eq 0) {
	try {
		$command.CommandText = "
		SELECT COUNT(*) FROM sys.databases d INNER JOIN
		sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
		sys.availability_groups ag ON ar.group_id = ag.group_id
		"
		[Int16]$AG_Cnt = $command.ExecuteScalar()
		$NodeNames = @()
		if ($AG_Cnt -gt 0) {
			if ($AvailabilityGroup) {
				#$ClusterNodes = @()
				$ReplicaInstances = @()
				$ReplicaInstancePorts = @()
				$command.CommandText = "SELECT node_name, replica_server_name FROM sys.dm_hadr_availability_replica_cluster_nodes WHERE group_name = '$AvailabilityGroup'"
				$reader = $command.ExecuteReader()
				while($Reader.Read())
				{
					$NodeName = $Reader["node_name"].ToString()
					$NodeNames += @($NodeName)						
					$ReplicaInstance = $Reader["replica_server_name"].ToString()
					$ReplicaInstances  += @($ReplicaInstance)
					$ReplicaInstancePorts += @("")
				}  	
				$reader.Close()
			}				
		}
		foreach ($TestNode in $NodeNames) {
			if($ClusterNodes -notcontains $TestNode) {
				$ClusterNodes += $TestNode
			}
		}
		$ClusterNodes = $ClusterNodes | Sort-Object
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
	$command.CommandText = "
	IF (SELECT COUNT(*) FROM [$Databasename].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
		EXEC [$Databasename].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
	EXEC [$Databasename].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
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

if ($returncode -eq 0) {
	$command.CommandText = "
	IF (SELECT COUNT(*) FROM [master].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
		EXEC [master].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
	EXEC [master].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
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

if ($returncode -eq 0) {
	if ($Connection.State.ToString().ToUpper() -eq 'OPEN') {
		$Connection.Close()
	}
}

If ($returncode -ne -1) {
	If (($IsClustered -eq 0) -and (!$AvailabilityGroup)) {
	
		$AzureConf = Confirm-Azure -Computername $Computername
		If ($AzureConf -eq $true) {
			$IsAzure = $true
		}
		
		
		#If ($Credentials.PSObject.Properties.name -match $Computername) {
		if ($Credentials.PSObject.Properties.name -match $Computername) {
			$sess = New-PSSession -ComputerName $Computername -Credential $Credentials.($Computername)
		}
		else {
			$sess = New-PSSession -ComputerName $Computername
		}

		try {
			$osver = Invoke-command -Session $sess -ScriptBlock { [environment]::OSVersion.Version }
			[Double]$OSMinorVersion = ($osver.Major.ToString() + "." + $osver.Minor.ToString())
			if ($OSMinorVersion -lt 6.2) {
				Write-Host "The Operating System on $Computername ($OSMinorVersion) is not supported. Only Windows Server 2012 and newer is supported!" -ForegroundColor Yellow
				$returncode = -1		
			}
			$psver = Invoke-command -Session $sess -ScriptBlock { $PSVersionTable.PSVersion }
			[Double]$PSMinorVersion = ($psver.Major.ToString() + "." + $psver.Minor.ToString())
			if ($PSMinorVersion -lt 3.0) {
				Write-Host "The PowerShell on $Computername ($PSMinorVersion) is not supported. Only PowerShell 3.0 and newer is supported!" -ForegroundColor Yellow
				$returncode = -1		
			}
			$clrver = Invoke-command -Session $sess -ScriptBlock { $PSVersionTable.CLRVersion }
			[Double]$CLRMinorVersion = ($clrver.Major.ToString() + "." + $clrver.Minor.ToString())
			if ($CLRMinorVersion -lt 4.0) {
				Write-Host "The CLR version on $Computername ($CLRMinorVersion) is not supported. Only CLR 4.0 and newer is supported!" -ForegroundColor Yellow
				$returncode = -1		
			}
			$netversion = Invoke-command -Session $sess -ScriptBlock { (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Where-Object -Property Property -eq 'Release' | Sort-Object Release -Descending | Select-Object -First 1).GetValue("Version") } -ErrorAction SilentlyContinue
			[Double]$MaxNetVersion = $netversion.SubString(0,3)
			if ($MaxNetVersion -lt 4.5) {
				Write-Host "The NET Framework System on $Computer ($MaxNetVersion) is not supported. Only .NET 4.5 and newer is supported!" -ForegroundColor Yellow
				$returncode = -1		
			}
			$Error.Clear()
		}
		catch {
			if ($PSBoundParameters['Verbose']) {
				$ErrorString = $_ | format-list -force | Out-String
				Write-Host $ErrorString -ForegroundColor Red
			}
		}

		$returncode = Invoke-Command -Session $sess -ArgumentList $Global:ModuleName -ScriptBlock {
			param($ModuleName)
			[Environment]::SetEnvironmentVariable($ModuleName, "TRUE", "MACHINE")
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
		if ($AvailabilityGroup) {
			foreach ($ReplicaInstance in $ReplicaInstances) {
				if ($ReplicaInstance -eq $Servername) {
					$ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$ReplicaInstance.ToUpper())] = $InstancePort
				}
				if ($ReplicaInstance -ne $Servername) {
					
					$ReplicaNode = $ReplicaInstance.Split("\")[0]
					try {
						if ($Credentials.PSObject.Properties.name -match $ReplicaNode) {
							[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $ReplicaNode -Credential $Credentials.($ReplicaNode) -Authentication Default -ErrorAction Stop)
							if ($PSRemotingEnabled) {
								[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $ReplicaNode -Credential $Credentials.($ReplicaNode) -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
							}
											}
						else {
							[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $ReplicaNode -ErrorAction Stop)
							if ($PSRemotingEnabled) {
								[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $ReplicaNode -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
							}
						}
					}
					catch {
						if ($PSBoundParameters['Verbose']) {
							$ErrorString = $_ | format-list -force | Out-String
							Write-Host $ErrorString -ForegroundColor Red
						}
						[bool]$PSRemotingEnabled = $false
					}
					#[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $ReplicaNode -ErrorAction SilentlyContinue)
					If ($PSRemotingEnabled -eq $false) {
						#Write-Host "PowerShell Remoting seems not to be enabled on $ReplicaNode. Please enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
						Write-Host "PowerShell Remoting seems not to be enabled on $ReplicaNode or target machine is unavailable. Please make sure the target machine is available and enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
						$returncode = -1
					}
					
					if ($ReplicaInstance.IndexOf("\") -ge 0) {
						$ReplicaComputer = $ReplicaInstance.Split("\")[0]
						$ReplicaInstanceName = $ReplicaInstance.Split("\")[1]
					}
					else {
						$ReplicaComputer = $ReplicaInstance
						$ReplicaInstanceName = "MSSQLSERVER"
					}
			
					try {
						if ($Credentials.PSObject.Properties.name -match $ReplicaComputer) {
							$sess = New-PSSession -ComputerName $ReplicaComputer -Credential $Credentials.($ReplicaComputer)
						}
						else {
							$sess = New-PSSession -ComputerName $ReplicaComputer
						}								

						$ReplicaInstancePort = Invoke-Command -Session $sess -ArgumentList $ReplicaInstanceName, $ReplicaInstance -ScriptBlock {
						Param($Instancename, $Servername)
						try {
							#$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, '.')
							$reg = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, 0)
							$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\Instance Names\\SQL", $FALSE)
							$InstanceKey = $regKey.GetValue($Instancename).ToString()
							$regKey = $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\$InstanceKey\\MSSQLServer\\SuperSocketNetLib\\Tcp\IPAll", $FALSE)
							$InstancePort = $regKey.GetValue('TcpPort').ToString()
							if ($InstancePort -like '*,*') {
								$InstancePort = $InstancePort = $($InstancePort -split ',')[0].Trim()
							}
							if (!($InstancePort)) {
								$InstancePort = $regKey.GetValue('TcpDynamicPorts').ToString()
								if ($InstancePort -like '*,*') {
									$InstancePort = $InstancePort = $($InstancePort -split ',')[0].Trim()
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
						return $InstancePort
						}
						Remove-PSSession -Session $sess -ErrorAction SilentlyContinue				
						
						#$ReplicaInstancePorts[[array]::indexof($ReplicaInstances,$ReplicaInstance)] = $ReplicaInstancePort
						$ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$ReplicaInstance.ToUpper())] = $ReplicaInstancePort
						$returncode = 0

						if ($Authentication -eq 'SQL Server Authentication') {
							$connectionString      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
							$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
							[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
							$SQLPwd.MakeReadOnly()
							$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
							$Connection.credential = $cred		
						}
						else {
							$ConnectionString      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
							$Connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
						}									
						$Connection.Open()

						$command = New-Object system.Data.SqlClient.SqlCommand($Connection)
						$command.CommandTimeout = '300'
						$command.Connection = $Connection

						$AliasClusterNodes = @()

						$command.CommandText = "SELECT NodeName FROM sys.dm_os_cluster_nodes WHERE CONVERT(VARCHAR(255),SERVERPROPERTY('ComputerNamePhysicalNetbios')) <> NodeName" 
						$reader = $command.ExecuteReader()

						while($Reader.Read())
						{
							$NodeName = $Reader["NodeName"].ToString()    
							$AliasClusterNodes  += @($NodeName)
						}
						$Connection.Close()
						
						foreach ( $Node in $AliasClusterNodes ) {
							try {
								if ($Credentials.PSObject.Properties.name -match $Node) {
									[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -Credential $Credentials.($Node) -Authentication Default -ErrorAction Stop)
									if ($PSRemotingEnabled) {
										[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $$Node -Credential $Credentials.($Node) -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
									}
								}
								else {
									[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction Stop)
									if ($PSRemotingEnabled) {
										[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Node -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
									}
								}
							}
							catch {
								if ($PSBoundParameters['Verbose']) {
									$ErrorString = $_ | format-list -force | Out-String
									Write-Host $ErrorString -ForegroundColor Red
								}
								[bool]$PSRemotingEnabled = $false							
							}
							#[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction SilentlyContinue)
							If ($PSRemotingEnabled -eq $false) {
								#Write-Host "PowerShell Remoting seems not to be enabled on $Node. Please enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
								Write-Host "PowerShell Remoting seems not to be enabled on $Node or target machine is unavailable. Please make sure the target machine is available and enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
								$returncode = -1
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
						$returncode = -1
					}

					Write-Host "Connecting to replica $ReplicaInstance ..."
					if ($returncode -eq 0) {
						try {
							#$ReplicaInstancePort = $ReplicaInstancePorts[[array]::indexof($ReplicaInstances,$ReplicaInstance)]
							$ReplicaInstancePort = $ReplicaInstancePorts[[array]::indexof(($ReplicaInstances | ForEach-Object { $_.ToUpper() }),$ReplicaInstance.ToUpper())]
							if ($Authentication -eq 'SQL Server Authentication') {
								$connectionString      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=False;Network Library=DBMSSOCN;Connect Timeout=3"
								$Connection2 = New-Object System.Data.SqlClient.SqlConnection($connectionString)
								[System.Security.SecureString]$SQLPwd = $SQL_Password #| ConvertTo-SecureString
								$SQLPwd.MakeReadOnly()
								$cred = New-Object System.Data.SqlClient.SqlCredential($SQL_Username,$SQLPwd)
								$Connection2.credential = $cred
								$connectionString      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=False;User Id=$SQL_Username;Password=$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SQL_Password)));Network Library=DBMSSOCN;Connect Timeout=3"
								$Connection2 = New-Object System.Data.SqlClient.SqlConnection($connectionString)
							}
							else {
								$ConnectionString      = "Data Source=$($ReplicaInstance),$($ReplicaInstancePort);Initial Catalog=master;Integrated Security=True;Network Library=DBMSSOCN;Connect Timeout=3"
								$Connection2 = New-Object System.Data.SqlClient.SqlConnection($connectionString)
							}	
							$Connection2.open()
						}
						catch [System.Data.SqlClient.SqlException] {
							if ($Connection2.State.ToString().ToUpper() -ne 'OPEN') {
								if ($_.Exception.Number -ge 18400 -and $_.Exception.Number -le 18500) {
									Write-Host "Could not connect to SQL Server." -ForegroundColor Red
									Write-Host $_.Exception.Message -ForegroundColor Red
								}
								else {
									Write-Host "Could not connect to SQL Server. Check if SQL Server is running!" -ForegroundColor Red
								}
								$returncode = -1
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
							$returncode = -1
						}
						catch {
						    if ($PSBoundParameters['Verbose']) {
						        $ErrorString = $_ | format-list -force | Out-String
								Write-Host $ErrorString -ForegroundColor Red
						    }
						    else {
						        Write-Host $_.Exception.Message -ForegroundColor Red
						    }
						}
						if ($returncode -eq 0) {
							$command2 = New-Object system.Data.SqlClient.SqlCommand($Connection2)
							$command2.CommandTimeout = '300'
							$command2.Connection = $Connection2
							$command2.CommandText = "
							IF (SELECT COUNT(*) FROM [master].sys.fn_listextendedproperty(default, default, default, default, default, default, default) WHERE name = N'$Global:ModuleName') > 0
								EXEC [master].sys.sp_dropextendedproperty @name = N'$Global:ModuleName'
							EXEC [master].sys.sp_addextendedproperty @name=N'$Global:ModuleName', @value=N'TRUE'
							"
							try {
								$rs = $command2.ExecuteNonQuery()
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
						try {
							$Connection2.close()
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
				}
			}
		}
		if ($returncode -eq 0) {		
			foreach ($Node in $ClusterNodes) {
				#Write-Host $Node
				Write-Host "Connecting to cluster node $Node ..."
				
				try {
					if ($Credentials.PSObject.Properties.name -match $Node) {
						[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -Credential $Credentials.($Node) -Authentication Default -ErrorAction Stop)
						if ($PSRemotingEnabled) {
							[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Node -Credential $Credentials.($Node) -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
						}
					}
					else {
						[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction Stop)
						if ($PSRemotingEnabled) {
							[bool]$PSRemotingEnabled = [Bool](Invoke-Command -ComputerName $Node -Authentication Default -ScriptBlock { $true } -ErrorAction Stop)
						}
					}
				}
				catch {
					if ($PSBoundParameters['Verbose']) {
						$ErrorString = $_ | format-list -force | Out-String
						Write-Host $ErrorString -ForegroundColor Red
					}
					[bool]$PSRemotingEnabled = $false
				}
				
				#[bool]$PSRemotingEnabled = [Bool](Test-WSMan -ComputerName $Node -ErrorAction SilentlyContinue)			
				$AzureConf = Confirm-Azure -Computername $Node
				If ($AzureConf -eq $true) {
					$IsAzure = $true
				}
				
				If ($PSRemotingEnabled -eq $false) {
					#Write-Host "PowerShell Remoting seems not to be enabled on $Node. Please enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
					Write-Host "PowerShell Remoting seems not to be enabled on $Node or target machine is unavailable. Please make sure the target machine is available and enable PowerShell Remoting on all target machines!" -ForegroundColor Yellow
					$returncode = -1
				}
				
				if ($returncode -eq 0) {
					if ($Credentials.PSObject.Properties.name -match $Node) {
						$sess = New-PSSession -ComputerName $Node -Credential $Credentials.($Node)
					}
					else {
						$sess = New-PSSession -ComputerName $Node
					}

					try {
						$osver = Invoke-command -Session $sess -ScriptBlock { [environment]::OSVersion.Version }
						[Double]$OSMinorVersion = ($osver.Major.ToString() + "." + $osver.Minor.ToString())
						if ($OSMinorVersion -lt 6.2) {
							Write-Host "The Operating System on $Node ($OSMinorVersion) is not supported. Only Windows Server 2012 and newer is supported!" -ForegroundColor Yellow
							$returncode = -1		
						}
						$psver = Invoke-command -Session $sess -ScriptBlock { $PSVersionTable.PSVersion }
						[Double]$PSMinorVersion = ($psver.Major.ToString() + "." + $psver.Minor.ToString())
						if ($PSMinorVersion -lt 3.0) {
							Write-Host "The PowerShell on $Node ($PSMinorVersion) is not supported. Only PowerShell 3.0 and newer is supported!" -ForegroundColor Yellow
							$returncode = -1		
						}
						$clrver = Invoke-command -Session $sess -ScriptBlock { $PSVersionTable.CLRVersion }
						[Double]$CLRMinorVersion = ($clrver.Major.ToString() + "." + $clrver.Minor.ToString())
						if ($CLRMinorVersion -lt 4.0) {
							Write-Host "The CLR version on $Node ($CLRMinorVersion) is not supported. Only CLR 4.0 and newer is supported!" -ForegroundColor Yellow
							$returncode = -1		
						}
						$netversion = Invoke-command -Session $sess -ScriptBlock { (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Where-Object -Property Property -eq 'Release' | Sort-Object Release -Descending | Select-Object -First 1).GetValue("Version") } -ErrorAction SilentlyContinue
						[Double]$MaxNetVersion = $netversion.SubString(0,3)
						if ($MaxNetVersion -lt 4.5) {
							Write-Host "The NET Framework System on $Node ($MaxNetVersion) is not supported. Only .NET 4.5 and newer is supported!" -ForegroundColor Yellow
							$returncode = -1		
						}
						$Error.Clear()
					}
					catch {
						if ($PSBoundParameters['Verbose']) {
							$ErrorString = $_ | format-list -force | Out-String
							Write-Host $ErrorString -ForegroundColor Red
						}
					}

					$returncode = Invoke-Command -Session $sess -ArgumentList $Global:ModuleName -ScriptBlock {
						param($ModuleName)
						[Environment]::SetEnvironmentVariable($ModuleName, "TRUE", "MACHINE")
						if ($error[0]) {
							return -1
						}
						else {
							return 0
						}
					}
					Remove-PSSession -Session $sess -ErrorAction SilentlyContinue
				}
				if ($returncode -ne 0) {
					break
				}
			}
		}
	}
}

if ($error[0]) {
	$returncode = -1
}
	
if ($returncode -eq 0) {
	Write-Host "Scoping execution successful!" -ForegroundColor Green
}
else {
	Write-Host "Scoping execution failed!" -ForegroundColor Red
	return
}

#region WritingScopinginformation

Write-Host "Writing Scoping information ..."
$error.clear()

$ToolsMachine = Get-Content env:computername
$ScopingDate = get-date -format "yyyy-MM-dd"

try {
	# Create The Document
	$XmlWriter = New-Object System.XMl.XmlTextWriter($ScopingFilePath,$Null)

	# Set The Formatting
	$xmlWriter.Formatting = "Indented"
	$xmlWriter.Indentation = "4"

	# Write the XML Decleration
	$xmlWriter.WriteStartDocument()

	# Set the XSL
	$XSLPropText = "type='text/xsl' href='style.xsl'"
	$xmlWriter.WriteProcessingInstruction("xml-stylesheet", $XSLPropText)

	# Write Root Element
	$xmlWriter.WriteStartElement("RootElement")

	# Write the Document
	$xmlWriter.WriteStartElement("$Global:ModuleName")
	$xmlWriter.WriteElementString("ToolsMachine","$ToolsMachine")
	$xmlWriter.WriteElementString("ScopingDate","$ScopingDate")
	$xmlWriter.WriteElementString("Computername","$Computername")
	$xmlWriter.WriteElementString("Instancename","$Instancename")
	$xmlWriter.WriteElementString("InstancePort","$InstancePort")
	if ($IsClustered -eq 1) {
		$xmlWriter.WriteElementString("IsClustered","true")
	}
	else {
		$xmlWriter.WriteElementString("IsClustered","false")
	}
	$xmlWriter.WriteElementString("Databasename","$Databasename")
	if ($AvailabilityGroup) {
		$xmlWriter.WriteElementString("AvailabilityGroup","$AvailabilityGroup")
		#$xmlWriter.WriteElementString("ReplicaInstances","$ReplicaInstances")
		foreach ($ReplicaInstance in $ReplicaInstances) {
			$xmlWriter.WriteElementString("ReplicaInstances",$ReplicaInstance)
		}
		#$xmlWriter.WriteElementString("ReplicaInstancePorts","$ReplicaInstancePorts")
		foreach ($ReplicaInstancePort in $ReplicaInstancePorts) {
			$xmlWriter.WriteElementString("ReplicaInstancePorts",$ReplicaInstancePort)
		}
		#$xmlWriter.WriteElementString("AvailabilityGroupResource","$AGresourcename")
	}
	if ($IsAzure -eq $true) {
		$xmlWriter.WriteElementString("Azure","true")
	}
	else {
		$xmlWriter.WriteElementString("Azure","false")
	}
	#if (($IsClustered -eq $true) -or ($AvailabilityGroup)) {
		foreach ($ClusterNode in $ClusterNodes) {
			$xmlWriter.WriteElementString("ClusterNodes",$ClusterNode)
		}
	#}
	$XmlWriter.WriteElementString("ClusterType", $ClusterType)
	$xmlWriter.WriteElementString("Authentication",$Authentication)
	if ($Authentication -eq 'SQL Server Authentication') {
		$xmlWriter.WriteElementString("SQL_Username",$SQL_Username)
		$xmlWriter.WriteElementString("SQL_Password",$($SQL_Password | ConvertFrom-SecureString -ErrorAction Stop ))
	}
	#$ClusterNodes = ($ClusterNodes | Sort-Object)
	#if ($SaveWindowsCredentials) {
		$XmlWriter.WriteStartElement("Credentials")
		if ($Credentials) {
			#for ([Int16]$c = 0; $c -lt $ClusterNodes.Count ; $c++) {
			foreach ($ClusterNode in $ClusterNodes) {
				#$XmlWriter.WriteStartElement($ClusterNodes[$c]) | Out-Null
				#Write-Host $ClusterNodes[$c]
				if ($Credentials.PSObject.Properties.name -match $ClusterNode) {
					$XmlWriter.WriteStartElement($ClusterNode)
					$xmlWriter.WriteElementString("Username",$Credentials.($ClusterNode).Username)
					$xmlWriter.WriteElementString("Password",$($Credentials.($ClusterNode).Password | ConvertFrom-SecureString -ErrorAction Stop ))
					$XmlWriter.WriteEndElement() | out-null # <-- Closing Credential for ClusterNode
				}
				#Write-Host $ClusterNodes[$c]
			}
		}
		$XmlWriter.WriteEndElement() | out-null # <-- Closing Credentials
		#$XmlWriter.WriteStartElement("MacAddresses")
		#$MacAddresses
		#for ([Int16]$c = 0; $c -lt $ClusterNodes.Count ; $c++) {
		#foreach ($ClusterNode in $ClusterNodes) {
			#$XmlWriter.WriteStartElement($ClusterNodes[$c]) | Out-Null
			#Write-Host $ClusterNodes[$c]
			#Write-Host $($MacAddresses.("OLIVERHA4"))
		#	$xmlWriter.WriteElementString($ClusterNode, $($MacAddresses.($ClusterNode)).ToString())
			#Write-Host $ClusterNodes[$c]
		#}
		#$XmlWriter.WriteEndElement() | out-null # <-- Closing MacAdresses
	#}
	$xmlWriter.WriteEndElement() | out-null # <-- Closing Servers

	# Write Close Tag for Root Element
	$xmlWriter.WriteEndElement() | out-null # <-- Closing RootElement

	# End the XML Document
	$xmlWriter.WriteEndDocument()

	# Finish The Document
	#$xmlWriter.Finalize
	$xmlWriter.Flush | out-null
	$xmlWriter.Close()

	[xml]$ToolsetConfig = Get-Content $ScopingFilePath
	$HashValue = Get-StringHash $ToolsetConfig.RootElement.($Global:ModuleName).InnerXML "SHA256"
	$e = $ToolsetConfig.CreateElement("ConfigHash")
	$e.set_InnerText($HashValue)
	$ToolsetConfig.RootElement.AppendChild($e) | out-null
	$ToolsetConfig.Save($ScopingFilePath)	
} 
catch {
    if ($PSBoundParameters['Verbose']) {
        $ErrorString = $_ | format-list -force | Out-String
		Write-Host $ErrorString -ForegroundColor Red
    }
    else {
        Write-Host $_.Exception.Message -ForegroundColor Red
    }
	Write-Host "Writing scoping information failed!" -ForegroundColor Red
}

#endregion WritingScopinginformation

if (!$error[0]) {
	$global:Computername = $Computername
	$global:Instancename = $Instancename
	$global:InstancePort = $InstancePort
	$global:Databasename = @($Databasename)
	if ($AvailabilityGroup) {
		$global:AvailabilityGroup = $AvailabilityGroup
		$global:ReplicaInstances = $ReplicaInstances
		$global:ReplicaInstancePorts = $ReplicaInstancePorts
	}
	else {
		$global:AvailabilityGroup = $null
	}
	[Boolean]$global:IsClustered = $IsClustered
	$global:IsAzure = $IsAzure
	$global:ClusterNodes = ($ClusterNodes | Sort-Object)
	$global:ClusterType = $ClusterType
	$global:ToolsMachine = $ToolsMachine
	$global:ScopingDate = $ScopingDate
	$global:Authentication = $Authentication
	$global:Credentials = $Credentials
	$global:SQL_Username = $SQL_Username
	$global:SQL_Password = $SQL_Password
	
	$global:ScopingCompleted = $TRUE
	Write-Host "Writing scoping information succeeded!" -ForegroundColor Green
	Write-Host "You can add copies of the scoped database using Scope-CloneDatabase"
	
	If ($global:ScopingCompleted -eq $true) {
		#$Global:IsInLoop
		if ($Global:IsInLoop -eq $false) {
			Write-Host "Press any key to continue ..."
			$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
			Clear-Host
			Show-Scoping
			Launch-TestcaseMenu
		}
	}
	
}

}
