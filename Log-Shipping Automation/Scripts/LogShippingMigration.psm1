#Requires -Modules dbatools
<#
================================================================================
 LogShippingMigration.psm1

 Helper functions used by Start-LogShippingMigration.ps1,
 Remove-LogShippingMigrationTracking.ps1 and Remove-LogShippingConfiguration.ps1.

 Requires the dbatools PowerShell module (https://dbatools.io) and Windows
 Integrated authentication to the source, target and tracking SQL instances.
================================================================================
#>

Set-StrictMode -Version Latest

function Write-MigrationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Warn','Error')][string]$Level = 'Info',
        [string]$LogPath
    )
    $line = "{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}" -f (Get-Date), $Level, $Message
    switch ($Level) {
        'Warn'  { Write-Warning $line }
        'Error' { Write-Error $line -ErrorAction Continue }
        default { Write-Host $line }
    }
    if ($LogPath) { Add-Content -Path $LogPath -Value $line }
}

function Assert-DbatoolsModule {
    if (-not (Get-Module -ListAvailable -Name dbatools)) {
        throw "The 'dbatools' PowerShell module is required but not found. Install it with: Install-Module dbatools -Scope CurrentUser"
    }
    Import-Module dbatools -ErrorAction Stop

    # Modern dbatools (Microsoft.Data.SqlClient) defaults to encrypted connections with full certificate
    # chain validation, which fails against instances using a self-signed/internal cert. Relax that to
    # optional/untrusted-cert-allowed for THIS SESSION ONLY (not persisted machine-wide) so connections
    # succeed without requiring a trusted cert on every SQL instance involved.
    Write-MigrationLog "Relaxing dbatools connection encryption to optional / trusting server certificates (this session only)." -Level Warn
    Set-DbatoolsInsecureConnection -SessionOnly
}

function Get-WaveDatabaseList {
    <# Reads a wave input file: one DatabaseName per line, '#' comments and blank lines ignored. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$WaveFile)

    if (-not (Test-Path $WaveFile)) { throw "Wave file not found: $WaveFile" }

    Get-Content -Path $WaveFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') } |
        Select-Object -Unique
}

function Sync-FileMapping {
    <#
    Loads DatabaseFileMapping.csv (DatabaseName,LogicalFileName,TargetPath), restricts it to the
    supplied database list, upserts it into dbo.LogShippingFileMapping for durability, and returns
    an in-memory map: @{ DatabaseName = @{ LogicalFileName = TargetPath } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$MappingFile,
        [Parameter(Mandatory)][string[]]$DatabaseName,
        [Parameter(Mandatory)][string]$WaveName,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase
    )

    if (-not (Test-Path $MappingFile)) { throw "Mapping file not found: $MappingFile" }

    $rows = Import-Csv -Path $MappingFile | Where-Object { $DatabaseName -contains $_.DatabaseName }
    if (-not $rows) { throw "No rows in $MappingFile matched the requested database(s)." }

    $map = @{}
    foreach ($row in $rows) {
        if (-not $map.ContainsKey($row.DatabaseName)) { $map[$row.DatabaseName] = @{} }
        $map[$row.DatabaseName][$row.LogicalFileName] = $row.TargetPath

        $upsertSql = @"
MERGE dbo.LogShippingFileMapping AS tgt
USING (SELECT @DatabaseName AS DatabaseName, @LogicalFileName AS LogicalFileName) AS src
    ON tgt.DatabaseName = src.DatabaseName AND tgt.LogicalFileName = src.LogicalFileName
WHEN MATCHED THEN UPDATE SET TargetPath = @TargetPath, WaveName = @WaveName
WHEN NOT MATCHED THEN INSERT (WaveName, DatabaseName, LogicalFileName, TargetPath)
    VALUES (@WaveName, @DatabaseName, @LogicalFileName, @TargetPath);
"@
        Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query $upsertSql -SqlParameters @{
            DatabaseName    = $row.DatabaseName
            LogicalFileName = $row.LogicalFileName
            TargetPath      = $row.TargetPath
            WaveName        = $WaveName
        } -EnableException | Out-Null
    }
    return $map
}

