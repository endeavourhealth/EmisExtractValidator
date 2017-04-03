use EMISXMaster

go

if (object_id('ValidateForeignKeys') is not null)
	drop procedure ValidateForeignKeys

go

create procedure ValidateForeignKeys
(
	@PracticeDBName varchar(100),
	@ExtractId integer = null,
	@RunGroupId integer = null
)
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	declare @ValidationDate datetime2 = getdate()
	declare @PracticeName varchar(1000)
	declare @OdsCode varchar(1000)
	declare @ExtractDate datetime2
	declare @VrId integer
	declare @CommonDBName varchar(100) = 'EMISXCommon'

	if (@ExtractId is null)
	begin
		select @ExtractId = max(ExtractId) from Data.InstalledExtracts
	end

	if not exists (select * from Data.InstalledExtracts where ExtractId = @ExtractId)
	begin
		set @msg = 'Could not find ExtractId ' + convert(varchar(100), @ExtractId)
		exec ThrowError @msg
		return
	end

	if not exists (select * from Data.ConfiguredPractices where PracticeDBName = @PracticeDBName)
	begin
		set @msg = 'Could not find PracticeDBName ' + @PracticeDBName
		exec ThrowError @msg
		return
	end

	if not exists (select * from Data.ConfiguredPractices where PracticeDBName = @PracticeDBName and StartExtractId <= @ExtractId)
	begin
		declare @StartExtractId integer = (select StartExtractId from Data.ConfiguredPractices where PracticeDBName = @PracticeDBName)

		set @msg = 'PracticeDBName doesn''t start until ExtractId ' + convert(varchar(100), @StartExtractId)
		exec ThrowError @msg
		return
	end

	select 
		@PracticeName = PracticeName,
		@OdsCode = ODSCode
	from Data.ConfiguredPractices
	where PracticeDBName = @PracticeDBName

	select
		@ExtractDate = ExtractDate
	from Data.InstalledExtracts
	where ExtractId = @ExtractId

	insert into Validation.Run
	(
		PracticeDBName,  
		ExtractId,
		RunDate,
		RunGroupId
	)
	values
	(
		@PracticeDBName,
		@ExtractId,
		@ValidationDate,
		@RunGroupId
	)

	set @VrId = scope_identity()

	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg '-- Validate foreign keys'
	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg ''

	exec PrintVrMsg @VrId, 'Data Integrity Report'
	set @msg = 'Practice: ' + @OdsCode + '/ ' + @PracticeName
	exec PrintVrMsg @VrId, @msg
	set @msg = 'Extract Id: ' + convert(varchar(100), @ExtractId)
	exec PrintVrMsg @VrId, @msg
	set @msg = 'Extract date: ' + convert(varchar(100), @ExtractDate, 120)
	exec PrintVrMsg @VrId, @msg
	set @msg = 'Validation date: ' + convert(varchar(100), @ValidationDate, 120)
	exec PrintVrMsg @VrId, @msg
	exec PrintVrMsg @VrId, ''

	declare @FromTables table
	(
		FromTable varchar(100),
		FromDB varchar(100)
	)

	insert into @FromTables 
	(
		FromTable, 
		FromDB
	)
	select distinct
		FromTable, 
		case
			when TableType = 'P' then @PracticeDBName
			when TableType = 'C' then @CommonDBName
			else 'UNKNOWN'
		end as FromDB
	from Definition.ForeignKeys 
	inner join Definition.Tables td on td.TableName = FromTable

	while exists (select * from @FromTables)
	begin
		  declare @FromTable varchar(100) = (select top 1 FromTable from @FromTables)
		  declare @FromDB varchar(100) = (select FromDB from @FromTables where FromTable = @FromTable)
		  delete from @FromTables where FromTable = @FromTable

		  declare @FromColumns table
		  (
				FromColumn varchar(100)
		  )
 
		  insert into @FromColumns (FromColumn)
		  select 
			FromColumn 
		  from Definition.ForeignKeys 
		  where FromTable = @FromTable

		  declare @PrintedTableHeader bit = 0
 
		  while exists (select * from @FromColumns)
		  begin
				declare @FromColumn varchar(100) = (select top 1 FromColumn from @FromColumns)
				delete from @FromColumns where FromColumn = @FromColumn

				declare @ForeignKeyId integer
				declare @ToTable varchar(100)
				declare @ToDB varchar(100)
				declare @ToColumn varchar(100)

				select
					@ForeignKeyId = ForeignKeyId,
					@ToTable = ToTable,
					@ToColumn = ToColumn,
					@ToDB = case
								when TableType = 'P' then @PracticeDBName
								when TableType = 'C' then @CommonDBName
								else 'UNKNOWN'
							end
				from Definition.ForeignKeys 
				inner join Definition.Tables on ToTable = TableName
				where FromTable = @FromTable
				and FromColumn = @FromColumn
 
				set @sql  =
					  'select f.<<FROM_COLUMN>> 
					  from <<FROM_DB>>.dbo.fn_<<FROM_TABLE>>(<<EXTRACT_ID>>) f 
					  left outer join <<TO_DB>>.dbo.fn_<<TO_TABLE>>(<<EXTRACT_ID>>) t on f.<<FROM_COLUMN>> = t.<<TO_COLUMN>> 
					  where isnull(f.<<FROM_COLUMN>>, '''') != ''''
					  and t.<<TO_COLUMN>> is null'
  
				set @sql = replace(@sql, '<<FROM_DB>>', @FromDB)
				set @sql = replace(@sql, '<<FROM_TABLE>>', @FromTable)
				set @sql = replace(@sql, '<<FROM_COLUMN>>', @FromColumn)
				set @sql = replace(@sql, '<<TO_DB>>', @ToDB)
				set @sql = replace(@sql, '<<TO_TABLE>>', @ToTable)
				set @sql = replace(@sql, '<<TO_COLUMN>>', @ToColumn)
				set @sql = replace(@sql, '<<EXTRACT_ID>>', @ExtractId)

				declare @errors StringList
				insert into @errors (String)
				execute sp_executesql @sql
 
				declare @error_count integer = (select count(*) from @errors)
				declare @distinct_error_count integer = (select count(distinct String) from @errors)

				if (@error_count > 0)
				begin
					if (@PrintedTableHeader = 0)
					begin
						exec PrintVrMsg @VrId,'----------------------------------------------------'
						set @msg = '>>Table ' + @FromTable
						exec PrintVrMsg @VrId, @msg
						exec PrintVrMsg @VrId, '----------------------------------------------------'
						exec PrintVrMsg @VrId, ''
						set @PrintedTableHeader = 1
					end

					set @msg = '  >Column ' + @FromColumn
					exec PrintVrMsg @VrId, @msg
					exec PrintVrMsg @VrId, ''

					insert into Validation.ForeignKeyErrors
					(
						RunId, 
						ForeignKeyId, 
						Count, 
						DistinctCount
					)
					values
					(
						@VrId,
						@ForeignKeyId,
						@error_Count,
						@distinct_error_count
					)

					declare @error_text varchar(1000) = '     [ERROR]  ' 
														+ convert(varchar(100), @error_count) + ' (' + convert(varchar(100), @distinct_error_count) + ' distinct) ' +
														+ @FromColumn + ' value(s) not present in ' + @ToTable + ' (column ' + @ToColumn + ')' 
					exec PrintVrMsg @VrId, @error_text
 
					declare @top10errors StringList
					insert into @top10errors (String) select distinct top 10 String from @errors
					
					exec PrintVrMsg @VrId, ''

					if (@distinct_error_count > 10)
						exec PrintVrMsg @VrId, '     First ten distinct value(s) are:'
					else
						exec PrintVrMsg @VrId, '     Distinct value(s) are:'

					exec PrintVrList @VrId, @top10errors, '         '
					
					exec PrintVrMsg @VrId, ''

					delete from @errors
					delete from @top10errors
				end	
		  end
	end

go
