USE Global_BI_NPrinting
GO

--TABLE CHANGES
IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME='MailSubject' AND TABLE_NAME='TaskMaster' AND TABLE_SCHEMA='NPT')
BEGIN
ALTER TABLE [NPT].[TaskMaster]
ADD MailSubject NVARCHAR(MAX)
END
GO

IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME='MailCCList' AND TABLE_NAME='TaskMaster' AND TABLE_SCHEMA='NPT')
BEGIN
ALTER TABLE [NPT].[TaskMaster]
ADD MailCCList VARCHAR(MAX)
END
GO

IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME='MailSubject' AND TABLE_NAME='TaskMaster' AND TABLE_SCHEMA='APP')
BEGIN
ALTER TABLE [APP].[TaskMaster]
ADD MailSubject NVARCHAR(MAX)
END
GO

IF NOT EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME='MailCCList' AND TABLE_NAME='TaskMaster' AND TABLE_SCHEMA='APP')
BEGIN
ALTER TABLE [APP].[TaskMaster]
ADD MailCCList VARCHAR(MAX)
END
GO

--PROCEDURE
IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.ExecuteNprintingTask') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[ExecuteNprintingTask]
END
GO

CREATE procedure [APP].[ExecuteNprintingTask]
AS
BEGIN
select distinct TM.TaskMasterID,TM.NprintingTaskID,RD.REPORTDETAILSFREQUENCYID FrequencyID,F.FrequencyName,TM.ReportFormatID,RF.ReportFormatName,TM.NextRunDate,RD.ReportDetailsReportID "ReportID",TM.TaskName
from APP.TaskMaster TM
Join APP.[ReportFormat] RF ON(RF.ReportFormatID=TM.ReportFormatID) and RF.[ReportFormatAuditFlag]<>2
join APP.REPORTDETAILS RD ON RD.ReportDetailsTaskMasterID=TM.TaskMasterID AND RD.REPORTDETAILSAUDITFLAG<>2
Join APP.[Frequency] F ON F.FrequencyID=RD.REPORTDETAILSFREQUENCYID and F.[FrequencyAuditFlag]<>2
join APP.SubscriptionMaster SM on SM.ReportDetailsID=RD.ReportDetailsID
where CONVERT (date, RD.NextRunDate)=CONVERT (date, GETDATE())
and TM.AuditFlag<>2
and SM.AuditFlag<>2
END
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.SaveEmailTaskDetail') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[SaveEmailTaskDetail]
END
GO

CREATE PROCEDURE [APP].[SaveEmailTaskDetail]
@TaskName nvarchar(50),
@AttachmentName nvarchar(100),
@Result varchar(10) output
AS
BEGIN
DECLARE @TASKID NVARCHAR(50)
SET @TASKID=(SELECT NprintingTaskID FROM [APP].[TaskMaster] WHERE TaskName=@TaskName) 
IF  @TaskID is not null
BEGIN
IF NOT EXISTS(SELECT 1 FROM APP.AttachmentRetrieval WHERE TaskID=@TaskID AND AttachmentName=@AttachmentName
AND INSERTEDDATE=GETDATE())
--AND CONVERT(DATE,INSERTEDDATE)=CONVERT(DATE,GETDATE()))
BEGIN
	INSERT INTO APP.AttachmentRetrieval(TaskID,AttachmentName,EmailFlag,InsertedDate,UpdatedDate)
	VALUES(@TaskID,@AttachmentName,0,GETDATE(),GETDATE())
	SET @Result='Email Task Detail Inserted Successfully'

END
END
END
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.GetAttachmentDetails') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[GetAttachmentDetails]
END
GO

