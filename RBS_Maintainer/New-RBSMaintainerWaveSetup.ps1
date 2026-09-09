<#
.SYNOPSIS
    Phase 5 - Wave orchestrator. Runs Phase 1 (RBS detection), Phase 2 (config file
    update), and Phase 4 (SQL Agent wave job creation) for one wave, in sequence.
 
.DESCRIPTION
    Single entry point for setting up RBS Maintainer automation for one migration wave.
    Calls, in order:
        1. Detect-RBSEnabledDatabases.ps1  - checks every DB in -WaveFile against
                                              -SqlInstance, writes "<wave>_RBSStatus.csv".
        2. Update-RBSMaintainerConfig.ps1  - adds/updates connection strings in
                                              -ConfigPath for every RBS-enabled DB found.
        4. New-RBSMaintainerAgentJobs.ps1  - creates (or recreates, with -DropExisting)
                                              the single "<JobNamePrefix><WaveName>" SQL
                                              Agent job with one step per RBS-enabled DB.
 
    (There is no separate Phase 3 call here - Invoke-RBSMaintainerRun.ps1 is the wrapper
    that the SQL Agent job STEPS run later, on their own schedule; this orchestrator never
    invokes it directly.)
 
    Supports -WhatIf: Phase 1 always runs as written (it is read-only - it only queries
    metadata and writes a CSV, so previewing it separately would add nothing), but
    -WhatIf is forwarded to Phase 2 and Phase 4 so you can preview exactly what
    connection strings and what SQL Agent job/steps WOULD be created/changed, without
    writing anything, before running for real.
 
    If any phase fails, the chain stops immediately - later phases are not attempted
    against a possibly-incomplete earlier result.
 
.PARAMETER WaveFile
    Path to the wave's database list (one content database name per line), e.g.
    "Wave0_Databases.txt".
 
.PARAMETER WaveName
    Wave identifier used to build the job name, e.g. "Wave0" -> job name
    "RBS_Maintainer_Wave0" (with the default -JobNamePrefix). Should normally match
    -WaveFile's own wave number, but is taken as an explicit parameter rather than
    inferred from the file name, since that naming isn't guaranteed.
 
.PARAMETER SqlInstance
    Target SQL Server instance for every database in -WaveFile (Phase 1).
 
.PARAMETER ConfigPath
    Path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config on this machine, updated
    by Phase 2.
 
.PARAMETER WrapperScriptPath
    Full path to Invoke-RBSMaintainerRun.ps1 (Phase 3) ON THE TARGET SQL SERVER HOST -
    passed straight through to Phase 4, which bakes it into each step's CmdExec command.
 
.PARAMETER MaintainerExePath
    Full path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe ON THE TARGET SQL SERVER
    HOST - passed straight through to Phase 4.
 
.PARAMETER ScheduleTime
    Daily run time as "HH:mm" (24-hour), e.g. "02:00" - passed through to Phase 4.
 
.PARAMETER ProxyName
    SQL Agent proxy the per-database CmdExec steps run under. Default 'RBSMaintainer_Proxy'.
 
