use EMISXMaster

go

if (object_id('PrintMsg') is not null)
	drop procedure PrintMsg

go

create procedure PrintMsg
(
	@Text varchar(8000)
)
as
	raiserror(@Text, 0, 1) with nowait

go
