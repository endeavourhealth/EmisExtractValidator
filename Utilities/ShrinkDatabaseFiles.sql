select 
      'use [' + d.name + N']' + char(13) + char(10) 
    + 'dbcc shrinkfile (N''' + mf.name + N''' , 0, truncateonly)' 
    + char(13) + char(10) + char(13) + char(10) 
from sys.master_files mf 
inner join sys.databases d on mf.database_id = d.database_id 
where d.name in
(
	select 'EMISXMaster' as DBName
	union
	select 'EMISXStaging' as DBName
	union
	select 'EMISXCommon' as DBName
	union
	select 
		PracticeDBName as DBName
	from EMISXMaster.Data.ConfiguredPractices d
)