.PARAMETER TimeLimitMinutes
    Passed through to Phase 4 (and from there to every step's wrapper invocation).
    Default 120.
 
.PARAMETER SuccessExitCodes
    Comma-separated exit codes treated as success, e.g. "0,10,20,40" (the default).
    Passed through unchanged to Phase 4. A string, not an array - see Phase 3/4's own
    notes for why (PowerShell's external-invocation parameter binder does not reliably
    collect space-separated tokens into an array parameter).
 
.PARAMETER ConnectionStringPrefix
    Shared between Phase 2 (names the entries it writes) and Phase 4 (names the entries
    each step's wrapper invocation looks up). Default 'RBSMaintainer_'.
 
.PARAMETER JobNamePrefix
    Prefix for the generated job name, passed through to Phase 4. Default 'RBS_Maintainer_'.
 
.PARAMETER ConnectTimeoutSeconds
    SQL connection timeout in seconds for Phase 1's per-database checks. Default 15.
 
.PARAMETER ScriptsDirectory
    Folder containing Detect-RBSEnabledDatabases.ps1, Update-RBSMaintainerConfig.ps1, and
    New-RBSMaintainerAgentJobs.ps1. Defaults to this script's own folder.
 
.PARAMETER DropExisting
    Passed through to Phase 4: if the wave's job already exists, drop and recreate it
    instead of skipping.
 
.EXAMPLE
    # Preview everything for Wave0 - detects RBS status for real (read-only), then shows
    # what Phase 2/4 WOULD change, without writing anything.
    .\New-RBSMaintainerWaveSetup.ps1 -WaveFile .\Wave0_Databases.txt -WaveName "Wave0" `
        -SqlInstance "SQL2022-NEW" `
        -ConfigPath "F:\RBS\Maintainer\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -ScheduleTime "02:00" -WhatIf
 
.EXAMPLE
    # Run for real.
    .\New-RBSMaintainerWaveSetup.ps1 -WaveFile .\Wave0_Databases.txt -WaveName "Wave0" `
        -SqlInstance "SQL2022-NEW" `
        -ConfigPath "F:\RBS\Maintainer\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
        -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
        -MaintainerExePath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
        -ScheduleTime "02:00"
 
.NOTES
    Run this on the target SQL Server host (or anywhere with network access to it) using
    an account with rights to read every database in the wave and to msdb on the target
    instance. Assumes Windows Authentication end to end, matching the rest of this
    solution.
#>
 
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$WaveFile,
 
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WaveName,
 
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
    [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
    [string]$ScheduleTime,
 
    [string]$ProxyName = 'RBSMaintainer_Proxy',
 
    [int]$TimeLimitMinutes = 120,
 
    [string]$SuccessExitCodes = '0,10,20,40',
 
    [string]$ConnectionStringPrefix = 'RBSMaintainer_',
 
    [string]$JobNamePrefix = 'RBS_Maintainer_',
 
    [int]$ConnectTimeoutSeconds = 15,
 
    [string]$ScriptsDirectory,
 
    [switch]$DropExisting
)
 
# ---- Resolve the folder holding Phase 1/2/4, then each phase script's path ----
# Same fallback used in Phase 3 for -LogDirectory: $PSScriptRoot is not reliably
# populated as a param-block default value expression, so it's resolved here instead.
if (-not $ScriptsDirectory) {
    $ScriptsDirectory = if ($PSScriptRoot) {
        $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    }
    else {
        Write-Warning "Could not determine this script's own folder - defaulting -ScriptsDirectory to the current directory."
        (Get-Location).Path
    }
}
else {
    $ScriptsDirectory = (Resolve-Path -Path $ScriptsDirectory).ProviderPath
}
 
$phase1ScriptPath = Join-Path $ScriptsDirectory 'Detect-RBSEnabledDatabases.ps1'
$phase2ScriptPath = Join-Path $ScriptsDirectory 'Update-RBSMaintainerConfig.ps1'
$phase4ScriptPath = Join-Path $ScriptsDirectory 'New-RBSMaintainerAgentJobs.ps1'
 
foreach ($required in @(
    @{ Path = $phase1ScriptPath; Name = 'Detect-RBSEnabledDatabases.ps1' },
    @{ Path = $phase2ScriptPath; Name = 'Update-RBSMaintainerConfig.ps1' },
    @{ Path = $phase4ScriptPath; Name = 'New-RBSMaintainerAgentJobs.ps1' }
)) {
    if (-not (Test-Path -Path $required.Path -PathType Leaf)) {
        throw "$($required.Name) was not found in '$ScriptsDirectory'. Pass -ScriptsDirectory to point at the folder containing all three Phase 1/2/4 scripts."
    }
}
 
# ---- Resolve inputs to full paths up front (see Phase 2's own notes on why) ----
$WaveFile          = (Resolve-Path -Path $WaveFile).ProviderPath
$ConfigPath        = (Resolve-Path -Path $ConfigPath).ProviderPath
$WrapperScriptPath = (Resolve-Path -Path $WrapperScriptPath).ProviderPath
$MaintainerExePath = (Resolve-Path -Path $MaintainerExePath).ProviderPath
 
# ---- Compute Phase 1's output CSV path explicitly ----
# This mirrors Detect-RBSEnabledDatabases.ps1's own default-naming logic, but is computed
# here and passed in via -OutputCsv so Phase 2/4 are guaranteed to read the exact same
# file Phase 1 just wrote, rather than each independently re-deriving the name.
$waveBase = [System.IO.Path]::GetFileNameWithoutExtension($WaveFile)
$waveDir  = Split-Path -Path $WaveFile -Parent
$statusCsvPath = Join-Path $waveDir "$($waveBase)_RBSStatus.csv"
 
$jobName = "$JobNamePrefix$WaveName"
 
Write-Host "=== RBS Maintainer wave setup: $WaveName ===" -ForegroundColor Cyan
Write-Host "  Wave file       : $WaveFile"
Write-Host "  SQL instance    : $SqlInstance"
Write-Host "  Config file     : $ConfigPath"
Write-Host "  Target job name : $jobName"
Write-Host "  Schedule        : daily at $ScheduleTime"
if ($WhatIfPreference) {
    Write-Host "  Mode            : -WhatIf (preview only - Phase 2/4 will not write or create anything)" -ForegroundColor Yellow
}
Write-Host ""
 
# ---- Phase 1: detect RBS-enabled databases (always runs - read-only) ----
 
Write-Host "--- Phase 1: Detect RBS-enabled databases ---" -ForegroundColor Cyan
try {
    # Phase 1 has no -WhatIf parameter of its own (it's read-only, so there's nothing to
    # preview) - but $WhatIfPreference is a preference variable that PowerShell resolves
    # up the parent scope chain, so if this orchestrator was itself invoked with -WhatIf,
    # that $true value would otherwise be silently visible inside Phase 1 too and put ITS
    # internal Export-Csv into WhatIf mode - skipping the write and leaving Phase 2/4 with
    # no status CSV to read. Running the call inside its own script block with
    # $WhatIfPreference forced back to $false scopes that override to just this call,
    # without touching the outer $WhatIfPreference that Phase 2/4 still need below.
    & {
        $WhatIfPreference = $false
        & $phase1ScriptPath `
            -WaveFile $WaveFile `
            -SqlInstance $SqlInstance `
            -OutputCsv $statusCsvPath `
            -ConnectTimeoutSeconds $ConnectTimeoutSeconds
    }
}
catch {
    Write-Error "Phase 1 (RBS detection) failed - stopping before Phase 2/4: $($_.Exception.Message)"
    return
}
 
if (-not (Test-Path -Path $statusCsvPath -PathType Leaf)) {
    Write-Error "Phase 1 did not produce a status CSV at '$statusCsvPath' (see the console output above - the wave file may have contained no database names). Stopping before Phase 2/4."
    return
}
 
$statusRows = Import-Csv -Path $statusCsvPath
$rbsCount   = @($statusRows | Where-Object { $_.RBSEnabled -eq 'True' }).Count
Write-Host "Phase 1 complete: $rbsCount of $($statusRows.Count) database(s) in '$WaveName' are RBS-enabled." -ForegroundColor Cyan
Write-Host ""
 
# ---- Phase 2: add/update connection strings for RBS-enabled databases ----
 
Write-Host "--- Phase 2: Update RBS Maintainer config ---" -ForegroundColor Cyan
try {
    & $phase2ScriptPath `
        -StatusCsv $statusCsvPath `
        -ConfigPath $ConfigPath `
        -ConnectionStringPrefix $ConnectionStringPrefix `
        -WhatIf:$WhatIfPreference
}
catch {
    Write-Error "Phase 2 (config update) failed - stopping before Phase 4: $($_.Exception.Message)"
    return
}
Write-Host ""
 
# ---- Phase 4: create/recreate the wave's SQL Agent job ----
 
Write-Host "--- Phase 4: Create SQL Agent wave job ---" -ForegroundColor Cyan
try {
    & $phase4ScriptPath `
        -StatusCsv $statusCsvPath `
        -WaveName $WaveName `
        -WrapperScriptPath $WrapperScriptPath `
        -MaintainerExePath $MaintainerExePath `
        -ScheduleTime $ScheduleTime `
        -ProxyName $ProxyName `
        -TimeLimitMinutes $TimeLimitMinutes `
        -SuccessExitCodes $SuccessExitCodes `
        -ConnectionStringPrefix $ConnectionStringPrefix `
        -JobNamePrefix $JobNamePrefix `
        -DropExisting:$DropExisting `
        -WhatIf:$WhatIfPreference
}
catch {
    Write-Error "Phase 4 (SQL Agent job creation) failed: $($_.Exception.Message)"
    return
}
Write-Host ""
 
Write-Host "=== Wave setup complete: $WaveName ===" -ForegroundColor Green
if ($WhatIfPreference) {
    Write-Host "This was a -WhatIf preview - nothing was written or created. Re-run without -WhatIf to apply." -ForegroundColor Yellow
}
else {
    Write-Host "Status CSV : $statusCsvPath"
    Write-Host "Job        : $jobName (SSMS: SQL Server Agent > Jobs)"
    Write-Host "Rollback   : sp_delete_job @job_name = N'$jobName' removes the job; the config backup" -ForegroundColor DarkGray
    Write-Host "             taken by Phase 2 (ConfigPath.bak_<timestamp>, only if a change was made)" -ForegroundColor DarkGray
    Write-Host "             can be restored to undo the connection string change." -ForegroundColor DarkGray
}
 