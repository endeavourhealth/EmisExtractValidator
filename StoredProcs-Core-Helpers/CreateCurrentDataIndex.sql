use EMISXMaster

go

if (object_id('dbo.CreateCurrentDataIndex') is not null)
	drop procedure dbo.CreateCurrentDataIndex

go

create procedure dbo.CreateCurrentDataIndex
(
	@DBName varchar(100),
	@TableName varchar(100)
)
as
	
	set nocount on
	declare @msg varchar(8000)
	declare @sql nvarchar(4000)

	----------------------------------------------------------------------------------------
	-- drop existing index
	----------------------------------------------------------------------------------------
	declare @IndexName varchar(100) = 'IX_' + @TableName + '_ViewSupport'

	set @sql = 'if exists (select * from sys.indexes where name = ''<<INDEX>>'') drop index <<INDEX>> on <<TABLE>>'
	set @sql = replace(@sql, '<<TABLE>>', @TableName)
	set @sql = replace(@sql, '<<INDEX>>', @IndexName)
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
	-- create index
	----------------------------------------------------------------------------------------
	if ((@HasExtractId = 1) and (@HasPrimaryKeys = 1))
	begin
		declare @PrimaryKeys table
		(
			ColumnName varchar(100),
			ColumnOrder integer
		)

		insert into @PrimaryKeys 
		(
			ColumnName,
			ColumnOrder
		) 
		select ColumnName1, 1 from Definition.PrimaryKeys where TableName = @TableName and ColumnName1 is not null
		union select ColumnName2, 2 from Definition.PrimaryKeys where TableName = @TableName and ColumnName2 is not null
		union select @DeletedColumn, 3 where isnull(@DeletedColumn, '') != ''
		union select 'ExtractId', 4

		declare @IndexColumns varchar(1000) = null
		select @IndexColumns = isnull(@IndexColumns + ', ' + ColumnName, ColumnName) from @PrimaryKeys order by ColumnOrder

		set @sql = 'create nonclustered index <<INDEX>> on dbo.<<TABLE>> (<<COLUMNS>>)'

		set @sql = replace(@sql, '<<INDEX>>', @IndexName)
		set @sql = replace(@sql, '<<TABLE>>', @TableName)
		set @sql = replace(@sql, '<<COLUMNS>>', @IndexColumns)

		set @msg = '  Creating index ' + @IndexName
		exec PrintMsg @msg

		if (@sql is null)
		begin
			set @msg = 'Cannot create index' + @DBName + '.' + @IndexName
			exec ThrowError @msg
		end

		execute ExecuteOnDB @Sql = @sql, @DBName = @DBName
	end

go
