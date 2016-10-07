--
-- Event trigger to add constraints automatic to tables with OMT-G types
--
CREATE EVENT TRIGGER ast_add_class_constraint_trigger
   ON ddl_command_end
   WHEN tag IN ('create table', 'alter table')
   EXECUTE PROCEDURE _ast_addClassConstraint();



--
-- Event trigger to validate user triggers
--
CREATE EVENT TRIGGER ast_validate_triggers
   ON ddl_command_end
   WHEN tag IN ('create trigger')
   EXECUTE PROCEDURE _ast_validateTrigger();
