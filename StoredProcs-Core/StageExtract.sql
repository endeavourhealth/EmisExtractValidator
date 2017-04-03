use EMISXMaster

go

if (object_id('StageExtract') is not null)
	drop procedure StageExtract

go

create procedure StageExtract
(
	@FileDirectory varchar(500),
	@AdminLocationFilename varchar(1000)
)
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg '-- Stage extract'
	set @msg = '-- Run date: ' + convert(varchar, getdate())
	exec PrintMsg @msg
	exec PrintMsg ''

	if not exists (select * from sys.databases where name = 'EMISXStaging')
	begin
		exec PrintMsg 'EMISXStaging database not found, please run:'
		exec PrintMsg ''
		exec PrintMsg 'exec CreateStagingDatabase'
		exec PrintMsg ''
		exec ThrowError 'EMISXStaging database not found, cannot continue'
		return
	end

	if exists (select * from Data.StagedExtract)
	begin
		exec ThrowError 'An extract is already staged.  Please run exec CleanStaging'
		return
	end

	begin try
		begin transaction
			
			declare @ProcessingIdStart integer 
			declare @ProcessingIdEnd integer
			declare @AdminSchemaName varchar(100)
			declare @LocationTableName varchar(100)
			declare @ExtractDateString varchar(100)
			declare @ExtractDate datetime2
			declare @SharingAgreementGuid uniqueidentifier

			exec ParseExtractFilename
				@Filename = @AdminLocationFilename,
				@ProcessingIdStart = @ProcessingIdStart output,
				@ProcessingIdEnd = @ProcessingIdEnd output,
				@SchemaName = @AdminSchemaName output,
				@TableName = @LocationTableName output,
				@ExtractDateString = @ExtractDateString output,
				@ExtractDate = @ExtractDate output,
				@SharingAgreementGuid = @SharingAgreementGuid output

			if ((@AdminSchemaName != 'Admin') or (@LocationTableName != 'Location'))
			begin
				exec ThrowError 'Please pass the Admin_Location filename'
				return
			end

			-- construct filename template
			declare @FileTypePlaceholder varchar(100) = '<<FILE_TYPE>>'
			declare @FilenameTemplate varchar(1000) = convert(varchar(100), @ProcessingIdStart) + '-' + convert(varchar(100), @ProcessingIdEnd) 
													  + '_' + @FileTypePlaceholder + '_' + @ExtractDateString + '_' 
													  + convert(varchar(200), @SharingAgreementGuid) + '.csv' 
			
			exec PrintMsg ''
			set @msg = 'Staging data with filename template ' + @FilenameTemplate
			exec PrintMsg @msg

			-- get list of tables to import
			declare @Tables table (TableName varchar(100))
			insert into @Tables (TableName) select TableName from Definition.Tables where TableType in ('C', 'P')

			-- loop round each table importing
			while exists (select * from @Tables)
			begin	
				declare @TableName varchar(100) = (select top 1 TableName from @Tables)
				declare @start datetime2 = getdate()		
				delete from @Tables where TableName = @TableName

				set @msg = '  Staging into ' + @TableName
				execute PrintMsg @msg

				declare @FilePath varchar(1000) = @FileDirectory + '\' + replace(@FilenameTemplate, @FileTypePlaceholder, @TableName)		
		
				set @sql = 'bulk insert EMISXStaging.dbo.<<TABLE>>
					from ''<<FILEPATH>>''
					with 
					(
						fieldterminator = ''","'',
						rowterminator = ''"\n"'',
						firstrow = 2
					)'

				set @sql = replace(@sql, '<<TABLE>>', @TableName)
				set @sql = replace(@sql, '<<FILEPATH>>', @FilePath)

				execute sp_executesql @sql
				declare @rowcount integer = @@rowcount
		
				declare @end datetime2 = getdate()
				declare @duration integer = datediff(second, @start, @end)

				set @msg = '  ' + convert(varchar, @rowcount) + ' row(s) inserted in ' + convert(varchar, @duration) + 's'
				exec PrintMsg @msg
				exec PrintMsg ''
			end

			exec PrintMsg ''
			exec RemoveTrailingQuotesFromStagedExtract
			exec PrintMsg ''

			-- update CurrentStatedExtract record
			insert into Data.StagedExtract
			(
				FileDirectory,
				ProcessingIdStart,
				ProcessingIdEnd,
				ExtractDate,
				SharingAgreementGuid,
				FilenameTemplate,
				StagedDate
			)
			values
			(
				@FileDirectory,
				@ProcessingIdStart,
				@ProcessingIdEnd,
				@ExtractDate,
				@SharingAgreementGuid,
				@FilenameTemplate,
				getdate()
			)
		
		commit transaction
		exec PrintMsg 'COMMITTED'
	end try
	begin catch
		exec PrintMsg 'ERROR detected, ROLLING BACK changes'
		rollback;
		throw
	end catch
go



