use EMISXMaster

go

if (object_id('dbo.GetStagingOrganisations') is not null)
	drop function dbo.GetStagingOrganisations

go

create function dbo.GetStagingOrganisations()
returns @Result table
(
	OrganisationGuid varchar(100) primary key not null,
	HaveDetails bit not null,
	IsInstalled bit not null,
	CDB varchar(10) null,
	OrganisationName varchar(500) null,
	ODSCode varchar(10) null,
	PracticeDBName varchar(100) null
)
begin
	insert into @Result
	(
		OrganisationGuid,
		HaveDetails,
		IsInstalled,
		CDB,
		OrganisationName,
		ODSCode,
		PracticeDBName
	)
	select 
		so.OrganisationGuid,
		case
			when coalesce(p.CDB, o.CDB, co.CDB) is not null then 1
			else 0
		end as HaveDetails,
		case
			when p.OrganisationGuid is not null then 1
			else 0
		end as IsInstalled,
		coalesce(p.CDB, o.CDB, co.CDB) as CDB,
		coalesce(p.PracticeName, o.OrganisationName, co.OrganisationName) as OrganisationName,
		coalesce(p.ODSCode, o.ODSCode, co.ODSCode) as ODSCode,
		p.PracticeDBName
	from EMISXStaging.dbo.Agreements_SharingOrganisation so
	left outer join Data.ConfiguredPractices p on so.OrganisationGuid = p.OrganisationGuid
	left outer join EMISXStaging.dbo.vw_Admin_Organisation o on so.OrganisationGuid = o.OrganisationGuid
	left outer join EMISXCommon.dbo.vw_Admin_Organisation co on so.OrganisationGuid = co.OrganisationGuid
	where so.IsActivated = 'true'

	return
end

go
