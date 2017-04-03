use EMISXMaster

go

if (object_id('dbo.CreateCurrentDataFunctionAndView') is not null)
	drop procedure dbo.CreateCurrentDataFunctionAndView

go

create procedure dbo.CreateCurrentDataFunctionAndView
(
	@DBName varchar(100),
	@TableName varchar(100)
)
as
	
	set nocount on
	declare @msg varchar(8000)
	declare @sql nvarchar(4000)

	----------------------------------------------------------------------------------------
	-- drop existing function
	----------------------------------------------------------------------------------------
	declare @FunctionName varchar(100) = 'fn_' + @TableName

	set @sql = 'if (object_id(''' + @FunctionName + ''') is not null) drop function ' + @FunctionName
	execute ExecuteOnDB @Sql = @sql, @DBName = @DBName

	----------------------------------------------------------------------------------------
	-- determine whether table has ExtractId column
	----------------------------------------------------------------------------------------
	declare @HasExtractId bit = 0

	set @sql = N'if exists 
	(
		select *
		from <<DB>>.sys.tables t
		inner join <<DB>>.sys.columns c on t.object_id = c.object_id
		where t.name = ''<<TABLE>>''
		and c.name = ''ExtractId''	
	)
	begin
		set @HasExtractId = 1
	end'

	set @sql = replace(@sql, '<<DB>>', @DBname)
	set @sql = replace(@sql, '<<TABLE>>', @TableName)

	execute sp_executesql @sql, N'@HasExtractId bit output', @HasExtractId = @HasExtractId output

	----------------------------------------------------------------------------------------
	-- get deleted column name
	----------------------------------------------------------------------------------------
	declare @DeletedColumn varchar(100) = (select DeletedColumnName from Definition.Tables where TableName = @TableName)

	----------------------------------------------------------------------------------------
	-- determine if table has primary keys
	----------------------------------------------------------------------------------------
	declare @HasPrimaryKeys bit = 0

	if exists
	(
		select *
		from Definition.PrimaryKeys
		where TableName = @TableName
		and (isnull(ColumnName1, '') != '' or (isnull(ColumnName2, '') != ''))
	)
	begin
		set @HasPrimaryKeys = 1
	end

	----------------------------------------------------------------------------------------
	-- build function sql
	----------------------------------------------------------------------------------------
	if ((@HasExtractId = 0) or (@HasPrimaryKeys = 0))
	begin
		set @sql = 
'create function <<FUNCTION>>
(
	@ExtractId integer
)
returns table
as
	return select
	*
	from dbo.<<TABLE>> t'

		set @sql = replace(@sql, '<<FUNCTION>>', @FunctionName)
		set @sql = replace(@sql, '<<TABLE>>', @TableName)

		if (@HasExtractId = 1)
		begin
			set @sql = @sql + 
'
	where ((t.ExtractId <= @ExtractId) or @ExtractId is null)'
		end

		if (@DeletedColumn != '')
		begin
			set @sql = @sql + 
'
	<<WHERE_KEYWORD>> t.<<DELETED>> = ''false'''

			set @sql = replace(@sql, '<<DELETED>>', @DeletedColumn)
			set @sql = replace(@sql, '<<WHERE_KEYWORD>>', case when @HasExtractId = 1 then 'and' else 'where' end)
		end
	end
	else
	begin
		declare @PrimaryKeys StringList

		insert into @PrimaryKeys 
		(
			String
		) 
		select ColumnName1 from Definition.PrimaryKeys where TableName = @TableName and ColumnName1 is not null
		union select ColumnName2 from Definition.PrimaryKeys where TableName = @TableName and ColumnName2 is not null

		declare @PK_SelectList varchar(1000) = null
		select @PK_SelectList = isnull(@PK_SelectList + ', ' + String, String) from @PrimaryKeys
		declare @PK_JoinList varchar(1000) = null
		select @PK_JoinList = isnull(@PK_JoinList + ' and e.' + String + ' = t.' + String, 'e.' + String + ' = t.' + String) from @PrimaryKeys
	
		set @sql = 
'create function <<FUNCTION>>
(
	@ExtractId integer
)
returns table 
as
	return with LatestExtract as
	(
		select
			<<PK_SELECT>>, max(ExtractId) as MaxExtractId
		from dbo.<<TABLE>>
		where ExtractId <= @ExtractId
		or @ExtractId is null
		group by <<PK_SELECT>>
	)
	select
		t.*
	from LatestExtract e
	inner join dbo.<<TABLE>> t on <<PK_JOIN>>
	where e.MaxExtractId = t.ExtractId'

		set @sql = replace(@sql, '<<FUNCTION>>', @FunctionName)
		set @sql = replace(@sql, '<<TABLE>>', @TableName)
		set @sql = replace(@sql, '<<PK_SELECT>>', @PK_SelectList)
		set @sql = replace(@sql, '<<PK_JOIN>>', @PK_JoinList)

		if (@DeletedColumn != '')
		begin
			set @sql = @sql + 
'
	and t.<<DELETED>> = ''false'''

			set @sql = replace(@sql, '<<DELETED>>', @DeletedColumn)
		end
	end

	----------------------------------------------------------------------------------------
	-- create function
	----------------------------------------------------------------------------------------
	set @msg = '  Creating function ' + @FunctionName
	exec PrintMsg @msg

	if (@sql is null)
	begin
		set @msg = 'Cannot create function ' + @DBName + '.' + @FunctionName
		exec ThrowError @msg
	end

	execute ExecuteOnDB @Sql = @sql, @DBName = @DBName

	----------------------------------------------------------------------------------------
	-- drop existing view
	----------------------------------------------------------------------------------------
	declare @ViewName varchar(100) = 'vw_' + @TableName

	set @sql = 'if (object_id(''' + @ViewName + ''') is not null) drop view ' + @ViewName
	execute ExecuteOnDB @Sql = @sql, @DBName = @DBName

	----------------------------------------------------------------------------------------
	-- build view sql
	----------------------------------------------------------------------------------------
	set @sql = 
'create view <<VIEW>>
as
	select
	*
	from dbo.<<FUNCTION>>(null)'

	set @sql = replace(@sql, '<<VIEW>>', @ViewName)
	set @sql = replace(@sql, '<<FUNCTION>>', @FunctionName)

	----------------------------------------------------------------------------------------
	-- create view
	----------------------------------------------------------------------------------------
	set @msg = '  Creating view ' + @ViewName
	exec PrintMsg @msg

	if (@sql is null)
	begin
		set @msg = 'Cannot create view ' + @DBName + '.' + @ViewName
		exec ThrowError @msg
	end

	execute ExecuteOnDB @Sql = @sql, @DBName = @DBName

go
