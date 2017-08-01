@ECHO OFF

echo.
echo.
echo ====BULK INSTALL from %1=====
echo This batch file generates the SQL used to load ALL extracts
echo from one of the SFTP servers
echo.
echo "Usage: BulkInstall.bat <sftp folder>"
echo e.g.   BulkInstall.bat E:\Shares\Endeavour\sftpreader\EMIS004
echo.
echo.

for /f "tokens=*" %%G in ('dir /b /a:d /o:n "%1"') do (
	for /f "tokens=*" %%H in ('dir /b "%1\%%G\*Admin_Location*.csv"') do (
		echo execute StageExtract '%1\%%G', '%%H'
		echo execute InstallExtract
		echo.
	)
)
