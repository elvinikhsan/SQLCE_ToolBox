<#
.SYNOPSIS
    Phase 2 - Adds/updates one Windows-Authentication connection string per RBS-enabled
    content database in Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config.
 
.DESCRIPTION
    Reads the RBS status CSV produced by Phase 1 (Detect-RBSEnabledDatabases.ps1),
    filters to databases where RBSEnabled = True, and for each one adds or updates a
    named connection string entry in the RBS Maintainer's .config file:
 
        name="RBSMaintainer_<DatabaseName>"
        connectionString="Server=<SqlInstance>;Database=<DatabaseName>;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
        providerName="System.Data.SqlClient"
 
    The connection string name is deterministic (RBSMaintainer_<DatabaseName>) so Phase 4
    (SQL Agent job generation) can compute the same -ConnectionStringName value without
    re-reading the config file.
 
    The existing default entry (RBSMaintainerConnection, created by the RBS installer) is
    left untouched. The script is idempotent: re-running it against the same CSV updates
    existing entries in place rather than duplicating them.
 
    A timestamped backup of the config file is taken before any write, and only if a
    change is actually needed.
 
.PARAMETER StatusCsv
    Path to the CSV produced by Detect-RBSEnabledDatabases.ps1 (Phase 1).
 
.PARAMETER ConfigPath
    Path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config.
 
.PARAMETER ConnectionStringPrefix
    Prefix used to build each connection string's name. Default 'RBSMaintainer_'.
 
.EXAMPLE
    .\Update-RBSMaintainerConfig.ps1 -StatusCsv .\Wave0_Databases_RBSStatus.csv `
        -ConfigPath "F:\RBS\Maintainer\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config"
 
.EXAMPLE
    # Preview changes without writing anything
    .\Update-RBSMaintainerConfig.ps1 -StatusCsv .\Wave0_Databases_RBSStatus.csv `
        -ConfigPath "F:\RBS\Maintainer\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" -WhatIf
 
.NOTES
    Assumes Windows Authentication end to end (unencrypted connection strings), per the
    environment's stated auth model. If the connectionStrings section is already
    encrypted (aspnet_regiis -pef was run against it), the script aborts rather than
    risk corrupting it - decrypt first (rename to web.config, aspnet_regiis -pdf
    connectionStrings, rename back) before running this.
#>
 
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$StatusCsv,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigPath,
 
    [string]$ConnectionStringPrefix = 'RBSMaintainer_'
)
 
# ---- Resolve to full filesystem paths ----
# Get-Content/Copy-Item resolve relative paths against PowerShell's working directory
# correctly, but [xml]::Save() is a raw .NET call that resolves relative paths against
# the process's current directory - which is not guaranteed to match, especially once
# this runs unattended under a SQL Agent job. Resolving to an absolute path up front
# avoids writing to (or backing up) the wrong location.
$StatusCsv  = (Resolve-Path -Path $StatusCsv).ProviderPath
$ConfigPath = (Resolve-Path -Path $ConfigPath).ProviderPath
 
# ---- Load and filter Phase 1 results ----
 
$statusRows = Import-Csv -Path $StatusCsv
 
$rbsDatabases = @($statusRows | Where-Object { $_.RBSEnabled -eq 'True' })
 
if ($rbsDatabases.Count -eq 0) {
    Write-Warning "No RBS-enabled databases found in '$StatusCsv'. Nothing to do."
    return
}
 
Write-Host "Found $($rbsDatabases.Count) RBS-enabled database(s) in '$StatusCsv'." -ForegroundColor Cyan
 
# ---- Load config as XML ----
 
[xml]$configXml = Get-Content -Path $ConfigPath -Raw
 
$connectionStringsNode = $configXml.configuration.connectionStrings
 
if ($connectionStringsNode -and $connectionStringsNode.EncryptedData) {
    throw "The <connectionStrings> section in '$ConfigPath' is encrypted (EncryptedData found). " +
          "This environment uses Windows Authentication and expects an unencrypted section. " +
          "Decrypt it first (rename to web.config, run 'aspnet_regiis -pdf connectionStrings', rename back) before re-running this script."
}
 
if (-not $connectionStringsNode) {
    Write-Host "No <connectionStrings> section found - creating one." -ForegroundColor Yellow
    $connectionStringsNode = $configXml.CreateElement('connectionStrings')
    $configXml.configuration.AppendChild($connectionStringsNode) | Out-Null
}
 
# ---- Add/update one entry per RBS-enabled database ----
 
$addedCount   = 0
$updatedCount = 0
 
foreach ($row in $rbsDatabases) {
    $dbName          = $row.DatabaseName
    $sqlInstance     = $row.SqlInstance
    $connStringName  = "$ConnectionStringPrefix$dbName"
    $connStringValue = "Server=$sqlInstance;Database=$dbName;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
 
    $existingNode = $connectionStringsNode.SelectSingleNode("add[@name='$connStringName']")
 
    # Count the planned action regardless of -WhatIf, so the summary/"no changes needed"
    # message reflects what was actually found - only the mutation itself is gated behind
    # ShouldProcess. Previously the counters lived inside the ShouldProcess block, so a
    # -WhatIf run always reported "0 added, 0 updated" even when changes were pending.
    if ($existingNode) {
        $updatedCount++
        if ($PSCmdlet.ShouldProcess($connStringName, "Update connection string")) {
            $existingNode.SetAttribute('connectionString', $connStringValue)
            $existingNode.SetAttribute('providerName', 'System.Data.SqlClient')
            Write-Host "  Updated: $connStringName" -ForegroundColor DarkGray
        }
    }
    else {
        $addedCount++
        if ($PSCmdlet.ShouldProcess($connStringName, "Add connection string")) {
            $newNode = $configXml.CreateElement('add')
            $newNode.SetAttribute('name', $connStringName)
            $newNode.SetAttribute('connectionString', $connStringValue)
            $newNode.SetAttribute('providerName', 'System.Data.SqlClient')
            $connectionStringsNode.AppendChild($newNode) | Out-Null
            Write-Host "  Added:   $connStringName" -ForegroundColor Green
        }
    }
}
 
# ---- Save (with backup), only if something actually changed ----
 
if ($addedCount -eq 0 -and $updatedCount -eq 0) {
    Write-Host "No changes needed - config already up to date." -ForegroundColor DarkGray
}
elseif ($PSCmdlet.ShouldProcess($ConfigPath, "Save updated config")) {
    $backupPath = "$ConfigPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $ConfigPath -Destination $backupPath -Force
    Write-Host "Backup written to: $backupPath" -ForegroundColor Cyan
 
    $configXml.Save($ConfigPath)
    Write-Host "Config saved: $ConfigPath" -ForegroundColor Cyan
}
 
Write-Host ""
Write-Host "Summary: $addedCount added, $updatedCount updated." -ForegroundColor Cyan
 