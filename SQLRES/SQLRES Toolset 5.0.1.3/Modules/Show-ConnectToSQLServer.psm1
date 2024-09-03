#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Show-ConnectToSQLServer.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 3.1 Added support for other cluster types WSFC, EXTERNAL, NONE
# 3.2 Added support for Read-Scale Availability Group
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Show-ConnectToSQLServer 
{
 <# 
   .Synopsis 
    Shows connection dialog for SQL Server
   .Description
    The new connection dialog pre-checks prerequisites for the toolset
   .Notes  
   .Example 
    Show-ConnectToSQLServer
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Verbose "Creating SQL Connect form ..."

#region formconfig

$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size @(480,320)

$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'

#$global:modulename = "SQLRES"

$form.Text = "$global:modulename : Connect to SQL Server"
$form.MinimizeBox = $false
$form.MaximizeBox = $false

$Assemblies = @(
'System.Windows.Forms',
'System.Drawing',
'System.Data',
'System.Xml',
'System.ServiceProcess',
'System.Core'
)

$Code = @"
	Imports System
	Imports System.Drawing
	Imports System.Windows.Forms
	Public Class NewCheckBox
	    Inherits System.Windows.Forms.CheckBox
	    Protected Overrides Sub OnPaint(ByVal e As PaintEventArgs)
	        MyBase.OnPaint(e)
	        Dim boxsize As Integer = Me.Height * 0.75
	        Dim rect As New Rectangle(New Point(0, Me.Height / 2 - boxsize / 2), New Size(boxsize, boxsize))
	        ControlPaint.DrawCheckBox(e.Graphics, rect, If(Me.Checked, ButtonState.Checked, ButtonState.Normal))
	    End Sub
	End Class
"@;

$Code = @"
	using System;
	//using System.Collections;
	//using System.Collections.Generic;
	//using System.Data;
	//using System.Diagnostics;
	using System.Drawing;
	using System.Windows.Forms;
	public class NewCheckBox : System.Windows.Forms.CheckBox
	{
		protected override void OnPaint(PaintEventArgs e)
		{
			base.OnPaint(e);
			int boxsize = (int)(this.Height * 0.75);
			Rectangle rect = new Rectangle(new Point(0, this.Height / 2 - boxsize / 2), new Size(boxsize, boxsize));
			ControlPaint.DrawCheckBox(e.Graphics, rect, this.Checked ? ButtonState.Checked : ButtonState.Normal);
		}
	}
"@;

#-WarningAction SilentlyContinue 
#Add-Type -Language VisualBasic -ReferencedAssemblies $Assemblies -TypeDefinition $Code
Add-Type -Language CSharp -ReferencedAssemblies $Assemblies -TypeDefinition $Code -WarningAction SilentlyContinue 

$lblSQLServer = New-Object System.Windows.Forms.Label
$lblServername = New-Object System.Windows.Forms.Label
$txtServername = New-Object System.Windows.Forms.TextBox
$lblAuthentication = New-Object System.Windows.Forms.Label
$cboAuthentication = New-Object System.Windows.Forms.ComboBox
$lblUsername = New-Object System.Windows.Forms.Label
$txtUsername = New-Object System.Windows.Forms.TextBox
$lblPassword = New-Object System.Windows.Forms.Label
$txtPassword = New-Object System.Windows.Forms.TextBox
$lblDatabase = New-Object System.Windows.Forms.Label
$cboDatabase = New-Object System.Windows.Forms.ComboBox
$lblAvailabilityGroups = New-Object System.Windows.Forms.Label
$cboAvailabilityGroups = New-Object System.Windows.Forms.ComboBox
$lblIsClustered = New-Object System.Windows.Forms.Label
$chkIsClustered = New-Object System.Windows.Forms.CheckBox
$lblSaveWindowsCredentials = New-Object System.Windows.Forms.Label
#$chkSaveWindowsCredentials = New-Object System.Windows.Forms.CheckBox
$chkSaveWindowsCredentials = New-Object NewCheckBox
$lblSaveWindowsCredentialsDesc = New-Object System.Windows.Forms.Label

$Servername_Value = New-Object System.Windows.Forms.Label
$Instancename_Value = New-Object System.Windows.Forms.Label
$InstancePort_Value = New-Object System.Windows.Forms.Label
$Databasename_Value = New-Object System.Windows.Forms.Label
$Availabilitygroupname_Value = New-Object System.Windows.Forms.Label
$IsClustered_Value = New-Object System.Windows.Forms.Label
$lblBackslash = New-Object System.Windows.Forms.Label
$lblComma = New-Object System.Windows.Forms.Label

$btnNext = New-Object System.Windows.Forms.Button
$btnOK = New-Object System.Windows.Forms.Button
$btnCancel = New-Object System.Windows.Forms.Button
$btnPrevious = New-Object System.Windows.Forms.Button


$ttToolTip = New-Object System.Windows.Forms.ToolTip
# Set up the delays for the ToolTip.
$ttToolTip.AutoPopDelay = 3000
$ttToolTip.InitialDelay = 500
$ttToolTip.ReshowDelay = 500
# Force the ToolTip text to be displayed whether or not the form is active.
$ttToolTip.ShowAlways = $true

$btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

$btnOK.Text = "&OK"
$btnNext.Text = "&Next"
$btnPrevious.Text = "&Previous"
$btnCancel.Text = "&Cancel"
$btnNext.Enabled = $false
$btnPrevious.Enabled = $false

$lblServername.Text = "Server name:"
$lblAuthentication.Text = "Authentication:"
$lblUsername.Text = "User name:"
$lblPassword.Text = "Password"
$lblSQLServer.Text = "SQL Server"
$lblDatabase.Text = "Database:"
$lblAvailabilityGroups.Text = "Availability Groups:"
$lblIsClustered.Text = "Is clustered:"
$lblSaveWindowsCredentials.Text = "Store Win. Creds:"
# Set up the ToolTip text for the Button and Checkbox.
$ttToolTip.SetToolTip($chkSaveWindowsCredentials, "For Cross-Domain and Azure scenarios")
#$chkSaveWindowsCredentials.ToolTipText = "For Cross-Domain and Azure scenarios"
$lblDatabase.Visible = $false
$cboDatabase.Visible = $false
$lblAvailabilityGroups.Visible = $false
$cboAvailabilityGroups.Visible = $false
$lblIsClustered.Visible = $false
$chkIsClustered.Visible = $false
$lblSaveWindowsCredentials.Visible = $false
$chkSaveWindowsCredentials.Visible = $false
$lblSaveWindowsCredentialsDesc.Visible = $false
$lblBackslash.Visible = $false
$lblComma.Visible = $false

$form.AcceptButton = $btnOK
$form.CancelButton = $btnCancel

#$btn.add_click({Get-Date|Out-Host})
#$txtBox.Text = "Click here"
$form.Controls.Add($lblSQLServer)
$form.Controls.Add($lblServername)
$form.Controls.Add($txtServername)
$form.Controls.Add($lblAuthentication)
$form.Controls.Add($cboAuthentication)
$form.Controls.Add($lblUsername)
$form.Controls.Add($txtUsername)
$form.Controls.Add($lblPassword)
$form.Controls.Add($txtPassword)
$form.Controls.Add($btnOK)
$form.Controls.Add($btnNext)
$form.Controls.Add($btnPrevious)
$form.Controls.Add($btnCancel)
$form.Controls.Add($lblDatabase)
$form.Controls.Add($cboDatabase)
$form.Controls.Add($lblAvailabilityGroups)
$form.Controls.Add($cboAvailabilityGroups)
$form.Controls.Add($lblIsClustered)
$form.Controls.Add($chkIsClustered)
$form.Controls.Add($Servername_Value)
$form.Controls.Add($Instancename_Value)
$form.Controls.Add($InstancePort_Value)
$form.Controls.Add($Databasename_Value)
$form.Controls.Add($Availabilitygroupname_Value)
$form.Controls.Add($IsClustered_Value)
$form.Controls.Add($lblBackslash)
$form.Controls.Add($lblComma)
$form.Controls.Add($lblSaveWindowsCredentials)
$form.Controls.Add($chkSaveWindowsCredentials)
$form.Controls.Add($lblSaveWindowsCredentialsDesc)
#$form.Controls.Add($ttToolTip)

$Form.Add_Shown({$Form.Activate(); $btnCancel.focus()})

#$txtBox.
$txtUsername.ReadOnly = $true
$txtPassword.ReadOnly = $true
$txtPassword.Enabled = $false

$lblSQLServer.Left = 130
$lblSQLServer.Top = 20
$lblSQLServer.Width = 400
$lblSQLServer.Height = 50
#$lblSQLServer.AutoSize = $true
#$lblSQLServer.FontSize = 100
$Font = New-Object System.Drawing.Font("Segoe UI",30)
$lblSQLServer.Font = $Font
#$lblSQLServer.TextAlign = "middle"

$lblServername.Left = 10
$lblServername.Top = 100
$lblServername.Width = 100
$lblServername.Height = 20

$txtServername.Left = 120
$txtServername.Top = 100
$txtServername.Width = 160
$txtServername.Height = 20

$Servername_Value.Left = 280
$Servername_Value.Top = 100
$Servername_Value.Width = 100
$Servername_Value.Height = 20

$Servername_Value.AutoSize = $true
$lblBackslash.Left = $Servername_Value.Left + $Servername_Value.Width
$lblBackslash.Text = '\'
$lblBackslash.Top = 100
$lblBackslash.Height = 20
$lblBackslash.AutoSize = $true

$Instancename_Value.Left = $lblBackslash.Left + $lblBackslash.Width
$Instancename_Value.Top = 100
$Instancename_Value.Height = 20
$Instancename_Value.AutoSize = $true

$lblComma.Left = $Instancename_Value.Left + $Instancename_Value.Width
$lblComma.Text = ','
$lblComma.Top = 100
$lblComma.Height = 20
$lblComma.AutoSize = $true

$InstancePort_Value.Left = $lblComma.Left + $lblComma.Width
$InstancePort_Value.Top = 100
$InstancePort_Value.Height = 20
$InstancePort_Value.AutoSize = $true

$lblAuthentication.Left = 10
$lblAuthentication.Top = 130
$lblAuthentication.Width = 100
$lblAuthentication.Height = 20

$cboAuthentication.Left = 120
$cboAuthentication.Top = 130
$cboAuthentication.Width = 160
$cboAuthentication.Height = 20

$lblDatabase.Left = 10
$lblDatabase.Top = 130
$lblDatabase.Width = 100
$lblDatabase.Height = 20

$cboDatabase.Left = 120
$cboDatabase.Top = 130
$cboDatabase.Width = 160
$cboDatabase.Height = 20

$Databasename_Value.Left = 280
$Databasename_Value.Top = 130
$Databasename_Value.Width = 140
$Databasename_Value.Height = 20
$Databasename_Value.AutoSize = $true

$lblAvailabilityGroups.Left = 10
$lblAvailabilityGroups.Top = 160
$lblAvailabilityGroups.Width = 110
$lblAvailabilityGroups.Height = 20

$cboAvailabilityGroups.Left = 120
$cboAvailabilityGroups.Top = 160
$cboAvailabilityGroups.Width = 160
$cboAvailabilityGroups.Height = 20
$cboAvailabilityGroups.Enabled = $false

$Availabilitygroupname_Value.Left = 280
$Availabilitygroupname_Value.Top = 160
$Availabilitygroupname_Value.Width = 140
$Availabilitygroupname_Value.Height = 20
$Availabilitygroupname_Value.AutoSize = $true

$lblIsClustered.Left = 10
$lblIsClustered.Top = 190
$lblIsClustered.Width = 110
$lblIsClustered.Height = 20

$chkIsClustered.Left = 120
$chkIsClustered.Top = 190
$chkIsClustered.Width = 160
$chkIsClustered.Height = 20
$chkIsClustered.Enabled = $false
$chkIsClustered.Checked = $false # [System.Windows.Forms.CheckState]::Unchecked

$IsClustered_Value.Left = 280
$IsClustered_Value.Top = 190
$IsClustered_Value.Width = 140
$IsClustered_Value.Height = 20

$lblSaveWindowsCredentials.Left = 10
$lblSaveWindowsCredentials.Top = 220
$lblSaveWindowsCredentials.Height = 20

$chkSaveWindowsCredentials.Left = 120
$chkSaveWindowsCredentials.Top = 210
$chkSaveWindowsCredentials.Height = 30
$chkSaveWindowsCredentials.Width = 30
$chkSaveWindowsCredentials.Checked = $false # [System.Windows.Forms.CheckState]::Unchecked
$chkSaveWindowsCredentials.Enabled = $false

$lblSaveWindowsCredentialsDesc.Left = 150
$lblSaveWindowsCredentialsDesc.Top = 220
$lblSaveWindowsCredentialsDesc.Height = 30
$lblSaveWindowsCredentialsDesc.AutoSize = $true
$Font = New-Object System.Drawing.Font($lblSaveWindowsCredentialsDesc.Font.FontFamily, ($lblSaveWindowsCredentialsDesc.Font.Size + 1), [System.Drawing.FontStyle]::Bold)
$lblSaveWindowsCredentialsDesc.Text = "Important for cross-domain and azure scenarios!"
$lblSaveWindowsCredentialsDesc.Font = $Font

$cboAuthentication.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cboAuthentication.Items.Clear()
$cboAuthentication.Items.Add("Windows Authentication")
$cboAuthentication.Items.Add("SQL Server Authentication")
$cboAuthentication.SelectedItem = "Windows Authentication"

$cboDatabase.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDown
$cboAvailabilityGroups.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

$lblUsername.Left = 10
$lblUsername.Top = 160
$lblUsername.Width = 100
$lblUsername.Height = 20

$txtUsername.Left = 120
$txtUsername.Top = 160
$txtUsername.Width = 160
$txtUsername.Height = 20

$lblPassword.Left = 10
$lblPassword.Top = 190
$lblPassword.Width = 100
$lblPassword.Height = 20

$txtPassword.Left = 120
$txtPassword.Top = 190
$txtPassword.Width = 160
$txtPassword.Height = 20
$txtPassword.PasswordChar = '*'

$formGraphics = $form.createGraphics()
$mypen = New-Object System.Drawing.Pen black

#$bitmap = New-Object System.Drawing.Bitmap 100, 100

$p0 = New-Object System.Drawing.Point(0, 0)
$p1 = New-Object System.Drawing.Point(240, 0)

$c0 = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$c1 = [System.Drawing.Color]::FromArgb(255, 255, 130, 0)

$p2 = New-Object System.Drawing.Point(240, 0)
$p3 = New-Object System.Drawing.Point(480, 0)

$c2 = [System.Drawing.Color]::FromArgb(255, 255, 130, 0)
$c3 = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)

