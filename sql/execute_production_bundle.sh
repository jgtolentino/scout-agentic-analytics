#!/bin/bash
echo "Executing Scout Analytics Production Bundle..."
sqlcmd -S sqltbwaprojectscoutserver.database.windows.net -d SQL-TBWA-ProjectScout-Reporting-Prod -U sqladmin -P Azure_pw26 -i create_production_views_fixed.sql
echo "Done."