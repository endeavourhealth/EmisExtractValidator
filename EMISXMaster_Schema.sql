use EMISXMaster

go

create schema Definition authorization dbo

go

create schema Data authorization dbo

go

create schema Validation authorization dbo;

go

create type dbo.StringList as table
(
	String varchar(8000)
)

create table Data.InstalledExtracts
(
	ExtractId integer not null,
	FileDirectory varchar(1000) not null,
	ProcessingIdStart integer not null,
	ProcessingIdEnd integer not null,
	ExtractDate datetime2 not null,
	SharingAgreementGuid uniqueidentifier not null,
	FilenameTemplate varchar(500) not null,
	StagedDate datetime2 not null,
	InstalledDated datetime2 not null

	constraint PK_Data_InstalledExtracts_ExtractId primary key clustered (ExtractId)
)

create table Data.StagedExtract
(
	FileDirectory varchar(1000) not null,
	ProcessingIdStart integer not null,
	ProcessingIdEnd integer not null,
	ExtractDate datetime2 not null,
	SharingAgreementGuid uniqueidentifier not null,
	FilenameTemplate varchar(500) not null,
	StagedDate datetime2 not null,
	SingleRowLock bit not null default (1)

	constraint PK_StagedData_SingleRowLock primary key clustered (SingleRowLock),
	constraint CK_StagedData_SingleRowLock check (SingleRowLock = 1),
	constraint UQ_StagedData_SingleRowLock unique (SingleRowLock)
)

create table Data.ConfiguredPractices
(
	OrganisationGuid uniqueidentifier not null,
	PracticeName varchar(200) not null,
	ODSCode varchar(10) not null,
	CDB integer not null,
	PracticeDBName varchar(100) not null,
	StartExtractId integer null,
	NewlyConfigured bit not null,
	ConfiguredAfter integer null

	constraint PK_Data_ConfiguredPractices_OrganisationGuid primary key clustered (OrganisationGuid),
	constraint UQ_Data_ConfiguredPractices_ODSCode unique (ODSCode),
	constraint UQ_Data_ConfiguredPractices_CDB unique (CDB),
	constraint UQ_Data_ConfiguredPractices_PracticeDBName unique (PracticeDBName),
	constraint FK_Data_ConfiguredPractices_BulkExtractId foreign key (StartExtractId) references Data.InstalledExtracts (ExtractId),
	constraint FK_Data_ConfiguredPractices_ConfiguredAfter foreign key (ConfiguredAfter) references Data.InstalledExtracts (ExtractId),
	constraint CK_Data_ConfiguredPractices_NewlyConfigured_ConfiguredAfter check ((NewlyConfigured = 1) or (NewlyConfigured = 0 and ConfiguredAfter is null)),
	constraint CK_Data_ConfiguredPractices_NewlyConfigured_StartExtractId check ((NewlyConfigured = 1 and StartExtractId is null) or (NewlyConfigured = 0 and StartExtractId is not null))
)

create table Definition.TableTypes
(
	TableType char(1) not null,
	Description varchar(100) not null

	constraint PK_Definition_TableTypes_TableType primary key clustered (TableType),
	constraint UQ_Definition_TableTypes_Description unique (Description)
)

create table Definition.Tables
(
	TableName varchar(100) not null,
	TableType char(1) not null,
	DeletedColumnName varchar(100) not null,
	OrganisationGuidJoin nvarchar(4000) not null,
	CreateSql nvarchar(4000) not null

	constraint PK_Definition_Tables_TableName primary key clustered (TableName),
	constraint FK_Definition_Tables_TableType foreign key (TableType) references Definition.TableTypes (TableType)
)

create table Definition.PrimaryKeys
(
	PrimaryKeyId integer not null,
	TableName varchar(100) not null,
	ColumnName1 varchar(100) null,
	ColumnName2 varchar(100) null

	constraint PK_Definition_PrimaryKeys_PrimaryKeyId primary key clustered (PrimaryKeyId),
	constraint UQ_Definition_PrimaryKeys_TableName unique (TableName),
	constraint FK_Definition_PrimaryKeys_TableName foreign key (TableName) references Definition.Tables (TableName)
)

