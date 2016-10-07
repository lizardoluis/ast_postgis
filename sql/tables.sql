--
-- Spatial error log table
--
CREATE TABLE ast_violation_log (
   time timestamp,
   type VARCHAR(50),
   description VARCHAR(150)
);

--
-- Mark the ast_violation table as a configuration table, which will cause
-- pg_dump to include the table's contents (not its definition) in dumps.
--
SELECT pg_catalog.pg_extension_config_dump('ast_violation_log', '');