CREATE PROCEDURE [APP].[GetAttachmentDetails]
AS
select  distinct AR.AttachmentID, TM.NPrintingTaskID TaskID,UM.UserName,TM.TaskName,TM.MailSubject,
--UM.Email_ID,
'karanjit.singh@mediaagility.com;sonali.nikarde@mediaagility.com;supriya.atkare@mediaagility.com' Email_ID,
RM.ReportName,AR.AttachmentName,RD.ReportDetailsID,TM.MailCCList MailCCList
from APP.SubscriptionMaster SM 
JOIN APP.TaskMaster TM ON SM.[TaskMasterID]=TM.TaskMasterID and TM.AuditFlag<>2
JOIN APP.AttachmentRetrieval AR ON RTRIM(LTRIM(AR.TASKID))= RTRIM(LTRIM(TM.NPrintingTaskID))
JOIN APP.ReportDetails RD ON SM.ReportDetailsID=RD.ReportDetailsID
JOIN OTIS_SUBSCRIPTION.DBO.User_INFORMATION UM ON UM.ID=SM.UserMasterID and UM.IsActive=1
JOIN APP.ReportMaster RM ON TM.ReportID=RM.ReportMasterReportID and RM.AuditFlag<>2
WHERE CONVERT(DATE,AR.INSERTEDDATE) =CONVERT(DATE,GETDATE())
AND CONVERT(DATE,RD.NextRunDate) =CONVERT(DATE,GETDATE())
AND AR.EMAILFLAG=0
AND SM.AuditFlag<>2
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.UpdateTaskEmailFlag') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[UpdateTaskEmailFlag]
END
GO

CREATE PROCEDURE [APP].[UpdateTaskEmailFlag]
@AttachmentID nvarchar(100)
AS
Insert into APP.AuditAttachmentRetrieval
([AttachmentID],[TaskID],[AttachmentName],[EmailFlag],[InsertedDate],[UpdatedDate])
select [AttachmentID],[TaskID],[AttachmentName],[EmailFlag],[InsertedDate],[UpdatedDate]
from APP.AttachmentRetrieval
where [AttachmentID]=@AttachmentID

UPDATE APP.AttachmentRetrieval
SET EMAILFLAG=1,UpdatedDate=getdate()
WHERE AttachmentID=@AttachmentID
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.UpdateNextRunDate') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[UpdateNextRunDate]
END
GO

CREATE PROCEDURE [APP].[UpdateNextRunDate]
@ReportDetailsID int
AS
DECLARE @FREQUENCYID INT,@NEXTRUNDATE DATETIME,@NEXTRUNDATE_NEW DATETIME

SELECT @FREQUENCYID=ReportDetailsFrequencyID,@NEXTRUNDATE=NEXTRUNDATE
FROM [APP].[ReportDetails] WHERE ReportDetailsID=@ReportDetailsID
PRINT @FREQUENCYID 
PRINT @NEXTRUNDATE

SET @NEXTRUNDATE_NEW=(CASE 
WHEN @FREQUENCYID=1 THEN @NEXTRUNDATE
WHEN @FREQUENCYID=2 THEN DATEADD(dd,1,@NEXTRUNDATE)
WHEN @FREQUENCYID=3 THEN DATEADD(dd,7,@NEXTRUNDATE)
WHEN @FREQUENCYID=4 THEN DATEADD(dd,14,@NEXTRUNDATE)
WHEN @FREQUENCYID=5 THEN DATEADD(dd,30,@NEXTRUNDATE)
WHEN @FREQUENCYID=6 THEN DATEADD(dd,90,@NEXTRUNDATE)
WHEN @FREQUENCYID=7 THEN DATEADD(dd,365,@NEXTRUNDATE)
END)

UPDATE [APP].[ReportDetails]
SET NEXTRUNDATE=@NEXTRUNDATE_NEW WHERE ReportDetailsID=@ReportDetailsID
GO

IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'APP.SynchNPrintingDataToAPP') AND type IN ( N'P', N'PC' ))
BEGIN
DROP PROCEDURE [APP].[SynchNPrintingDataToAPP]
END
GO

CREATE PROCEDURE [APP].[SynchNPrintingDataToAPP]

AS

BEGIN

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportMasterID') AND parent_object_id = OBJECT_ID(N'APP.SubscriptionMaster'))
BEGIN
ALTER TABLE [APP].[SubscriptionMaster] DROP CONSTRAINT [FK_ReportMasterID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_TaskMasterID') AND parent_object_id = OBJECT_ID(N'APP.SubscriptionMaster'))
BEGIN
ALTER TABLE [APP].[SubscriptionMaster] DROP CONSTRAINT [FK_TaskMasterID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_FrequencyID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_FrequencyID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportFormatID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_ReportFormatID]
END

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'APP.FK_ReportID') AND parent_object_id = OBJECT_ID(N'APP.TaskMaster'))
BEGIN
ALTER TABLE [APP].[TaskMaster] DROP CONSTRAINT [FK_ReportID]
END

