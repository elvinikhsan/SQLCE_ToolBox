<#
================================================================================
 Remove-LogShippingMigrationTracking.ps1

 Standalone cleanup utility for dbo.LogShippingInitTracking / LogShippingFileMapping
 (item 11a). Complements the -CleanupTracking switch on Start-LogShippingMigration.ps1
 (which only removes rows that are fully Complete) by also allowing:
   - forced removal of a wave's rows regardless of status (-Force)
   - dropping the tracking tables entirely once the whole migration project is done (-DropTables)

 EXAMPLES
 --------
 # Safe cleanup: remove only fully-completed rows for Wave1
 .\Remove-LogShippingMigrationTracking.ps1 -TrackingSqlInstance SQL-TGT01 -WaveName Wave1_Databases

 # Force-remove all rows for Wave1 regardless of status
 .\Remove-LogShippingMigrationTracking.ps1 -TrackingSqlInstance SQL-TGT01 -WaveName Wave1_Databases -Force

 # Drop the tracking tables entirely at the end of the whole migration project
 .\Remove-LogShippingMigrationTracking.ps1 -TrackingSqlInstance SQL-TGT01 -DropTables -Force
================================================================================
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$TrackingSqlInstance,
    [string]$TrackingDatabase = 'DBA_LogShippingMigration',

    [Parameter(ParameterSetName = 'Wave', Mandatory)][string]$WaveName,
    [Parameter(ParameterSetName = 'DropAll', Mandatory)][switch]$DropTables,

    [switch]$Force
)

Import-Module (Join-Path $PSScriptRoot 'LogShippingMigration.psm1') -Force
Assert-DbatoolsModule

if ($DropTables) {
    if (-not $Force) { throw "-DropTables requires -Force as a safety confirmation." }
    if ($PSCmdlet.ShouldProcess($TrackingSqlInstance, "DROP tracking tables/view in $TrackingDatabase")) {
        Invoke-DbaQuery -SqlInstance $TrackingSqlInstance -Database $TrackingDatabase -Query @"
IF OBJECT_ID('dbo.vw_LogShippingProgress', 'V') IS NOT NULL DROP VIEW dbo.vw_LogShippingProgress;
IF OBJECT_ID('dbo.LogShippingInitTracking', 'U') IS NOT NULL DROP TABLE dbo.LogShippingInitTracking;
IF OBJECT_ID('dbo.LogShippingFileMapping', 'U') IS NOT NULL DROP TABLE dbo.LogShippingFileMapping;
"@
        Write-MigrationLog "Dropped tracking tables/view in $TrackingDatabase on $TrackingSqlInstance."
    }
    return
}

if ($Force) {
    $sql = "DELETE FROM dbo.LogShippingInitTracking WHERE WaveName = @WaveName;"
}
else {
    $sql = @"
DELETE FROM dbo.LogShippingInitTracking
WHERE WaveName = @WaveName
  AND BackupStatus = 'Complete' AND CopyStatus = 'Complete' AND RestoreStatus = 'Complete'
  AND LogShippingConfigStatus IN ('Complete', 'Skipped');
"@
}

if ($PSCmdlet.ShouldProcess($TrackingSqlInstance, "DELETE tracking rows for wave '$WaveName'$(if ($Force) {' (forced, any status)'})")) {
    Invoke-DbaQuery -SqlInstance $TrackingSqlInstance -Database $TrackingDatabase -Query $sql -SqlParameters @{ WaveName = $WaveName } | Out-Null
    Write-MigrationLog "Tracking rows removed for wave '$WaveName'$(if ($Force) {' (forced)'} else {' (Complete rows only)'})."
}
