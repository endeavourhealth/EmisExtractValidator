use EMISXMaster

go

if (object_id('ValidateForeignKeysAllPractices') is not null)
	drop procedure ValidateForeignKeysAllPractices

go

create procedure ValidateForeignKeysAllPractices
(
	@ExtractId integer = null
)
as

	set nocount on

	declare @RunGroupId integer = (select isnull(max(RunGroupId), 0) + 1 from Validation.Run)

	declare @Practices table
	(
		PracticeDBName varchar(100) not null
	)

	insert into @Practices
	(
		PracticeDBName
	)
	select PracticeDBName 
	from Data.ConfiguredPractices 
	order by StartExtractId, PracticeName

	while exists (select * from @Practices)
	begin
		declare @PracticeDBName varchar(100) = (select top 1 PracticeDBName from @Practices)
		delete from @Practices where PracticeDBName = @PracticeDBName

		exec ValidateForeignKeys 
			@PracticeDBName = @PracticeDBName, 
			@ExtractId = @ExtractId,
			@RunGroupId = @RunGroupId
	end

go
