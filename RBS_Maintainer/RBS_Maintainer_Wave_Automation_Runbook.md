# RBS Maintainer Wave Automation — Pilot Validation & Rollback Runbook

**Pilot scope:** Wave0, `vm-sql01-dev`
**Solution:** `Detect-RBSEnabledDatabases.ps1` (Phase 1) → `Update-RBSMaintainerConfig.ps1` (Phase 2) → `Invoke-RBSMaintainerRun.ps1` (Phase 3, runs inside each SQL Agent step) → `New-RBSMaintainerAgentJobs.ps1` (Phase 4) → `New-RBSMaintainerWaveSetup.ps1` (Phase 5, orchestrates 1/2/4) → `Remove-RBSMaintainerWave.ps1` (Phase 6, rollback) → `Add-RBSMaintainerDatabase.ps1` (post-migration, onboards one new database - see below)

## Already validated on Wave0

- `-WhatIf` dry run previewed the expected connection string update and job/step creation with no changes made.
- Live run created the connection string entry and the `RBS_Maintainer_Wave0` job with one step per RBS-enabled database plus the `CheckResults` gate step.
- Manually running the job completed successfully end to end.
- Deliberate-failure test: forced one database step to fail while others succeeded - confirmed the `CheckResults` gate step correctly fails the job overall rather than reporting the last step's outcome.
- `Remove-RBSMaintainerWave.ps1` (job drop + config backup restore) tested successfully against Wave0.
- `Add-RBSMaintainerDatabase.ps1` (both `-CreateNewJob` and `-AppendJobStep`, including the step-insertion/renumbering behavior) tested successfully against `vm-sql01-dev`.

## Checklist before rolling out to additional waves

A few things are worth confirming on Wave0 before treating the pattern as proven for the rest of the migration — some can be checked now, others only after the job has run on its own schedule for a while.

**Check now:**

1. **Job history** — SSMS → SQL Server Agent → Jobs → `RBS_Maintainer_Wave0` → View History. Every per-database step and the `CheckResults` step should show Succeeded. If any database step failed but the job still reports overall success, the gate step isn't doing its job — worth deliberately failing one step (e.g. wrong connection string name) to confirm the gate actually catches it.
2. **Per-database logs** — `Logs\<DatabaseName>.log` should show the actual RBS Maintainer stdout (garbage collection / consistency check output), the raw exit code, and a classification that matches (`SUCCESS` for codes in `0,10,20,40`, `FAILED` otherwise).
3. **Config file** — confirm the `RBSMaintainer_<DatabaseName>` connection string entries are Windows Auth, unencrypted, and point at the right database and instance.

**Check after the job has run unattended at least once:**

4. **Schedule** — confirm a run actually fired at `02:00` (or whatever `-ScheduleTime` was set to) without manual intervention, and that it succeeded the same way the manual run did.
5. **Log retention** — once entries start aging past 30 days, confirm `Invoke-RBSMaintainerRun.ps1` is actually trimming them (this was verified with synthetic dates locally, but worth a real spot check once the log has genuine history).

**Ongoing:**

6. **`-SuccessExitCodes` list** — `0,10,20,40` was given as provisional by the client. As more real exit codes get logged across waves, revisit whether the list needs to change. It's a single parameter on Phase 3/4/5, so revising it doesn't require touching any script logic — just re-run Phase 5 (or Phase 4 directly with `-DropExisting`) with the updated `-SuccessExitCodes` value.

## Rolling out to the next wave

No new scripts needed — just point Phase 5 at the next wave's file:

```powershell
.\New-RBSMaintainerWaveSetup.ps1 -WaveFile .\Wave1_Databases.txt -WaveName "Wave1" `
    -SqlInstance "<target instance>" -ConfigPath "<...>.config" `
    -WrapperScriptPath "F:\Scripts\Invoke-RBSMaintainerRun.ps1" `
    -MaintainerExePath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
    -ScheduleTime "02:00" -WhatIf   # then again without -WhatIf once it looks right
```

## Rollback

### Automated (recommended)

`Remove-RBSMaintainerWave.ps1` drops the wave's job and, optionally, restores the config file to its most recent pre-change backup:

```powershell
# Preview only
.\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev" `
    -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
    -RestoreConfigBackup -WhatIf

# Drop the job only
.\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev"

# Drop the job and roll the config back to its latest pre-change backup
.\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev" `
    -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" -RestoreConfigBackup

# Roll back to a specific (not the latest) backup
.\Remove-RBSMaintainerWave.ps1 -WaveName "Wave0" -SqlInstance "vm-sql01-dev" `
    -ConfigPath "F:\Scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
    -RestoreConfigBackup -BackupTimestamp "20260908_020000"
```