create table Definition.ForeignKeys
(
	ForeignKeyId integer not null,
	FromTable varchar(100),
	FromColumn varchar(100),
	ToTable varchar(100),
	ToColumn varchar(100)

	constraint PK_Definition_ForeignKeys_ForeignKeyId primary key clustered (ForeignKeyId),
	constraint FK_Definition_ForeignKeys_FromTable foreign key (FromTable) references Definition.Tables (TableName),
	constraint FK_Definition_ForeignKeys_ToTable foreign key (ToTable) references Definition.Tables (TableName),
	constraint UQ_Definition_ForeignKeys_FromTable_FromColumn unique (FromTable, FromColumn)
)

create table Validation.Run
(
	RunId integer not null identity(1, 1),
	PracticeDBName varchar(100) not null,
	ExtractId integer not null,
	RunDate datetime2 not null,
	RunGroupId integer null

	constraint PK_Validation_Run_ValidationRunId primary key clustered (RunId),
	constraint FK_Validation_Run_PracticeDBName foreign key (PracticeDBName) references Data.ConfiguredPractices (PracticeDBName),
	constraint FK_Validation_Run_CurrentExtractId foreign key (ExtractId) references Data.InstalledExtracts (ExtractId)
)

create table Validation.RunText
(
	RunId integer not null,
	LineId integer not null identity(1, 1),
	Line varchar(max) not null

	constraint PK_Validation_RunText_ValidationRunId_LineId primary key clustered (RunId, LineId),
	constraint FK_Validation_RunText_ValidationRunId foreign key (RunId) references Validation.Run (RunId)
)

create table Validation.ForeignKeyErrors
(
	RunId integer not null,
	ForeignKeyId integer not null,
	Count integer not null,
	DistinctCount integer not null

	constraint PK_Validation_ForeignKeyErrors_RunId_ForeignKeyId primary key clustered (RunId, ForeignKeyId),
	constraint FK_Validation_ForeignKeyErrors_RunId foreign key (RunId) references Validation.Run (RunId),
	constraint FK_Validation_ForeignKeyErrors_ForeignKeyId foreign key (ForeignKeyId) references Definition.ForeignKeys (ForeignKeyId)
)

insert into Definition.TableTypes (TableType, Description) values 
('P', 'Practice table'),
('C', 'Common table')

