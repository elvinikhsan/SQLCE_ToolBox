<#
================================================================================
 Start-LogShippingMigration.ps1

 Orchestrates SharePoint content database migration via log shipping:
   - Phase 'Initialize'          : seed backup (full copy-only + 1 log, compressed),
                                    copy backup files to the target share, restore
                                    WITH NORECOVERY on the target (WITH MOVE per the
                                    folder mapping).
   - Phase 'ConfigureLogShipping': configures the ongoing log shipping backup/copy/
                                    restore jobs (assumes Initialize already ran).
   - Phase 'Both'                : runs Initialize then ConfigureLogShipping.

 Two input modes (mutually exclusive):
   -WaveFile + -MappingFile   : bulk mode, processes every database listed in the
                                 wave file using DatabaseFileMapping.csv for target paths.
   -DatabaseName + -FileMap   : single ad-hoc database, target paths passed directly.

 Databases are processed smallest-first (by live source size) within a wave.
 Backup / Copy / Restore can each be toggled independently so large databases can
 have their (long) copy done today and restore done separately later - progress
 and status for every phase is persisted in dbo.LogShippingInitTracking on the
 tracking instance (run Sql\01_Create_LogShippingMigrationDB.sql once first).

 EXAMPLES
 --------
 # Wave 1, full initialization (backup + copy + restore), in one run:
 .\Start-LogShippingMigration.ps1 -Phase Initialize -EnableBackup -EnableCopy -EnableRestore `
     -SourceSqlInstance SQL-SRC01 -TargetSqlInstance SQL-TGT01 `
     -TrackingSqlInstance SQL-TGT01 `
     -SourceBackupShare '\\SQL-SRC01\LSBackups' -TargetBackupShare '\\SQL-TGT01\LSBackups' `
     -WaveFile .\Wave1_Databases.txt -MappingFile .\DatabaseFileMapping.csv

 # Same wave, restore only (backup/copy already done in an earlier run):
 .\Start-LogShippingMigration.ps1 -Phase Initialize -EnableRestore `
     -SourceSqlInstance SQL-SRC01 -TargetSqlInstance SQL-TGT01 -TrackingSqlInstance SQL-TGT01 `
     -SourceBackupShare '\\SQL-SRC01\LSBackups' -TargetBackupShare '\\SQL-TGT01\LSBackups' `
     -WaveFile .\Wave1_Databases.txt

 # Configure the ongoing log shipping jobs once initialization is verified complete:
 .\Start-LogShippingMigration.ps1 -Phase ConfigureLogShipping `
     -SourceSqlInstance SQL-SRC01 -TargetSqlInstance SQL-TGT01 -TrackingSqlInstance SQL-TGT01 `
     -SourceBackupShare '\\SQL-SRC01\LSBackups' -TargetBackupShare '\\SQL-TGT01\LSBackups' -WaveFile .\Wave1_Databases.txt `
     -BackupIntervalMinutes 15 -CopyIntervalMinutes 15 -RestoreIntervalMinutes 15 -MonitorServer SQL-MON01

 # Single ad-hoc database, initialize only:
 .\Start-LogShippingMigration.ps1 -Phase Initialize -EnableBackup -EnableCopy -EnableRestore `
     -SourceSqlInstance SQL-SRC01 -TargetSqlInstance SQL-TGT01 -TrackingSqlInstance SQL-TGT01 `
     -SourceBackupShare '\\SQL-SRC01\LSBackups' -TargetBackupShare '\\SQL-TGT01\LSBackups' `
     -DatabaseName SP_Content_Test -FileMap @{ SP_Content_Test = 'L:\DATA-L\SP_Content_Test.mdf'; SP_Content_Test_log = 'H:\LOG-H\SP_Content_Test_log.ldf' }
================================================================================
#>
[CmdletBinding(DefaultParameterSetName = 'Wave')]
param(
    [Parameter(Mandatory)][string]$SourceSqlInstance,
    [Parameter(Mandatory)][string]$TargetSqlInstance,
    [string]$TrackingSqlInstance = $TargetSqlInstance,
    [string]$TrackingDatabase = 'DBA_LogShippingMigration',

    [ValidateSet('Initialize', 'ConfigureLogShipping', 'Both')]
    [string]$Phase = 'Initialize',

    [switch]$EnableBackup,
    [switch]$EnableCopy,
    [switch]$EnableRestore,

    [string]$SourceBackupShare,
    [string]$TargetBackupShare,

    # Bulk mode
    [Parameter(Mandatory, ParameterSetName = 'Wave')][string]$WaveFile,
    [Parameter(ParameterSetName = 'Wave')][string]$MappingFile,

    # Single ad-hoc database mode
    [Parameter(Mandatory, ParameterSetName = 'Single')][string]$DatabaseName,
    [Parameter(ParameterSetName = 'Single')][hashtable]$FileMap,

    # Log-shipping job schedule intervals (Phase ConfigureLogShipping / Both)
    [int]$BackupIntervalMinutes = 15,
    [int]$CopyIntervalMinutes = 15,
    [int]$RestoreIntervalMinutes = 15,
    [int]$BackupRetentionMinutes = 4320,
    [int]$BackupThresholdMinutes = 60,
    [int]$RestoreThresholdMinutes = 45,
    # Optional: names the dedicated server to record log-shipping history/threshold alerts.
    # If omitted, source and target each default to monitoring themselves (dbatools' Invoke-DbaDbLogShipping
    # always registers a monitor - there's no "none at all" option - but self-monitoring is a normal,
    # fully supported configuration and needs no extra infrastructure).
    [string]$MonitorServer,

    [switch]$CleanupTracking,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'LogShippingMigration.psm1') -Force
Assert-DbatoolsModule

$doInit = $Phase -in @('Initialize', 'Both')
$doConfig = $Phase -in @('ConfigureLogShipping', 'Both')

if ($doInit -and (-not $SourceBackupShare -or -not $TargetBackupShare)) {
    throw "-SourceBackupShare and -TargetBackupShare are required when -Phase is 'Initialize' or 'Both'."
}
if ($doConfig -and (-not $SourceBackupShare -or -not $TargetBackupShare)) {
    throw "-SourceBackupShare and -TargetBackupShare are required when -Phase is 'ConfigureLogShipping' or 'Both' (the ongoing log-shipping backup share and the secondary's copy destination)."
}

# If none of the three phase switches were passed for Initialize, run all three by default.
$anyEnableGiven = $PSBoundParameters.ContainsKey('EnableBackup') -or $PSBoundParameters.ContainsKey('EnableCopy') -or $PSBoundParameters.ContainsKey('EnableRestore')
if ($doInit -and -not $anyEnableGiven) {
    $EnableBackup = $true; $EnableCopy = $true; $EnableRestore = $true
}

# ---------------------------------------------------------------------------
# Resolve database list, wave name and file mapping
# ---------------------------------------------------------------------------
if ($PSCmdlet.ParameterSetName -eq 'Wave') {
    $WaveName = [System.IO.Path]::GetFileNameWithoutExtension($WaveFile)
    $databases = Get-WaveDatabaseList -WaveFile $WaveFile
    Write-MigrationLog "Wave '$WaveName': $($databases.Count) database(s) from $WaveFile" -LogPath $LogPath

    $fileMapByDb = @{}
    if ($doInit -and $EnableRestore) {
        if ($MappingFile) {
            $fileMapByDb = Sync-FileMapping -MappingFile $MappingFile -DatabaseName $databases -WaveName $WaveName `
                -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase
        }
        else {
            Write-MigrationLog "No -MappingFile supplied; will read file mapping from the tracking DB for each database." -Level Warn
        }
    }
}
else {
    $WaveName = 'Adhoc'
    $databases = @($DatabaseName)
    $fileMapByDb = @{ $DatabaseName = $FileMap }
    Write-MigrationLog "Single-database ad-hoc run: $DatabaseName" -LogPath $LogPath
}

