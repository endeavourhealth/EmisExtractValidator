use EMISXMaster

go

if (object_id('dbo.CreateStagingDatabase') is not null)
	drop procedure dbo.CreateStagingDatabase

go

create procedure dbo.CreateStagingDatabase
(
	@DropExistingDatabase bit = 0
)
as
	
	declare @DBName varchar(100) = 'EMISXStaging'

	execute dbo.CreateDatabase 
		@DestDbName = @DBName, 
		@InstallCommonTables = 1, 
		@InstallPracticeTables = 1, 
		@IsStaging = 1

go
