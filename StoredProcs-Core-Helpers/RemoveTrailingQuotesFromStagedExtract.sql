use EMISXMaster

go

if (object_id('RemoveTrailingQuotesFromStagedExtract') is not null)
	drop procedure RemoveTrailingQuotesFromStagedExtract

go

create procedure RemoveTrailingQuotesFromStagedExtract
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	declare @LastColumnNames table
	(
		TableName varchar(100) not null primary key,
		LastColumnName varchar(100) not null
	)

	;with MaxColumnId as
	(
		select 
			t.object_id, 
			max(c.column_id) as MaxColumnId 
		from Definition.Tables t1
		inner join EMISXStaging.sys.tables t on t1.TableName = t.name
		inner join EMISXStaging.sys.columns c on t.object_id = c.object_id
		group by t.object_id
	)
	insert into @LastColumnNames 
	(
		TableName, 
		LastColumnName
	)
	select 
		t.name as TableName,
		c.name as LastColumnName
	from EMISXStaging.sys.tables t
	inner join MaxColumnId mc on t.object_id = mc.object_id
	inner join EMISXStaging.sys.columns c on mc.object_id = c.object_id and mc.MaxColumnId = c.column_id

	while exists (select * from @LastColumnNames)
	begin
		declare @TableName varchar(100) = (select top 1 TableName from @LastColumnNames)
		declare @LastColumnName varchar(100) = (select LastColumnName from @LastColumnNames where TableName = @TableName)
		delete from @LastColumnNames where TableName = @TableName

		declare @TotalRowCount integer = 0
		
		set @sql = N'select @TotalRowCount = count(*) from EMISXStaging.dbo.<<TABLE>>'
		set @sql = replace(@sql, '<<TABLE>>', @TableName)
		
		execute sp_executesql @sql, N'@TotalRowCount integer output', @TotalRowCount = @TotalRowCount output

		if (@TotalRowCount > 0)
		begin
			declare @QuotedRowCount integer = 0

			set @sql = N'select @QuotedRowCount = isnull(count(*), 0)
						 from EMISXStaging.dbo.<<TABLE>>
						 where replace(replace(<<COLUMN>>, char(10), ''''), char(13), '''') like ''%"'''
						 			
			set @sql = replace(@sql, '<<TABLE>>', @TableName)
			set @sql = replace(@sql, '<<COLUMN>>', @LastColumnName)

			execute sp_executesql @sql, N'@QuotedRowCount integer output', @QuotedRowCount = @QuotedRowCount output

			set @msg = 'Removing trailing quotes from ' + @TableName + ', column ' + @LastColumnName + ' (' + convert(varchar, @QuotedRowCount) + ' row(s) found)'
			exec PrintMsg @msg

			if (isnull(@QuotedRowCount, 0)) = 0
			begin
				set @msg = 'No rows in ' + @TableName + ' contain trailing quotes'
				exec ThrowError @msg
				return
			end
			else if (isnull(@QuotedRowCount, 0) > 1)
			begin
				set @msg = 'More than one row in ' + @TableName + ' contain trailing quotes - not expected'
				exec ThrowError @msg
				return
			end

			set @sql = N';with LastRow as
			(
				select <<COLUMN>>
				from EMISXStaging.dbo.<<TABLE>>
				where replace(replace(<<COLUMN>>, char(10), ''''), char(13), '''') like ''%"''
			)
			update LastRow
			set <<COLUMN>> = replace(replace(replace(<<COLUMN>>, ''"'', ''''), char(10), ''''), char(13), '''')'

			set @sql = replace(@sql, '<<TABLE>>', @TableName)
			set @sql = replace(@sql, '<<COLUMN>>', @LastColumnName)

			exec sp_executesql @sql

			set @QuotedRowCount = 0
			set @sql = N'select @QuotedRowCount = isnull(count(*), 0)
						 from EMISXStaging.dbo.<<TABLE>>
						 where replace(replace(<<COLUMN>>, char(10), ''''), char(13), '''') like ''%"'''
			
			set @sql = replace(@sql, '<<TABLE>>', @TableName)
			set @sql = replace(@sql, '<<COLUMN>>', @LastColumnName)
			
			execute sp_executesql @sql, N'@QuotedRowCount integer output', @QuotedRowCount = @QuotedRowCount output

			if (isnull(@QuotedRowCount, 0)) > 0
			begin
				set @msg = 'Row in ' + @TableName + ' still contains trailing quotes after update'
				exec ThrowError @msg
				return
			end
		end
	end

go
