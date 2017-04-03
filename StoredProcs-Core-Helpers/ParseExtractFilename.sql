use EMISXMaster

go

if (object_id('dbo.ParseExtractFilename') is not null)
	drop procedure dbo.ParseExtractFilename

go

create procedure dbo.ParseExtractFilename
(
	@Filename varchar(1000),
	@ProcessingIdStart integer output,
	@ProcessingIdEnd integer output,
	@SchemaName varchar(100) output,
	@TableName varchar(100) output,
	@ExtractDateString varchar(100) output,
	@ExtractDate datetime2 output,
	@SharingAgreementGuid uniqueidentifier output
)
as

	if (@Filename is null)
	begin
		exec ThrowError '@Filename is null'
		return
	end

	declare @OriginalFilename varchar(1000)

	if (not upper(@Filename) like '%.CSV')
	begin
		exec ThrowError 'Filename does not have .csv extension'
		return
	end

	set @OriginalFilename = @Filename
	set @Filename = substring(@Filename, 1, len(@Filename) - 4)

	declare @Components table
	(
		Id integer primary key,
		Component varchar(1000)
	)

	insert into @Components (Id, Component)
	select Id, Data from Split(@Filename, '_')

	if ((select count(*) from @Components) != 5)
	begin
		exec ThrowError 'Could not parse filename'
		return
	end

	declare @ProcesingIds varchar(100) = (select Component from @Components where Id = 1)
	set @SchemaName = (select Component from @Components where Id = 2)
	set @TableName = (select Component from @Components where Id = 3)
	set @ExtractDateString = (select Component from @Components where Id = 4)
	set @SharingAgreementGuid = convert(uniqueidentifier, (select Component from @Components where Id = 5))

	declare @ProcessingIdComponents table
	(
		Id integer primary key,
		Component varchar(100)
	)

	insert into @ProcessingIdComponents
	select Id, Data from Split(@ProcesingIds, '-')

	if ((select count(*) from @ProcessingIdComponents) != 2)
	begin
		exec ThrowError 'Could not parse processing ids'
		return
	end

	set @ProcessingIdStart = (select convert(integer, Component) from @ProcessingIdComponents where Id = 1)
	set @ProcessingIdEnd = (select convert(integer, Component) from @ProcessingIdComponents where Id = 2)

	if ((len(@SchemaName) = 0) or (len(@TableName) = 0))
	begin
		exec ThrowError 'Could not determine schema or table name'
		return
	end

	if (len(@ExtractDateString) != 14)
	begin
		exec ThrowError 'Extract date/time is incorrect length'
		return
	end

	declare @ExtractDateStringNewFormat varchar(100)
		 = substring(@ExtractDateString, 1, 4) + '-' 
		   + substring(@ExtractDateString, 5, 2) + '-' 
		   + substring(@ExtractDateString, 7, 2) + ' '
		   + substring(@ExtractDateString, 9, 2) + ':'
		   + substring(@ExtractDateString, 11, 2) + ':' 
		   + substring(@ExtractDateString, 13, 3)

	set @ExtractDate = convert(datetime2, @ExtractDateStringNewFormat, 120)

go
