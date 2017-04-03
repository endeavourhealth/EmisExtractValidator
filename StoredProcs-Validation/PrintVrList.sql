use EMISXMaster

go

if (object_id('PrintVrList') is not null)
	drop procedure PrintVrList

go

create procedure PrintVrList
(
	@ValidationRunId integer,
	@StringList StringList readonly,
	@Prefix varchar(100) = ''
)
as

	set nocount on
	declare @msg varchar(8000)

	declare @StringListCopy StringList
	insert into @StringListCopy (String) select String from @StringList

	while exists (select * from @StringListCopy)
	begin
		declare @String varchar(8000) = (select top 1 String from @StringListCopy)
		;with t as (select top 1 * from @StringListCopy) delete from t

		set @msg = @Prefix + @String
		exec PrintVrMsg @ValidationRunId, @msg
	end
	
go