function Get-FileMappingFromTracking {
    <# Fallback for a restore-only re-run where the CSV isn't supplied: read the durable copy back. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase
    )
    $rows = Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query `
        "SELECT LogicalFileName, TargetPath FROM dbo.LogShippingFileMapping WHERE DatabaseName = @DatabaseName" `
        -SqlParameters @{ DatabaseName = $DatabaseName } -EnableException

    if (-not $rows) { throw "No file mapping found in tracking DB for $DatabaseName. Supply -MappingFile or run the backup/restore phase with -MappingFile at least once." }

    $map = @{}
    foreach ($r in $rows) { $map[$r.LogicalFileName] = $r.TargetPath }
    return $map
}

function Get-SourceDatabaseSizeMB {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SqlInstance,
        [Parameter(Mandatory)][string]$DatabaseName
    )
    # Guard explicitly rather than letting DB_ID() silently resolve to NULL for a missing/mistyped database -
    # a size query against a nonexistent database should fail loudly, not sort it as "smallest" by accident.
    $dbCheck = Invoke-DbaQuery -SqlInstance $SqlInstance -Database 'master' -Query `
        "SELECT database_id FROM sys.databases WHERE name = @DatabaseName;" `
        -SqlParameters @{ DatabaseName = $DatabaseName } -EnableException
    if (-not $dbCheck) { throw "Database '$DatabaseName' was not found on $SqlInstance." }

    $sql = "SELECT CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(18,2)) AS SizeMB FROM sys.master_files WHERE database_id = DB_ID(@DatabaseName);"
    $result = Invoke-DbaQuery -SqlInstance $SqlInstance -Database 'master' -Query $sql -SqlParameters @{ DatabaseName = $DatabaseName } -EnableException

    if ($null -eq $result -or $null -eq $result.SizeMB) {
        throw "Could not determine size of '$DatabaseName' on $SqlInstance (query returned no size)."
    }
    return [decimal]$result.SizeMB
}

function Set-TrackingField {
    <# Generic, parameterized column updater for dbo.LogShippingInitTracking. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase,
        [Parameter(Mandatory)][int]$TrackingId,
        [Parameter(Mandatory)][hashtable]$Fields
    )
    $setClauses = @()
    $sqlParams = @{ TrackingId = $TrackingId }
    $i = 0
    foreach ($key in $Fields.Keys) {
        $paramName = "p$i"
        $setClauses += "$key = @$paramName"
        $sqlParams[$paramName] = $Fields[$key]
        $i++
    }
    $setClauses += 'ModifiedDate = SYSUTCDATETIME()'
    $sql = "UPDATE dbo.LogShippingInitTracking SET $($setClauses -join ', ') WHERE TrackingId = @TrackingId;"
    Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query $sql -SqlParameters $sqlParams -EnableException | Out-Null
}

function Initialize-TrackingQueue {
    <#
    Ensures a tracking row exists for every database in the wave (inserting Pending rows for new
    ones, leaving existing rows/status alone so re-runs resume rather than restart), stamps each
    with its live source size, orders the queue smallest-database-first, and returns the ordered
    tracking rows.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceSqlInstance,
        [Parameter(Mandatory)][string]$WaveName,
        [Parameter(Mandatory)][string[]]$DatabaseName,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase
    )

    foreach ($db in $DatabaseName) {
        $existing = Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query `
            "SELECT TrackingId FROM dbo.LogShippingInitTracking WHERE WaveName = @WaveName AND DatabaseName = @DatabaseName" `
            -SqlParameters @{ WaveName = $WaveName; DatabaseName = $db } -EnableException

        if (-not $existing) {
            $sizeMB = Get-SourceDatabaseSizeMB -SqlInstance $SourceSqlInstance -DatabaseName $db
            Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query `
                "INSERT INTO dbo.LogShippingInitTracking (WaveName, DatabaseName, DatabaseSizeMB) VALUES (@WaveName, @DatabaseName, @SizeMB);" `
                -SqlParameters @{ WaveName = $WaveName; DatabaseName = $db; SizeMB = $sizeMB } -EnableException | Out-Null
        }
    }

    # Re-sequence smallest-database-first (item 12) every run, in case new databases were added to the wave.
    $reseqSql = @"
