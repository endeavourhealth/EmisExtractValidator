use EMISXMaster

go

if (object_id('GetForeignKeyValidationResults') is not null)
	drop procedure GetForeignKeyValidationResults

go

create procedure GetForeignKeyValidationResults
	@DistinctCount bit = 0,
	@UsePracticeNameInHeader bit = 0,
	@CDB integer = null,
	@RunGroupId integer = null,
	@ComparisonRunGroupId integer = null
as

	if (@CDB is null and @RunGroupId is null)
	begin
		exec ThrowError 'Please specify @CDB or @RunGroupId'
		return 
	end

	declare @Results table
	(
		RunId varchar(100) not null,
		ComparisonRunId varchar(100) null,
		ExtractId varchar(100) not null,
		CDB varchar(100) not null,
		PracticeName varchar(100) not null,
		OrderBy integer not null
	)

	insert into @Results
	(
		RunId,
		ComparisonRunId,
		ExtractId,
		CDB,
		PracticeName,
		OrderBy
	)
	select 
		convert(varchar(100), vr.RunId),
		convert(varchar(100), vr2.RunId),
		convert(varchar(100), vr.ExtractId),
		convert(varchar(100), CDB),
		substring(p.PracticeName, 1, 10),
		row_number() over (order by p.StartExtractId, p.PracticeName)
	from Validation.Run vr
	left outer join Data.ConfiguredPractices p on vr.PracticeDBName = p.PracticeDBName
	left outer join Validation.Run vr2 on vr.PracticeDBName = vr2.PracticeDBName and vr2.RunGroupId = @ComparisonRunGroupId  
	where (p.CDB = @CDB or @CDB is null)
	and (vr.RunGroupId = @RunGroupId or @RunGroupId is null)

	declare @JoinTemplate varchar(1000) = 'left outer join GetForeignKeyValidationResult(<<X>>, <<Y>>) r<<X>> on r.FromTable = r<<X>>.FromTable and r.FromColumn = r<<X>>.FromColumn and r.ToTable = r<<X>>.ToTable and r.ToColumn = r<<X>>.ToColumn' + char(13) + char(10)
	declare @Joins varchar(8000) = ''
	declare @ColumnTemplate varchar(1000) = '	,r<<X>>.<<DISTINCT>>Count as [<<CDB>>-Ext<<EXTRACTID>>]' + char(13) + char(10)
	declare @Columns varchar(8000) = ''

	select @Joins = @Joins + replace(replace(@JoinTemplate, '<<X>>', RunId), '<<Y>>', case when ComparisonRunId is null then 'null' else ComparisonRunId end) from @Results order by OrderBy
	select @Columns = @Columns + replace(replace(replace(@ColumnTemplate, '<<X>>', RunId), '<<CDB>>', case when @UsePracticeNameInHeader = 1 then PracticeName else 'CDB' + CDB end), '<<EXTRACTID>>', ExtractId) from @Results order by OrderBy
	set @Columns = replace(@COLUMNS, '<<DISTINCT>>', case when @DistinctCount = 1 then 'Distinct' else '' end)

	declare @Sql varchar(max) =
	'select 
		r.TableType,
		r.FromTable,
		r.FromColumn,
		r.ToTable,
		r.ToColumn
	<<COLUMNS>>
	from GetForeignKeyValidationResult(0, null) r
	<<JOINS>> 
	order by 
		r.TableType,
		r.FromTable,
		r.FromColumn,
		r.ToTable,
		r.ToColumn'

	set @Sql = replace(@Sql, '<<COLUMNS>>', @Columns)
	set @Sql = replace(@Sql, '<<JOINS>>', @Joins)
	
	exec (@Sql)

go
