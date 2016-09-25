--
-- This function returns the name of the column given its type.
--
CREATE FUNCTION _omtg_createOnDeleteTriggerOnTable(tgrname text, tname text, procedure text) RETURNS void AS $$
BEGIN
   -- Check if trigger already exists
   IF NOT _omtg_isTriggerEnable(tgrname) THEN
      -- Suspend event trigger to avoid loop
      EXECUTE 'ALTER EVENT TRIGGER omtg_validate_triggers DISABLE;';

      EXECUTE 'CREATE TRIGGER '|| tgrname ||' AFTER DELETE ON '|| tname ||'
          FOR EACH STATEMENT EXECUTE PROCEDURE '|| procedure ||';';

      --RAISE NOTICE 'Trigger created AFTER DELETE on table % with % procedure.', tname, procedure;

      -- Enable event trigger again
      EXECUTE 'ALTER EVENT TRIGGER omtg_validate_triggers ENABLE;';
   END IF;

END;
$$  LANGUAGE plpgsql;


--
-- This function adds the right trigger to a table with a geometry omtg column.
--
CREATE FUNCTION _omtg_validateTriggers() RETURNS event_trigger AS $$
DECLARE
   r record;
   events text[];
   function_arguments text[];
   function_name text;
   row_statement text;
   timing text;
   table_name text;

   arc_domain text;
   node_domain text;

   on_tbl text;
BEGIN
   FOR r IN SELECT * FROM pg_event_trigger_ddl_commands()
   LOOP

        -- verify that tags match
      IF r.command_tag = 'CREATE TRIGGER' THEN

         timing := (_omtg_triggerParser(r.objid)).timing;
         function_name := (_omtg_triggerParser(r.objid)).function_name;
         row_statement := (_omtg_triggerParser(r.objid)).row_statement;
         function_arguments := (_omtg_triggerParser(r.objid)).function_arguments;
         table_name := (_omtg_triggerParser(r.objid)).table_name;
         events := _omtg_arraylower((_omtg_triggerParser(r.objid)).events);

         -- trigger must be fired after an statement
         IF timing != 'AFTER' or row_statement != 'STATEMENT'  THEN
            RAISE EXCEPTION 'OMT-G error on trigger %.', r.object_identity
               USING DETAIL = 'Trigger must be fired AFTER a STATEMENT.';
         END IF;

         CASE function_name

            WHEN 'omtg_arcarcnetwork' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 2 THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: omtg_arcarcnetwork(''arc_tbl'', ''arc_geom'').';
               END IF;

               -- table that fired the trigger must be the same of the parameter
               IF function_arguments[1] != table_name THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Table associated with the trigger must be passed in the first parameter. Usage: omtg_arcarcnetwork(''arc_table'', ''arc_geometry'').';
               END IF;

               -- domain must be an arc
               arc_domain := _omtg_getGeomColumnDomain(function_arguments[1], function_arguments[2]);
               IF arc_domain != 'omtg_uniline' AND arc_domain != 'omtg_biline' THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table passed as parameter does not contain an arc geometry (omtg_uniline or omtg_biline).';
               END IF;

               -- trigger events must be insert, delete and update
               IF not events @> '{insert}' or not events @> '{delete}' or not events @> '{update}' THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'ARC-ARC trigger events must be INSERT OR UPDATE OR DELETE.';
               END IF;


            WHEN 'omtg_arcnodenetwork' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 4 THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: omtg_arcnodenetwork(''arc_tbl'', ''arc_geom'', ''node_tbl'', ''node_geom'').';
               END IF;

               -- domain must be arc and node
               arc_domain := _omtg_getGeomColumnDomain(function_arguments[1], function_arguments[2]);
               node_domain := _omtg_getGeomColumnDomain(function_arguments[3], function_arguments[4]);
               IF node_domain != 'omtg_node' OR (arc_domain != 'omtg_uniline' AND arc_domain != 'omtg_biline' ) THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Arc table must heve OMTG_UNILINE or OMTG_BILINE geometry. Node table must have OMTG_NODE geometry.';
               END IF;

               IF table_name != function_arguments[1] AND table_name != function_arguments[3] THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table that fires the trigger must be passed through the procedure parameters.';
               END IF;

               -- only insert or update
               IF (not events @> '{insert}' or not events @> '{update}' or events @> '{delete}') THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'ARC-NODE trigger events must be INSERT OR UPDATE.';
               END IF;

               IF table_name = function_arguments[1] THEN
                  -- create trigger on delete on node
                  on_tbl := function_arguments[3];
               ELSE
                  -- create trigger on delete on arc
                  on_tbl := function_arguments[1];
               END IF;

               PERFORM _omtg_createOnDeleteTriggerOnTable(
                  split_part(r.object_identity, ' ', 1) ||'_auto',
                  on_tbl,
                  'omtg_arcnodenetwork('|| function_arguments[1] ||', '|| function_arguments[2] ||', '|| function_arguments[3] ||', '|| function_arguments[4] ||')'
               );


            WHEN 'omtg_topologicalrelationship' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 5 OR NOT _omtg_isOMTGDomain(function_arguments[1], function_arguments[2]) OR NOT _omtg_isOMTGDomain(function_arguments[3], function_arguments[4]) THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: omtg_topologicalrelationship(''a_tbl'', ''a_geom'', ''b_tbl'', ''b_geom'', ''operator/distance'').';
               END IF;

               IF NOT _omtg_isnumeric(function_arguments[5]) AND NOT _omtg_isTopologicalRelationship(function_arguments[5]) THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: omtg_topologicalrelationship(''a_tbl'', ''a_geom'', ''b_tbl'', ''b_geom'', ''operator/distance'').';
               END IF;

               IF table_name != function_arguments[1] AND table_name != function_arguments[3] THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table that fires the trigger must be passed as the first procedure parameter.';
               END IF;

               -- only insert or update
               IF (not events @> '{insert}' or not events @> '{update}' or events @> '{delete}') THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'TOPOLOGICAL RELATIONSHIP trigger events must be INSERT OR UPDATE.';
               END IF;

               PERFORM _omtg_createOnDeleteTriggerOnTable(
                  split_part(r.object_identity, ' ', 1) ||'_auto',
                  function_arguments[3],
                  'omtg_topologicalrelationship('|| function_arguments[1] ||', '|| function_arguments[2] ||', '|| function_arguments[3] ||', '|| function_arguments[4] ||', '|| function_arguments[5] ||')'
               );

            WHEN 'omtg_aggregation' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 4 OR NOT _omtg_isOMTGDomain(function_arguments[1], function_arguments[2]) OR NOT _omtg_isOMTGDomain(function_arguments[3], function_arguments[4]) THEN
                  RAISE EXCEPTION 'OMT-G error at AGGREGATION constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: omtg_aggregation(''part_tbl'', ''part_geom'', ''whole_tbl'', ''whole_geom'').';
               END IF;

               IF table_name != function_arguments[1] THEN
                  RAISE EXCEPTION 'OMT-G error at AGGREGATION constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Part table that fires the trigger must be passed as the first procedure parameter.';
               END IF;

               IF (not events @> '{insert}' or not events @> '{update}' or not events @> '{delete}') THEN
                  RAISE EXCEPTION 'OMT-G error at AGGREGATION constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'AGGREGATION trigger events must be INSERT OR UPDATE OR DELETE.';
               END IF;

            ELSE RETURN;

         END CASE;

      END IF;
   END LOOP;
END;
$$ LANGUAGE plpgsql;
