<#
.SYNOPSIS
    Phase 4 - Creates ONE SQL Server Agent job per wave, containing one step per
    RBS-enabled content database in that wave, each step running the Phase 3 wrapper
    (Invoke-RBSMaintainerRun.ps1).
 
.DESCRIPTION
    Reads the RBS status CSV produced by Phase 1 (Detect-RBSEnabledDatabases.ps1),
    filters to RBSEnabled = True, and creates a single SQL Server Agent job for the wave:
 
        Job name     : <JobNamePrefix><WaveName>            e.g. RBS_Maintainer_Wave0
        Schedule name: same as the job name                 e.g. RBS_Maintainer_Wave0
        Step per DB  : <JobName>_<DatabaseName>              e.g. RBS_Maintainer_Wave0_WSS_Content
                       Operating System (CmdExec), run as -ProxyName (default RBSMaintainer_Proxy):
                           powershell.exe -NoProfile -ExecutionPolicy Bypass -File "<WrapperScriptPath>"
                               -DatabaseName "<DatabaseName>" -MaintainerExePath "<MaintainerExePath>"
                               -ConnectionStringPrefix "<ConnectionStringPrefix>" -TimeLimitMinutes <n>
                               -SuccessExitCodes <codes>
        Final step   : <JobName>_CheckResults (T-SQL) - see FAILURE HANDLING below.
        Schedule     : daily at -ScheduleTime
 
    CmdExec (not the native "PowerShell" job step subsystem) is used deliberately for the
    per-database steps - SQL Agent's native PowerShell subsystem has documented issues
    reliably surfacing a script's real exit code back to the job step. CmdExec just runs
    powershell.exe as an ordinary process and reads ITS exit code, which is exactly what
    the Phase 3 wrapper is built to set correctly (0 = success, 1 = failure).
 
    FAILURE HANDLING (deliberate design, confirmed with the environment owner):
    Every per-database step is wired to proceed to the next step regardless of whether it
    succeeds or fails (@on_success_action = @on_fail_action = "Go to next step"), so one
    database's failure never skips maintenance for the rest of the wave that run. Because
    of that, the LAST database step's own outcome can no longer be trusted as the job's
    overall status - SQL Agent only reports whatever the last-executed step's outcome was.
    A final "<JobName>_CheckResults" T-SQL step is appended specifically to correct for
    this: it looks up this job's most recent N step-history rows (N = number of database
    steps) and deliberately fails (RAISERROR) if any of them did not succeed. That step
    quits the job reporting failure if so, or reporting success otherwise - so the job's
    overall status in SSMS/job history accurately reflects "did every database in this
    wave succeed", while every database was still attempted regardless of earlier
    failures.
 
    Idempotent by default: if a job with the target name already exists, it is left alone
    and reported as skipped. Pass -DropExisting to drop and recreate it instead (e.g. after
    changing -ScheduleTime, -TimeLimitMinutes, or the wave's database list).
 
.PARAMETER StatusCsv
    Path to the CSV produced by Detect-RBSEnabledDatabases.ps1 (Phase 1) for this wave.
    All rows must share the same SqlInstance value - this script assumes one target
    instance per wave, per the environment's stated topology.
 
.PARAMETER WaveName
    Wave identifier used to build the job name, e.g. "Wave0" -> job name
    "RBS_Maintainer_Wave0" (with the default -JobNamePrefix).
 
.PARAMETER WrapperScriptPath
    Full path to Invoke-RBSMaintainerRun.ps1 (Phase 3) ON THE TARGET SQL SERVER HOST -
    CmdExec job steps always run locally on the SQL Agent service's own machine, never
    remotely.
 
.PARAMETER MaintainerExePath
    Full path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe on the target SQL Server host.
 
.PARAMETER ScheduleTime
    Daily run time as "HH:mm" (24-hour), e.g. "02:00".
 
.PARAMETER ProxyName
    SQL Agent proxy the per-database CmdExec steps run under. Default 'RBSMaintainer_Proxy'.
 
.PARAMETER TimeLimitMinutes
    Passed through to the wrapper's -TimeLimitMinutes (and from there to the exe's own
    -TimeLimit) for every database step. Default 120 (matches the RBS installer's own
    default - use a smaller value only for testing).
 
