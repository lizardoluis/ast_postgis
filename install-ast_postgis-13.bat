@echo off
set /p PGUSER="Insert the username for PostgreSQL: "  
set /p PGPASSWORD="Insert the password for PostgreSQL: "     
set /p PGDATABASE="Insert the schema name to each ast_postgis should be installed: "

        
echo "Enabling the extension PostGIS"

"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\postgis.sql"

echo "Installing the ast_postgis."

"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\tables.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\types.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\type_functions.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\utils.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\domain_functions.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\domains.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\relationship_triggers.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\event_triggers.sql"
"C:/Program Files/PostgreSQL/15/bin/psql.exe" -h localhost < "%~dp0\sql\consistency_functions.sql"

pause