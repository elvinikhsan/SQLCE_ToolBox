#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Show-SaveWindowsCredentials.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Show-SaveWindowsCredentials 
{
 <# 
   .Synopsis 
    Shows credentials saving dialog
   .Description
    Shows credentials saving dialog
   .Notes  
   .Example 
    Show-SaveWindowsCredentials
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region formconfig

$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size @(480,320)

$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'

#$global:modulename = "SQLRES"

$form.Text = "$global:modulename : Store Windows Credentials"
$form.MinimizeBox = $false
$form.MaximizeBox = $false

function c_label ($iname, $iposx, $iposy, $isizex, $isizey)
{
   $sText = $iname
   $iname = New-Object System.Windows.Forms.Label
   $iname.Location = New-Object System.Drawing.Size($iposx, $iposy) 
   $iname.Size = New-Object System.Drawing.Size($isizex, $isizey) 
   $iname.Tag = $sText
   $iname
}

function c_button ($iname, $iposx, $iposy, $isizex, $isizey)
{
   $sText = $iname
   $iname = New-Object System.Windows.Forms.Button
   $iname.Location = New-Object System.Drawing.Size($iposx, $iposy) 
   $iname.Size = New-Object System.Drawing.Size($isizex, $isizey) 
   $iname.Tag = $sText
   $iname 
}

$labels = @()
$labelsUser = @()
$buttonsAdd = @()
$buttonsCpy = @()
$buttonsClear = @()
for ([int16]$i = 0; $i -lt ($global:ScopingResults.ClusterNodes.Count); $i++) {
    # Create the textbox
	$x = 20
	$y = 30
    $name = "label$i"
    $label = c_label $name $x (($i * $y) + 120) 100 20
    $label.Text = $global:ScopingResults.ClusterNodes[$i]
    $labels += $label
    $form.Controls.Add($labels[-1])
	
	$x = 120
	$y = 30
    $name = "button$i"
    $button = c_button $name $x (($i * $y) + 120) 20 20
    $button.Text = "+"
	$button.Add_Click( [Scriptblock]::Create("Func_Add $i"))
    $buttonsAdd += $button
	#$buttonsAdd[-1].Add_Click( [Scriptblock]::Create("Func_Add $i") )
    #$form.Controls.Add($buttonsAdd[-1])
    $form.Controls.Add($button)

	$x = 150
	$y = 30
    $name = "button$i"
    $button = c_button $name $x (($i * $y) + 120) 20 20
    $button.Text = "-"
	$button.Add_Click( [Scriptblock]::Create("Func_Clear $i" ) )
    $buttonsClear += $button
    #$form.Controls.Add($buttonsClear[-1])
    $form.Controls.Add($button)

	$x = 180
	$y = 30
    $name = "button$i"
    $button = c_button $name $x (($i * $y) + 120) 20 20
    $button.Text = "C"
	$button.Add_Click( [Scriptblock]::Create("Func_Cpy $i" ) )
    $buttonsCpy += $button
    #$form.Controls.Add($buttonsCpy[-1])
    $form.Controls.Add($button)
	
	$x = 210
	$y = 30
    $name = "label$i"
    $label = c_label $name $x (($i * $y) + 120) 100 20
    $label.Text = "" #"CONTOSO\GlobalSQLSysAdmin"
	$label.AutoSize = $true
    $labelsUser += $label
    $form.Controls.Add($labelsUser[-1])
}

$buttonsCpy[0].Enabled = $false

$btnOK = New-Object System.Windows.Forms.Button
$btnCancel = New-Object System.Windows.Forms.Button

$lblDescription = New-Object System.Windows.Forms.Label
$lblDescription1 = New-Object System.Windows.Forms.Label
$lblDescription2 = New-Object System.Windows.Forms.Label
$lblDescription3 = New-Object System.Windows.Forms.Label

$btnOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

$btnOK.Text = "&OK"
$btnCancel.Text = "&Cancel"
$lblDescription.Text = "Please enter the corresponding credentials for every computer."
$lblDescription1.Text = "Add a credential with the (+) button"
$lblDescription2.Text = "Delete a credential with the (-) button"
$lblDescription3.Text = "Adopt the credential from the line above with the (C) button"

$btnOK.Left = 150
$btnOK.Width = 80
$btnOK.Top = 250
$btnOK.Visible = $true
$btnOK.Enabled = $false

$btnCancel.Left = 250
$btnCancel.Width = 80
$btnCancel.Top = 250

$lblDescription.Top = 20
$lblDescription1.Top = 40
$lblDescription2.Top = 60
$lblDescription3.Top = 80

$lblDescription.Left = 20
$lblDescription1.Left = 20
$lblDescription2.Left = 20
$lblDescription3.Left = 20

$lblDescription.AutoSize = $true
$lblDescription1.AutoSize = $true
$lblDescription2.AutoSize = $true
$lblDescription3.AutoSize = $true

$btnOK.Top = $labels[$labels.Count - 1].Top + 50
$btnCancel.Top = $labels[$labels.Count - 1].Top + 50

$form.Height = $labels[$labels.Count - 1].Top + 120

$form.AcceptButton = $btnOK
$form.CancelButton = $btnCancel

#$btn.add_click({Get-Date|Out-Host})
#$txtBox.Text = "Click here"
$form.Controls.Add($btnOK)
$form.Controls.Add($btnCancel)
$form.Controls.Add($lblDescription)
$form.Controls.Add($lblDescription1)
$form.Controls.Add($lblDescription2)
$form.Controls.Add($lblDescription3)
#$form.Controls.Add($ttToolTip)

$Form.Add_Shown({$Form.Activate(); $btnCancel.focus()})

#endregion formconfig

#$global:ScopingResults | Add-Member NoteProperty Credentials @()
$global:ScopingResults | Add-Member NoteProperty Credentials (New-Object PSObject)

for ($i = 0; $i -lt $global:ScopingResults.ClusterNodes.Count; $i++) 
{ 
	$global:ScopingResults.Credentials | Add-Member NoteProperty $global:ScopingResults.ClusterNodes[$i] $null
}

Function Func_Cpy {
	param([Int16]$i)
	#[Int16]$i = ($Sender.Tag).Substring(($Sender.Tag).Length - 1,1)
	$global:ScopingResults.Credentials.($global:ScopingResults.ClusterNodes[$i]) = $global:ScopingResults.Credentials.($global:ScopingResults.ClusterNodes[$i-1])
	$labelsUser[$i].Text = $labelsUser[$i-1].Text
	
	[Boolean]$AllCredentialsAvailable = $true
	for ([Int16]$j=0; $j -lt ($global:ScopingResults.ClusterNodes.Count); $j++)
	{
		if ($labelsUser[$j].Text -eq "") {
			$AllCredentialsAvailable = $false
		}
	}
	if ($AllCredentialsAvailable) {
		$btnOK.Enabled = $true
	}	
}

Function Func_Clear {
	param([Int16]$i)
	#[Int16]$i = ($Sender.Tag).Substring(($Sender.Tag).Length - 1,1)
	$global:ScopingResults.Credentials.($global:ScopingResults.ClusterNodes[$i]) = $null
	$labelsUser[$i].Text = ""

	[Boolean]$AllCredentialsAvailable = $true
	for ([Int16]$j=0; $j -lt ($global:ScopingResults.ClusterNodes.Count); $j++)
	{
		if ($labelsUser[$j].Text -eq "") {
			$AllCredentialsAvailable = $false
			break
		}
	}
	if ($AllCredentialsAvailable -eq $false) {
		$btnOK.Enabled = $false
	}

}

Function Func_Add {
	param([Int16]$i)
	#[Int16]$i = ($Sender.Tag).Substring(($Sender.Tag).Length - 1,1)
	$Computername = $labels[$i].Text
	#Write-Host $i
	
	#$cred = Get-Credential -Credential $null | Out-Null
	$cred = $host.ui.PromptForCredential("Need credentials for $Computername", "Please enter your user name and password.", "", "")
	if ($cred) {
		$form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
		#Add-Type -AssemblyName System.DirectoryServices.AccountManagement
		#$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$Computername)
		#$PasswordCorrect = $DS.ValidateCredentials($cred.UserName, $cred.GetNetworkCredential().password)
		try {
			if ($Computername -eq "$env:Computername") {
				Add-Type -AssemblyName System.DirectoryServices.AccountManagement
				$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext('machine',$Computername)
				$PasswordCorrect = $DS.ValidateCredentials($cred.UserName, $cred.GetNetworkCredential().password)
			}
			else {
				Test-WSMan -ComputerName $Computername -Credential $cred -Authentication Default -ErrorAction Stop | Out-Null
				$PasswordCorrect = $true	
			}
		}
		catch {
			if ($PSBoundParameters['Verbose']) {
				$ErrorString = $_ | format-list -force | Out-String
				Write-Host $ErrorString -ForegroundColor Red
			}
			$PasswordCorrect = $false	
		}
		
		If ($PasswordCorrect) {	
			$global:ScopingResults.Credentials.($global:ScopingResults.ClusterNodes[$i]) = $cred
			$labelsUser[$i].Text = $global:ScopingResults.Credentials.($global:ScopingResults.ClusterNodes[$i]).Username
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
		}
		else {
			$form.Cursor = [System.Windows.Forms.Cursors]::Default
			[System.Windows.Forms.MessageBox]::Show( "The entered credentials are incorrect!" , "$global:modulename : Error",[System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
		}
		[Boolean]$AllCredentialsAvailable = $true
		for ([Int16]$j=0; $j -lt ($global:ScopingResults.ClusterNodes.Count); $j++)
		{
			if ($labelsUser[$j].Text -eq "") {
				$AllCredentialsAvailable = $false
				break
			}
		}
		if ($AllCredentialsAvailable) {
			$btnOK.Enabled = $true
		}
	}
}

$btnOK.add_click({
	$form.Close()
})
$btnCancel.add_click({$form.Close()})

$drc = $form.ShowDialog()

return $drc

}
