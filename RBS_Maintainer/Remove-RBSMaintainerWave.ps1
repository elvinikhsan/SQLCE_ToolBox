<#
.SYNOPSIS
    Phase 6 - Rollback: removes a wave's SQL Agent job and, optionally, restores its
    Maintainer config file to a pre-Phase-2 backup.
 
.DESCRIPTION
    Undoes what New-RBSMaintainerWaveSetup.ps1 (Phase 5) / New-RBSMaintainerAgentJobs.ps1
    (Phase 4) created for one wave, so the wave can be redone from a clean slate:
 
        1. Drops the wave's SQL Agent job ("<JobNamePrefix><WaveName>", e.g.
           RBS_Maintainer_Wave0) on -SqlInstance, if it exists. Idempotent - if the job is
           already gone, this is reported and nothing else happens.
        2. Optionally (-RestoreConfigBackup), restores Microsoft.Data.SqlRemoteBlobs.
           Maintainer.exe.config from the timestamped backup Update-RBSMaintainerConfig.ps1
           (Phase 2) took before its last write - by default the MOST RECENT backup, or a
           specific one via -BackupTimestamp. The config's current content is itself saved
           first (as "<ConfigPath>.before_rollback_<timestamp>") so restoring a backup is
           never a one-way trip either.
 
    This does not touch the content databases or RBS itself - only the automation this
    solution added (the job and the connection string entries added for this wave).
 
.PARAMETER WaveName
    Wave identifier used to build the job name, e.g. "Wave0" -> "RBS_Maintainer_Wave0"
    (with the default -JobNamePrefix). Must match what was passed to Phase 4/5.
 
.PARAMETER SqlInstance
    SQL Server instance the wave's job was created on.
 
.PARAMETER JobNamePrefix
    Must match the prefix used when the job was created. Default 'RBS_Maintainer_'.
 
.PARAMETER ConfigPath
    Path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config. Required if
    -RestoreConfigBackup is used (ignored otherwise - dropping the job alone doesn't touch
    the config).
 
.PARAMETER RestoreConfigBackup
    Also restore -ConfigPath from a Phase 2 backup (<ConfigPath>.bak_<timestamp>).
 
.PARAMETER BackupTimestamp
    Restore a specific backup (the "<timestamp>" part of an existing
    "<ConfigPath>.bak_<timestamp>" file) instead of the most recent one. Use this if a
    newer backup exists but you need to go further back.
 
.EXAMPLE
    # Preview: what would be dropped/restored for Wave0
    .\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev" `
        -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
        -RestoreConfigBackup -WhatIf
 
.EXAMPLE
    # Drop the job only, leave the config alone
    .\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev"
 
.EXAMPLE
    # Drop the job and roll the config back to its most recent pre-change backup
    .\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev" `
        -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" -RestoreConfigBackup
 
.NOTES
    Connects to msdb using Windows Authentication, matching the rest of this solution.
    After a rollback, a wave can simply be re-run from Phase 5/1 once whatever needed
    fixing is fixed - Phase 1/2 are safe to re-run (read-only detection / idempotent
    add-or-update), and Phase 4/5 will recreate the job from scratch.
#>
 
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WaveName,
 
    [Parameter(Mandatory = $true)]
    [string]$SqlInstance,
 
    [string]$JobNamePrefix = 'RBS_Maintainer_',
 
    [string]$ConfigPath,
 
    [switch]$RestoreConfigBackup,
 
    [string]$BackupTimestamp
)
 
if ($RestoreConfigBackup -and -not $ConfigPath) {
    throw "-RestoreConfigBackup requires -ConfigPath."
}
 
if ($BackupTimestamp -and -not $RestoreConfigBackup) {
    throw "-BackupTimestamp only applies with -RestoreConfigBackup."
}
 
$jobName = "$JobNamePrefix$WaveName"
 
# ---- Step 1: drop the wave's SQL Agent job (idempotent) ----
 
Write-Host "--- Job: $jobName on $SqlInstance ---" -ForegroundColor Cyan
 
$connString = "Server=$SqlInstance;Database=msdb;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connString
$conn.Open()
 
try {
    $checkCmd = $conn.CreateCommand()
    $checkCmd.CommandText = 'SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @jobName'
    [void]$checkCmd.Parameters.AddWithValue('@jobName', $jobName)
    $existingJobId = $checkCmd.ExecuteScalar()
    $jobExists = ($null -ne $existingJobId) -and ($existingJobId -isnot [DBNull])
 
    if (-not $jobExists) {
        Write-Host "Job '$jobName' does not exist on '$SqlInstance' - nothing to drop." -ForegroundColor DarkGray
    }
    elseif ($PSCmdlet.ShouldProcess("$jobName on $SqlInstance", 'Drop SQL Agent job')) {
        $dropCmd = $conn.CreateCommand()
        $dropCmd.CommandText = 'EXEC msdb.dbo.sp_delete_job @job_name = @jobName'
        [void]$dropCmd.Parameters.AddWithValue('@jobName', $jobName)
        [void]$dropCmd.ExecuteNonQuery()
        Write-Host "Dropped: $jobName" -ForegroundColor Green
    }
}
finally {
    $conn.Close()
    $conn.Dispose()
}
 
# ---- Step 2 (optional): restore the config file from a Phase 2 backup ----
 
if ($RestoreConfigBackup) {
    Write-Host ""
    Write-Host "--- Config: $ConfigPath ---" -ForegroundColor Cyan
 
    if (-not (Test-Path -Path $ConfigPath -PathType Leaf)) {
        Write-Warning "ConfigPath '$ConfigPath' not found - skipping config restore."
    }
    else {
        $ConfigPath   = (Resolve-Path -Path $ConfigPath).ProviderPath
        $configDir    = Split-Path -Path $ConfigPath -Parent
        $configLeaf   = Split-Path -Path $ConfigPath -Leaf
 
        if ($BackupTimestamp) {
            $backupPath = Join-Path $configDir "$configLeaf.bak_$BackupTimestamp"
            if (-not (Test-Path -Path $backupPath -PathType Leaf)) {
                throw "No backup found matching '$backupPath'."
            }
            $chosenBackup = Get-Item -Path $backupPath
        }
        else {
            # Backup file names are "<leaf>.bak_yyyyMMdd_HHmmss" - that timestamp format
            # sorts correctly as plain text, so the lexicographically-last name is also
            # the most recent backup; no need to parse dates out of the file names.
            $chosenBackup = Get-ChildItem -Path $configDir -Filter "$configLeaf.bak_*" -File |
                Sort-Object Name -Descending |
                Select-Object -First 1
        }
 
        if (-not $chosenBackup) {
            Write-Warning "No backup files found matching '$configLeaf.bak_*' in '$configDir' - skipping config restore."
        }
        elseif ($PSCmdlet.ShouldProcess($ConfigPath, "Restore from backup '$($chosenBackup.Name)'")) {
            # Save the config's current (pre-rollback) content too, so restoring a backup
            # is never itself a one-way trip.
            $preRollbackPath = "$ConfigPath.before_rollback_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $ConfigPath -Destination $preRollbackPath -Force
            Write-Host "Current config saved to: $preRollbackPath" -ForegroundColor DarkGray
 
            Copy-Item -Path $chosenBackup.FullName -Destination $ConfigPath -Force
            Write-Host "Restored '$ConfigPath' from backup: $($chosenBackup.Name)" -ForegroundColor Green
        }
    }
}
 
Write-Host ""
Write-Host "=== Rollback complete: $WaveName ===" -ForegroundColor Green
 