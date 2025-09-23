@echo off
echo Executing Scout Analytics Production Bundle...
sqlcmd -S sql-tbwa-projectscout-reporting-prod.database.windows.net -d SQL-TBWA-ProjectScout-Reporting-Prod -U sqladmin -P Azure_pw26 -i create_production_views.sql
echo Done.
pause