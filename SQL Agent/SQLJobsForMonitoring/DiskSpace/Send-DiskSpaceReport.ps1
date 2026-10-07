<#
.SYNOPSIS
    Emails an HTML report of every local disk volume on this server: size,
    used space, free space and free %, with free-space highlighting.

.DESCRIPTION
    Reads volumes from Windows (Win32_Volume), so every local fixed volume is
    listed - drive letters and mount points - whether or not it holds
    database files. The email is sent through SQL Server Database Mail
    (msdb.dbo.sp_send_dbmail), so no separate SMTP setup is needed.

    Highlighting on the Free (GB) and Free % cells:
      Free % <= 5   : red
      Free % <= 10  : orange
      Free % <= 15  : yellow

    Designed to run as a SQL Agent CmdExec job step (see
    Create_Job_DiskSpaceReport.sql). Exit code 0 = success, 1 = failure, so
    the job step fails visibly if anything goes wrong.

.NOTES
    - Reports the node the script runs on. On the FCI that is the node that
      currently owns the SQL Server role, so it sees all FCI cluster disks.
      Cluster disks owned by another cluster role/node (e.g. the quorum disk,
      if the core cluster group is on another node) are not visible.
    - Volumes without a drive letter or mount point (System Reserved,
      Recovery) are excluded.
    - Windows PowerShell 5.1 compatible. No extra modules required.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File Send-DiskSpaceReport.ps1 `
        -SqlInstance "VM-SQL01-DEV,1433" -MailProfile "DB_Mail" -Recipients "dba@contoso.com"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $SqlInstance,
    [Parameter(Mandatory = $true)] [string] $MailProfile,
    [Parameter(Mandatory = $true)] [string] $Recipients,      # semicolon-separated
    [decimal] $RedPct    = 5,
    [decimal] $OrangePct = 10,
    [decimal] $YellowPct = 15
)

$ErrorActionPreference = 'Stop'

try {
    # ---- Collect volumes -------------------------------------------------
    $volumes = Get-CimInstance -ClassName Win32_Volume -Filter 'DriveType = 3' |
        Where-Object { $_.Name -notlike '\\?\*' -and $_.Capacity -gt 0 } |
        Sort-Object -Property Name

    # ---- HTML styles (inline - Outlook ignores most <style> rules) -------
    $font   = "font-family:'Segoe UI',Arial,sans-serif;font-size:9pt;"
    $title  = $font + 'font-weight:700;color:#0078D4;'
    $th     = $font + 'background:#0078D4;color:#FFFFFF;font-weight:600;padding:4px 6px;border:1px solid #005A9E;text-align:left;white-space:nowrap;'
    $td     = $font + 'padding:3px 6px;border:1px solid #D9D9D9;white-space:nowrap;'
    $num    = 'text-align:right;'
    $bandA  = 'background:#FFFFFF;'
    $bandB  = 'background:#EAF3FB;'
    $red    = 'background:#FF5B5B;'
    $orange = 'background:#FFB366;'
    $yellow = 'background:#FFE666;'

    function Enc([string] $s) { [System.Net.WebUtility]::HtmlEncode($s) }
    function Gb([double] $bytes) { ($bytes / 1GB).ToString('N2') }

    # ---- Table rows ------------------------------------------------------
    $rows = New-Object System.Text.StringBuilder
    $i = 0
    foreach ($v in $volumes) {
        $i++
        $band     = if ($i % 2 -eq 0) { $bandB } else { $bandA }
        $used     = [double]$v.Capacity - [double]$v.FreeSpace
        $freePct  = [math]::Round(([double]$v.FreeSpace * 100.0 / [double]$v.Capacity), 2)
        $freeStyle =
            if     ($freePct -le $RedPct)    { $red }
            elseif ($freePct -le $OrangePct) { $orange }
            elseif ($freePct -le $YellowPct) { $yellow }
            else                             { $band }
        $label = if ([string]::IsNullOrEmpty($v.Label)) { '-' } else { Enc $v.Label }

        [void]$rows.Append('<tr>')
        [void]$rows.Append("<td style=""$td$band"">$(Enc $v.Name)</td>")
        [void]$rows.Append("<td style=""$td$band"">$label</td>")
        [void]$rows.Append("<td style=""$td$band$num"">$(Gb $v.Capacity)</td>")
        [void]$rows.Append("<td style=""$td$band$num"">$(Gb $used)</td>")
        [void]$rows.Append("<td style=""$td$freeStyle$num"">$(Gb $v.FreeSpace)</td>")
        [void]$rows.Append("<td style=""$td$freeStyle$num"">$($freePct.ToString('N2'))%</td>")
        [void]$rows.Append('</tr>')
    }
    if ($i -eq 0) {
        [void]$rows.Append("<tr><td colspan=""6"" style=""$td"">No volumes found.</td></tr>")
    }

    # ---- Body ------------------------------------------------------------
    $node    = [Environment]::MachineName
    $runTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $box     = 'padding:1px 6px;'

    $body = @"
<html><body style="$font">
<p style="$title">Disk Drive Space - $(Enc $node) (SQL instance: $(Enc $SqlInstance))</p>
<p style="$font">Generated: $runTime &nbsp;|&nbsp; Volumes: <span style="$($font)font-weight:700;">$i</span></p>
<p style="$font"><span style="$font$red$box">&nbsp;</span> Free &le; $RedPct% &nbsp;
<span style="$font$orange$box">&nbsp;</span> Free &le; $OrangePct% &nbsp;
<span style="$font$yellow$box">&nbsp;</span> Free &le; $YellowPct%</p>
<table style="border-collapse:collapse;$font">
<tr><th style="$th">Drive / Mount Point</th><th style="$th">Volume Label</th><th style="$th">Total Size (GB)</th><th style="$th">Used (GB)</th><th style="$th">Free (GB)</th><th style="$th">Free %</th></tr>
$($rows.ToString())
</table>
</body></html>
"@

    $subject = "[$node] Disk Drive Space - $(Get-Date -Format 'yyyy-MM-dd')"

    # ---- Send via Database Mail -----------------------------------------
    $conn = New-Object System.Data.SqlClient.SqlConnection(
        "Server=$SqlInstance;Database=msdb;Integrated Security=True;Application Name=Send-DiskSpaceReport")
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'EXEC msdb.dbo.sp_send_dbmail @profile_name = @p, @recipients = @r, @subject = @s, @body = @b, @body_format = ''HTML'';'
    $cmd.Parameters.Add('@p', [System.Data.SqlDbType]::NVarChar, 128).Value = $MailProfile
    $cmd.Parameters.Add('@r', [System.Data.SqlDbType]::NVarChar, -1).Value  = $Recipients
    $cmd.Parameters.Add('@s', [System.Data.SqlDbType]::NVarChar, 255).Value = $subject
    $cmd.Parameters.Add('@b', [System.Data.SqlDbType]::NVarChar, -1).Value  = $body

    $conn.Open()
    try     { [void]$cmd.ExecuteNonQuery() }
    finally { $conn.Close() }

    Write-Output "Disk space report sent: $i volume(s) on $node."
    exit 0
}
catch {
    Write-Output "ERROR: $($_.Exception.Message)"
    exit 1
}
