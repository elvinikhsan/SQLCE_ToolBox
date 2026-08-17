# Log Shipping Migration Automation

Automates the log-shipping-based migration of SharePoint content databases: seeding
each target database (backup / copy / restore) and, once ready, configuring the
ongoing log shipping jobs. Built on PowerShell 7 + the `dbatools` module.

## Prerequisites

- winget install --id Microsoft.PowerShell --source winget
- Set-ExecutionPolicy -ExecutionPolicy RemoteSigned on all target machines
- Enable-PSRemoting -Force on all target machines
- `dbatools` PowerShell module installed on the machine running these scripts (`Install-Module dbatools -Scope CurrentUser`).
- Windows Integrated authentication with sysadmin rights on the source, target and tracking SQL instances.
- SQL Server Agent running on both source and target instances.
- Network shares already created and reachable in both directions (`-SourceBackupShare` writable from the source instance's service account, `-TargetBackupShare` writable from the target's, and each share readable from the *other* server for the copy/restore and log-shipping jobs).
- All other standard log-shipping prerequisites (matching SQL Server versions/editions where required, monitor server reachable, etc.) already in place — this tooling does not set those up.

## One-time setup

Run once on the target instance:

```
sqlcmd -S <TargetSqlInstance> -i Sql\01_Create_LogShippingMigrationDB.sql
```

This creates the `DBA_LogShippingMigration` database with the tracking tables used by every script below.

## Files

- `Sql\01_Create_LogShippingMigrationDB.sql` — tracking database/table DDL (run once).
- `Scripts\LogShippingMigration.psm1` — shared helper functions (imported automatically by the scripts below).
- `Scripts\Start-LogShippingMigration.ps1` — main orchestrator: backup / copy / restore (`-Phase Initialize`) and/or configure the ongoing log shipping jobs (`-Phase ConfigureLogShipping`, or `-Phase Both`).
- `Scripts\Remove-LogShippingMigrationTracking.ps1` — cleans up this tool's own tracking rows/tables.
- `Scripts\Remove-LogShippingConfiguration.ps1` — tears down the real log shipping configuration after cutover.
- `DatabaseFileMapping.csv` — DatabaseName / LogicalFileName / TargetPath for every content database (source of truth for `-MappingFile`).
- `Wave1_Databases.txt` — template for a wave's database list (`-WaveFile`); copy per wave.

## Typical wave workflow

1. Create/edit a wave file, e.g. `Wave1_Databases.txt`, with the databases going in that wave (one per line).
2. Run initialization — can be split across separate runs/days per phase, e.g. for very large databases:

   ```powershell
   # Today: backup + copy (long-running for large DBs)
   .\Start-LogShippingMigration.ps1 -Phase Initialize -EnableBackup -EnableCopy `
        -SourceSqlInstance vm-sql01-ag -TargetSqlInstance vm-sql02-ag -TrackingSqlInstance vm-sql02-ag `
        -SourceBackupShare '\\vm-sql01-ag\shared\backups' -TargetBackupShare '\\vm-sql02-ag\shared\backups' `
        -WaveFile ..\Wave1_Databases.txt -MappingFile ..\DatabaseFileMapping.csv

   # Later: restore only
   .\Start-LogShippingMigration.ps1 -Phase Initialize -EnableRestore `
        -SourceSqlInstance vm-sql01-ag -TargetSqlInstance vm-sql02-ag -TrackingSqlInstance vm-sql02-ag `
        -SourceBackupShare '\\vm-sql01-ag\shared\backups' -TargetBackupShare '\\vm-sql02-ag\shared\backups' `
        -WaveFile ..\Wave1_Databases.txt -MappingFile ..\DatabaseFileMapping.csv
   ```

   Databases are processed smallest-first automatically. Query `dbo.vw_LogShippingProgress` on the tracking instance at any time to see status and percent-complete per database.

3. Once every database in the wave shows `RestoreStatus = Complete`, configure the ongoing log shipping jobs:

   ```powershell
   .\Start-LogShippingMigration.ps1 -Phase ConfigureLogShipping `
       -SourceSqlInstance vm-sql01-ag -TargetSqlInstance vm-sql02-ag -TrackingSqlInstance vm-sql02-ag `
       -SourceBackupShare '\\vm-sql01-ag\shared\backups' -TargetBackupShare '\\vm-sql02-ag\shared\backups' `
       -WaveFile ..\Wave1_Databases.txt -MappingFile ..\DatabaseFileMapping.csv `
       -BackupIntervalMinutes 15 -CopyIntervalMinutes 15 -RestoreIntervalMinutes 15
   ```

