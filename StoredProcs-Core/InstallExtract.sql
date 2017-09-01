USE [EMISXMaster]
GO

/****** Object:  StoredProcedure [dbo].[InstallExtract]    Script Date: 01/09/2017 11:20:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO


CREATE procedure [dbo].[InstallExtract]
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg '-- Install extract'
	set @msg = '-- Run date: ' + convert(varchar, getdate())
	exec PrintMsg @msg
	exec PrintMsg ''

	----------------------------------------------------------------------
	-- check staged data exists
	----------------------------------------------------------------------
	if not exists (select * from Data.StagedExtract)
	begin
		exec ThrowError 'No staged data exists'
		return
	end

	if not exists (select * from sys.databases where name = 'EMISXCommon')
	begin
		exec PrintMsg 'EMISXCommon database not found, please run:'
		exec PrintMsg ''
		exec PrintMsg 'exec CreateCommonDatabase'
		exec PrintMsg ''
		exec ThrowError 'EMISXCommon database not found, cannot continue'
		return
	end

	----------------------------------------------------------------------
	-- check is in correct sequence order
	----------------------------------------------------------------------
	declare @StagedProcessingIdStart integer = (select ProcessingIdStart from Data.StagedExtract)
	declare @InstalledProcessingIdEnd integer = (select top 1 ProcessingIdEnd from Data.InstalledExtracts order by ExtractId desc)
	
	if (@StagedProcessingIdStart != 1)
	begin
		if (@InstalledProcessingIdEnd is null)
		begin
			exec ThrowError 'Cannot install - first installed extract must be a bulk'
			return
		end
		else if (@StagedProcessingIdStart != (@InstalledProcessingIdEnd + 1))
		begin
			exec ThrowError 'Cannot install - processing ID does not continue from last installed extract'
			return
		end
	end

	declare @StagedExtractDate datetime2 = (select ExtractDate from Data.StagedExtract)
	declare @InstalledExtractDate datetime2 = (select top 1 ExtractDate from Data.InstalledExtracts order by ExtractId desc)

	if (@InstalledExtractDate is not null)
	begin
		if (@StagedExtractDate <= @InstalledExtractDate)
		begin
			exec ThrowError 'Cannot install - staged extract date is less than or equal to last installed extract date'
			return
		end
	end

	----------------------------------------------------------------------
	-- check organisations in extract
	----------------------------------------------------------------------
	/*declare @OrganisationGuid varchar(5000)

	select 
		@OrganisationGuid = isnull(@OrganisationGuid + ', ' + OrganisationGuid, OrganisationGuid)
	from dbo.GetStagingOrganisations() 
	where IsInstalled = 0 
	and HaveDetails = 0

	if (@OrganisationGuid is not null)
	begin
		set @msg = 'Data for the organisations (' + @OrganisationGuid + ') was found in staging but cannot find associated organisation details in the staged data or EMISXCommon, cannot continue.'
		exec ThrowError @msg
		return
	end
	*/

	declare @PracticeNames varchar(5000) 
	
	select 
		@PracticeNames = isnull(@PracticeNames + ', ' + OrganisationName + ' (CDB ' + CDB + ')', OrganisationName + ' (CDB ' + CDB + ')') 
	from dbo.GetStagingOrganisations() 
	where IsInstalled = 0 
	and HaveDetails = 1

	if (@PracticeNames is not null)
	begin
		declare @CreatePracticeCommands StringList
		insert into @CreatePracticeCommands (String) 
			select 'exec ConfigurePractice ' + CDB + ', ''' + OrganisationName + ''', ''' + ODSCode + ''', ''' + OrganisationGuid + ''';'
			from dbo.GetStagingOrganisations() where IsInstalled = 0 and HaveDetails = 1

		-- DL - actually execute the SQL to create the practice databases 
		declare @StringListCopy StringList
		insert into @StringListCopy (String) select String from @CreatePracticeCommands

		while exists (select * from @StringListCopy)
		begin
			declare @String varchar(8000) = (select top 1 String from @StringListCopy)
			;with t as (select top 1 * from @StringListCopy) delete from t

			EXEC (@String);
		end

		/*set @msg = 'Data found for new organisations ' + @PracticeNames
		exec PrintMsg @msg
		exec PrintMsg ''
		exec PrintMsg 'Please run:'
		exec PrintMsg ''
		exec PrintList @CreatePracticeCommands
		exec PrintMsg ''

		exec ThrowError 'Please add new practices before rerunning this procedure'
		return*/
	end


	begin try
		begin transaction

			declare @PreviousExtractId integer = (select max(ExtractId) from Data.InstalledExtracts)
			declare @ExtractId integer = isnull(@PreviousExtractId + 1, 1)

			insert into Data.InstalledExtracts
			(
				ExtractId,
				FileDirectory,
				ProcessingIdStart,
				ProcessingIdEnd,
				ExtractDate,
				SharingAgreementGuid,
				FilenameTemplate,
				StagedDate,
				InstalledDated
			)
			select
				@ExtractId,
				FileDirectory,
				ProcessingIdStart,
				ProcessingIdEnd,
				ExtractDate,
				SharingAgreementGuid,
				FilenameTemplate,
				StagedDate,
				getdate()
			from Data.StagedExtract

			set @msg = '  Using ExtractId ' + convert(varchar, @ExtractId)
			exec PrintMsg @msg
			exec PrintMsg ''

			----------------------------------------------------------------------
			-- update newly configured practices
			----------------------------------------------------------------------
			if exists
			(
				select *
				from Data.ConfiguredPractices
				where NewlyConfigured = 1
			)
			begin
				-- do better checks here

				update Data.ConfiguredPractices
				set
					StartExtractId = @ExtractId,
					NewlyConfigured = 0,
					ConfiguredAfter = null
				where NewlyConfigured = 1
				and 
				(
					(ConfiguredAfter is null and @PreviousExtractId is null)
					or (ConfiguredAfter = @PreviousExtractId)
				)
			end

			----------------------------------------------------------------------
			-- migrate data
			----------------------------------------------------------------------
			declare @Practices table
			(
				OrganisationGuid varchar(100),
				CDB integer,
				PracticeName varchar(1000),
				PracticeDBName varchar(100)
			)

			insert into @Practices
			(
				OrganisationGuid,
				CDB,
				PracticeName,
				PracticeDBName
			)
			select distinct
				OrganisationGuid,
				CDB,
				OrganisationName,
				PracticeDBName
			from dbo.GetStagingOrganisations()
			where IsInstalled = 1

			declare @PracticeCount integer = (select count(*) from @Practices)
			set @msg = '  Migrating practice data for ' + convert(varchar, @PracticeCount) + ' organisations'
			exec PrintMsg @msg

			while exists (select * from @Practices)
			begin
				declare @MigrationOrganisationGuid varchar(100) = (select top 1 OrganisationGuid from @Practices)
				declare @MigrationDBName varchar(200) = (select PracticeDBName from @Practices where OrganisationGuid = @MigrationOrganisationGuid)
				delete from @Practices where OrganisationGuid = @MigrationOrganisationGuid

				set @msg = '    Migrating into ' + @MigrationDBName
				exec PrintMsg @msg


				declare @PracticeTables table 
				(
					TableName nvarchar(4000),
					OrganisationGuidJoin nvarchar(4000)
				)
				insert into @PracticeTables 
				(
					TableName,
					OrganisationGuidJoin
				) 
				select 
					TableName,
					OrganisationGuidJoin
				from Definition.Tables
				where TableType = 'P'

				while exists (select * from @PracticeTables)
				begin
					declare @PracticeTableName nvarchar(4000) = (select top 1 TableName from @PracticeTables order by case when isnull(OrganisationGuidJoin, '') != '' then 1 else 0 end desc, TableName asc)   -- so deletions with tables that require a join occur first
					declare @OrganisationGuidJoin nvarchar(4000) = (select OrganisationGuidJoin from @PracticeTables where TableName = @PracticeTableName)
					delete from @PracticeTables where TableName = @PracticeTableName
					
					declare @start datetime2 = getdate()
					declare @rowcount integer = 0

					set @msg = '      Migrating into ' + @MigrationDBName + '.dbo.' + @PracticeTableName
					exec PrintMsg @msg

					set @sql = 'insert into ' + @MigrationDBName + '.dbo.' + @PracticeTableName + 
							   ' select t.*, ' + convert(varchar(100), @ExtractId) + ' from EMISXStaging.dbo.' + @PracticeTableName + ' t ' +
							   replace(@OrganisationGuidJoin, '<<DBNAME>>', 'EMISXStaging') +
							   ' where OrganisationGuid = ''' + @MigrationOrganisationGuid + ''''

					execute sp_executesql @sql
					set @rowcount = @@rowcount

					declare @middle datetime2 = getdate()

					set @msg = '        inserted ' + convert(varchar(100), @rowcount) + ' row(s) into ' + @MigrationDBName + ' in ' + convert(varchar, datediff(second, @start, @middle)) +	 's'
					exec PrintMsg @msg

					set @sql = 'delete t from EMISXStaging.dbo.' + @PracticeTableName + ' as t ' +
							   replace(@OrganisationGuidJoin, '<<DBNAME>>', 'EMISXStaging') +
							   ' where OrganisationGuid = ''' + @MigrationOrganisationGuid + ''''

					execute sp_executesql @sql
					set @rowcount = @@rowcount

					declare @end datetime2 = getdate()

					set @msg = '        deleted ' + convert(varchar(100), @rowcount) + ' row(s) from EMISXStaging in ' + convert(varchar, datediff(second, @middle, @end)) +	 's'
					exec PrintMsg @msg
				end
			end

			----------------------------------------------------------------------
			-- file common data
			----------------------------------------------------------------------
			exec PrintMsg '  Migrating common data'
			declare @Tables table (TableName nvarchar(4000))

			insert into @Tables (TableName) select TableName from Definition.Tables where TableType = 'C'

			while exists (select * from @Tables)
			begin
				declare @TableName nvarchar(4000) = (select top 1 TableName from @Tables)
				delete from @Tables where TableName = @TableName

				set @msg = '    Migrating into EMISXCommon.dbo.' + @TableName
				exec PrintMsg @msg

				set @sql = 'insert into EMISXCommon.dbo.' + @TableName + ' select *, ' + convert(varchar(100), @ExtractId) + ' from EMISXStaging.dbo.' + @TableName
				execute sp_executesql @sql

				set @sql = 'delete from EMISXStaging.dbo.' + @TableName
				execute sp_executesql @sql
			end

			----------------------------------------------------------------------
			-- ensure all data migrated
			----------------------------------------------------------------------
			exec PrintMsg ''

			exec PrintMsg ''
			exec PrintMsg '  Checking for data remaining in staging'

			delete from EMISXStaging.dbo.Appointment_SessionUser

			declare @NonEmptyTables StringList

			insert into @NonEmptyTables
				exec GetNonEmptyTables 'EMISXStaging'

			if exists (select * from @NonEmptyTables)
			begin
				exec PrintMsg '  Data remains in staging in the following table(s):'
				exec PrintList @NonEmptyTables, '    '
				exec ThrowError 'Cannot complete extract - data remains in staging after install'
				return
			end
			else
			begin
				delete from Data.StagedExtract

				exec PrintMsg '  No data remains in staging - all data has been installed'
				exec PrintMsg 'Install complete'
			end

		commit transaction
		exec PrintMsg 'COMMITTED'
	end try
	begin catch
		exec PrintMsg 'ERROR detected, ROLLING BACK changes'
		rollback;
		throw
	end catch

GO

