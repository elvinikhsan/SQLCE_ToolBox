#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
# ----------------------------------------------------------------------------- 
# Script: Show-EULA.psm1 
# Author: oliverha 
# Date: 01/17/2019 21:06:32
# Version:  5.0
# Keywords: 
# comments: 
# 3.0 Initial version for SQL 2016 release
# 4.0 Initial version for SQL 2017 release
# 5.0 Initial version for SQL 2019 release
# ----------------------------------------------------------------------------- 
function Show-EULA 
{
 <# 
   .Synopsis 
    Shows EULA dialog
   .Description
    Shows EULA dialog
   .Notes  
   .Example 
    Show-EULA   
   .Link 
    http://aka.ms/sqlres
 #> 
[CmdletBinding()]
param()
Set-StrictMode -Version 2.0

Add-Type -AssemblyName System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size @(640,480)

$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = 'FixedDialog'

#$global:modulename = "SQLRES"

$form.Text = "$global:modulename (EULA)"
$form.MinimizeBox = $false
$form.MaximizeBox = $false

$txtBox = New-Object System.Windows.Forms.RichTextBox


$btnAccept = New-Object System.Windows.Forms.Button
$btnCancel = New-Object System.Windows.Forms.Button

$btnAccept.DialogResult = [System.Windows.Forms.DialogResult]::OK
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

$btnAccept.Text = "&I Accept"
$btnCancel.Text = "&Cancel"
$btnAccept.Enabled = $false

$form.AcceptButton = $btnAccept
$form.CancelButton = $btnCancel

$btnAccept.add_click({$form.Close()})
$btnCancel.add_click({$form.Close()})

$txtBox.Text = "Click here"
$form.Controls.Add($txtBox)
$form.Controls.Add($btnAccept)
$form.Controls.Add($btnCancel)
$txtBox.Multiline = $true

$Form.Add_Shown({$Form.Activate(); $btnCancel.focus()})

$txtBox.ReadOnly = $true

$txtBox.Left = 10
$txtBox.Top = 10
$txtBox.Width = 610
$txtBox.Height = 380

$EULAPath = $(resolve-path .).ToString() + "\" + "EULA.rtf"

$txtBox.LoadFile($EULAPath )

$a = "##global:modulename##"

while ($txtBox.Text.IndexOf("##global:modulename##") -ne -1)
{

    $txtBox.SelectionStart = $txtBox.Text.IndexOf("##global:modulename##")
    $txtBox.SelectionLength = $a.Length
    $txtBox.SelectedText = $global:modulename

}

$txtBox.Add_VScroll( {
# code is in a 'here' string 
$signature=@' 
[DllImport("user32.dll")]
public static extern int GetScrollPos(IntPtr hwnd, int nBar);
'@ 
 
# call Add-Type to compile code 
$GetScrollInfo = Add-Type -memberDefinition $signature -name "GetScrollInfo" -namespace Win32Functions -passThru 

$VPos = $GetScrollInfo::GetScrollPos($txtBox.Handle , 1) 

if ($VPos -gt 500) {
    $btnAccept.Enabled = $true
}

})

$btnAccept.Left = 200
$btnAccept.Width = 100
$btnAccept.Top = 400
$btnCancel.Left = 320
$btnCancel.Width = 100
$btnCancel.Top = 400

$drc = $form.ShowDialog()

return $drc

}
