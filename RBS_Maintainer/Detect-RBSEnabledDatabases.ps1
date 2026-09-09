<#
.SYNOPSIS
    Phase 1 - Detects which SharePoint content databases in a migration wave are RBS-enabled
    (native FILESTREAM RBS provider) by checking RBS metadata inside each database.
 
.DESCRIPTION
    Reads a wave file containing one content database name per line, connects to the
    specified target SQL Server instance using Windows Authentication, and checks each
    database for the RBS FILESTREAM provider's metadata table:
        [mssqlrbs_resources].[rbs_internal_blob_stores]
    A database is considered RBS-enabled when that table exists AND
    (SELECT TOP 1 blob_store_type FROM [mssqlrbs_resources].[rbs_internal_blob_stores]) = 'Filestream'.
 
    Output is written to the console and exported to a CSV. That CSV is the input for
    Phase 2 (config file generation) and Phase 4 (SQL Agent job generation) - only rows
    with RBSEnabled = True should be carried forward.
 
.PARAMETER WaveFile
    Path to the text file containing one content database name per line
    (e.g. Wave0_Databases.txt). Blank lines and lines starting with '#' are ignored.
 
.PARAMETER SqlInstance
    Target SQL Server instance name (e.g. "SQL2022-NEW\INST01" or "SQL2022-NEW").
    All databases in the wave file are assumed to reside on this single instance.
 
.PARAMETER OutputCsv
    Optional path for the results CSV. Defaults to "<WaveFile base name>_RBSStatus.csv"
    in the same folder as WaveFile.
 
.PARAMETER ConnectTimeoutSeconds
    SQL connection timeout in seconds. Default 15.
 
.EXAMPLE
    .\Detect-RBSEnabledDatabases.ps1 -WaveFile .\Wave0_Databases.txt -SqlInstance "SQL2022-NEW"
 
.NOTES
    Run this interactively (or under whatever account has read access to the content DBs)
    by whoever is setting up the wave. This is NOT the SQL Agent proxy account
    (RBSMaintainer_Proxy) used later to actually run the RBS Maintainer exe - that account
    is only needed starting at Phase 4. Assumes Windows Authentication end to end.
#>
 
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$WaveFile,
 
    [Parameter(Mandatory = $true)]
    [string]$SqlInstance,
 
    [string]$OutputCsv,
 
    [int]$ConnectTimeoutSeconds = 15
)
 
Add-Type -AssemblyName System.Data
 
function Test-RBSEnabled {
    param(
        [string]$SqlInstance,
        [string]$DatabaseName,
        [int]$TimeoutSeconds
    )
 
    $result = [pscustomobject]@{
        DatabaseName  = $DatabaseName
        SqlInstance   = $SqlInstance
        RBSEnabled    = $false
        BlobStoreType = $null
        Status        = 'Unknown'
        ErrorMessage  = $null
    }
 
    # Windows Authentication, unencrypted - matches the environment's stated auth model.
    $connString = "Server=$SqlInstance;Database=$DatabaseName;Integrated Security=SSPI;Connect Timeout=$TimeoutSeconds;Encrypt=False;"
 
    # Dynamic SQL inside the IF EXISTS branch guarantees the reference to
    # [mssqlrbs_resources].[rbs_internal_blob_stores] is only resolved/executed
    # when the table actually exists, so this is safe to run against non-RBS databases.
    $query = @"
DECLARE @sql nvarchar(max);
IF EXISTS (
    SELECT 1 FROM sys.objects o
    JOIN sys.schemas s ON o.schema_id = s.schema_id
    WHERE s.name = N'mssqlrbs_resources'
      AND o.name = N'rbs_internal_blob_stores'
      AND o.type = 'U'
)
BEGIN
    SET @sql = N'SELECT TOP (1) blob_store_type FROM [mssqlrbs_resources].[rbs_internal_blob_stores];';
    EXEC sp_executesql @sql;
END
ELSE
BEGIN
    SELECT CAST(NULL AS sysname) AS blob_store_type WHERE 1 = 0;
END
"@
 
    $conn = New-Object System.Data.SqlClient.SqlConnection $connString
    try {
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $cmd.CommandTimeout = $TimeoutSeconds
 
        $reader = $cmd.ExecuteReader()
        if ($reader.Read()) {
            $rawValue = $reader['blob_store_type']
            $blobStoreType = if ($rawValue -is [DBNull]) { $null } else { [string]$rawValue }
            $result.BlobStoreType = $blobStoreType
            $result.RBSEnabled = ($null -ne $blobStoreType) -and ($blobStoreType.Trim() -ieq 'Filestream')
        }
        $reader.Close()
        $result.Status = 'OK'
    }
    catch [System.Data.SqlClient.SqlException] {
        $sqlEx = $_.Exception
        if ($sqlEx.Number -eq 4060 -or $sqlEx.Number -eq 916) {
            # 4060: cannot open database (doesn't exist / no access)
            # 916: server principal not able to access database under current security context
            $result.Status = 'DatabaseNotFoundOrNoAccess'
        }
        else {
            $result.Status = 'SqlError'
        }
        $result.ErrorMessage = $sqlEx.Message
    }
    catch {
        $result.Status = 'ConnectionError'
        $result.ErrorMessage = $_.Exception.Message
    }
    finally {
        if ($conn.State -eq 'Open') { $conn.Close() }
        $conn.Dispose()
    }
 
    return $result
}
 
# ---- Main ----
 
if (-not $OutputCsv) {
    $waveBase  = [System.IO.Path]::GetFileNameWithoutExtension($WaveFile)
    $waveDir   = Split-Path -Path (Resolve-Path $WaveFile) -Parent
    $OutputCsv = Join-Path $waveDir "$($waveBase)_RBSStatus.csv"
}
 
$databaseNames = Get-Content -Path $WaveFile |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
 
if (-not $databaseNames) {
    Write-Warning "No database names found in '$WaveFile'."
    return
}
 
Write-Host "Checking $($databaseNames.Count) database(s) against instance '$SqlInstance'..." -ForegroundColor Cyan
 
$results = foreach ($dbName in $databaseNames) {
    Write-Host "  Checking $dbName ..." -NoNewline
    $r = Test-RBSEnabled -SqlInstance $SqlInstance -DatabaseName $dbName -TimeoutSeconds $ConnectTimeoutSeconds
    $statusText = if ($r.Status -eq 'OK') { if ($r.RBSEnabled) { 'RBS-ENABLED' } else { 'not RBS' } } else { $r.Status }
    $color = if ($r.Status -ne 'OK') { 'Red' } elseif ($r.RBSEnabled) { 'Green' } else { 'DarkGray' }
    Write-Host " $statusText" -ForegroundColor $color
    $r
}
 
$results | Sort-Object DatabaseName | Format-Table DatabaseName, RBSEnabled, BlobStoreType, Status -AutoSize
 
$results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
 
$rbsCount   = @($results | Where-Object { $_.RBSEnabled }).Count
$errorCount = @($results | Where-Object { $_.Status -ne 'OK' }).Count
 
Write-Host ""
Write-Host "Summary: $($databaseNames.Count) checked, $rbsCount RBS-enabled, $errorCount error(s)." -ForegroundColor Cyan
Write-Host "Results written to: $OutputCsv" -ForegroundColor Cyan
 
if ($errorCount -gt 0) {
    Write-Warning "One or more databases could not be checked - review the CSV before proceeding to Phase 2/4."
}