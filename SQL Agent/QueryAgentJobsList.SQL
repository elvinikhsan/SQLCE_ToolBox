SELECT DISTINCT a.name,b.name as category, a.description,a.enabled, CASE WHEN c.job_id IS NOT NULL THEN 1 ELSE 0 END as IsScheduled
--INTO master.dbo.sqlbpmjobs
from sysjobs a
INNER JOIN syscategories b ON a.category_id=b.category_id 
LEFT JOIN sysjobschedules c ON a.job_id=c.job_id
ORDER BY a.name