insert into Definition.Tables 
(
	TableName, 
	TableType,
	DeletedColumnName,
	OrganisationGuidJoin, 
	CreateSql
) 
values
(
	'Admin_Location',
	'C',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Admin_Location](
		[LocationGuid] [varchar](50) NULL,
		[LocationName] [varchar](500) NULL,
		[LocationTypeDescription] [varchar](50) NULL,
		[ParentLocationGuid] [varchar](50) NULL,
		[OpenDate] [varchar](50) NULL,
		[CloseDate] [varchar](50) NULL,
		[MainContactName] [varchar](50) NULL,
		[FaxNumber] [varchar](50) NULL,
		[EmailAddress] [varchar](50) NULL,
		[PhoneNumber] [varchar](50) NULL,
		[HouseNameFlatNumber] [varchar](100) NULL,
		[NumberAndStreet] [varchar](50) NULL,
		[Village] [varchar](50) NULL,
		[Town] [varchar](50) NULL,
		[County] [varchar](50) NULL,
		[Postcode] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Admin_Organisation',
	'C',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Admin_Organisation](
		[OrganisationGuid] [varchar](50) NULL,
		[CDB] [varchar](50) NULL,
		[OrganisationName] [varchar](500) NULL,
		[ODSCode] [varchar](50) NULL,
		[ParentOrganisationGuid] [varchar](50) NULL,
		[CCGOrganisationGuid] [varchar](50) NULL,
		[OrganisationType] [varchar](50) NULL,
		[OpenDate] [varchar](50) NULL,
		[CloseDate] [varchar](50) NULL,
		[MainLocationGuid] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Admin_OrganisationLocation',
	'C',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Admin_OrganisationLocation](
		[OrganisationGuid] [varchar](50) NULL,
		[LocationGuid] [varchar](50) NULL,
		[IsMainLocation] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Admin_Patient',
	'P',
	'Deleted',
	'',
	'CREATE TABLE <<DBNAME>>.[dbo].[Admin_Patient](
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[UsualGpUserInRoleGuid] [varchar](50) NULL,
		[Sex] [varchar](50) NULL,
		[DateOfBirth] [varchar](50) NULL,
		[DateOfDeath] [varchar](50) NULL,
		[Title] [varchar](50) NULL,
		[GivenName] [varchar](50) NULL,
		[MiddleNames] [varchar](50) NULL,
		[Surname] [varchar](50) NULL,
		[DateOfRegistration] [varchar](50) NULL,
		[NhsNumber] [varchar](50) NULL,
		[PatientNumber] [varchar](50) NULL,
		[PatientTypeDescription] [varchar](50) NULL,
		[DummyType] [varchar](50) NULL,
		[HouseNameFlatNumber] [varchar](50) NULL,
		[NumberAndStreet] [varchar](50) NULL,
		[Village] [varchar](50) NULL,
		[Town] [varchar](50) NULL,
		[County] [varchar](50) NULL,
		[Postcode] [varchar](50) NULL,
		[ResidentialInstituteCode] [varchar](50) NULL,
		[NHSNumberStatus] [varchar](50) NULL,
		[CarerName] [varchar](50) NULL,
		[CarerRelation] [varchar](50) NULL,
		[PersonGuid] [varchar](50) NULL,
		[DateOfDeactivation] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[SpineSensitive] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[EmailAddress] [varchar](50) NULL,
		[HomePhone] [varchar](50) NULL,
		[MobilePhone] [varchar](50) NULL,
		[ExternalUsualGPGuid] [varchar](50) NULL,
		[ExternalUsualGP] [varchar](50) NULL,
		[ExternalUsualGPOrganisation] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Admin_UserInRole',
	'C',
	'',
	'',
	'CREATE TABLE <<DBNAME>>.[dbo].[Admin_UserInRole](
		[UserInRoleGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[Title] [varchar](50) NULL,
		[GivenName] [varchar](100) NULL,
		[Surname] [varchar](100) NULL,
		[JobCategoryCode] [varchar](50) NULL,
		[JobCategoryName] [varchar](50) NULL,
		[ContractStartDate] [varchar](50) NULL,
		[ContractEndDate] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Agreements_SharingOrganisation',
	'C',
	'Deleted',
	'',
	'CREATE TABLE <<DBNAME>>.[dbo].[Agreements_SharingOrganisation](
		[OrganisationGuid] [varchar](50) NULL,
		[IsActivated] [varchar](50) NULL,
		[LastModifiedDate] [varchar](50) NULL,
		[Disabled] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Appointment_Session',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Appointment_Session](
		[AppointmentSessionGuid] [varchar](50) NULL,
		[Description] [varchar](200) NULL,
		[LocationGuid] [varchar](50) NULL,
		[SessionTypeDescription] [varchar](50) NULL,
		[SessionCategoryDisplayName] [varchar](50) NULL,
		[StartDate] [varchar](50) NULL,
		[StartTime] [varchar](50) NULL,
		[EndDate] [varchar](50) NULL,
		[EndTime] [varchar](50) NULL,
		[Private] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Appointment_SessionUser',
	'P',
	'Deleted',
	'inner join <<DBNAME>>.dbo.Appointment_Session s on t.SessionGuid = s.AppointmentSessionGuid',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Appointment_SessionUser](
		[SessionGuid] [varchar](50) NULL,
		[UserInRoleGuid] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Appointment_Slot',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Appointment_Slot](
		[SlotGuid] [varchar](50) NULL,
		[AppointmentDate] [varchar](50) NULL,
		[AppointmentStartTime] [varchar](50) NULL,
		[PlannedDurationInMinutes] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[SendInTime] [varchar](50) NULL,
		[LeftTime] [varchar](50) NULL,
		[DidNotAttend] [varchar](50) NULL,
		[PatientWaitInMin] [varchar](50) NULL,
		[AppointmentDelayInMin] [varchar](50) NULL,
		[ActualDurationInMinutes] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[SessionGuid] [varchar](50) NULL,
		[DnaReasonCodeId] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Audit_PatientAudit',
	'P',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Audit_PatientAudit](
		[ItemGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[ModifiedDate] [varchar](50) NULL,
		[ModifiedTime] [varchar](50) NULL,
		[UserInRoleGuid] [varchar](50) NULL,
		[ItemType] [varchar](50) NULL,
		[ModeType] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Audit_RegistrationAudit',
	'P',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Audit_RegistrationAudit](
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[ModifiedDate] [varchar](50) NULL,
		[ModifiedTime] [varchar](50) NULL,
		[UserInRoleGuid] [varchar](50) NULL,
		[ModeType] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'CareRecord_Consultation',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[CareRecord_Consultation](
		[ConsultationGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[EffectiveDate] [varchar](50) NULL,
		[EffectiveDatePrecision] [varchar](50) NULL,
		[EnteredDate] [varchar](50) NULL,
		[EnteredTime] [varchar](50) NULL,
		[ClinicianUserInRoleGuid] [varchar](50) NULL,
		[EnteredByUserInRoleGuid] [varchar](50) NULL,
		[AppointmentSlotGuid] [varchar](50) NULL,
		[ConsultationSourceTerm] [varchar](500) NULL,
		[ConsultationSourceCodeId] [varchar](50) NULL,
		[Complete] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'CareRecord_Diary',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[CareRecord_Diary](
		[DiaryGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[EffectiveDate] [varchar](50) NULL,
		[EffectiveDatePrecision] [varchar](50) NULL,
		[EnteredDate] [varchar](50) NULL,
		[EnteredTime] [varchar](50) NULL,
		[ClinicianUserInRoleGuid] [varchar](50) NULL,
		[EnteredByUserInRoleGuid] [varchar](50) NULL,
		[CodeId] [varchar](50) NULL,
		[OriginalTerm] [varchar](500) NULL,
		[AssociatedText] [varchar](50) NULL,
		[DurationTerm] [varchar](50) NULL,
		[LocationTypeDescription] [varchar](500) NULL,
		[Deleted] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[IsActive] [varchar](50) NULL,
		[IsComplete] [varchar](50) NULL,
		[ConsultationGuid] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'CareRecord_Observation',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[CareRecord_Observation](
		[ObservationGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[EffectiveDate] [varchar](50) NULL,
		[EffectiveDatePrecision] [varchar](50) NULL,
		[EnteredDate] [varchar](50) NULL,
		[EnteredTime] [varchar](50) NULL,
		[ClinicianUserInRoleGuid] [varchar](50) NULL,
		[EnteredByUserInRoleGuid] [varchar](50) NULL,
		[ParentObservationGuid] [varchar](50) NULL,
		[CodeId] [varchar](50) NULL,
		[ProblemGuid] [varchar](50) NULL,
		[AssociatedText] [varchar](1000) NULL,
		[ConsultationGuid] [varchar](50) NULL,
		[Value] [varchar](50) NULL,
		[NumericUnit] [varchar](500) NULL,
		[ObservationType] [varchar](50) NULL,
		[NumericRangeLow] [varchar](50) NULL,
		[NumericRangeHigh] [varchar](50) NULL,
		[DocumentGuid] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'CareRecord_ObservationReferral',
	'P',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[CareRecord_ObservationReferral](
		[ObservationGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[ReferralTargetOrganisationGuid] [varchar](50) NULL,
		[ReferralUrgency] [varchar](50) NULL,
		[ReferralServiceType] [varchar](50) NULL,
		[ReferralMode] [varchar](50) NULL,
		[ReferralReceivedDate] [varchar](50) NULL,
		[ReferralReceivedTime] [varchar](50) NULL,
		[ReferralEndDate] [varchar](50) NULL,
		[ReferralSourceId] [varchar](50) NULL,
		[ReferralSourceOrganisationGuid] [varchar](50) NULL,
		[ReferralUBRN] [varchar](50) NULL,
		[ReferralReasonCodeId] [varchar](50) NULL,
		[ReferringCareProfessionalStaffGroupCodeId] [varchar](50) NULL,
		[ReferralEpisodeRTTMeasurementTypeId] [varchar](50) NULL,
		[ReferralEpisodeClosureDate] [varchar](50) NULL,
		[ReferralEpisodeDischargeLetterIssuedDate] [varchar](50) NULL,
		[ReferralClosureReasonCodeId] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'CareRecord_Problem',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[CareRecord_Problem](
		[ObservationGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[ParentProblemObservationGuid] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[Comment] [varchar](500) NULL,
		[EndDate] [varchar](50) NULL,
		[EndDatePrecision] [varchar](50) NULL,
		[ExpectedDuration] [varchar](50) NULL,
		[LastReviewDate] [varchar](50) NULL,
		[LastReviewDatePrecision] [varchar](50) NULL,
		[LastReviewUserInRoleGuid] [varchar](50) NULL,
		[ParentProblemRelationship] [varchar](50) NULL,
		[ProblemStatusDescription] [varchar](50) NULL,
		[SignificanceDescription] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Coding_ClinicalCode',
	'C',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Coding_ClinicalCode](
		[CodeId] [varchar](50) NULL,
		[Term] [varchar](500) NULL,
		[ReadTermId] [varchar](50) NULL,
		[SnomedCTConceptId] [varchar](50) NULL,
		[SnomedCTDescriptionId] [varchar](50) NULL,
		[NationalCode] [varchar](50) NULL,
		[NationalCodeCategory] [varchar](500) NULL,
		[NationalDescription] [varchar](500) NULL,
		[EmisCodeCategoryDescription] [varchar](500) NULL,
		[ProcessingId] [varchar](50) NULL,
		[ParentCodeId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Coding_DrugCode',
	'C',
	'',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Coding_DrugCode](
		[CodeId] [varchar](50) NULL,
		[Term] [varchar](500) NULL,
		[DmdProductCodeId] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Prescribing_DrugRecord',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Prescribing_DrugRecord](
		[DrugRecordGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[EffectiveDate] [varchar](50) NULL,
		[EffectiveDatePrecision] [varchar](50) NULL,
		[EnteredDate] [varchar](50) NULL,
		[EnteredTime] [varchar](50) NULL,
		[ClinicianUserInRoleGuid] [varchar](50) NULL,
		[EnteredByUserInRoleGuid] [varchar](50) NULL,
		[CodeId] [varchar](50) NULL,
		[Dosage] [varchar](500) NULL,
		[Quantity] [varchar](50) NULL,
		[QuantityUnit] [varchar](500) NULL,
		[ProblemObservationGuid] [varchar](50) NULL,
		[PrescriptionType] [varchar](50) NULL,
		[IsActive] [varchar](50) NULL,
		[CancellationDate] [varchar](50) NULL,
		[NumberOfIssues] [varchar](50) NULL,
		[NumberOfIssuesAuthorised] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
),
(
	'Prescribing_IssueRecord',
	'P',
	'Deleted',
	'',
	N'CREATE TABLE <<DBNAME>>.[dbo].[Prescribing_IssueRecord](
		[IssueRecordGuid] [varchar](50) NULL,
		[PatientGuid] [varchar](50) NULL,
		[OrganisationGuid] [varchar](50) NULL,
		[DrugRecordGuid] [varchar](50) NULL,
		[EffectiveDate] [varchar](50) NULL,
		[EffectiveDatePrecision] [varchar](50) NULL,
		[EnteredDate] [varchar](50) NULL,
		[EnteredTime] [varchar](50) NULL,
		[ClinicianUserInRoleGuid] [varchar](50) NULL,
		[EnteredByUserInRoleGuid] [varchar](50) NULL,
		[CodeId] [varchar](50) NULL,
		[Dosage] [varchar](500) NULL,
		[Quantity] [varchar](50) NULL,
		[QuantityUnit] [varchar](500) NULL,
		[ProblemObservationGuid] [varchar](50) NULL,
		[CourseDurationInDays] [varchar](50) NULL,
		[EstimatedNhsCost] [varchar](50) NULL,
		[IsConfidential] [varchar](50) NULL,
		[Deleted] [varchar](50) NULL,
		[ProcessingId] [varchar](50) NULL
	) ON [PRIMARY]'
)

insert into Definition.PrimaryKeys
(
	PrimaryKeyId,
	TableName,
	ColumnName1,
	ColumnName2
)
values
(1, 'Admin_Location', 'LocationGuid', null),
(2, 'Admin_Organisation', 'OrganisationGuid', null),
(3, 'Admin_OrganisationLocation', 'OrganisationGuid', 'LocationGuid'),
(4, 'Admin_Patient', 'PatientGuid', null),
(5, 'Admin_UserInRole', 'UserInRoleGuid', null),
(6, 'Agreements_SharingOrganisation', 'OrganisationGuid', null),
(7, 'Appointment_Session', 'AppointmentSessionGuid', null),
(8, 'Appointment_SessionUser', 'SessionGuid', 'UserInRoleGuid'),
(9, 'Appointment_Slot', 'SlotGuid', null),
(10, 'Audit_PatientAudit', null, null),  -- no key!
(11, 'Audit_RegistrationAudit', null, null),  -- no key!
(12, 'CareRecord_Consultation', 'PatientGuid', 'ConsultationGuid'),
(13, 'CareRecord_Diary', 'PatientGuid', 'DiaryGuid'),
(14, 'CareRecord_Observation', 'PatientGuid', 'ObservationGuid'),
(15, 'CareRecord_ObservationReferral', 'PatientGuid', 'ObservationGuid'),
(16, 'CareRecord_Problem', 'PatientGuid', 'ObservationGuid'),
(17, 'Coding_ClinicalCode', 'CodeId', null),
(18, 'Coding_DrugCode', 'CodeId', null),
(19, 'Prescribing_DrugRecord', 'PatientGuid', 'DrugRecordGuid'),
(20, 'Prescribing_IssueRecord', 'PatientGuid', 'IssueRecordGuid')

insert into Definition.ForeignKeys
(
	ForeignKeyId,
	FromTable, 
	FromColumn, 
	ToTable, 
	ToColumn
)
values
(1, 'Admin_Location', 'ParentLocationGuid', 'Admin_Location', 'LocationGuid'),
(2, 'Admin_Organisation', 'CCGOrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(3, 'Admin_Organisation', 'MainLocationGuid', 'Admin_Location', 'LocationGuid'),
(4, 'Admin_Organisation', 'ParentOrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(5, 'Admin_OrganisationLocation', 'LocationGuid', 'Admin_Location', 'LocationGuid'),
(6, 'Admin_OrganisationLocation', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(7, 'Admin_Patient', 'ExternalUsualGPOrganisation', 'Admin_Organisation', 'OrganisationGuid'),
(8, 'Admin_Patient', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(9, 'Admin_Patient', 'UsualGpUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(10, 'Admin_UserInRole', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(11, 'Agreements_SharingOrganisation', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(12, 'Appointment_Session', 'LocationGuid', 'Admin_Location', 'LocationGuid'),
(13, 'Appointment_Session', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(14, 'Appointment_SessionUser', 'SessionGuid', 'Appointment_Session', 'AppointmentSessionGuid'),
(15, 'Appointment_SessionUser', 'UserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(16, 'Appointment_Slot', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(17, 'Appointment_Slot', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(18, 'Appointment_Slot', 'SessionGuid', 'Appointment_Session', 'AppointmentSessionGuid'),
(19, 'Audit_PatientAudit', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(20, 'Audit_PatientAudit', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(21, 'Audit_PatientAudit', 'UserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(22, 'Audit_RegistrationAudit', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(23, 'Audit_RegistrationAudit', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(24, 'Audit_RegistrationAudit', 'UserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(25, 'CareRecord_Consultation', 'AppointmentSlotGuid', 'Appointment_Slot', 'SlotGuid'),
(26, 'CareRecord_Consultation', 'ClinicianUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(27, 'CareRecord_Consultation', 'ConsultationSourceCodeId', 'Coding_ClinicalCode', 'CodeId'),
(28, 'CareRecord_Consultation', 'EnteredByUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(29, 'CareRecord_Consultation', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(30, 'CareRecord_Consultation', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(31, 'CareRecord_Diary', 'ClinicianUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(32, 'CareRecord_Diary', 'CodeId', 'Coding_ClinicalCode', 'CodeId'),
(33, 'CareRecord_Diary', 'ConsultationGuid', 'CareRecord_Consultation', 'ConsultationGuid'),
(34, 'CareRecord_Diary', 'EnteredByUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(35, 'CareRecord_Diary', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(36, 'CareRecord_Diary', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(37, 'CareRecord_Observation', 'ClinicianUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(38, 'CareRecord_Observation', 'CodeId', 'Coding_ClinicalCode', 'CodeId'),
(39, 'CareRecord_Observation', 'ConsultationGuid', 'CareRecord_Consultation', 'ConsultationGuid'),
(40, 'CareRecord_Observation', 'EnteredByUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(41, 'CareRecord_Observation', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(42, 'CareRecord_Observation', 'ParentObservationGuid', 'CareRecord_Observation', 'ObservationGuid'),
(43, 'CareRecord_Observation', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(44, 'CareRecord_Observation', 'ProblemGuid', 'CareRecord_Problem', 'ObservationGuid'),
(45, 'CareRecord_ObservationReferral', 'ObservationGuid', 'CareRecord_Observation', 'ObservationGuid'),
(46, 'CareRecord_ObservationReferral', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(47, 'CareRecord_ObservationReferral', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(48, 'CareRecord_ObservationReferral', 'ReferralClosureReasonCodeId', 'Coding_ClinicalCode', 'CodeId'),
(49, 'CareRecord_ObservationReferral', 'ReferralReasonCodeId', 'Coding_ClinicalCode', 'CodeId'),
(50, 'CareRecord_ObservationReferral', 'ReferralSourceOrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(51, 'CareRecord_ObservationReferral', 'ReferralTargetOrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(52, 'CareRecord_ObservationReferral', 'ReferringCareProfessionalStaffGroupCodeId', 'Coding_ClinicalCode', 'CodeId'),
(53, 'CareRecord_Problem', 'LastReviewUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(54, 'CareRecord_Problem', 'ObservationGuid', 'CareRecord_Observation', 'ObservationGuid'),
(55, 'CareRecord_Problem', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(56, 'CareRecord_Problem', 'ParentProblemObservationGuid', 'CareRecord_Problem', 'ObservationGuid'),
(57, 'CareRecord_Problem', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(58, 'Prescribing_DrugRecord', 'ClinicianUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(59, 'Prescribing_DrugRecord', 'CodeId', 'Coding_DrugCode', 'CodeId'),
(60, 'Prescribing_DrugRecord', 'EnteredByUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(61, 'Prescribing_DrugRecord', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(62, 'Prescribing_DrugRecord', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(63, 'Prescribing_DrugRecord', 'ProblemObservationGuid', 'CareRecord_Problem', 'ObservationGuid'),
(64, 'Prescribing_IssueRecord', 'ClinicianUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(65, 'Prescribing_IssueRecord', 'CodeId', 'Coding_DrugCode', 'CodeId'),
(66, 'Prescribing_IssueRecord', 'DrugRecordGuid', 'Prescribing_DrugRecord', 'DrugRecordGuid'),
(67, 'Prescribing_IssueRecord', 'EnteredByUserInRoleGuid', 'Admin_UserInRole', 'UserInRoleGuid'),
(68, 'Prescribing_IssueRecord', 'OrganisationGuid', 'Admin_Organisation', 'OrganisationGuid'),
(69, 'Prescribing_IssueRecord', 'PatientGuid', 'Admin_Patient', 'PatientGuid'),
(70, 'Prescribing_IssueRecord', 'ProblemObservationGuid', 'CareRecord_Problem', 'ObservationGuid'),
(71, 'Coding_ClinicalCode', 'ParentCodeId', 'Coding_ClinicalCode', 'CodeId'),
(72, 'Admin_Patient', 'ExternalUsualGPGuid', 'Admin_UserInRole', 'UserInRoleGuid')
