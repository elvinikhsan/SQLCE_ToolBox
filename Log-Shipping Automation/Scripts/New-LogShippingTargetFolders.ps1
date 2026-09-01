<#
================================================================================
 New-LogShippingTargetFolders.ps1

 Pre-flight step for the Initialize/restore phase: reads a DatabaseFileMapping
 CSV (the master file or a Wave{N}_DatabaseFileMapping.csv), works out every
 distinct target FOLDER those files will land in, and creates any that don't
 already exist on the target server.

 SQL Server does not create missing parent folders for a RESTORE ... WITH MOVE
 target - the folder must exist beforehand, or the restore fails with an
 "Operating system error 3 (The system cannot find the path specified.)".
 Running this first avoids that class of failure across a whole wave.

 Runs entirely over the SQL connection (via dbatools' Test-DbaPath and the
 master.sys.xp_create_subdir extended stored procedure) - no PowerShell
 Remoting, no need to log into the target server directly. It checks/creates
 folders from the SQL Server SERVICE ACCOUNT's perspective, which is exactly
 the account that needs to read/write them during backup/restore.

 FILESTREAM note: for a FILESTREAM entry, TargetPath is the container folder
 itself (e.g. 'T:\RBS-T\RBSFilestreamFile\Prime\Blob_SP_Content_BLNG'), and
 SQL Server creates that exact leaf folder itself as part of the restore - so
 this script only ensures the PARENT of each TargetPath exists (Split-Path
 -Parent), never the TargetPath leaf itself. That's also exactly correct for
 the ordinary .mdf/.ldf case (the parent folder must exist; the file itself
 is created by the restore) - one rule covers both, no need to know FileType.

 EXAMPLE
 -------
 .\New-LogShippingTargetFolders.ps1 -TargetSqlInstance vm-sql02-ag -MappingFile ..\Wave1_DatabaseFileMapping.csv

 # Preview only, don't actually create anything:
 .\New-LogShippingTargetFolders.ps1 -TargetSqlInstance vm-sql02-ag -MappingFile ..\Wave1_DatabaseFileMapping.csv -WhatIf
================================================================================
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TargetSqlInstance,
    [Parameter(Mandatory)][string]$MappingFile
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'LogShippingMigration.psm1') -Force
Assert-DbatoolsModule

if (-not (Test-Path $MappingFile)) { throw "Mapping file not found: $MappingFile" }

$rows = Import-Csv -Path $MappingFile
if (-not $rows) { throw "$MappingFile contains no rows." }

# Distinct parent folders across every row - shared folders (e.g. every ROWS file on
# one drive lands directly in the same DATA-<x> folder) collapse to one check/create.
$folders = $rows | ForEach-Object { Split-Path -Path $_.TargetPath -Parent } | Sort-Object -Unique

Write-MigrationLog "Checking $($folders.Count) distinct target folder(s) on $TargetSqlInstance (from $($rows.Count) file rows in $MappingFile)..."

$results = foreach ($folder in $folders) {
    $status = 'Unknown'
    $errorMessage = $null

    try {
        # -Path must be passed as an array (@($folder), not $folder). With a single scalar path
        # and a single instance, Test-DbaPath collapses to a plain boolean with no .IsContainer
        # property - accessing it then silently returns $null instead of erroring, so every
        # already-existing folder was falling through to the "create" branch below.
        $check = Test-DbaPath -SqlInstance $TargetSqlInstance -Path @($folder) -EnableException
        if ($check -and $check.IsContainer) {
            $status = 'AlreadyExists'
            Write-MigrationLog "  [Exists]  $folder"
        }
        else {
            if ($PSCmdlet.ShouldProcess($folder, "Create folder on $TargetSqlInstance")) {
                Invoke-DbaQuery -SqlInstance $TargetSqlInstance -Database 'master' -Query `
                    "EXEC master.sys.xp_create_subdir @Folder;" -SqlParameters @{ Folder = $folder } -EnableException | Out-Null

                # Re-check rather than trust a silent success, since xp_create_subdir doesn't
                # reliably raise a T-SQL error for every failure mode (e.g. some permission cases).
                $recheck = Test-DbaPath -SqlInstance $TargetSqlInstance -Path @($folder) -EnableException
                if ($recheck -and $recheck.IsContainer) {
                    $status = 'Created'
                    Write-MigrationLog "  [Created] $folder"
                }
                else {
                    $status = 'Failed'
                    $errorMessage = 'xp_create_subdir completed but the folder still does not appear to exist - check the SQL Server service account has write access to the parent path.'
                    Write-MigrationLog "  [Failed]  $folder - $errorMessage" -Level Error
                }
            }
            else {
                $status = 'WouldCreate'
            }
        }
    }
    catch {
        $status = 'Failed'
        $errorMessage = $_.Exception.Message
        Write-MigrationLog "  [Failed]  $folder - $errorMessage" -Level Error
    }

    [pscustomobject]@{
        Folder = $folder
        Status = $status
        Error  = $errorMessage
    }
}

$summary = $results | Group-Object Status | ForEach-Object { "$($_.Name)=$($_.Count)" }
Write-MigrationLog "Done. $($summary -join ', ')"

$failed = $results | Where-Object Status -eq 'Failed'
if ($failed) {
    Write-MigrationLog "$($failed.Count) folder(s) failed - review before running the Restore phase, or those restores will fail too." -Level Warn
}

$results
