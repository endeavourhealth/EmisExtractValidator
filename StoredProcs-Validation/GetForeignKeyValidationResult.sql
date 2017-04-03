use EMISXMaster

go

if (object_id('GetForeignKeyValidationResult') is not null)
	drop function GetForeignKeyValidationResult

go

create function GetForeignKeyValidationResult
(
	@RunId integer,
	@ComparisonRunId integer = null
)
returns @Result table
(
	TableType char(1) not null,
	FromTable varchar(100) not null,
	FromColumn varchar(100) not null,
	ToTable varchar(100) not null,
	ToColumn varchar(100) not null,
	Count varchar(100) not null,
	DistinctCount varchar(100) not null
)
as
begin

	insert into @Result
	(
		TableType,
		FromTable,
		FromColumn,
		ToTable,
		ToColumn,
		Count,
		DistinctCount
	)
	select 
		d.TableType,
		d.FromTable,
		d.FromColumn,
		d.ToTable,
		d.ToColumn,
		convert(varchar(100), isnull(e.Count, 0)) +
			case 
				when @ComparisonRunId is null then ''
				else case 
						when (isnull(e.Count, 0) - isnull(e2.Count, 0)) = 0 then ''
						when (isnull(e.Count, 0) - isnull(e2.Count, 0)) > 0 then '  (+' + convert(varchar(100), (isnull(e.Count, 0) - isnull(e2.Count, 0))) + ')'
						else '  (' + convert(varchar(100), (isnull(e.Count, 0) - isnull(e2.Count, 0))) + ')'
					 end
			end,
		convert(varchar(100), isnull(e.DistinctCount, 0)) +
			case 
				when @ComparisonRunId is null then ''
				else case 
						when (isnull(e.DistinctCount, 0) - isnull(e2.DistinctCount, 0)) = 0 then ''
						when (isnull(e.DistinctCount, 0) - isnull(e2.DistinctCount, 0)) > 0 then '  (+' + convert(varchar(100), (isnull(e.DistinctCount, 0) - isnull(e2.DistinctCount, 0))) + ')'
						else '  (' + convert(varchar(100), (isnull(e.DistinctCount, 0) - isnull(e2.DistinctCount, 0))) + ')'
					 end
			end
	from
	(
		select distinct
			t.TableType,
			fke.ForeignKeyId, 
			fk.FromTable, 
			fk.FromColumn, 
			fk.ToTable, 
			fk.ToColumn
		from Validation.ForeignKeyErrors fke
		inner join Definition.ForeignKeys fk on fke.ForeignKeyId = fk.ForeignKeyId
		inner join Definition.Tables t on fk.FromTable = t.TableName
	) d
	left outer join Validation.ForeignKeyErrors e on d.ForeignKeyId = e.ForeignKeyId and e.RunId = @RunId
	left outer join Validation.ForeignKeyErrors e2 on d.ForeignKeyId = e2.ForeignKeyId and e2.RunId = @ComparisonRunId
	order by d.TableType, d.FromTable, d.FromColumn, d.ToTable, d.ToColumn

	return
end

go