4. This is an example of performing both phases (Initizalization and Configre Logshipping) in a single command.

   ```powershell
   .\Start-LogShippingMigration.ps1 -Phase Both `
       -SourceSqlInstance vm-sql01-ag -TargetSqlInstance vm-sql02-ag -TrackingSqlInstance vm-sql02-ag `
       -SourceBackupShare '\\vm-sql01-ag\shared\backups' -TargetBackupShare '\\vm-sql02-ag\shared\backups' `
       -WaveFile ..\Wave1_Databases.txt -MappingFile ..\DatabaseFileMapping.csv `
       -BackupIntervalMinutes 15 -CopyIntervalMinutes 15 -RestoreIntervalMinutes 15
   ```

5. Once satisfied, clean up the tracking rows for the wave: add `-CleanupTracking` to either run above, or run `Remove-LogShippingMigrationTracking.ps1` separately.

   ```powershell
   .\Remove-LogShippingMigrationTracking.ps1 -TrackingSqlInstance vm-sql02-ag -Wave Wave1_Databases
   ```

6. After the SharePoint migration has cut over and log shipping is no longer needed, tear it down:

   ```powershell
   .\Remove-LogShippingConfiguration.ps1 -PrimarySqlInstance vm-sql01-ag -SecondarySqlInstance vm-sql02-ag -WaveFile ..\Wave1_Databases.txt
   ```

## Single ad-hoc database

Skip the wave file/mapping CSV entirely for a one-off database:

```powershell
.\Start-LogShippingMigration.ps1 -Phase Initialize -EnableBackup -EnableCopy -EnableRestore `
    -SourceSqlInstance SQL-SRC01 -TargetSqlInstance SQL-TGT01 -TrackingSqlInstance SQL-TGT01 `
    -SourceBackupShare '\\SQL-SRC01\LSBackups' -TargetBackupShare '\\SQL-TGT01\LSBackups' `
    -DatabaseName SP_Content_Test `
    -FileMap @{ SP_Content_Test = 'L:\DATA-L\SP_Content_Test.mdf'; SP_Content_Test_log = 'H:\LOG-H\SP_Content_Test_log.ldf' }
```

## Notes / things to validate in your environment before a production wave

- The log-shipping backup/copy/restore SQL Agent jobs created by `-Phase ConfigureLogShipping` run under the Agent service account by default — confirm that account (or an Agent proxy, if your policy requires one) has write/read access to `-SourceBackupShare` / `-TargetBackupShare`.
- `Set-DbaDbRecoveryModel` is called automatically during the Backup phase if a database isn't already in FULL recovery. When that happens, the full backup taken right afterward is deliberately **not** copy-only (a COPY_ONLY backup can't establish a new log backup chain — only a regular full backup can), even though item 7 asked for copy-only full backups. For databases already in FULL recovery with an existing chain, the full backup stays copy-only as originally specified, so it won't disturb that chain.
- Copy-phase percent-complete is computed by polling destination file size vs. source file size (robocopy doesn't expose a live percentage), so it's an approximation, not an exact byte-for-byte progress feed.
- Test one database end-to-end (Initialize → ConfigureLogShipping → verify secondary is restoring → Remove-LogShippingConfiguration) before running a full wave.
- `-Phase ConfigureLogShipping`/`Both` now require both `-SourceBackupShare` (where the ongoing backup job writes) and `-TargetBackupShare` (passed to dbatools as `-CopyDestinationFolder`, where the secondary's copy job places files before restoring). Without it, `Invoke-DbaDbLogShipping` prompts interactively for a default location, which hangs an unattended run — the script also passes `-Force` as a second safety net against any other such prompts.
- `-MonitorServer` is optional, but log shipping always has *some* monitor — `Invoke-DbaDbLogShipping` doesn't support "none at all." Omit it and source/target each default to monitoring themselves (a normal, fully supported setup, just without a shared/dedicated monitor or threshold alert jobs); pass it to point both sides at one specific server instead.
- `Assert-DbatoolsModule` (called by every script) runs `Set-DbatoolsInsecureConnection -SessionOnly`, which relaxes dbatools' default encrypted/certificate-validated connections so it can reach instances using a self-signed or internal cert. This only applies to the running PowerShell session, not persisted machine-wide. If your instances use properly trusted certificates and you'd rather keep strict validation, remove that line from `Assert-DbatoolsModule` in `LogShippingMigration.psm1`.

Sources referenced while validating the dbatools cmdlets used here:
[Backup-DbaDatabase](https://dbatools.io/Backup-DbaDatabase/), [Restore-DbaDatabase](https://dbatools.io/Restore-DbaDatabase/), [Invoke-DbaDbLogShipping](https://dbatools.io/Invoke-DbaDbLogShipping/), [Remove-DbaDbLogShipping](https://dbatools.io/Remove-DbaDbLogShipping/), [Set-DbaDbRecoveryModel](https://dbatools.io/Set-DbaDbRecoveryModel/), [Set-DbatoolsInsecureConnection](https://dbatools.io/Set-DbatoolsInsecureConnection/).
