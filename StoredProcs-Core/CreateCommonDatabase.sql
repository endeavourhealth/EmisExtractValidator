use EMISXMaster

go

if (object_id('dbo.CreateCommonDatabase') is not null)
	drop procedure dbo.CreateCommonDatabase

go

create procedure dbo.CreateCommonDatabase
(
	@DropExistingDatabase bit = 0
)
as
	
	declare @DBName varchar(100) = 'EMISXCommon'

	execute dbo.CreateDatabase 
		@DestDbName = @DBName, 
		@InstallCommonTables = 1, 
		@InstallPracticeTables = 0, 
		@IsStaging = 0

go
