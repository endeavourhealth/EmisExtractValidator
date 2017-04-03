--create table CodeCounts
--(
--	CodeId BigInt not null primary key,
--	MostRecentDate datetime2 null,
--	CodeCount integer not null
--)

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

	select @DatabaseName

	declare @sql nvarchar(4000) = N'insert into CodeCounts (CodeId, CodeCount)
	select distinct o.CodeId, 0 from <<DB>>.dbo.vw_CareRecord_Observation o
	left outer join CodeCounts cc on o.CodeId = cc.CodeId where cc.CodeId is null'

	set @sql = replace(@sql, '<<DB>>', @DatabaseName)

	execute sp_executesql @sql

	set @sql = N'update c1
	set 
		c1.MostRecentDate = case 
			when c1.MostRecentDate is null then c2.MostRecentDate
			when c2.MostRecentDate > c1.MostRecentDate then c2.MostRecentDate
			else c1.MostRecentDate
		end,
		c1.CodeCount = c1.CodeCount + c2.CodeCount
	from CodeCounts c1
	inner join
	(
		select 
			o.CodeId,
			max(o.EffectiveDate) as MostRecentDate,
			count(*) as CodeCount
		from <<DB>>.dbo.vw_CareRecord_Observation o
		group by o.CodeId
	) c2 on c1.CodeId = c2.CodeId'

	set @sql = replace(@sql, '<<DB>>', @DatabaseName)

	execute sp_executesql @sql
end

select 
	cc.CodeId as EmisCodeId,
	c.Term,
	c.ReadTermId,
	c.SnomedCTConceptId,
	c.SnomedCTDescriptionId,
	cc.CodeCount,
	cc.MostRecentDate
from CodeCounts cc 
inner join EMISXCommon.dbo.Coding_ClinicalCode c on c.CodeId = cc.CodeId
order by cc.CodeCount desc
