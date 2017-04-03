--------------------------------------------------------------------------------------------
-- installation instructions
--------------------------------------------------------------------------------------------
-- 
-- 1. create the EMISXMaster db with command below

create database EMISXMaster;

-- 
-- 2. run the script EMISXMaster_Schema.sql 
--
-- 3. install all the stored procedures in StoredProcedures directory by running the following from the command prompt
--
-- InstallStoredProcedures.bat
--
-- 4. then run:
--
-- execute CreateStagingDatabase
-- execute CreateCommonDatabase
--
