@echo off

set CURRENT_DIR=%~dp0

for /d %%G in (*) do (

cd %%G

for %%H in (*Admin_Location*.csv) do (

echo execute StageExtract '%CURRENT_DIR%%%G\', '%%H'>>"..\InstallCsv.sql"
echo execute InstallExtract>>"..\InstallCsv.Sql"
echo.>>"..\InstallCsv.sql"

)

cd ..

)
pause
