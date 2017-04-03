use EMISXMaster

go

if (object_id('DeleteAllDataFromDatabase') is not null)
	drop procedure DeleteAllDataFromDatabase

go

create procedure DeleteAllDataFromDatabase
(
	@DBName varchar(100)
)
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	begin try
		begin transaction
			
			set @msg = 'Deleting all data from ' + @DBName
			execute PrintMsg @msg

			if not exists (select * from sys.databases where name = @DBName)
			begin
				set @msg = 'Database ' + @DBName + ' not found'
				exec ThrowError @msg
				return
			end

			if (@DBName = 'EMISXMaster')
			begin
				set @msg = 'Cannot be run for EMISXMaster'
				exec ThrowError @msg
				return
			end

			declare @Tables table (TableName varchar(100))
			insert into @Tables (TableName) select TableName from Definition.Tables

			while exists (select * from @tables)
			begin
				declare @TableName nvarchar(4000) = (select top 1 TableName from @tables)
				delete from @Tables where TableName = @TableName

				declare @TableExists bit = 0
				set @sql = 'if exists (select * from ' + @DBName + '.sys.tables where name = ''' + @TableName + ''') set @TableExists = 1'
				execute sp_executesql @sql, N'@TableExists bit output', @TableExists = @TableExists output

				if (@TableExists = 1)
				begin
					set @msg = '  Deleting data from ' + @DBName + '.dbo.' + @TableName
					exec PrintMsg @msg

					set @sql = 'truncate table ' + @DBName + '.dbo.' + @TableName
					execute sp_executesql @sql
				end
			end

		commit transaction
		exec PrintMsg 'COMMITTED'
	end try
	begin catch
		exec PrintMsg 'ERROR detected, ROLLING BACK changes'
		rollback transaction;
		throw
	end catch

go
