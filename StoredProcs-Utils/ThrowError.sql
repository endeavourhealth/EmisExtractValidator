use EMISXMaster

go

if (object_id('ThrowError') is not null)
	drop procedure ThrowError

go

create procedure ThrowError
(
	@Text varchar(8000)
)
as
	raiserror(@Text, 18, 10) with nowait

go
