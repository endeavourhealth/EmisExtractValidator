use EMISXMaster

go

if (object_id('dbo.ConfigurePractice') is not null)
	drop procedure dbo.ConfigurePractice

go

create procedure dbo.ConfigurePractice
(
	@CDB integer,
	@PracticeName varchar(500),
	@ODSCode varchar(10),
	@OrganisationGuid varchar(100)
)
as

	set nocount on

	declare @msg varchar(1000)
	declare @sql nvarchar(4000)

	exec PrintMsg '-----------------------------------------------------------------------------'
	exec PrintMsg '-- Configure practice'
	set @msg = '-- Run date: ' + convert(varchar, getdate())
	exec PrintMsg @msg
	exec PrintMsg ''

	if exists
	(
		select *
		from Data.ConfiguredPractices
		where CDB = @CDB
		or OrganisationGuid = @OrganisationGuid
	)
	begin
		exec ThrowError 'Practice already configured'
		return
	end

	declare @DBName varchar(100) = 'EMISX' + convert(varchar, @CDB)

	exec PrintMsg 'Adding to dbo.ConfiguredPractices'
	exec PrintMsg ''

	declare @ExtractId integer = (select max(ExtractId) from Data.InstalledExtracts)

	insert into Data.ConfiguredPractices
	(
		CDB,
		ODSCode,
		PracticeName, 
		OrganisationGuid,
		PracticeDBName,
		NewlyConfigured,
		ConfiguredAfter
	)
	values
	(
		@CDB,
		@ODSCode,
		@PracticeName,
		@OrganisationGuid,
		@DBName,
		1,
		@ExtractId
	)

	execute dbo.CreateDatabase 
		@DestDbName = @DBName,
		@InstallCommonTables = 0, 
		@InstallPracticeTables = 1, 
		@IsStaging = 0

go