.PARAMETER SuccessExitCodes
    Comma-separated exit codes passed through to the wrapper's -SuccessExitCodes, e.g.
    "0,10,20,40" (the default). A string rather than an array: PowerShell's command-line
    binder does not reliably collect multiple space-separated tokens into an array
    parameter when a script is invoked externally (as this script's own generated
    CmdExec commands - and potentially this script itself - are) - see the matching note
    in Invoke-RBSMaintainerRun.ps1 (Phase 3) for the full explanation and how it was
    diagnosed.
 
.PARAMETER ConnectionStringPrefix
    Must match Phase 2's prefix. Default 'RBSMaintainer_'.
 
.PARAMETER JobNamePrefix
    Prefix for the generated job name. Default 'RBS_Maintainer_'.
 
.PARAMETER DropExisting
    If a job with the target name already exists, drop and recreate it instead of skipping.
 
.EXAMPLE
    # Preview only
    .\New-RBSMaintainerAgentJobs.ps1 -StatusCsv .\Wave0_Databases_RBSStatus.csv -WaveName "Wave0" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -ScheduleTime "02:00" -WhatIf
 
.EXAMPLE
    .\New-RBSMaintainerAgentJobs.ps1 -StatusCsv .\Wave0_Databases_RBSStatus.csv -WaveName "Wave0" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -ScheduleTime "02:00"
 
.NOTES
    Connects to msdb using Windows Authentication, matching this environment's auth model.
#>
 
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$StatusCsv,
 
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WaveName,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$WrapperScriptPath,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$MaintainerExePath,
 
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
    [string]$ScheduleTime,
 
    [string]$ProxyName = 'RBSMaintainer_Proxy',
 
    [int]$TimeLimitMinutes = 120,
 
    [string]$SuccessExitCodes = '0,10,20,40',
 
    [string]$ConnectionStringPrefix = 'RBSMaintainer_',
 
    [string]$JobNamePrefix = 'RBS_Maintainer_',
 
    [switch]$DropExisting
)
 
# Resolve to full paths up front - see Phase 2's Update-RBSMaintainerConfig.ps1 for why
# (relative paths can silently resolve against the wrong working directory).
$StatusCsv         = (Resolve-Path -Path $StatusCsv).ProviderPath
$WrapperScriptPath = (Resolve-Path -Path $WrapperScriptPath).ProviderPath
$MaintainerExePath = (Resolve-Path -Path $MaintainerExePath).ProviderPath
 
$activeStartTime = [int]([datetime]::ParseExact($ScheduleTime, 'HH:mm', $null).ToString('HHmmss'))
 
$statusRows   = Import-Csv -Path $StatusCsv
$rbsDatabases = @($statusRows | Where-Object { $_.RBSEnabled -eq 'True' } | Sort-Object DatabaseName)
 
if ($rbsDatabases.Count -eq 0) {
    Write-Warning "No RBS-enabled databases found in '$StatusCsv'. Nothing to do."
    return
}
 
$sqlInstance    = $rbsDatabases[0].SqlInstance
$otherInstances = @($rbsDatabases | Where-Object { $_.SqlInstance -ne $sqlInstance })
if ($otherInstances.Count -gt 0) {
    throw "Status CSV contains more than one distinct SqlInstance value. This script assumes a single target instance per wave - split the CSV or re-run per instance."
}
 
$jobName = "$JobNamePrefix$WaveName"
 
Write-Host "Creating SQL Agent job '$jobName' on '$sqlInstance' with $($rbsDatabases.Count) database step(s)..." -ForegroundColor Cyan
 
