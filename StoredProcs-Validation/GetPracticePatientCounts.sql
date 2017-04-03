use EMISXMaster

go

if (object_id('GetPracticePatientCounts') is not null)
	drop procedure GetPracticePatientCounts

go

create procedure GetPracticePatientCounts
as

	declare @Result table
	(
		PracticeName varchar(1000) not null,
		DatabaseName varchar(100) not null,
		PatientCount integer not null
	)

	declare @Databases table
	(
		DatabaseName varchar(100) not null primary key
	)

	insert into @Databases
	(
		DatabaseName
	)
	select
		PracticeDBName
	from Data.ConfiguredPractices
	order by PracticeDBName

	while exists (select * from @Databases)
	begin
		declare @DatabaseName varchar(100) = (select top 1 DatabaseName from @Databases)
		delete from @Databases where DatabaseName = @DatabaseName

		declare @Sql nvarchar(4000) = N'select @PatientCount = count(*) from <<DB>>.dbo.vw_Admin_Patient'
		set @Sql = replace(@Sql, '<<DB>>', @DatabaseName);

		declare @PatientCount integer = 0;

		execute sp_executesql @Sql, N'@PatientCount integer output', @PatientCount = @PatientCount output

		declare @PracticeName varchar(1000) = (select PracticeName from Data.ConfiguredPractices where PracticeDBName = @DatabaseName)

		insert into @Result 
		(
			PracticeName,
			DatabaseName,
			PatientCount
		)
		values
		(
			@PracticeName,
			@DatabaseName,
			@PatientCount		
		)
	end

	select
		PracticeName,
		DatabaseName,
		PatientCount
	from @Result
	order by PatientCount desc

go