$brush1 = New-Object System.Drawing.Drawing2D.LinearGradientBrush($p0, $p1, $c0, $c1)
$brush2 = New-Object System.Drawing.Drawing2D.LinearGradientBrush($p2, $p3, $c2, $c3)

$form.add_paint(
{

$mypen.color = [System.Drawing.Color]::FromArgb(255, 255, 130, 0)
$mypen.width = 3     # ste the pen line width

$formGraphics.FillRectangle($brush1, 0, 80, 240, 3)
$formGraphics.FillRectangle($brush2, 240, 80, 240, 3)

$formGraphics.DrawLine($mypen, 239, 81, 241, 81) 

}
)

$btnPrevious.Left = 50
$btnPrevious.Width = 80
$btnPrevious.Top = 250

$btnNext.Left = 350
$btnNext.Width = 80
$btnNext.Top = 250
$btnNext.Visible = $true

$btnOK.Left = 150
$btnOK.Width = 80
$btnOK.Top = 250
$btnOK.Visible = $true
$btnOK.Enabled = $false

$btnCancel.Left = 250
$btnCancel.Width = 80
$btnCancel.Top = 250

#endregion formconfig

$txtUsername.Text = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

$btnOK.add_click({
	$global:ScopingResults = New-Object PSObject
	$global:ScopingResults | Add-Member NoteProperty Computername $Servername_Value.Text
	$global:ScopingResults | Add-Member NoteProperty Instancename $Instancename_Value.Text
	$global:ScopingResults | Add-Member NoteProperty InstancePort $InstancePort_Value.Text
	$global:ScopingResults | Add-Member NoteProperty IsClustered $chkIsClustered.Checked
	$global:ScopingResults | Add-Member NoteProperty Databasename $cboDatabase.Text
	If ($Availabilitygroupname_Value.Text -eq '(none)') {
		$global:ScopingResults | Add-Member NoteProperty AvailabilityGroup ([String]$null)
	}
	else {
		$global:ScopingResults | Add-Member NoteProperty AvailabilityGroup $Availabilitygroupname_Value.Text
	}
	$global:ScopingResults | Add-Member NoteProperty SaveWindowsCredentials $chkSaveWindowsCredentials.Checked
	$global:ScopingResults | Add-Member NoteProperty Authentication $cboAuthentication.Text
	$global:ScopingResults | Add-Member NoteProperty SQL_Username $txtUsername.Text
	if ($txtPassword.Text) {
		$global:ScopingResults | Add-Member NoteProperty SQL_Password ($txtPassword.Text | ConvertTo-SecureString -AsPlainText -Force)
	}
	else {
		$global:ScopingResults | Add-Member NoteProperty SQL_Password [String]$null
	}
	$ClusterType = "NONE"
	If ($global:ScopingResults.IsClustered -or $global:ScopingResults.AvailabilityGroup) {
		$ClusterType = "WSFC"
		$ClusterNodes = @()
		try {
			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			if ($cboAuthentication.Text -eq 'Windows Authentication') {
				$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = True;Network Library=DBMSSOCN;Connect Timeout=5"
			}
			else {
				$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = False;User ID=$($txtUsername.Text);Password=$($txtPassword.Text);Network Library=DBMSSOCN;Connect Timeout=5"
			}
			#$SqlConnection.ConnectionTimeout = 10
			$SqlConnection.Open() | Out-Null
		 				
			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.Connection = $SqlConnection

			$SqlCmd.CommandText = "
			DECLARE @ProductVersion VARCHAR(20)
			DECLARE @ProductMinorVersion DECIMAL(5,2)
			SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
			SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
			SELECT @ProductMinorVersion ProductMinorVersion
			"
			$ProductMinorVersion = $SqlCmd.ExecuteScalar()

			if (($Availabilitygroupname_Value.Text -ne '' -and $Availabilitygroupname_Value.Text -ne '(none)') -or ($ProductMinorVersion -ge 12)) {
				$SqlCmd.CommandText = "SELECT member_name FROM sys.dm_hadr_cluster_members WHERE member_type = 0 ORDER BY 1"
				$Reader = $SqlCmd.ExecuteReader()
				while($Reader.Read())
				{		
					$ClusterNodes += $Reader["member_name"]
				}
				$reader.Close()
			}
			if ($Availabilitygroupname_Value.Text -eq '' -or $Availabilitygroupname_Value.Text -eq '(none)') {
				$FCINodes = @()
				$SqlCmd.CommandText = "SELECT NodeName FROM sys.dm_os_cluster_nodes"
				$Reader = $SqlCmd.ExecuteReader()
				while($Reader.Read())
				{		
					$FCINodes += $Reader["NodeName"]
				}
				$reader.Close()
				foreach ($FCINode in $FCINodes) {
					if ($ClusterNodes -notcontains $FCINode) {
						$ClusterNodes += $FCINode
					}
				}
				$ClusterNodes = $ClusterNodes | Sort-Object
			}
			if ($ProductMinorVersion -ge 14 -and $Availabilitygroupname_Value.Text -ne '' -and $Availabilitygroupname_Value.Text -ne '(none)') {
				$SqlCmd.CommandText = "SELECT cluster_type FROM sys.availability_groups WHERE name = '$($Availabilitygroupname_Value.Text)'"
				$nClusterType = $SqlCmd.ExecuteScalar()
				if ($nClusterType -ne 0) {
					if ($nClusterType -eq 1) {
						$ClusterType = "NONE"
					}
					if ($nClusterType -eq 2) {
						$ClusterType = "EXTERNAL"
					}
				}
			}
			$SqlConnection.Close()
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
		
		if ( -not $ClusterNodes) {
			try {
				$ClusterNodes = ((Invoke-Command -Computername $global:ScopingResults.Computername -ScriptBlock { Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | sort-object name | Select-Object -ExpandProperty name } -ErrorAction Stop ) | Sort-Object)
			}
			catch {
				if ($PSBoundParameters['Verbose']) {
					$ErrorString = $_ | format-list -force | Out-String
					Write-Host $ErrorString -ForegroundColor Red
				}
				try {
					$cred =  $host.ui.PromptForCredential("Need credentials for $($global:ScopingResults.Computername) cluster info", "Please enter your user name and password.", "", "")
					$ClusterNodes = ((Invoke-Command -Computername $global:ScopingResults.Computername -Credential $cred -ScriptBlock { Get-WmiObject -namespace 'root\mscluster' MSCluster_Node | sort-object name | Select-Object -ExpandProperty name } ) | Sort-Object)
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
			}
		}
		$global:ScopingResults | Add-Member NoteProperty ClusterNodes $ClusterNodes
		$global:ScopingResults | Add-Member NoteProperty ClusterType $ClusterType
	}
	else {
		$ClusterNodes = @()
		$ClusterNodes += $Servername_Value.Text
		$global:ScopingResults | Add-Member NoteProperty ClusterNodes $ClusterNodes
		$global:ScopingResults | Add-Member NoteProperty ClusterType $ClusterType
	}
	#$global:ScopingResults | Add-Member NoteProperty MacAddresses (New-Object PSObject)
	#for ($i = 0; $i -lt $ClusterNodes.Count; $i++) 
	#{ 
	#	$global:ScopingResults.MacAddresses | Add-Member NoteProperty $ClusterNodes[$i] [String]$null
	#}
	$form.Close()
})
$btnCancel.add_click({$form.Close()})

$txtServername.Add_TextChanged( {
	
	if ($txtServername.Text -ne '') {
		$btnNext.Enabled = $true
	}
	else {
		$btnNext.Enabled = $false
	}
}
)

$cboAuthentication.Add_SelectedIndexChanged({
	If ( $cboAuthentication.Text -eq 'SQL Server Authentication' ) {
		$txtUsername.ReadOnly = $false
		$txtPassword.ReadOnly = $false
		$txtPassword.Enabled = $true
		$txtUsername.Text = ''
		$txtPassword.Text = ''
	}
	else {
		$txtUsername.ReadOnly = $true
		$txtPassword.ReadOnly = $true
		$txtPassword.Enabled = $false
		$txtUsername.Text = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
		$txtPassword.Text = ''
	}
}
)

$btnNext.Add_Click({
	
	$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor

	try {
		$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
		if ($cboAuthentication.Text -eq 'Windows Authentication') {
			$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = True;Network Library=DBMSSOCN;Connect Timeout=5"
		}
		else {
			$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = False;User ID=$($txtUsername.Text);Password=$($txtPassword.Text);Network Library=DBMSSOCN;Connect Timeout=5"
		}
		#$SqlConnection.ConnectionTimeout = 10
		$SqlConnection.Open() | Out-Null
	 
		$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
		$SqlCmd.Connection = $SqlConnection

		$SqlCmd.CommandText = "
		SELECT IS_SRVROLEMEMBER('sysadmin')
		"
		[Boolean]$IS_SRVROLEMEMBER = $SqlCmd.ExecuteScalar()
		If ($IS_SRVROLEMEMBER -eq $false) {
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
			[System.Windows.Forms.MessageBox]::Show( "Current user is not member of the sysadmin fixed server role!", "$global:modulename : Warning",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
			return
		}

		$SqlCmd.CommandText = "
		DECLARE @Servername VARCHAR(255)
		SET @Servername = CONVERT(VARCHAR(255),SERVERPROPERTY('MachineName'))
		SELECT @Servername Servername
		"
		$Servername_Value.Text = $SqlCmd.ExecuteScalar()

		$SqlCmd.CommandText = "
		DECLARE @Instancename VARCHAR(255)
		SET @Instancename = CONVERT(VARCHAR(255),SERVERPROPERTY('InstanceName'))
		SELECT ISNULL(@Instancename, 'MSSQLSERVER') Instancename
		"
		$Instancename_Value.Text = $SqlCmd.ExecuteScalar()
		
		if ($Instancename_Value.Text -eq 'MSSQLSERVER') {
			$lblBackslash.Visible = $false
			$Instancename_Value.Visible = $false
		}
		else {
			$lblBackslash.Visible = $true
			$lblBackslash.Left = $Servername_Value.Left + $Servername_Value.Width
			$Instancename_Value.Left = $lblBackslash.Left + $lblBackslash.Width
		}
		$SqlCmd.CommandText = "
		DECLARE @InstancePort VARCHAR(255)
		SET @InstancePort = (SELECT local_tcp_port FROM sys.dm_exec_connections WHERE session_id = @@SPID)
		SELECT ISNULL(@InstancePort, '') InstancePort
		"
		$InstancePort_Value.Text = $SqlCmd.ExecuteScalar()
		$lblComma.Visible = $true
		$lblComma.left = $Instancename_Value.Left + $Instancename_Value.Width
		$InstancePort_Value.Visible = $true
		$InstancePort_Value.Left = $lblComma.Left + $lblComma.Width
		
		$SqlCmd.CommandText = "
		DECLARE @ProductVersion VARCHAR(20)
		DECLARE @ProductMinorVersion DECIMAL(5,2)
		SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
		SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
		SELECT @ProductMinorVersion ProductMinorVersion
		"
		$ProductMinorVersion = $SqlCmd.ExecuteScalar()

		$SqlCmd.CommandText = "
		DECLARE @IsClustered INT
		SET @IsClustered = CONVERT(INT,SERVERPROPERTY('IsClustered'))
		SELECT @IsClustered IsClustered
		"
		[Boolean]$IsClustered = $SqlCmd.ExecuteScalar()
		If ($IsClustered -eq $true) {
			$chkIsClustered.Checked = $true #[System.Windows.Forms.CheckState]::Checked
		}
		$IsClustered_Value.Text = ($chkIsClustered.Checked -eq $true)
		$IsClustered_Value.Text = $IsClustered_Value.Text.ToUpper()

		If ($ProductMinorVersion -lt 11.0) {
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
			[System.Windows.Forms.MessageBox]::Show( "$Global:ModuleName is only supported for SQL Server 2012 and newer. $Global:ModuleName detected SQL Server ProductVersion {0:N2}!" -f $ProductMinorVersion, "$global:modulename : Warning",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
			return
		}

		If ($ProductMinorVersion -ge 14.0) {
			$SqlCmd.CommandText = 'SELECT host_platform FROM sys.dm_os_host_info'
			[String]$HostPlatform = $SqlCmd.ExecuteScalar()
			if ($HostPlatform -eq 'Linux') {
				$form.Cursor = [System.Windows.Forms.Cursors]::Default
				[System.Windows.Forms.MessageBox]::Show( "$Global:ModuleName is currently not supported on Linux.", "$global:modulename : Warning",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
				return
			}
		}
		
		#$SqlCmd.CommandText = 'SELECT windows_release FROM sys.dm_os_windows_info'
		$SqlCmd.CommandText = 'SET NOCOUNT ON
		DECLARE @WindowsVersion TABLE ([Index] INT, [Name] VARCHAR(255), [Internal_Value] INT, [Character_Value] VARCHAR(255))
		INSERT INTO @WindowsVersion
		exec xp_msver ''WindowsVersion''
		SELECT LEFT(Character_Value, CHARINDEX('' '', Character_Value) - 1) WindowsVersion FROM @WindowsVersion'
		
		[Double]$WindowsRelease = $SqlCmd.ExecuteScalar()
		If ($WindowsRelease -lt 6.2) {
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
			[System.Windows.Forms.MessageBox]::Show( "$Global:ModuleName is only supported for Windows Server 2012 and newer. $Global:ModuleName detected Windows Server version {0:N2}!" -f $WindowsRelease, "$global:modulename : Warning",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
			return
		}		
		
		$SqlCmd.CommandText = 'SELECT name FROM sys.databases WHERE is_distributor = 0 AND state = 0 AND is_read_only = 0 AND page_verify_option <> 0 AND database_id > 4 AND DATABASEPROPERTYEX(name,''Updateability'') = ''READ_WRITE'' ORDER BY name'

		$reader = $SqlCmd.ExecuteReader()
		while ($reader.Read())
		{
	   		$db_name = $reader.GetValue(0);
			$cboDatabase.Items.Add($db_name)
		}
		$reader.Close()
		$SqlConnection.Close()
		
		$txtServername.Enabled = $false
		$lblAuthentication.Visible = $false
		$cboAuthentication.Visible = $false
		$lblUsername.Visible = $false
		$txtUsername.Visible = $false
		$lblPassword.Visible = $false
		$txtPassword.Visible = $false
		
		$btnNext.Enabled = $false
		$btnPrevious.Enabled = $true
		$lblDatabase.Visible = $true
		$cboDatabase.Visible = $true
		$cboDatabase.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
	    $cboDatabase.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
		$cboDatabase.focus()
		$lblAvailabilityGroups.Visible = $true
		$cboAvailabilityGroups.Visible = $true
		$lblIsClustered.Visible = $true
		$chkIsClustered.Visible = $true
		$lblSaveWindowsCredentials.Visible = $true
		$chkSaveWindowsCredentials.Visible = $true
		$lblSaveWindowsCredentialsDesc.Visible = $true
		$chkSaveWindowsCredentials.Enabled = $true
		
		#$cboAvailabilityGroups.AutoCompleteMode = [System.Windows.Forms.AutoCompleteMode]::SuggestAppend
	    #$cboAvailabilityGroups.AutoCompleteSource = [System.Windows.Forms.AutoCompleteSource]::ListItems
		$form.Cursor = [System.Windows.Forms.Cursors]::Default
	}
	catch {
		$err = $_.Exception
		$form.Cursor = [System.Windows.Forms.Cursors]::Default
		$MessageText = "Could not connect to SQL Server." + "`r`n" + $err.Message
		[System.Windows.Forms.MessageBox]::Show( $MessageText , "$global:modulename : Error",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
	}
}
)

$btnPrevious.Add_Click({	
	$lblAuthentication.Visible = $true
	$cboAuthentication.Visible = $true
	$lblUsername.Visible = $true
	$txtUsername.Visible = $true
	$lblPassword.Visible = $true
	$txtPassword.Visible = $true
	if ($txtServername.Text -ne '') {
		$btnNext.Enabled = $true
	}
	else {
		$btnNext.Enabled = $false
	}
	$txtServername.Enabled = $true
	$cboDatabase.Items.Clear()
	$cboAvailabilityGroups.Items.Clear()
	$btnPrevious.Enabled = $false
	$lblDatabase.Visible = $false
	$cboDatabase.Visible = $false
	$lblAvailabilityGroups.Visible = $false
	$lblAvailabilityGroups.Visible = $false
	$cboAvailabilityGroups.Enabled = $false
	$cboDatabase.SelectedIndex = -1
	$cboDatabase.Text = ''
	$lblIsClustered.Visible = $false
	$chkIsClustered.Visible = $false
	$chkIsClustered.Checked = $false # [System.Windows.Forms.CheckState]::Unchecked
	$lblSaveWindowsCredentials.Visible = $false
	$chkSaveWindowsCredentials.Visible = $false
	$lblSaveWindowsCredentialsDesc.Visible = $false
	$chkSaveWindowsCredentials.Checked = $false # [System.Windows.Forms.CheckState]::Unchecked
	$chkSaveWindowsCredentials.Enabled = $false
	$Servername_Value.Text = ''
	$Databasename_Value.Text = ''
	$Instancename_Value.Text = ''
	$InstancePort_Value.Text = ''
	$Availabilitygroupname_Value.Text = ''
	$IsClustered_Value.Text = ''
	$lblBackslash.Visible = $false
	$lblComma.Visible = $false
	$btnOK.Enabled = $false
}
)

$cboDatabase.Add_SelectedIndexChanged({
	If ( $cboDatabase.Items -contains $cboDatabase.Text ) {
		$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
		try {
			$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
			if ($cboAuthentication.Text -eq 'Windows Authentication') {
				$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = True;Network Library=DBMSSOCN;Connect Timeout=10"
			}
			else {
				$SqlConnection.ConnectionString = "Server = $($txtServername.Text); Database = master; Integrated Security = False;User ID=$($txtUsername.Text);Password=$($txtPassword.Text);Network Library=DBMSSOCN;Connect Timeout=10"
			}
			#$SqlConnection.ConnectionTimeout = 10
			$SqlConnection.Open()
		 
			$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
			$SqlCmd.Connection = $SqlConnection
			$SqlCmd.CommandText = "
			DECLARE @ProductVersion VARCHAR(20)
			DECLARE @ProductMinorVersion DECIMAL(5,2)
			SET @ProductVersion = CONVERT(VARCHAR(20),SERVERPROPERTY('ProductVersion'))
			SET @ProductMinorVersion = CONVERT(NUMERIC(5,2),LEFT(@ProductVersion, CHARINDEX('.', @ProductVersion,4)-1))
			SELECT @ProductMinorVersion ProductMinorVersion
			"
			[Int16]$AG_Cnt = 0
			$ProductMinorVersion = $SqlCmd.ExecuteScalar()
			if ($ProductMinorVersion -ge 11.0) {
				$SqlCmd.CommandText = "
				SELECT ag.name FROM sys.databases d INNER JOIN
				sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
				sys.availability_groups ag ON ar.group_id = ag.group_id
				WHERE d.name = '$($cboDatabase.Text)'
				"
				[String]$AG_Name = $SqlCmd.ExecuteScalar()
				$SqlCmd.CommandText = "
				SELECT COUNT(*) FROM sys.databases d INNER JOIN
				sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
				sys.availability_groups ag ON ar.group_id = ag.group_id
				"
				[Int16]$AG_Cnt = $SqlCmd.ExecuteScalar()
				if ($AG_Cnt -gt 0) {
					$cboAvailabilityGroups.Enabled = $true
					$SqlCmd.CommandText = 'SELECT DISTINCT ag.name FROM sys.databases d INNER JOIN
					sys.availability_replicas ar ON d.replica_id = ar.replica_id INNER JOIN
					sys.availability_groups ag ON ar.group_id = ag.group_id ORDER BY ag.name'
					$cboAvailabilityGroups.Items.Clear()
					$cboAvailabilityGroups.Items.Add('(none)')
					$reader = $SqlCmd.ExecuteReader()
					while ($reader.Read())
					{
				   		$agname = $reader.GetValue(0);
						$cboAvailabilityGroups.Items.Add($agname)
					}
					if ($AG_Name) {
						$cboAvailabilityGroups.Text = $AG_Name
					}
					else {
						$cboAvailabilityGroups.SelectedIndex = 0
					}
					$reader.Close()
					$SqlConnection.Close()					
				}
			}
						
			$Databasename_Value.Text = $cboDatabase.Text
			$btnOK.Enabled = $true
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
		}
		catch {
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
			$MessageText = "Could not connect to SQL Server." + "`r`n" + $Error[0].Exception.ToString
			#Write-Host $Error[0]
			[System.Windows.Forms.MessageBox]::Show( $MessageText , "$global:modulename : Error",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
		}
	}
	else {
		$btnOK.Enabled = $false
	}
	#$form.DoEvents()
}
)

$cboAvailabilityGroups.Add_SelectedIndexChanged({
	$Availabilitygroupname_Value.Text = $cboAvailabilityGroups.Text
})

$drc = $form.ShowDialog()

return $drc

}
