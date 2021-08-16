@echo off
set /p PGUSER="Insira o nome do usuario do PostgreSQL: "  
set /p PGPASSWORD="Insira a senha do usuario do PostgreSQL: "     
set /p PGDATABASE="Insira o nome da base de dados: "
        
echo "Habilitando extensao PostGIS"

"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\postgis.sql"

echo "Instalando extensao ast_postgis."

"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\tables.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\types.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\type_functions.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\utils.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\domain_functions.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\domains.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\relationship_triggers.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\event_triggers.sql"
"C:/Program Files/PostgreSQL/13/bin/psql.exe" -h localhost < "%~dp0\sql\consistency_functions.sql"

pause