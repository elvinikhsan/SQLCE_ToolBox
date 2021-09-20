
;with IndexColumns AS(
select distinct  schema_name (o.schema_id) as 'SchemaName',object_name(o.object_id) as TableName, i.Name as IndexName, o.object_id,i.index_id,i.type,
(select case key_ordinal when 0 then NULL else '['+col_name(k.object_id,column_id) +'] ' + CASE WHEN is_descending_key=1 THEN 'Desc' ELSE 'Asc' END end as [data()]
from sys.index_columns  (NOLOCK) as k
where k.object_id = i.object_id
and k.index_id = i.index_id
order by key_ordinal, column_id
for xml path('')) as cols,
case when i.index_id=1 then 
(select '['+name+']' as [data()]
from sys.columns  (NOLOCK) as c
where c.object_id = i.object_id
and c.column_id not in (select column_id from sys.index_columns  (NOLOCK) as kk    where kk.object_id = i.object_id and kk.index_id = i.index_id)
order by column_id
for xml path(''))
else (select '['+col_name(k.object_id,column_id) +']' as [data()]
from sys.index_columns  (NOLOCK) as k
where k.object_id = i.object_id
and k.index_id = i.index_id and is_included_column=1 and k.column_id not in (Select column_id from sys.index_columns kk where k.object_id=kk.object_id and kk.index_id=1)
order by key_ordinal, column_id
for xml path('')) end as inc
from sys.indexes  (NOLOCK) as i
inner join sys.objects o  (NOLOCK) on i.object_id =o.object_id 
inner join sys.index_columns ic  (NOLOCK) on ic.object_id =i.object_id and ic.index_id =i.index_id
inner join sys.columns c  (NOLOCK) on c.object_id = ic.object_id and c.column_id = ic.column_id
where  o.type = 'U' and i.index_id <>0 and i.type <>3 and i.type <>5 and i.type <>6 and i.type <>7 
group by o.schema_id,o.object_id,i.object_id,i.Name,i.index_id,i.type
),
DuplicatesTable AS
(SELECT    ic1.SchemaName,ic1.TableName,ic1.IndexName,ic1.object_id, ic2.IndexName as DuplicateIndexName, 
CASE WHEN ic1.index_id=1 THEN ic1.cols + ' (Clustered)' WHEN ic1.inc = '' THEN ic1.cols  WHEN ic1.inc is NULL THEN ic1.cols ELSE ic1.cols + ' INCLUDE ' + ic1.inc END as IndexCols, 
ic1.index_id
from IndexColumns ic1 join IndexColumns ic2 on ic1.object_id = ic2.object_id
and ic1.index_id < ic2.index_id and ic1.cols = ic2.cols
and (ISNULL(ic1.inc,'') = ISNULL(ic2.inc,'')  OR ic1.index_id=1 )
)
SELECT SchemaName,TableName, IndexName,DuplicateIndexName, IndexCols, index_id, object_id, 0 AS IsXML
FROM DuplicatesTable dt
ORDER BY 1,2,3
