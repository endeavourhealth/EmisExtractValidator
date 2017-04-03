use EMISXMaster

go

if (object_id('ExecuteOnAllPracticeDBs') is not null)
	drop procedure ExecuteOnAllPracticeDBs

go

create procedure ExecuteOnAllPracticeDBs
(
	@Sql nvarchar(4000)
)
as

	set nocount on

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

		execute ExecuteOnDB @Sql, @DatabaseName
	end
	
go