# ---------------------------------------------------------------------------
# Phase: Initialize (backup / copy / restore)
# ---------------------------------------------------------------------------
if ($doInit) {
    $queue = Initialize-TrackingQueue -SourceSqlInstance $SourceSqlInstance -WaveName $WaveName -DatabaseName $databases `
        -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase

    Write-MigrationLog "Processing order (smallest first): $((($queue | Sort-Object SequenceNo).DatabaseName) -join ', ')" -LogPath $LogPath

    foreach ($row in ($queue | Sort-Object SequenceNo)) {
        $db = $row.DatabaseName
        Write-MigrationLog "=== $db (Sequence $($row.SequenceNo), $($row.DatabaseSizeMB) MB) ===" -LogPath $LogPath

        try {
            $fullFile = $row.FullBackupFile
            $logFile = $row.LogBackupFile

            if ($EnableBackup) {
                if ($row.BackupStatus -eq 'Complete') {
                    Write-MigrationLog "  Backup already Complete, skipping." -LogPath $LogPath
                }
                else {
                    Write-MigrationLog "  Backup: starting full (copy-only) + log, compressed..." -LogPath $LogPath
                    $backupResult = Invoke-DatabaseBackupPhase -SourceSqlInstance $SourceSqlInstance -DatabaseName $db `
                        -SourceBackupShare $SourceBackupShare -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase -TrackingId $row.TrackingId
                    $fullFile = $backupResult.FullBackupFile
                    $logFile = $backupResult.LogBackupFile
                    Write-MigrationLog "  Backup complete: $fullFile, $logFile" -LogPath $LogPath
                }
            }

            if ($EnableCopy) {
                if ($row.CopyStatus -eq 'Complete') {
                    Write-MigrationLog "  Copy already Complete, skipping." -LogPath $LogPath
                }
                else {
                    if (-not $fullFile) { throw "No backup file recorded for $db - run the Backup phase first." }
                    Write-MigrationLog "  Copy: $fullFile, $logFile -> $TargetBackupShare ..." -LogPath $LogPath
                    $filesToCopy = @($fullFile); if ($logFile) { $filesToCopy += $logFile }
                    Invoke-DatabaseCopyPhase -SourceBackupShare $SourceBackupShare -TargetBackupShare $TargetBackupShare `
                        -FileName $filesToCopy -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase -TrackingId $row.TrackingId
                    Write-MigrationLog "  Copy complete." -LogPath $LogPath
                }
            }

            if ($EnableRestore) {
                if ($row.RestoreStatus -eq 'Complete') {
                    Write-MigrationLog "  Restore already Complete, skipping." -LogPath $LogPath
                }
                else {
                    if (-not $fullFile) { throw "No backup file recorded for $db - run the Backup (and Copy) phase first." }
                    $map = if ($fileMapByDb.ContainsKey($db)) { $fileMapByDb[$db] } `
                        else { Get-FileMappingFromTracking -DatabaseName $db -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase }
                    Write-MigrationLog "  Restore: WITH NORECOVERY, WITH MOVE ($($map.Count) file(s))..." -LogPath $LogPath
                    Invoke-DatabaseRestorePhase -TargetSqlInstance $TargetSqlInstance -DatabaseName $db -TargetBackupShare $TargetBackupShare `
                        -FullBackupFile $fullFile -LogBackupFile $logFile -FileMap $map `
                        -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase -TrackingId $row.TrackingId
                    Write-MigrationLog "  Restore complete (database left WITH NORECOVERY)." -LogPath $LogPath
                }
            }
        }
        catch {
            Write-MigrationLog "  FAILED: $($_.Exception.Message)" -Level Error -LogPath $LogPath
            # Continue with the next database rather than aborting the whole wave.
            continue
        }
    }
}