;WITH ordered AS (
    SELECT TrackingId, ROW_NUMBER() OVER (ORDER BY DatabaseSizeMB ASC, DatabaseName ASC) AS rn
    FROM dbo.LogShippingInitTracking WHERE WaveName = @WaveName
)
UPDATE t SET t.SequenceNo = o.rn
FROM dbo.LogShippingInitTracking t JOIN ordered o ON t.TrackingId = o.TrackingId;
"@
    Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query $reseqSql -SqlParameters @{ WaveName = $WaveName } -EnableException | Out-Null

    Invoke-DbaQuery -SqlInstance $TrackingInstance -Database $TrackingDatabase -Query `
        "SELECT * FROM dbo.LogShippingInitTracking WHERE WaveName = @WaveName ORDER BY SequenceNo ASC;" `
        -SqlParameters @{ WaveName = $WaveName } -EnableException
}

function Invoke-DatabaseBackupPhase {
    <#
    Regular (non-copy-only) compressed full backup + one regular compressed log backup. Simplified per
    request: no copy-only logic. Note this means a full backup taken by this tool WILL become part of
    the database's normal backup/differential-base chain - if some other backup job (maintenance plan,
    third-party tool) is relying on that chain, coordinate with whoever owns it before running this
    against a database that isn't already dedicated to this migration.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceSqlInstance,
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$SourceBackupShare,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase,
        [Parameter(Mandatory)][int]$TrackingId
    )

    Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
        -Fields @{ BackupStatus = 'InProgress'; BackupStartTime = (Get-Date) }

    try {
        $recoveryModel = (Get-DbaDbRecoveryModel -SqlInstance $SourceSqlInstance -Database $DatabaseName).RecoveryModel
        if ($recoveryModel -ne 'Full') {
            Write-MigrationLog "Setting $DatabaseName to FULL recovery model (was $recoveryModel) - required for log shipping." -Level Warn
            Set-DbaDbRecoveryModel -SqlInstance $SourceSqlInstance -Database $DatabaseName -RecoveryModel Full -Confirm:$false | Out-Null
        }

        $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        $fullPath = Join-Path $SourceBackupShare "$DatabaseName`_FULL_$stamp.bak"
        $logPath  = Join-Path $SourceBackupShare "$DatabaseName`_LOG_$stamp.trn"

        $fullBackup = Backup-DbaDatabase -SqlInstance $SourceSqlInstance -Database $DatabaseName `
            -Type Full -CompressBackup -FilePath $fullPath -EnableException

        $logBackup = Backup-DbaDatabase -SqlInstance $SourceSqlInstance -Database $DatabaseName `
            -Type Log -CompressBackup -FilePath $logPath -EnableException

        $fullFile = Split-Path -Path $fullBackup.BackupPath -Leaf
        $logFile  = Split-Path -Path $logBackup.BackupPath -Leaf

        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId -Fields @{
            BackupStatus = 'Complete'; BackupEndTime = (Get-Date); FullBackupFile = $fullFile; LogBackupFile = $logFile
        }

        return [pscustomobject]@{ FullBackupFile = $fullFile; LogBackupFile = $logFile }
    }
    catch {
        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
            -Fields @{ BackupStatus = 'Failed'; LastErrorMessage = $_.Exception.Message }
        throw
    }
}

function Invoke-DatabaseCopyPhase {
    <# robocopy the backup file(s) from the source share to the target share, polling size for percent complete. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceBackupShare,
        [Parameter(Mandatory)][string]$TargetBackupShare,
        [Parameter(Mandatory)][string[]]$FileName,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase,
        [Parameter(Mandatory)][int]$TrackingId,
        [int]$PollSeconds = 15
    )

    Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
        -Fields @{ CopyStatus = 'InProgress'; CopyStartTime = (Get-Date) }

    try {
        $totalBytes = 0L
        foreach ($f in $FileName) {
            $src = Join-Path $SourceBackupShare $f
            if (Test-Path -LiteralPath $src) { $totalBytes += (Get-Item -LiteralPath $src).Length }
        }
        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId -Fields @{ BytesTotal = $totalBytes }

        $roboLog = Join-Path $env:TEMP "robocopy_$([guid]::NewGuid()).log"
        $roboArgs = @($SourceBackupShare, $TargetBackupShare) + $FileName + @('/NDL', '/NJH', '/NJS', '/R:3', '/W:10', "/LOG:$roboLog")
        $proc = Start-Process -FilePath robocopy.exe -ArgumentList $roboArgs -PassThru -WindowStyle Hidden

        while (-not $proc.HasExited) {
            Start-Sleep -Seconds $PollSeconds
            $copiedBytes = 0L
            foreach ($f in $FileName) {
                $dst = Join-Path $TargetBackupShare $f
                if (Test-Path -LiteralPath $dst) { $copiedBytes += (Get-Item -LiteralPath $dst).Length }
            }
            $pct = if ($totalBytes -gt 0) { [math]::Round(($copiedBytes / $totalBytes) * 100, 2) } else { 0 }
            Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
                -Fields @{ BytesCopied = $copiedBytes; CopyPercentComplete = $pct }
        }

        # robocopy exit codes 0-7 are success variants; 8+ indicates failure.
        if ($proc.ExitCode -ge 8) { throw "robocopy failed with exit code $($proc.ExitCode). See $roboLog" }

        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId -Fields @{
            CopyStatus = 'Complete'; CopyEndTime = (Get-Date); CopyPercentComplete = 100; BytesCopied = $totalBytes
        }
    }
    catch {
        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
            -Fields @{ CopyStatus = 'Failed'; LastErrorMessage = $_.Exception.Message }
        throw
    }
}