The config's content right before the rollback is itself saved (as `<ConfigPath>.before_rollback_<timestamp>`) before any backup is restored, so a rollback is never a one-way trip either.

### Manual fallback

If running the script isn't an option:

```sql
EXEC msdb.dbo.sp_delete_job @job_name = N'RBS_Maintainer_Wave0';
```

For the config, find the newest file matching `Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config.bak_*` next to the live config (Phase 2 writes one before every change it makes) and copy it over the live file.

### After a rollback

Once whatever caused the rollback is fixed, just re-run Phase 5 for that wave. Phase 1 (detection) is read-only and Phase 2 (config update) adds/updates idempotently, so re-running the full chain is safe — Phase 4/5 will recreate the job from scratch.

## Post-migration: onboarding a new database

Once all waves are migrated, the SharePoint team will occasionally add a new content
database (new site collection) that's RBS-enabled from the start. `Add-RBSMaintainerDatabase.ps1`
handles that case directly - no wave file, no RBS detection (the database is taken as
already RBS-enabled), just the database name, target instance, and where to plug it in.

It adds/updates the database's connection string in the config either way, then does
exactly one of the following:

- **`-CreateNewJob`** - stand up a brand-new single-database SQL Agent job. Fails if a job
  with that name already exists.
- **`-AppendJobStep`** - add a step for this database into an *existing* RBS Maintainer
  job, inserted just before that job's `CheckResults` gate step (which then gets its
  internal step count updated so it keeps checking the right number of steps). Fails if
  the job doesn't exist, doesn't look like an RBS Maintainer job, or its last step isn't a
  recognizable gate step.

`-CreateNewJob` and `-AppendJobStep` are mutually exclusive - exactly one is required.

```powershell
# New site collection's content DB - stand up its own new job
.\Add-RBSMaintainerDatabase.ps1 -DatabaseName "WSS_Content_NewSite" -SqlInstance "vm-sql01-dev" `
    -ConfigPath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
    -WrapperScriptPath "F:\scripts\Invoke-RBSMaintainerRun.ps1" `
    -MaintainerExePath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
    -JobName "RBS_Maintainer_WSS_Content_NewSite" -CreateNewJob -ScheduleTime "02:00" -WhatIf

# Same database, added as a step into an existing wave job instead of its own job
.\Add-RBSMaintainerDatabase.ps1 -DatabaseName "WSS_Content_NewSite" -SqlInstance "vm-sql01-dev" `
    -ConfigPath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe.config" `
    -WrapperScriptPath "F:\scripts\Invoke-RBSMaintainerRun.ps1" `
    -MaintainerExePath "F:\scripts\Microsoft.Data.SqlRemoteBlobs.Maintainer.exe" `
    -JobName "RBS_Maintainer_Wave0" -AppendJobStep -WhatIf

# Drop -WhatIf on either once the preview looks right
```

`-ScheduleTime` is required with `-CreateNewJob` (a new job needs one) and ignored with
`-AppendJobStep` (the existing job already has one). `-ProxyName`, `-TimeLimitMinutes`,
`-SuccessExitCodes`, and `-ConnectionStringPrefix` all default to the same values used
everywhere else in this solution (`RBSMaintainer_Proxy`, `120`, `0,10,20,40`,
`RBSMaintainer_`) and only need to be passed if one of those has changed.

## File inventory

| File | Purpose |
|---|---|
| `Detect-RBSEnabledDatabases.ps1` | Phase 1 — checks every DB in a wave file for RBS, writes `<wave>_RBSStatus.csv` |
| `Update-RBSMaintainerConfig.ps1` | Phase 2 — adds/updates connection strings in the Maintainer config for RBS-enabled DBs |
| `Invoke-RBSMaintainerRun.ps1` | Phase 3 — runs the Maintainer exe for one DB, classifies its exit code, logs output, prunes old log entries |
| `New-RBSMaintainerAgentJobs.ps1` | Phase 4 — creates the one-job-per-wave SQL Agent job (step per DB + result-check gate step) |
| `New-RBSMaintainerWaveSetup.ps1` | Phase 5 — orchestrates Phases 1/2/4 for one wave, with `-WhatIf` support |
| `Remove-RBSMaintainerWave.ps1` | Phase 6 — rollback: drops a wave's job and optionally restores its config backup |
| `Add-RBSMaintainerDatabase.ps1` | Post-migration — onboards one new RBS-enabled database into a new job (`-CreateNewJob`) or an existing job (`-AppendJobStep`) |