# ---------------------------------------------------------------------------
# Phase: ConfigureLogShipping
# ---------------------------------------------------------------------------
if ($doConfig) {
    foreach ($db in $databases) {
        $trackingRow = Invoke-DbaQuery -SqlInstance $TrackingSqlInstance -Database $TrackingDatabase -Query `
            "SELECT TOP 1 * FROM dbo.LogShippingInitTracking WHERE WaveName = @WaveName AND DatabaseName = @DatabaseName" `
            -SqlParameters @{ WaveName = $WaveName; DatabaseName = $db }

        if (-not $trackingRow -or $trackingRow.RestoreStatus -ne 'Complete') {
            Write-MigrationLog "$db - RestoreStatus is not Complete (initialization must finish before log shipping is configured). Skipping." -Level Warn -LogPath $LogPath
            continue
        }

        try {
            Write-MigrationLog "=== $db : configuring log shipping (backup ${BackupIntervalMinutes}m / copy ${CopyIntervalMinutes}m / restore ${RestoreIntervalMinutes}m) ===" -LogPath $LogPath
            Invoke-ConfigureLogShippingPhase -SourceSqlInstance $SourceSqlInstance -TargetSqlInstance $TargetSqlInstance -DatabaseName $db `
                -SourceBackupShare $SourceBackupShare -TargetBackupShare $TargetBackupShare -BackupIntervalMinutes $BackupIntervalMinutes -CopyIntervalMinutes $CopyIntervalMinutes `
                -RestoreIntervalMinutes $RestoreIntervalMinutes -BackupRetentionMinutes $BackupRetentionMinutes `
                -BackupThresholdMinutes $BackupThresholdMinutes -RestoreThresholdMinutes $RestoreThresholdMinutes -MonitorServer $MonitorServer `
                -TrackingInstance $TrackingSqlInstance -TrackingDatabase $TrackingDatabase -TrackingId $trackingRow.TrackingId
            Write-MigrationLog "  Log shipping configured." -LogPath $LogPath
        }
        catch {
            Write-MigrationLog "  FAILED: $($_.Exception.Message)" -Level Error -LogPath $LogPath
            continue
        }
    }
}

# ---------------------------------------------------------------------------
# Optional tracking cleanup (item 11a) - only removes rows that are fully Complete.
# ---------------------------------------------------------------------------
if ($CleanupTracking) {
    $deleteSql = @"
DELETE FROM dbo.LogShippingInitTracking
WHERE WaveName = @WaveName
  AND BackupStatus = 'Complete' AND CopyStatus = 'Complete' AND RestoreStatus = 'Complete'
  AND (LogShippingConfigStatus IN ('Complete','Skipped') OR @IncludeConfigPending = 1);
"@
    $includeConfigPending = if ($doConfig) { 0 } else { 1 }
    $deleted = Invoke-DbaQuery -SqlInstance $TrackingSqlInstance -Database $TrackingDatabase -Query $deleteSql `
        -SqlParameters @{ WaveName = $WaveName; IncludeConfigPending = $includeConfigPending }
    Write-MigrationLog "Cleaned up completed tracking rows for wave '$WaveName'." -LogPath $LogPath
}

Write-MigrationLog "Done." -LogPath $LogPath
