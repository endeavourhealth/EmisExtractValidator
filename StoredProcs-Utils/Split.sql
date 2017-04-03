use EMISXMaster

go

if (object_id('Split') is not null)
	drop function Split

go

create function Split
(
    @String nvarchar(4000),
    @Delimiter nchar(1)
)
returns table
as
return
(
	with Split(stpos, endpos)
    as
	(
		select 0 as stpos, charindex(@Delimiter, @String) as endpos
        union all
        select endpos + 1, charindex(@Delimiter, @String, endpos + 1)
		from Split
		where endpos > 0
    )
    select
		'Id' = row_number() over (order by (select 1)),
		'Data' = substring(@String, stpos, coalesce(nullif(endpos, 0), len(@String) + 1) - stpos)
    from Split
)

go
