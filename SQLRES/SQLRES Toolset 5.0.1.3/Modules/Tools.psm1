#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Tools.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 1.1 included sample code disclaimer
# 1.2 extended test case selection to use alphabetical prefix and comment
# 1.3 added function Get-MacAddressFromComputername
# 3.0 Initial version for SQL 2016 release
# 3.1 Fix: OwnerNode not available on Windows Server 2008/2008 R2
# 3.2 FIPS compliance
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# 5.1 Fix: Proper declaration of $options
# ----------------------------------------------------------------------------- 
function Select-TextItem  
{  
PARAM   
(  
    [Parameter(Mandatory=$true)]  
    #[array]$options,
    [PSObject[]]$options,
    $displayProperty,
	$PrefixProperty,
	[switch]$NoSorting
) 
Set-StrictMode -Version 2.0

	if (!(Get-Variable ToolsetDebug -Scope Global -ErrorAction SilentlyContinue)) {
		$Error.Clear()
		$global:ToolsetDebug = $false
	}

	if (!($NoSorting.IsPresent)) {
		if ($displayProperty -eq $null) {
			$options = $options | Sort-Object
		} else {
			$options = $options | Sort-Object $displayProperty
		}
	}
	
	if ($PrefixProperty) {
	    #[int]$optionPrefix = 1  
	    # Create menu list  
		foreach ($option in $options)
	    {  
			if (!($option.PSObject.Properties -match "Comment")) {
				$option | Add-Member -type NoteProperty -name Comment -Value $null
			}
	        if ($displayProperty -eq $null)  
	        {
				If ($option.Comment) {
            		Write-Host ("{0,3}: {1} ({2})" -f $option.$PrefixProperty,$option, $option.Comment)  
				}
				else {
	            	Write-Host ("{0,3}: {1}" -f $option.$PrefixProperty,$option)  
				}
	        }  
	        else  
	        {  
				if ($option.Comment) {
	            	Write-Host ("{0,3}: {1} ({2})" -f $option.$PrefixProperty,$option.$displayProperty, $option.Comment)
				}
				else {
		            Write-Host ("{0,3}: {1}" -f $option.$PrefixProperty,$option.$displayProperty)
				}
	        }  
	        #$optionPrefix++  
	    }
	}
	else {
	    [int]$optionPrefix = 1  
	    # Create menu list  
	    foreach ($option in $options)  
	    {  
			if (!($option.PSObject.Properties -match "Comment")) {
				$option | Add-Member -type NoteProperty -name Comment -Value $null
			}
	        if ($displayProperty -eq $null)  
	        {  
				if ($option.Comment) {
					Write-Host ("{0,3}: {1} ({2})" -f $optionPrefix,$option, $option.Comment)
				}
				else {
	            	Write-Host ("{0,3}: {1}" -f $optionPrefix,$option)
				}
	        }  
	        else  
	        {  
				if ($option.Comment) {
					Write-Host ("{0,3}: {1} ({2})" -f $optionPrefix,$option.$displayProperty, $option.Comment) 
				}
				else {
	            	Write-Host ("{0,3}: {1}" -f $optionPrefix,$option.$displayProperty)  
				}
	        }  
	        $optionPrefix++  
	    }
	}
    Write-Host ("{0,3}: {1}" -f 0,"To cancel")
    $val = $null  
	if ($PrefixProperty) {
    	$temp = Read-Host "Enter Selection"
		if ($temp.Length -eq 1) {
			[Char]$response = $temp
		}
		else {
			[Char]$response = " "
		}
		if ($global:ToolsetDebug -eq $true) {
			Write-Host "> $response selected."
		}

		foreach ($option in $options) {
			if ($option.$PrefixProperty -eq $response) {
				$val = $option.$displayProperty
			}
		}
	}
	else {
    	[String]$response = Read-Host "Enter Selection"  
		if ($response -match "^[0-9]*$") {
			[int]$response = $response
		}
		else {
			[int]$response = 0
		}
		if ($global:ToolsetDebug -eq $true) {
			Write-Host "> $response selected."
		}
	    if ($response -gt 0 -and $response -le $options.Count)  
	    {  
	        $val = $options[$response-1]  
	    }  
	}
    return $val  
}     

Function Get-StringHash([String] $String,$HashName = "SHA256") 
{ 
	$StringBuilder = New-Object System.Text.StringBuilder 
	[System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String)) | ForEach-Object { 
		[Void]$StringBuilder.Append($_.ToString("x2")) 
	} 
	$StringBuilder.ToString() 
}