$connString = "Server=$sqlInstance;Database=msdb;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connString
$conn.Open()
 
try {
    $checkCmd = $conn.CreateCommand()
    $checkCmd.CommandText = 'SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @jobName'
    [void]$checkCmd.Parameters.AddWithValue('@jobName', $jobName)
    $existingJobId = $checkCmd.ExecuteScalar()
    $jobExists = ($null -ne $existingJobId) -and ($existingJobId -isnot [DBNull])
 
    if ($jobExists -and -not $DropExisting) {
        Write-Host "Skipped (already exists): $jobName. Pass -DropExisting to recreate it." -ForegroundColor DarkGray
        return
    }
 
    if ($jobExists -and $DropExisting) {
        if ($PSCmdlet.ShouldProcess($jobName, 'Drop existing job')) {
            $dropCmd = $conn.CreateCommand()
            $dropCmd.CommandText = 'EXEC msdb.dbo.sp_delete_job @job_name = @jobName'
            [void]$dropCmd.Parameters.AddWithValue('@jobName', $jobName)
            [void]$dropCmd.ExecuteNonQuery()
            Write-Host "Dropped existing: $jobName" -ForegroundColor Yellow
        }
    }
 
    if (-not $PSCmdlet.ShouldProcess($jobName, "Create SQL Agent job with $($rbsDatabases.Count) database step(s)")) {
        return
    }
 
    $sql = New-Object System.Text.StringBuilder
    $createCmd = $conn.CreateCommand()
 
    [void]$sql.AppendLine('DECLARE @jobId BINARY(16);')
    [void]$sql.AppendLine('')
    [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_job')
    [void]$sql.AppendLine('    @job_name = @jobName,')
    [void]$sql.AppendLine('    @enabled = 1,')
    [void]$sql.AppendLine('    @description = @description,')
    [void]$sql.AppendLine('    @job_id = @jobId OUTPUT;')
    [void]$sql.AppendLine('')
 
    [void]$createCmd.Parameters.AddWithValue('@jobName', $jobName)
    [void]$createCmd.Parameters.AddWithValue('@description', "Runs RBS Maintainer (GC + consistency check) for all RBS-enabled content databases in $WaveName.")
    [void]$createCmd.Parameters.AddWithValue('@proxyName', $ProxyName)
    [void]$createCmd.Parameters.AddWithValue('@activeStartTime', $activeStartTime)
 
    # One CmdExec step per RBS-enabled database. Both success and failure go to the next
    # step (see FAILURE HANDLING in the header comment): no database's maintenance is
    # skipped because an earlier one failed.
    $stepId = 1
    foreach ($row in $rbsDatabases) {
        $dbName   = $row.DatabaseName
        $stepName = "${jobName}_$dbName"
 
        # -SuccessExitCodes is passed as ONE quoted comma-separated token
        # ("0,10,20,40"), not space-separated values - see the .PARAMETER
        # SuccessExitCodes note above for why that matters here.
        $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $WrapperScriptPath + '"' +
                   ' -DatabaseName "' + $dbName + '"' +
                   ' -MaintainerExePath "' + $MaintainerExePath + '"' +
                   ' -ConnectionStringPrefix "' + $ConnectionStringPrefix + '"' +
                   ' -TimeLimitMinutes ' + $TimeLimitMinutes +
                   ' -SuccessExitCodes "' + $SuccessExitCodes + '"'
 
        $stepNameParam = "@stepName$stepId"
        $commandParam  = "@command$stepId"
 
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobstep')
        [void]$sql.AppendLine('    @job_id = @jobId,')
        [void]$sql.AppendLine("    @step_id = $stepId,")
        [void]$sql.AppendLine("    @step_name = $stepNameParam,")
        [void]$sql.AppendLine("    @subsystem = N'CmdExec',")
        [void]$sql.AppendLine("    @command = $commandParam,")
        [void]$sql.AppendLine('    @proxy_name = @proxyName,')
        [void]$sql.AppendLine('    @on_success_action = 3,')
        [void]$sql.AppendLine('    @on_fail_action = 3,')
        [void]$sql.AppendLine('    @retry_attempts = 0;')
        [void]$sql.AppendLine('')
 
        [void]$createCmd.Parameters.AddWithValue($stepNameParam, $stepName)
        [void]$createCmd.Parameters.AddWithValue($commandParam, $command)
 
        $stepId++
    }
 
    # Final "gate" step: re-checks this job's own most recent N step-history rows (N =
    # number of database steps just added) and deliberately fails if any of them did not
    # succeed, so the job's overall status is trustworthy even though every database step
    # above continues regardless of earlier failures. Looked up by job NAME at run time
    # (not the @jobId variable above, which only exists in THIS creation batch) because
    # this text is stored as-is and executed standalone whenever the job actually runs.
    $gateStepName   = "${jobName}_CheckResults"
    $escapedJobName = $jobName.Replace("'", "''")
    $gateCommand = @"
DECLARE @gateJobId BINARY(16) = (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'$escapedJobName');
DECLARE @failedCount INT;
 
SELECT @failedCount = COUNT(*)
FROM (
    SELECT TOP ($($rbsDatabases.Count)) run_status
    FROM msdb.dbo.sysjobhistory
    WHERE job_id = @gateJobId AND step_id > 0
    ORDER BY instance_id DESC
) AS recent
WHERE run_status <> 1;
 
IF @failedCount > 0
BEGIN
    RAISERROR(N'%d of the RBS Maintainer step(s) in this run did not succeed - see this job''s step history for details.', 16, 1, @failedCount);
END
"@
 
    [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobstep')
    [void]$sql.AppendLine('    @job_id = @jobId,')
    [void]$sql.AppendLine("    @step_id = $stepId,")
    [void]$sql.AppendLine('    @step_name = @gateStepName,')
    [void]$sql.AppendLine("    @subsystem = N'TSQL',")
    [void]$sql.AppendLine("    @database_name = N'msdb',")
    [void]$sql.AppendLine('    @command = @gateCommand,')
    [void]$sql.AppendLine('    @on_success_action = 1,')
    [void]$sql.AppendLine('    @on_fail_action = 2,')
    [void]$sql.AppendLine('    @retry_attempts = 0;')
    [void]$sql.AppendLine('')
 
    [void]$createCmd.Parameters.AddWithValue('@gateStepName', $gateStepName)
    [void]$createCmd.Parameters.AddWithValue('@gateCommand', $gateCommand)
 
    [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobschedule')
    [void]$sql.AppendLine('    @job_id = @jobId,')
    [void]$sql.AppendLine('    @name = @jobName,')
    [void]$sql.AppendLine('    @freq_type = 4,')
    [void]$sql.AppendLine('    @freq_interval = 1,')
    [void]$sql.AppendLine('    @freq_subday_type = 1,')
    [void]$sql.AppendLine('    @active_start_time = @activeStartTime;')
    [void]$sql.AppendLine('')
 
    [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobserver')
    [void]$sql.AppendLine('    @job_id = @jobId,')
    [void]$sql.AppendLine("    @server_name = N'(local)';")
 
    $createCmd.CommandText = $sql.ToString()
    [void]$createCmd.ExecuteNonQuery()
 
    Write-Host "Created: $jobName - $($rbsDatabases.Count) database step(s) + 1 result-check step, daily at $ScheduleTime" -ForegroundColor Green
    foreach ($row in $rbsDatabases) {
        Write-Host "    Step: ${jobName}_$($row.DatabaseName)" -ForegroundColor DarkGray
    }
    Write-Host "    Step: $gateStepName (checks the above and fails the job if any did not succeed)" -ForegroundColor DarkGray
}
catch {
    Write-Host "FAILED: $jobName - $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    $conn.Close()
    $conn.Dispose()
}