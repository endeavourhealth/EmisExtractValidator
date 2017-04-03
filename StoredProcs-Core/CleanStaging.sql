use EMISXMaster

go

if (object_id('dbo.CleanStaging') is not null)
	drop procedure dbo.CleanStaging

go

create procedure dbo.CleanStaging
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg '-- Clean staging'
	set @msg = '-- Run date: ' + convert(varchar, getdate())
	exec PrintMsg @msg
	exec PrintMsg ''

	begin try
		begin transaction
		
			exec PrintMsg 'Delete from EMISXMaster.Data.StagedExtract'
			exec PrintMsg ''

			delete from Data.StagedExtract

			exec DeleteAllDataFromDatabase 'EMISXStaging'

		commit transaction
		exec PrintMsg 'COMMITTED'
	end try
	begin catch
		exec PrintMsg 'ERROR detected, ROLLING BACK changes'
		rollback;
		throw
	end catch

go
