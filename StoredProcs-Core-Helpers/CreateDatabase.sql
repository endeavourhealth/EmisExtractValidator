use EMISXMaster

go

if (object_id('CreateDatabase') is not null)
	drop procedure CreateDatabase

go

create procedure CreateDatabase
(
	@DestDbName varchar(100),
	@InstallCommonTables bit,
	@InstallPracticeTables bit,
	@IsStaging bit
)
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	begin try

		exec PrintMsg '-----------------------------------------------------------------------------'
		exec PrintMsg '-- Create database'
		set @msg = '-- Run date: ' + convert(varchar, getdate())
		exec PrintMsg @msg
		exec PrintMsg ''

		---------------------------------------------------------------------------
		-- creating database
		---------------------------------------------------------------------------

		set @msg = 'Creating ' + @DestDbName + ' database'
		execute PrintMsg @msg

		if exists (select * from sys.databases where name = @DestDbName)
		begin
			exec ThrowError 'Database already exists, cannot continue'
			return
		end

		execute PrintMsg '  Creating database'

		set @sql = 'create database ' + @DestDbName
		execute sp_executesql @sql

		---------------------------------------------------------------------------
		-- creating tables, views and indexes
		---------------------------------------------------------------------------
		declare @Tables table 
		(
			TableName varchar(100),
			CreateSql nvarchar(4000),
			TableType char(1)
		)

		insert into @Tables 
		(
			TableName, 
			CreateSql,
			TableType
		) 
		select 
			TableName,
			CreateSql,
			TableType 
		from Definition.Tables
		where (TableType = 'P' and @InstallPracticeTables = 1)
		or (TableType = 'C' and @InstallCommonTables = 1)

		while exists (select * from @Tables)
		begin
			declare @TableName nvarchar(4000) = (select top 1 TableName from @Tables)
			declare @TableSql nvarchar(4000) = (select CreateSql from @Tables where TableName = @TableName)
			declare @TableType char(1) = (select TableType from @Tables where TableName = @TableName)
			delete from @Tables where TableName = @TableName

			set @sql = replace(@TableSql, '<<DBNAME>>', @DestDbName)
			execute sp_executesql @sql

			set @msg = '  Creating table ' + @TableName
			execute PrintMsg @msg

			if (@IsStaging = 0)
			begin
				set @sql = 'alter table <<DB>>.dbo.<<TABLE>> add ExtractId integer not null'
				set @sql = replace(@sql, '<<DB>>', @DestDBName)
				set @sql = replace(@sql, '<<TABLE>>', @TableName)
				execute sp_executesql @sql
			end
		
			execute dbo.CreateCurrentDataIndex
				@DBName = @DestDbName,
				@TableName = @TableName
			
			execute dbo.CreateCurrentDataFunctionAndView 
				@DBName = @DestDbName, 
				@TableName = @TableName
		end

		exec PrintMsg 'Completed'
	end try
	begin catch
		exec ThrowError 'Error occurred creating database, please drop and recreate';
		throw
	end catch
go