truncate table [APP].[SubscriptionMaster]
truncate table [APP].[ReportDetails]

-- Insert into [APP].[ReportModule] 
Truncate table [APP].[ReportModule] 
  Insert into [APP].[ReportModule] 
 select distinct  nptrpt.ModuleName,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate  
 from [NPT].[ReportMaster] nptrpt 


 --  Insert into [APP].[ReportFormat] 
Truncate table [APP].[ReportFormat]  
  Insert into [APP].[ReportFormat] 
 select  distinct npttskdetailmap.FormatName,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate  
 from [NPT].[TaskDetailsMapping] npttskdetailmap 

 TRUNCATE TABLE APP.AdminReportDetails
 INSERT INTO APP.AdminReportDetails
 SELECT 'UTCCGL\ABHISHF' AS ADMINREPORTADMINID,REPORTMASTERREPORTID AS ADMINREPORTREPORTID,0,GETDATE(),GETDATE()
 FROM [APP].[ReportMaster]

 --  Insert into [APP].[ReportMaster] 
 Truncate table [APP].[ReportMaster] 
  Insert into [APP].[ReportMaster] 
 select  nptrpt.ReportName,nptrpt.ReportID,rptModule.ReportModuleID,0 as AuditFlag,getdate() as InsertedDate, getdate() as UpdatedDate,
 null,nptrpt.LEVEL AS REPORTLEVEL,nptrpt.COMPANYNAME
 from [NPT].[ReportMaster] nptrpt 
 left join  [APP].[ReportModule] rptModule on rptModule.ReportModuleName=nptrpt.ModuleName


--insert into [APP].[TaskMaster] 
Truncate table [APP].[TaskMaster]
Insert into [APP].[TaskMaster] 
 select distinct  npttsk.NprintingTaskID,rptmaster.ReportMasterReportID,3 as FrequencyID,apprptfrmt.ReportFormatID,
 getdate() as NextRunDate,0 as AuditFlag,getdate() as InsertedDate,getdate() as UpdatedDate , npttsk.TaskName, npttsk.MailSubject,npttsk.MailCCList
 FROM [NPT].[TaskMaster] npttsk
 left join [NPT].[TaskDetailsMapping] npttskdetailmap on npttskdetailmap.NprintingTaskID=npttsk.NprintingTaskID
 left join [APP].[ReportMaster] rptmaster on  rptmaster.NprintingReportID=npttskdetailmap.NprintReportID
 left join [APP].[ReportFormat] apprptfrmt on apprptfrmt.ReportFormatName= npttskdetailmap.FormatName


 
ALTER TABLE [APP].[SubscriptionMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportMasterID] FOREIGN KEY([ReportMasterID])
REFERENCES [APP].[ReportMaster] ([ReportMasterReportID])

ALTER TABLE [APP].[SubscriptionMaster] CHECK CONSTRAINT [FK_ReportMasterID]

ALTER TABLE [APP].[SubscriptionMaster]  WITH CHECK ADD  CONSTRAINT [FK_TaskMasterID] FOREIGN KEY([TaskMasterID])
REFERENCES [APP].[TaskMaster] ([TaskMasterID])

ALTER TABLE [APP].[SubscriptionMaster] CHECK CONSTRAINT [FK_TaskMasterID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_FrequencyID] FOREIGN KEY([FrequencyID])
REFERENCES [APP].[Frequency] ([FrequencyID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_FrequencyID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportFormatID] FOREIGN KEY([ReportFormatID])
REFERENCES [APP].[ReportFormat] ([ReportFormatID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_ReportFormatID]

ALTER TABLE [APP].[TaskMaster]  WITH CHECK ADD  CONSTRAINT [FK_ReportID] FOREIGN KEY([ReportID])
REFERENCES [APP].[ReportMaster] ([ReportMasterReportID])

ALTER TABLE [APP].[TaskMaster] CHECK CONSTRAINT [FK_ReportID]
END
GO

-- SCRIPT FOR MAIL SUBJECT FROM SRC TO TARGET
UPDATE TRGT
SET TRGT.MailSubject=SRC.MailSubject
FROM NPT.TASKMASTER SRC
JOIN APP.TASKMASTER TRGT ON SRC.NprintingTaskID=TRGT.NprintingTaskID





