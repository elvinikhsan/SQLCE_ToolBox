<#
================================================================================
 Remove-LogShippingConfiguration.ps1

 Tears down the ACTUAL log shipping configuration (Agent jobs, msdb log-shipping
 metadata on both primary and secondary) once the migration has cut over and
 log shipping is no longer needed (item 11b). This is separate from
 Remove-LogShippingMigrationTracking.ps1, which only cleans up this project's
 own tracking tables.

 Wraps dbatools' Remove-DbaDbLogShipping, which discovers the paired
 primary/secondary from msdb log-shipping metadata and removes both sides in
 one call.

 EXAMPLES
 --------
 # Remove log shipping for every database in a wave, keep the secondary database:
 .\Remove-LogShippingConfiguration.ps1 -PrimarySqlInstance SQL-SRC01 -SecondarySqlInstance SQL-TGT01 -WaveFile .\Wave1_Databases.txt

 # Remove log shipping AND drop the secondary copy for one database (post-cutover, secondary is now primary):
 .\Remove-LogShippingConfiguration.ps1 -PrimarySqlInstance SQL-SRC01 -DatabaseName SP_Content_BLNG -RemoveSecondaryDatabase
================================================================================
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$PrimarySqlInstance,
    [string]$SecondarySqlInstance,

    [Parameter(ParameterSetName = 'Wave', Mandatory)][string]$WaveFile,
    [Parameter(ParameterSetName = 'Single', Mandatory)][string[]]$DatabaseName,

    [switch]$RemoveSecondaryDatabase
)

Import-Module (Join-Path $PSScriptRoot 'LogShippingMigration.psm1') -Force
Assert-DbatoolsModule

$databases = if ($PSCmdlet.ParameterSetName -eq 'Wave') { Get-WaveDatabaseList -WaveFile $WaveFile } else { $DatabaseName }
Write-MigrationLog "Removing log shipping configuration for $($databases.Count) database(s)."

foreach ($db in $databases) {
    try {
        if ($PSCmdlet.ShouldProcess($db, "Remove log shipping configuration")) {
            $params = @{
                PrimarySqlInstance = $PrimarySqlInstance
                Database           = $db
                Confirm             = $false
                EnableException     = $true
            }
            if ($SecondarySqlInstance) { $params.SecondarySqlInstance = $SecondarySqlInstance }
            if ($RemoveSecondaryDatabase) { $params.RemoveSecondaryDatabase = $true }

            Remove-DbaDbLogShipping @params
            Write-MigrationLog "  $db - log shipping configuration removed."
        }
    }
    catch {
        Write-MigrationLog "  $db - FAILED: $($_.Exception.Message)" -Level Error
        continue
    }
}

Write-MigrationLog "Done."
