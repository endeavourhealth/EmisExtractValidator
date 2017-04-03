@echo off

echo Install stored procedures

sqlcmd /S localhost -E -i"StoredProcs-Utils/PrintMsg.sql"



for %%G in (StoredProcs-Utils/*.sql) do sqlcmd /S localhost -E -i"StoredProcs-Utils/%%G"
for %%G in (StoredProcs-Core-Helpers/*.sql) do sqlcmd /S localhost -E -i"StoredProcs-Core-Helpers/%%G"
for %%G in (StoredProcs-Core/*.sql) do sqlcmd /S localhost -E -i"StoredProcs-Core/%%G"
for %%G in (StoredProcs-Validation/*.sql) do sqlcmd /S localhost -E -i"StoredProcs-Validation/%%G"

pause
