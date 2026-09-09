<#
.SYNOPSIS
    Post-migration - onboards ONE already-RBS-enabled content database into RBS Maintainer
    automation, either as a new single-database SQL Agent job or as an added step in an
    existing RBS Maintainer job.
 
.DESCRIPTION
    For a database the SharePoint team has already confirmed is RBS-enabled (no detection
    is performed here - unlike Phase 1, this script trusts -DatabaseName as given), this
    script:
 
        1. Adds/updates the database's Windows-Authentication connection string in the
           RBS Maintainer config (same "RBSMaintainer_<DatabaseName>" naming and
           connection string format as Update-RBSMaintainerConfig.ps1 / Phase 2).
        2. Either:
             -CreateNewJob   : creates a brand-new SQL Agent job named -JobName with one
                                database step + one CheckResults gate step, on a daily
                                schedule. Fails if a job with that name already exists.
             -AppendJobStep  : inserts a new database step into an EXISTING job named
                                -JobName, immediately before its last step - which must
                                already be that job's CheckResults gate step. The gate
                                step's own history-check query is then rewritten so its
                                "how many recent steps to check" count includes the newly
                                added step. Fails if the job doesn't exist, doesn't look
                                like an RBS Maintainer job (name doesn't contain
                                "RBS_Maintainer_"), its last step isn't a recognizable
                                CheckResults gate step, or it already has a step for this
                                database.
        -CreateNewJob and -AppendJobStep are mutually exclusive - exactly one is required.
 
    Both the new job step (CreateNewJob) and the inserted step (AppendJobStep) are wired
    exactly like every per-database step Phase 4 creates: CmdExec running
    Invoke-RBSMaintainerRun.ps1 (Phase 3) under -ProxyName, with @on_success_action =
    @on_fail_action = 3 ("go to next step") so one database's failure never blocks
    whatever step comes after it - failure is instead caught by the CheckResults gate step
    that always runs last.
 
.PARAMETER DatabaseName
    The new content database. Assumed RBS-enabled already - not verified here.
 
.PARAMETER SqlInstance
    SQL Server instance hosting the database and (for -CreateNewJob/-AppendJobStep) the
    target SQL Agent job.
 
.PARAMETER ConfigPath
    Path to the existing Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config to add/update
    this database's connection string in.
 
.PARAMETER WrapperScriptPath
    Full path to Invoke-RBSMaintainerRun.ps1 (Phase 3) on the target SQL Server host.
 
.PARAMETER MaintainerExePath
    Full path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe on the target SQL Server host.
 
.PARAMETER JobName
    The exact SQL Agent job name to create (-CreateNewJob) or modify (-AppendJobStep) -
    unlike Phase 4/5, this is not built from a prefix + wave name, it's taken as given.
 
.PARAMETER CreateNewJob
    Create a brand-new job named -JobName. Fails if it already exists.
 
.PARAMETER AppendJobStep
    Add a step for -DatabaseName into the existing job named -JobName, just before its
    CheckResults gate step. Fails if the job doesn't exist or doesn't look like a valid
    RBS Maintainer job (see DESCRIPTION).
 
