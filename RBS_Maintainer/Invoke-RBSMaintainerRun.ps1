<#
.SYNOPSIS
    Phase 3 - Runs Microsoft.Data.SqlRemoteBlobs.Maintainer.exe for one content database,
    logs full output, and normalizes its exit code for SQL Server Agent.
 
.DESCRIPTION
    Wraps a single RBS Maintainer run so a SQL Agent job step can reliably tell success
    from failure.
 
    SQL Server Agent's CmdExec subsystem can only be configured with ONE "successful"
    exit code (default 0) - it has no concept of "any of these codes means success".
    RBS Maintainer is known to return non-zero exit codes on runs that are not actually
    failures. This wrapper runs the exe, captures the RAW exit code, classifies it
    against -SuccessExitCodes, logs everything (command line, stdout, stderr, raw exit
    code, classification), and then itself exits with a single normalized code:
        0  = raw exit code was in -SuccessExitCodes (default: 0, 10, 20, 40)
        1  = anything else (real failure, process could not start, or it timed out)
 
    The success-code list is provisional (confirmed as of the RBS Maintainer version in
    use, treating everything else as failure for now) and is a parameter specifically so
    it can be revised later from the accumulated logs without touching this script's
    logic or any SQL Agent job definition.
 
    -SuccessExitCodes is a comma-separated STRING, not a PowerShell array parameter, and
    that is deliberate: testing found that when this script is invoked externally (as a
    SQL Agent CmdExec step does, via "powershell.exe -File ... -SuccessExitCodes 0 10 20
    40"), PowerShell's command-line binder does NOT collect multiple space-separated
    tokens into one array parameter - it silently takes only the first value and lets the
    rest bind positionally to whatever parameters come next in this param block
    (corrupting -Operation/-GarbageCollectionPhases/-ConsistencyCheckMode with exit-code
    numbers). A single quoted string, split internally, avoids that entirely. -Operation
    is still a real array parameter below because Phase 4 never sets it on the command
    line (it relies on this default) - if that ever changes, convert it the same way
    first.
 
.PARAMETER DatabaseName
    Content database name. Used to build the connection string name
    (<ConnectionStringPrefix><DatabaseName>, matching Phase 2's naming) and to name the log file.
 
.PARAMETER MaintainerExePath
    Full path to Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.
 
.PARAMETER ConnectionStringPrefix
    Must match the prefix used by Update-RBSMaintainerConfig.ps1 (Phase 2). Default 'RBSMaintainer_'.
 
.PARAMETER Operation
    RBS Maintainer -Operation value(s). Default matches the RBS installer's own default:
    GarbageCollection, ConsistencyCheck, ConsistencyCheckForStores.
 
.PARAMETER GarbageCollectionPhases
    Default 'rdo' (Reference scan, Delete propagation, Orphan cleanup) - matches installer default.
 
.PARAMETER ConsistencyCheckMode
    Default 'r' - matches installer default.
 
.PARAMETER TimeLimitMinutes
    Maximum time budget passed to the exe's own -TimeLimit. Default 120 (installer default).
 
.PARAMETER SuccessExitCodes
    Comma-separated exit codes treated as success, e.g. "0,10,20,40" (the default). A
    string rather than an array - see DESCRIPTION for why.
 
.PARAMETER LogDirectory
    Where per-database log files are written (appended to, one file per DB). Default
    "<script folder>\Logs" - uses $PSScriptRoot rather than a relative path, so it
    resolves correctly regardless of the caller's working directory.
 
.PARAMETER LogRetentionDays
    Before appending this run's entry, entries older than this many days are trimmed from
    the database's log file, so it doesn't grow unbounded. Default 30. Set to 0 to disable
    pruning and keep everything. Runs on every invocation - since this is the same script
    that writes the log, no separate cleanup job is needed.
 
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Invoke-RBSMaintainerRun.ps1" `
        -DatabaseName "WSS_Content" -MaintainerExePath "F:\RBS\Maintainer\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe"
 
.NOTES
    IMPORTANT FOR MANUAL TESTING: this script ends with a bare 'exit <code>'. If you run
    it directly at an interactive PowerShell prompt (".\Invoke-RBSMaintainerRun.ps1 ..."),
    that 'exit' will close your CURRENT PowerShell session/window, because a script run
    that way executes in the same process, not a child one. Test it the same way SQL
    Agent will actually invoke it, as a child process, so 'exit' only ends that child:
 
        powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Invoke-RBSMaintainerRun.ps1 `
            -DatabaseName "WSS_Content" -MaintainerExePath "..." -TimeLimitMinutes 5
        Write-Host "Wrapper exit code: $LASTEXITCODE"
 
    Intended to be called from a SQL Server Agent CmdExec job step (Phase 4) via
    powershell.exe -File, not the native "PowerShell" step subsystem - that subsystem has
    documented issues reliably surfacing a script's real exit code to the job step.
#>
 
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,
 
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$MaintainerExePath,
 
    [string]$ConnectionStringPrefix = 'RBSMaintainer_',
 
    [string[]]$Operation = @('GarbageCollection', 'ConsistencyCheck', 'ConsistencyCheckForStores'),
 
    [string]$GarbageCollectionPhases = 'rdo',
 
    [string]$ConsistencyCheckMode = 'r',
 
    [int]$TimeLimitMinutes = 120,
 
    [string]$SuccessExitCodes = '0,10,20,40',
 
    [string]$LogDirectory,
 
    [int]$LogRetentionDays = 30
)
 
function ConvertTo-ProcessArgumentString {
    # ProcessStartInfo.Arguments (Windows PowerShell / .NET Framework) takes one string,
    # not an array - quote any element that contains whitespace or a quote so it survives
    # as a single argument.
    param([string[]]$ArgumentList)
    ($ArgumentList | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }) -join ' '
}
 
function Remove-OldLogEntries {
    # Each entry in the log written below always starts with a line like
    # "==== 2026-09-09 02:00:00 | Database: WSS_Content ====" - split the file on that
    # marker (a zero-width lookahead keeps the marker attached to the entry it starts,
    # rather than the one before it), parse each entry's own timestamp out of its header
    # line, and keep only entries within the retention window plus anything that doesn't
    # parse (never silently discard something this pattern doesn't recognize).
    param(
        [Parameter(Mandatory = $true)][string]$LogFile,
        [Parameter(Mandatory = $true)][int]$RetentionDays
    )
 
    if ($RetentionDays -le 0) { return }
    if (-not (Test-Path -Path $LogFile -PathType Leaf)) { return }
 
    $existingContent = Get-Content -Path $LogFile -Raw
    if (-not $existingContent) { return }
 
    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $entryStartPattern = '(?m)(?=^==== \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \| Database: )'
    $entries = [regex]::Split($existingContent, $entryStartPattern) | Where-Object { $_.Trim() }
 
    if ($entries.Count -eq 0) { return }
 
    $keptEntries = foreach ($entry in $entries) {
        if ($entry -match '^==== (?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \|') {
            $entryDate = [datetime]::ParseExact($Matches['ts'], 'yyyy-MM-dd HH:mm:ss', $null)
            if ($entryDate -ge $cutoff) { $entry }
        }
        else {
            # Doesn't match the expected header shape (e.g. leftover/malformed content) -
            # keep it rather than risk losing data pruning can't confidently judge.
            $entry
        }
    }
 
    if (@($keptEntries).Count -lt $entries.Count) {
        Set-Content -Path $LogFile -Value (($keptEntries) -join '') -Encoding UTF8 -NoNewline
    }
}
 
$finalExitCode = 1   # fail closed unless we prove success below
 
# Parse the comma-separated -SuccessExitCodes string into actual integers (see
# DESCRIPTION for why this parameter is a string, not [int[]]).
$successExitCodeList = @($SuccessExitCodes -split ',' | ForEach-Object { [int]$_.Trim() })
 
try {
    if (-not $LogDirectory) {
        # $PSScriptRoot is not reliably populated as a param-block default value in every
        # invocation context - resolve it here instead, with a fallback to the invoked
        # script's own path so this still works even when $PSScriptRoot comes back empty.
        $scriptFolder = if ($PSScriptRoot) {
            $PSScriptRoot
        }
        elseif ($MyInvocation.MyCommand.Path) {
            Split-Path -Path $MyInvocation.MyCommand.Path -Parent
        }
        else {
            Write-Warning "Could not determine the script's own folder - defaulting LogDirectory to the current directory."
            (Get-Location).Path
        }
        $LogDirectory = Join-Path $scriptFolder 'Logs'
    }
 
    if (-not (Test-Path $LogDirectory)) {
        New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
    }
 
    $startTime      = Get-Date
    $connStringName = "$ConnectionStringPrefix$DatabaseName"
    $logFile        = Join-Path $LogDirectory "$DatabaseName.log"
 
    $exeArgs = @(
        '-ConnectionStringName', $connStringName,
        '-Operation'
    ) + $Operation + @(
        '-GarbageCollectionPhases', $GarbageCollectionPhases,
        '-ConsistencyCheckMode', $ConsistencyCheckMode,
        '-TimeLimit', $TimeLimitMinutes
    )
 
    $commandLine = "`"$MaintainerExePath`" " + ($exeArgs -join ' ')
 
    $rawExitCode     = $null
    $timedOut        = $false
    $hadProcessError = $false
    $processError    = $null
    $stdOut          = ''
    $stdErr          = ''
 
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $MaintainerExePath
        $psi.Arguments              = ConvertTo-ProcessArgumentString -ArgumentList $exeArgs
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
 
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
 
        # Using the raw Process/ProcessStartInfo API here rather than Start-Process:
        # testing showed Start-Process -PassThru -NoNewWindow combined with
        # -RedirectStandardOutput/-RedirectStandardError does not reliably surface
        # .ExitCode afterwards on this environment (reproduced on both a failing AND a
        # fully successful RBS Maintainer run) - a known limitation of that cmdlet
        # combination.
        #
        # Output is captured via ReadToEndAsync() Tasks started immediately after Start()
        # and explicitly awaited afterwards - this avoids the classic pipe-buffer deadlock
        # of only reading after WaitForExit(), and testing showed it reliably captures
        # everything, unlike the event-based (OutputDataReceived) pattern tried first,
        # which does not consistently finish flushing before WaitForExit() returns.
        [void]$process.Start()
        $stdOutTask = $process.StandardOutput.ReadToEndAsync()
        $stdErrTask = $process.StandardError.ReadToEndAsync()
 
        # Safety net beyond the exe's own -TimeLimit, in case it hangs outright
        # (e.g. blocked on a lock) rather than completing its own internal budget.
        $timeoutMs = ($TimeLimitMinutes + 15) * 60 * 1000
        $exited = $process.WaitForExit($timeoutMs)
 
        if (-not $exited) {
            $timedOut = $true
            try { $process.Kill() } catch { }
        }
 
        $process.WaitForExit()
 
        # The read tasks complete once the child closes its output handles, which
        # normally happens at/just after exit - wait for them explicitly (with their own
        # generous timeout) rather than assuming they're already done.
        [System.Threading.Tasks.Task]::WaitAll(@($stdOutTask, $stdErrTask), 60000) | Out-Null
 
        $rawExitCode = $process.ExitCode
        $stdOut = if ($stdOutTask.IsCompleted) { $stdOutTask.Result } else { '' }
        $stdErr = if ($stdErrTask.IsCompleted) { $stdErrTask.Result } else { '' }
    }
    catch {
        $hadProcessError = $true
        $processError = if ($_.Exception.Message) { $_.Exception.Message } else { $_.Exception.GetType().FullName }
    }
 
    if (-not $hadProcessError -and -not $timedOut -and $null -eq $rawExitCode) {
        # Defensive: should not happen given the WaitForExit() call above, but never let
        # an unexplained missing exit code silently read as a plain, unremarked failure.
        $hadProcessError = $true
        $processError = 'Process exited but no exit code could be retrieved.'
    }
 
    $isSuccess = (-not $timedOut) -and (-not $hadProcessError) -and ($null -ne $rawExitCode) -and ($successExitCodeList -contains $rawExitCode)
    $finalExitCode = if ($isSuccess) { 0 } else { 1 }
 
    $classification =
        if ($hadProcessError) { "FAILED ($processError)" }
        elseif ($timedOut)    { "FAILED (timed out after $($TimeLimitMinutes + 15) minutes, process killed)" }
        elseif ($isSuccess)   { "SUCCESS (exit code $rawExitCode is in success list: $($successExitCodeList -join ', '))" }
        else                  { "FAILED (exit code $rawExitCode not in success list: $($successExitCodeList -join ', '))" }
 
    $duration = (Get-Date) - $startTime
 
    $logEntry = @"
==== $($startTime.ToString('yyyy-MM-dd HH:mm:ss')) | Database: $DatabaseName ====
Command: $commandLine
--- STDOUT ---
$stdOut
--- STDERR ---
$stdErr
Raw exit code: $rawExitCode
Classification: $classification
Wrapper exit code: $finalExitCode
Duration: $($duration.ToString())
==== END ====
 
"@
 
    Remove-OldLogEntries -LogFile $logFile -RetentionDays $LogRetentionDays
 
    Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
 
    Write-Host "[$DatabaseName] $classification - wrapper exit code $finalExitCode"
}
catch {
    # Anything unexpected (e.g. couldn't create LogDirectory) - still surface it,
    # and fail closed rather than silently reporting success.
    Write-Error "Invoke-RBSMaintainerRun failed for '$DatabaseName': $($_.Exception.Message)"
    $finalExitCode = 1
}
 
exit $finalExitCode
 