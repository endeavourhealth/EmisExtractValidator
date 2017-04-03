use EMISXMaster

go

if (object_id('PrintVrMsg') is not null)
	drop procedure PrintVrMsg

go

create procedure PrintVrMsg
(
	@RunId integer,
	@Text varchar(8000)
)
as
	insert into Validation.RunText
	(
		RunId,
		Line
	)
	values
	(
		@RunId,
		@Text
	)

	exec PrintMsg @Text = @Text

go
