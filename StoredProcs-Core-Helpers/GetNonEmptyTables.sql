use EMISXMaster

go

if (object_id('dbo.GetNonEmptyTables') is not null)
	drop procedure dbo.GetNonEmptyTables

go

create procedure dbo.GetNonEmptyTables
(
	@DBName varchar(100)
)
as
	set nocount on
	declare @sql nvarchar(4000)

	declare @Result StringList
	declare @Tables StringList

	insert into @Tables 
	select TableName from Definition.Tables order by TableName

	while exists (select * from @Tables)
	begin
		declare @TableName varchar(100) = (select top 1 String from @Tables)
		delete from @Tables where String = @TableName

		declare @count integer = 0

		set @sql = 'if exists (select * from ' + @DBName + '.sys.tables where name = ''' + @TableName + ''') ' +
				   'begin select @count = count(*) from ' + @DBName + '.dbo.' + @TableName + ' ' +
				   'end else begin set @count = 0 end'
		
		execute sp_executesql @sql, N'@count integer output', @count = @count output

		if (@count > 0)
		begin
			insert into @Result (String) values
			(convert(varchar(10), @count) + ' row(s) in ' + @DBName + '.dbo.' + @TableName)
		end
	end

	select String as TableNameAndCount
	from @Result

go
