USE MSDB
SELECT  DISTINCT --jh.instance_id,
        j.name AS jobname,
        --jh.step_id,
        --jh.step_name AS JobStepName,
        CASE jh.run_status
          WHEN 0 THEN 'Failed'
          WHEN 1 THEN 'Success'
          WHEN 2 THEN 'Retry'
          WHEN 3 THEN 'Cancelled'
          WHEN 4 THEN 'InProgress'
        END AS runstatus,
        CAST(LEFT(CAST(run_date AS VARCHAR), 4) + '/'
        + SUBSTRING(CAST(run_date AS VARCHAR), 5, 2) + '/'
        + RIGHT(CAST(run_date AS VARCHAR), 2) + ' '
        + CAST(( ( run_time / 10000 ) % 100 ) AS VARCHAR) + ':'
        + CAST(( ( run_time / 100 ) % 100 ) AS VARCHAR) AS DATETIME) AS RunTime
FROM    msdb..sysjobs j
        JOIN msdb..sysjobhistory jh ON j.job_id = jh.job_id
WHERE   CAST(LEFT(CAST(run_date AS VARCHAR), 4) + '/'
        + SUBSTRING(CAST(run_date AS VARCHAR), 5, 2) + '/'
        + RIGHT(CAST(run_date AS VARCHAR), 2) + ' '
        + CAST(( ( run_time / 10000 ) % 100 ) AS VARCHAR) + ':'
        + CAST(( ( run_time / 100 ) % 100 ) AS VARCHAR) AS DATETIME) >= GETDATE() - 7;