function Invoke-DatabaseRestorePhase {
    <# Restores full + log WITH NORECOVERY WITH MOVE, polling sys.dm_exec_requests.percent_complete live. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TargetSqlInstance,
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$TargetBackupShare,
        [Parameter(Mandatory)][string]$FullBackupFile,
        [string]$LogBackupFile,
        [Parameter(Mandatory)][hashtable]$FileMap,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase,
        [Parameter(Mandatory)][int]$TrackingId,
        [int]$PollSeconds = 15
    )

    Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
        -Fields @{ RestoreStatus = 'InProgress'; RestoreStartTime = (Get-Date) }

    try {
        $paths = @(Join-Path $TargetBackupShare $FullBackupFile)
        if ($LogBackupFile) { $paths += Join-Path $TargetBackupShare $LogBackupFile }

        # Start-Job runs in a separate child process with its own dbatools config state - it does NOT
        # inherit the parent session's Set-DbatoolsInsecureConnection -SessionOnly setting from
        # Assert-DbatoolsModule, so the cert-trust relaxation has to be re-applied inside the job too.
        $job = Start-Job -Name "Restore_$DatabaseName" -ScriptBlock {
            param($SqlInstance, $DbName, $Paths, $Map)
            Import-Module dbatools -ErrorAction Stop
            Set-DbatoolsInsecureConnection -SessionOnly
            Restore-DbaDatabase -SqlInstance $SqlInstance -Path $Paths -DatabaseName $DbName `
                -FileMapping $Map -NoRecovery -WithReplace -EnableException
        } -ArgumentList $TargetSqlInstance, $DatabaseName, $paths, $FileMap

        while ($job.State -eq 'Running') {
            Start-Sleep -Seconds $PollSeconds
            $pctSql = @"
SELECT TOP 1 r.percent_complete
FROM sys.dm_exec_requests r
JOIN sys.databases d ON r.database_id = d.database_id
WHERE r.command LIKE 'RESTORE%' AND d.name = @DatabaseName
ORDER BY r.percent_complete DESC;
"@
            # Not -EnableException here: this is a best-effort progress poll running alongside the
            # background restore job: a transient failure to read percent_complete shouldn't abort
            # the restore itself, just skip that one progress update.
            $result = Invoke-DbaQuery -SqlInstance $TargetSqlInstance -Database 'master' -Query $pctSql -SqlParameters @{ DatabaseName = $DatabaseName } -ErrorAction SilentlyContinue
            if ($result) {
                Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
                    -Fields @{ RestorePercentComplete = [math]::Round([double]$result.percent_complete, 2) }
            }
        }

        Receive-Job -Job $job -ErrorAction Stop | Out-Null
        Remove-Job -Job $job -Force

        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId -Fields @{
            RestoreStatus = 'Complete'; RestoreEndTime = (Get-Date); RestorePercentComplete = 100
        }
    }
    catch {
        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
            -Fields @{ RestoreStatus = 'Failed'; LastErrorMessage = $_.Exception.Message }
        throw
    }
}

function Invoke-ConfigureLogShippingPhase {
    <#
    Configures the ongoing log shipping backup/copy/restore jobs via dbatools' Invoke-DbaDbLogShipping,
    with -NoInitialization since the seed full+log backup/copy/restore was already handled by this
    tool's own Initialize phase (or a prior run). Requires the target database to already be in
    NORECOVERY (i.e. the Initialize phase's restore step must have completed).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SourceSqlInstance,
        [Parameter(Mandatory)][string]$TargetSqlInstance,
        [Parameter(Mandatory)][string]$DatabaseName,
        [Parameter(Mandatory)][string]$SourceBackupShare,
        [Parameter(Mandatory)][string]$TargetBackupShare,
        [int]$BackupIntervalMinutes = 15,
        [int]$CopyIntervalMinutes = 15,
        [int]$RestoreIntervalMinutes = 15,
        [int]$BackupRetentionMinutes = 4320,
        [int]$BackupThresholdMinutes = 60,
        [int]$RestoreThresholdMinutes = 45,
        [string]$MonitorServer,
        [Parameter(Mandatory)][string]$TrackingInstance,
        [Parameter(Mandatory)][string]$TrackingDatabase,
        [Parameter(Mandatory)][int]$TrackingId
    )

    Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
        -Fields @{ LogShippingConfigStatus = 'InProgress'; LogShippingConfigStartTime = (Get-Date) }

    try {
        # CopyDestinationFolder tells the secondary where to copy backup files to locally before
        # restoring them - without it, Invoke-DbaDbLogShipping prompts interactively ("copy destination
        # is missing... use default?"), which blocks unattended runs. -Force additionally suppresses
        # any other such interactive confirmations so this never hangs waiting for input.
        #
        # NOTE: Invoke-DbaDbLogShipping always registers SOME monitor - it is not possible to configure
        # log shipping with no monitor at all through this cmdlet. If -MonitorServer isn't supplied, it
        # defaults PrimaryMonitorServer to the source instance and SecondaryMonitorServer to the target
        # (self-monitoring), which is what -PrimaryThresholdAlertEnabled/-SecondaryThresholdAlertEnabled
        # being left off then avoids is just the threshold ALERT jobs, not monitor registration itself.
        # Self-monitoring is a normal, fully supported log shipping configuration - it simply means
        # history is recorded on the source/target rather than on a separate dedicated monitor server.
        $lsParams = @{
            SourceSqlInstance      = $SourceSqlInstance
            DestinationSqlInstance = $TargetSqlInstance
            Database               = $DatabaseName
            SharedPath             = $SourceBackupShare
            CopyDestinationFolder  = $TargetBackupShare
            Force                  = $true
            CompressBackup         = $true
            BackupRetention        = $BackupRetentionMinutes
            BackupScheduleFrequencyType          = 'Daily'
            BackupScheduleFrequencyInterval      = 1
            BackupScheduleFrequencySubdayType    = 'Minutes'
            BackupScheduleFrequencySubdayInterval = $BackupIntervalMinutes
            CopyScheduleFrequencyType             = 'Daily'
            CopyScheduleFrequencyInterval         = 1
            CopyScheduleFrequencySubdayType       = 'Minutes'
            CopyScheduleFrequencySubdayInterval   = $CopyIntervalMinutes
            RestoreScheduleFrequencyType          = 'Daily'
            RestoreScheduleFrequencyInterval      = 1
            RestoreScheduleFrequencySubdayType    = 'Minutes'
            RestoreScheduleFrequencySubdayInterval = $RestoreIntervalMinutes
            NoInitialization       = $true
            NoRecovery             = $true
            BackupThreshold        = $BackupThresholdMinutes
            RestoreThreshold       = $RestoreThresholdMinutes
            EnableException        = $true
        }
        if ($MonitorServer) {
            $lsParams.PrimaryMonitorServer = $MonitorServer
            $lsParams.SecondaryMonitorServer = $MonitorServer
            $lsParams.PrimaryThresholdAlertEnabled = $true
            $lsParams.SecondaryThresholdAlertEnabled = $true
        }
        else {
            Write-MigrationLog "  No -MonitorServer supplied - source and target will each default to self-monitoring (no separate monitor server, no threshold alerts)." -Level Warn
        }

        Invoke-DbaDbLogShipping @lsParams

        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId -Fields @{
            LogShippingConfigStatus = 'Complete'; LogShippingConfigEndTime = (Get-Date)
        }
    }
    catch {
        Set-TrackingField -TrackingInstance $TrackingInstance -TrackingDatabase $TrackingDatabase -TrackingId $TrackingId `
            -Fields @{ LogShippingConfigStatus = 'Failed'; LastErrorMessage = $_.Exception.Message }
        throw
    }
}

Export-ModuleMember -Function *