Function Get-MacAddressFromComputername
{
PARAM   
(  
    [Parameter(Mandatory=$true)]  
    [String]$Computername
) 
Set-StrictMode -Version 2.0

	try {
		$MacAddress = $null
		$IPv4Address =  (get-wmiobject -Query "select * from win32_pingstatus where Address='$Computername'" -ErrorAction Stop | Select-Object -First 1 IPV4Address).IPV4Address.IPAddressToString
		$MacAddress = (Get-WmiObject Win32_NetworkAdapterConfiguration -ErrorAction Stop | where-object { $_.IPAddress -contains $IPv4Address} | Select-Object -ExpandProperty MacAddress)
		if ( -not ($MacAddress)) {
			$MacAddress  = Invoke-Expression -Command "arp -a" -ErrorAction Stop | select-string $IPv4Address | Where-Object {$_ -match "\d"} | ForEach-Object { $_.ToString().Replace($IPv4Address,"").Trim().Split("  ")[0] }
		}
		$MacAddress = $MacAddress.ToUpper()
		$MacAddress = $MacAddress.Replace(":","-")
		return $MacAddress
	}
	catch {
		if ($PSBoundParameters['Verbose']) {
			$ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
		}
	}
}

Function Get-HostnameFromServername
{
PARAM   
(  
    [Parameter(Mandatory=$true)]  
    [String]$Servername
 ,
   [Parameter(Mandatory=$false)]
   [PSObject]$Credentials = $global:Credentials
 ,
   [Parameter(Mandatory=$false)]
   [String]$ClusterNode = $global:ClusterNodes[0]
 ,
   [Parameter(Mandatory=$false)]
   [PSObject]$ClusterNodes = $global:ClusterNodes
)  
Set-StrictMode -Version 2.0
	
	try {
		if ($ClusterNodes -contains $Servername) {
			return $Servername
		}
		$DNSName = [System.Net.Dns]::GetHostByName("$Servername")
		if ($DNSName) {
			$Servername = $DNSName.HostName.substring(0,$DNSName.HostName.IndexOf("."))
		}
		if ($global:ClusterNodes.Count -gt 1) {
			if ($Credentials.PSObject.Properties.name -match $ClusterNode) {
				$OwnerNode = (Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource -ComputerName $ClusterNode -Credential $Credentials.($ClusterNode) -Authentication PacketPrivacy -Impersonation Impersonate -ErrorAction Stop | Where-Object {$_.Type -eq 'Network Name'} | Select-Object OwnerNode -ExpandProperty PrivateProperties | Where-Object {$_.Name -eq $Servername } | Select-Object OwnerNode).OwnerNode
				if (!$OwnerNode) {
					$OwnerNode = (Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource -ComputerName $ClusterNode -Credential $Credentials.($ClusterNode) -Authentication PacketPrivacy -Impersonation Impersonate -ErrorAction Stop | Where-Object {$_.Type -eq 'Network Name'} | Where-Object { $_ | Select-Object -ExpandProperty PrivateProperties | Where-Object {$_.Name -eq $Servername }} | Select-Object @{n='OwnerNode';e={$(Get-WmiObject -namespace "root\mscluster" -computerName $ClusterNode -Credential $Credentials.($ClusterNode) -Authentication PacketPrivacy -Impersonation Impersonate -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($_.Name)'} WHERE AssocClass = MSCluster_NodeToActiveResource" | Select-Object -ExpandProperty Name)}}).OwnerNode
				}
			}
			else {
				$OwnerNode = (Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource -ComputerName $ClusterNode -Authentication PacketPrivacy -Impersonation Impersonate -ErrorAction Stop | Where-Object {$_.Type -eq 'Network Name'} | Select-Object OwnerNode -ExpandProperty PrivateProperties | Where-Object {$_.Name -eq $Servername } | Select-Object OwnerNode).OwnerNode
				if (!$OwnerNode) {
					$OwnerNode = (Get-WmiObject -namespace 'root\mscluster' MSCluster_Resource -ComputerName $ClusterNode -Authentication PacketPrivacy -Impersonation Impersonate -ErrorAction Stop | Where-Object {$_.Type -eq 'Network Name'} | Where-Object { $_ | Select-Object -ExpandProperty PrivateProperties | Where-Object {$_.Name -eq $Servername }} | Select-Object @{n='OwnerNode';e={$(Get-WmiObject -namespace "root\mscluster" -computerName $ClusterNode -Authentication PacketPrivacy -Impersonation Impersonate -query "ASSOCIATORS OF {MSCluster_Resource.Name='$($_.Name)'} WHERE AssocClass = MSCluster_NodeToActiveResource" | Select-Object -ExpandProperty Name)}}).OwnerNode
				}
			}
		}
		else 
		{
			$OwnerNode = $Servername
		}
		if ($OwnerNode) {
			return $OwnerNode
		}
	}
	catch {
		if ($PSBoundParameters['Verbose']) {
			$ErrorString = $_ | format-list -force | Out-String
			Write-Host $ErrorString -ForegroundColor Red
		}
	}
	return $Servername
}