.PARAMETER ScheduleTime
    Daily run time as "HH:mm" (24-hour). Required with -CreateNewJob (a new job needs a
    schedule); ignored with -AppendJobStep (the existing job's schedule is left as-is).
 
.PARAMETER ProxyName
    SQL Agent proxy the new/inserted step runs under. Default 'RBSMaintainer_Proxy'.
 
.PARAMETER TimeLimitMinutes
    Passed through to the wrapper's -TimeLimitMinutes. Default 120.
 
.PARAMETER SuccessExitCodes
    Comma-separated exit codes passed through to the wrapper's -SuccessExitCodes. Default
    '0,10,20,40'. A string, not an array - see Phase 3/4's own notes for why.
 
.PARAMETER ConnectionStringPrefix
    Must match the rest of the solution. Default 'RBSMaintainer_'.
 
.EXAMPLE
    # New site collection's content DB, new standalone job
    .\Add-RBSMaintainerDatabase.ps1 -DatabaseName "WSS_Content_NewSite" -SqlInstance "SQL2022-NEW" `
        -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -JobName "RBS_Maintainer_WSS_Content_NewSite" -CreateNewJob -ScheduleTime "02:00" -WhatIf
 
.EXAMPLE
    # New content DB added to an existing wave's job
    .\Add-RBSMaintainerDatabase.ps1 -DatabaseName "WSS_Content_NewSite" -SqlInstance "SQL2022-NEW" `
        -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -JobName "RBS_Maintainer_Wave0" -AppendJobStep -WhatIf
 
.NOTES
    -AppendJobStep relies on documented SQL Server Agent behavior: calling
    sp_add_jobstep with a @step_id that already belongs to another step inserts the new
    step there and shifts that step (and any after it) down by one - the same mechanism
    SSMS itself uses for "Insert Step". This could not be exercised against a live SQL
    Server instance while this script was written (only the T-SQL/parameter logic could
    be verified in isolation) - run it with -WhatIf first, then for real against a
    low-stakes job, and confirm the resulting step order/IDs in SSMS before relying on it
    for a production job.
#>
 
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,
 
    [Parameter(Mandatory = $true)]
    [string]$SqlInstance,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigPath,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$WrapperScriptPath,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$MaintainerExePath,
 
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$JobName,
 
    [switch]$CreateNewJob,
 
    [switch]$AppendJobStep,
 
    [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
    [string]$ScheduleTime,
 
    [string]$ProxyName = 'RBSMaintainer_Proxy',
 
    [int]$TimeLimitMinutes = 120,
 
    [string]$SuccessExitCodes = '0,10,20,40',
 
    [string]$ConnectionStringPrefix = 'RBSMaintainer_'
)
 
# ---- Upfront validation - fail before touching the config or SQL Server ----
 
if (-not $CreateNewJob -and -not $AppendJobStep) {
    throw "Specify either -CreateNewJob or -AppendJobStep."
}
if ($CreateNewJob -and $AppendJobStep) {
    throw "-CreateNewJob and -AppendJobStep cannot be used in the same execution - choose one."
}
if ($CreateNewJob -and -not $ScheduleTime) {
    throw "-ScheduleTime is required when using -CreateNewJob."
}
if ($AppendJobStep -and $ScheduleTime) {
    Write-Warning "-ScheduleTime is ignored with -AppendJobStep - the existing job's schedule is left as-is."
}
 
$ConfigPath         = (Resolve-Path -Path $ConfigPath).ProviderPath
$WrapperScriptPath  = (Resolve-Path -Path $WrapperScriptPath).ProviderPath
$MaintainerExePath  = (Resolve-Path -Path $MaintainerExePath).ProviderPath
 
# ---- Helpers (shared by both -CreateNewJob and -AppendJobStep) ----
 
function New-RBSDatabaseStepCommand {
    # Builds the exact CmdExec command line Phase 4 uses for a per-database step -
    # -SuccessExitCodes stays ONE quoted comma-separated token, not space-separated
    # values, for the same reason documented in Phase 3/4.
    param(
        [string]$WrapperScriptPath, [string]$DatabaseName, [string]$MaintainerExePath,
        [string]$ConnectionStringPrefix, [int]$TimeLimitMinutes, [string]$SuccessExitCodes
    )
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $WrapperScriptPath + '"' +
        ' -DatabaseName "' + $DatabaseName + '"' +
        ' -MaintainerExePath "' + $MaintainerExePath + '"' +
        ' -ConnectionStringPrefix "' + $ConnectionStringPrefix + '"' +
        ' -TimeLimitMinutes ' + $TimeLimitMinutes +
        ' -SuccessExitCodes "' + $SuccessExitCodes + '"'
}
 
function New-RBSGateStepCommand {
    # Same CheckResults T-SQL template Phase 4 uses, parameterized by how many database
    # steps precede it - see New-RBSMaintainerAgentJobs.ps1's own header comment for why
    # this count has to be exact (it drives how many recent job-history rows the gate
    # step reads back to decide pass/fail).
    param([string]$JobName, [int]$DatabaseStepCount)
    $escapedJobName = $JobName.Replace("'", "''")
    @"
DECLARE @gateJobId BINARY(16) = (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = N'$escapedJobName');
DECLARE @failedCount INT;
 
SELECT @failedCount = COUNT(*)
FROM (
    SELECT TOP ($DatabaseStepCount) run_status
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
}
 
function Set-RBSMaintainerConnectionStringEntry {
    # Adds/updates one connection string entry - the same logic and connection string
    # format as Update-RBSMaintainerConfig.ps1 (Phase 2), inlined here since this script
    # works from direct parameters rather than Phase 1's status CSV.
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$ConfigPath, [string]$DatabaseName, [string]$SqlInstance, [string]$ConnectionStringPrefix
    )
 
    [xml]$configXml = Get-Content -Path $ConfigPath -Raw
    $connectionStringsNode = $configXml.configuration.connectionStrings
 
    if ($connectionStringsNode -and $connectionStringsNode.EncryptedData) {
        throw "The <connectionStrings> section in '$ConfigPath' is encrypted. Decrypt it first (rename to web.config, run 'aspnet_regiis -pdf connectionStrings', rename back) before re-running this script."
    }
    if (-not $connectionStringsNode) {
        $connectionStringsNode = $configXml.CreateElement('connectionStrings')
        $configXml.configuration.AppendChild($connectionStringsNode) | Out-Null
    }
 
    $connStringName  = "$ConnectionStringPrefix$DatabaseName"
    $connStringValue = "Server=$SqlInstance;Database=$DatabaseName;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
    $existingNode    = $connectionStringsNode.SelectSingleNode("add[@name='$connStringName']")
    $action          = if ($existingNode) { 'Update connection string' } else { 'Add connection string' }
 
    if (-not $PSCmdlet.ShouldProcess($connStringName, $action)) { return $false }
 
    if ($existingNode) {
        $existingNode.SetAttribute('connectionString', $connStringValue)
        $existingNode.SetAttribute('providerName', 'System.Data.SqlClient')
    }
    else {
        $newNode = $configXml.CreateElement('add')
        $newNode.SetAttribute('name', $connStringName)
        $newNode.SetAttribute('connectionString', $connStringValue)
        $newNode.SetAttribute('providerName', 'System.Data.SqlClient')
        $connectionStringsNode.AppendChild($newNode) | Out-Null
    }
 
    $backupPath = "$ConfigPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item -Path $ConfigPath -Destination $backupPath -Force
    $configXml.Save($ConfigPath)
    Write-Host "$action for '$connStringName' (backup: $backupPath)" -ForegroundColor Green
    return $true
}
 
# ---- Step 1 (always): connection string ----
 
Write-Host "--- Config: $ConfigPath ---" -ForegroundColor Cyan
[void](Set-RBSMaintainerConnectionStringEntry -ConfigPath $ConfigPath -DatabaseName $DatabaseName `
    -SqlInstance $SqlInstance -ConnectionStringPrefix $ConnectionStringPrefix)
Write-Host ""
 
# ---- Step 2: create or append ----
 
Write-Host "--- Job: $JobName on $SqlInstance ---" -ForegroundColor Cyan
 
$connString = "Server=$SqlInstance;Database=msdb;Integrated Security=True;Encrypt=False;TrustServerCertificate=True;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connString
$conn.Open()
 
try {
    $checkCmd = $conn.CreateCommand()
    $checkCmd.CommandText = 'SELECT job_id FROM msdb.dbo.sysjobs WHERE name = @jobName'
    [void]$checkCmd.Parameters.AddWithValue('@jobName', $JobName)
    $existingJobId = $checkCmd.ExecuteScalar()
    $jobExists = ($null -ne $existingJobId) -and ($existingJobId -isnot [DBNull])
 
    if ($CreateNewJob) {
        if ($jobExists) {
            throw "Job '$JobName' already exists on '$SqlInstance'. Use -AppendJobStep to add a step to it instead, or choose a different -JobName."
        }
 
        if (-not $PSCmdlet.ShouldProcess($JobName, "Create SQL Agent job with 1 database step for '$DatabaseName'")) { return }
 
        $activeStartTime = [int]([datetime]::ParseExact($ScheduleTime, 'HH:mm', $null).ToString('HHmmss'))
        $dbCommand   = New-RBSDatabaseStepCommand -WrapperScriptPath $WrapperScriptPath -DatabaseName $DatabaseName `
            -MaintainerExePath $MaintainerExePath -ConnectionStringPrefix $ConnectionStringPrefix `
            -TimeLimitMinutes $TimeLimitMinutes -SuccessExitCodes $SuccessExitCodes
        $gateCommand = New-RBSGateStepCommand -JobName $JobName -DatabaseStepCount 1
        $stepName    = "${JobName}_$DatabaseName"
        $gateStepName = "${JobName}_CheckResults"
 
        $sql = New-Object System.Text.StringBuilder
        [void]$sql.AppendLine('DECLARE @jobId BINARY(16);')
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_job @job_name = @jobName, @enabled = 1, @description = @description, @job_id = @jobId OUTPUT;')
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobstep @job_id = @jobId, @step_id = 1, @step_name = @stepName, @subsystem = N''CmdExec'', @command = @command, @proxy_name = @proxyName, @on_success_action = 3, @on_fail_action = 3, @retry_attempts = 0;')
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobstep @job_id = @jobId, @step_id = 2, @step_name = @gateStepName, @subsystem = N''TSQL'', @database_name = N''msdb'', @command = @gateCommand, @on_success_action = 1, @on_fail_action = 2, @retry_attempts = 0;')
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobschedule @job_id = @jobId, @name = @jobName, @freq_type = 4, @freq_interval = 1, @freq_subday_type = 1, @active_start_time = @activeStartTime;')
        [void]$sql.AppendLine('EXEC msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N''(local)'';')
 
        $createCmd = $conn.CreateCommand()
        $createCmd.CommandText = $sql.ToString()
        [void]$createCmd.Parameters.AddWithValue('@jobName', $JobName)
        [void]$createCmd.Parameters.AddWithValue('@description', "Runs RBS Maintainer (GC + consistency check) for $DatabaseName.")
        [void]$createCmd.Parameters.AddWithValue('@stepName', $stepName)
        [void]$createCmd.Parameters.AddWithValue('@command', $dbCommand)
        [void]$createCmd.Parameters.AddWithValue('@proxyName', $ProxyName)
        [void]$createCmd.Parameters.AddWithValue('@gateStepName', $gateStepName)
        [void]$createCmd.Parameters.AddWithValue('@gateCommand', $gateCommand)
        [void]$createCmd.Parameters.AddWithValue('@activeStartTime', $activeStartTime)
        [void]$createCmd.ExecuteNonQuery()
 
        Write-Host "Created: $JobName - step '$stepName' + '$gateStepName', daily at $ScheduleTime" -ForegroundColor Green
    }
    else {
        # -AppendJobStep
        if (-not $jobExists) {
            throw "Job '$JobName' does not exist on '$SqlInstance'. Use -CreateNewJob to create it first."
        }
        if (-not $JobName.Contains('RBS_Maintainer_')) {
            throw "Job name '$JobName' does not contain 'RBS_Maintainer_' - refusing to modify a job that doesn't look like an RBS Maintainer job."
        }
 
        $stepsCmd = $conn.CreateCommand()
        $stepsCmd.CommandText = 'SELECT step_id, step_name FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId ORDER BY step_id ASC'
        [void]$stepsCmd.Parameters.AddWithValue('@jobId', $existingJobId)
        $steps = @()
        $reader = $stepsCmd.ExecuteReader()
        try {
            while ($reader.Read()) {
                $steps += [pscustomobject]@{ StepId = [int]$reader['step_id']; StepName = [string]$reader['step_name'] }
            }
        }
        finally { $reader.Close() }
 
        if ($steps.Count -eq 0) {
            throw "Job '$JobName' has no steps - nothing to insert before."
        }
 
        $lastStep = $steps[-1]
        if (-not ($lastStep.StepName.Contains('RBS_Maintainer_') -and $lastStep.StepName.Contains('CheckResults'))) {
            throw "Job '$JobName''s last step ('$($lastStep.StepName)') doesn't look like an RBS Maintainer CheckResults gate step (expected its name to contain both 'RBS_Maintainer_' and 'CheckResults'). Refusing to modify it."
        }
 
        $newStepName = "${JobName}_$DatabaseName"
        if ($steps.StepName -contains $newStepName) {
            throw "Job '$JobName' already has a step named '$newStepName' for this database."
        }
 
        if (-not $PSCmdlet.ShouldProcess($JobName, "Insert step '$newStepName' before '$($lastStep.StepName)'")) { return }
 
        $dbCommand = New-RBSDatabaseStepCommand -WrapperScriptPath $WrapperScriptPath -DatabaseName $DatabaseName `
            -MaintainerExePath $MaintainerExePath -ConnectionStringPrefix $ConnectionStringPrefix `
            -TimeLimitMinutes $TimeLimitMinutes -SuccessExitCodes $SuccessExitCodes
 
        # Inserting at the gate step's CURRENT step_id shifts the gate step (and anything
        # after it - normally nothing) down by one; this is documented SQL Server Agent
        # behavior (the same mechanism SSMS's own "Insert Step" uses) - see .NOTES.
        $insertCmd = $conn.CreateCommand()
        $insertCmd.CommandText = 'EXEC msdb.dbo.sp_add_jobstep @job_id = @jobId, @step_id = @stepId, @step_name = @stepName, @subsystem = N''CmdExec'', @command = @command, @proxy_name = @proxyName, @on_success_action = 3, @on_fail_action = 3, @retry_attempts = 0;'
        [void]$insertCmd.Parameters.AddWithValue('@jobId', $existingJobId)
        [void]$insertCmd.Parameters.AddWithValue('@stepId', $lastStep.StepId)
        [void]$insertCmd.Parameters.AddWithValue('@stepName', $newStepName)
        [void]$insertCmd.Parameters.AddWithValue('@command', $dbCommand)
        [void]$insertCmd.Parameters.AddWithValue('@proxyName', $ProxyName)
        [void]$insertCmd.ExecuteNonQuery()
 
        # Re-look-up the gate step by NAME (not by arithmetic +1) to get its new step_id -
        # more robust than assuming exactly how the renumbering landed.
        $gateIdCmd = $conn.CreateCommand()
        $gateIdCmd.CommandText = 'SELECT step_id FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId AND step_name = @stepName'
        [void]$gateIdCmd.Parameters.AddWithValue('@jobId', $existingJobId)
        [void]$gateIdCmd.Parameters.AddWithValue('@stepName', $lastStep.StepName)
        $newGateStepId = [int]$gateIdCmd.ExecuteScalar()
 
        $countCmd = $conn.CreateCommand()
        $countCmd.CommandText = 'SELECT COUNT(*) FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId'
        [void]$countCmd.Parameters.AddWithValue('@jobId', $existingJobId)
        $totalSteps = [int]$countCmd.ExecuteScalar()
        $newDbStepCount = $totalSteps - 1   # every step except the gate step itself
 
        $updatedGateCommand = New-RBSGateStepCommand -JobName $JobName -DatabaseStepCount $newDbStepCount
 
        $updateGateCmd = $conn.CreateCommand()
        $updateGateCmd.CommandText = 'EXEC msdb.dbo.sp_update_jobstep @job_id = @jobId, @step_id = @stepId, @command = @command;'
        [void]$updateGateCmd.Parameters.AddWithValue('@jobId', $existingJobId)
        [void]$updateGateCmd.Parameters.AddWithValue('@stepId', $newGateStepId)
        [void]$updateGateCmd.Parameters.AddWithValue('@command', $updatedGateCommand)
        [void]$updateGateCmd.ExecuteNonQuery()
 
        Write-Host "Inserted: '$newStepName' as step $($lastStep.StepId), gate step '$($lastStep.StepName)' moved to step $newGateStepId and now checks $newDbStepCount database step(s)." -ForegroundColor Green
    }
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    $conn.Close()
    $conn.Dispose()
}
 
Write-Host ""
Write-Host "=== Done: $DatabaseName -> $JobName ===" -ForegroundColor Green
 