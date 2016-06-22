--
-- Event trigger to add constraints automatic to tables with OMT-G types
--
CREATE EVENT TRIGGER omtg_add_class_constraint_trigger
   ON ddl_command_end
   WHEN tag IN ('create table', 'alter table')
   EXECUTE PROCEDURE _omtg_addClassConstraint();
