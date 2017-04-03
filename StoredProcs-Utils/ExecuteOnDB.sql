use EMISXMaster

go

if (object_id('ExecuteOnDB') is not null)
	drop procedure ExecuteOnDB

go

create procedure ExecuteOnDB
(
	@Sql nvarchar(4000),
	@DBName varchar(100)
)
as

	set nocount on

	declare @OuterSql nvarchar(4000) = 'execute <<DB>>.sys.sp_executesql N''<<SQL>>'''

	set @Sql = replace(@Sql, '''', '''''')
	set @OuterSql = replace(@OuterSql, '<<DB>>', @DBName)
	set @OuterSql = replace(@OuterSql, '<<SQL>>', @sql)
	
	execute sp_executesql @OuterSql
	
go

