--
-- This function checks if the geometry is simple.
--
CREATE FUNCTION _omtg_isSimpleGeometry(geom geometry) RETURNS BOOLEAN AS $$
BEGIN
   IF NOT ST_IsSimple(geom) THEN
      RAISE EXCEPTION 'OMT-G integrity constraint violation.'
         USING DETAIL = 'Geometry has anomalous geometric points, such as self intersection or self tangency.';
   END IF;

    RETURN 'TRUE';
END;
$$  LANGUAGE plpgsql;



--
-- This function checks if the geometry is a triangle.
--
CREATE FUNCTION _omtg_isTriangle(geom geometry) RETURNS BOOLEAN AS $$
BEGIN
   IF ST_NPoints(geom) != 4 THEN
      RAISE EXCEPTION 'OMT-G integrity constraint violation.'
         USING DETAIL = 'Geometry is not a triangle.';
   END IF;

    RETURN 'TRUE';
END;
$$  LANGUAGE plpgsql;



--
-- This function returns the name of the column given its type.
--
CREATE FUNCTION _omtg_getGeomColumnName(tbl regclass, omtgClass text) RETURNS TEXT AS $$
DECLARE
   geoms text array;
BEGIN

   geoms := array(
      SELECT attname::text AS type
      FROM pg_attribute
      WHERE  attrelid = tbl AND attnum > 0 AND NOT attisdropped AND format_type(atttypid, atttypmod) = omtgClass
   );

   IF array_length(geoms, 1) < 1 THEN
      RAISE EXCEPTION 'OMT-G extension error at _omtg_getGeomColumnName'
         USING DETAIL = 'Table has no column with the given OMT-G domain.';
   ELSIF array_length(geoms, 1) > 1 THEN
      RAISE EXCEPTION 'OMT-G extension error at _omtg_getGeomColumnName'
         USING DETAIL = 'Table has multiple columns with the given OMT-G domain.';
   END IF;

   RETURN geoms[1];
END;
$$  LANGUAGE plpgsql;



--
-- This function returns the name of the column given its type.
--
CREATE FUNCTION _omtg_getGeomColumnDomain(tbl regclass, cname text) RETURNS TEXT AS $$
DECLARE
   dname text;
BEGIN

   SELECT domain_name::text INTO dname
   FROM information_schema.columns
   WHERE table_name = tbl::text AND column_name = cname
   LIMIT 1;

   RETURN dname;
END;
$$  LANGUAGE plpgsql;




--
-- This function checks if the geometry is a triangle.
--
CREATE FUNCTION _omtg_isTriggerEnable(tgrname TEXT) RETURNS BOOLEAN AS $$
BEGIN
   IF EXISTS (SELECT  tgenabled
      FROM pg_trigger WHERE tgname=tgrname AND tgenabled != 'D') THEN
         RETURN 'TRUE';
   END IF;
   RETURN 'FALSE';
END;
$$  LANGUAGE plpgsql;




--
-- This function creates a domain trigger on a table
--
CREATE FUNCTION _omtg_createTriggerOnTable(tname text, omtgClass text, geomName text) RETURNS void AS $$
DECLARE
   tgrname text := tname ||'_'|| omtgClass ||'_'|| geomName ||'_trigger';
BEGIN

   -- Check if trigger already exists
   IF NOT _omtg_isTriggerEnable(tgrname) THEN

      EXECUTE 'CREATE TRIGGER '|| tgrname ||' AFTER INSERT OR UPDATE OR DELETE ON '|| tname ||'
          FOR EACH STATEMENT EXECUTE PROCEDURE _omtg_check_'|| omtgClass ||'();';

   END IF;

END;
$$  LANGUAGE plpgsql;



--
-- This function adds the right trigger to a table with a geometry omtg column.
--
CREATE FUNCTION _omtg_addClassConstraint() RETURNS event_trigger AS $$
DECLARE
    r record;
    tname text;
    omtg_column record;
    cname text;
    ctype text;
BEGIN
   FOR r IN SELECT * FROM pg_event_trigger_ddl_commands()
   LOOP
      SELECT r.object_identity::regclass INTO tname;

      -- verify that tags match
      IF r.command_tag = 'CREATE TABLE' OR r.command_tag = 'ALTER TABLE' THEN

         FOR omtg_column IN SELECT attname AS cname, format_type(atttypid, atttypmod) AS ctype
            FROM pg_attribute
            WHERE  attrelid = r.objid AND attnum > 0 AND NOT attisdropped and format_type(atttypid, atttypmod) like 'omtg_%'
         LOOP

            CASE omtg_column.ctype
               WHEN 'omtg_isoline' THEN
                  PERFORM _omtg_createTriggerOnTable(tname, 'isoline', omtg_column.cname);

               WHEN 'omtg_planarsubdivision' THEN
                  PERFORM _omtg_createTriggerOnTable(tname, 'planarsubdivision', omtg_column.cname);

               WHEN 'omtg_sample' THEN
                  PERFORM _omtg_createTriggerOnTable(tname, 'sample', omtg_column.cname);

               WHEN 'omtg_tin' THEN
                  PERFORM _omtg_createTriggerOnTable(tname, 'tin',  omtg_column.cname);

               ELSE RETURN;

            END CASE;
         END LOOP;
      END IF;
   END LOOP;
END;
$$ LANGUAGE plpgsql;



--
-- This function checks if the column is a OMTG geometry domain
--
CREATE FUNCTION _omtg_isOMTGDomain(tname regclass, cname text) RETURNS BOOLEAN AS $$
DECLARE
   cDomain TEXT := _omtg_getGeomColumnDomain(tname, cname);
   res boolean;
BEGIN

   SELECT cDomain = ANY ('{omtg_polygon, omtg_line, omtg_point, omtg_node,
      omtg_isoline, omtg_planarsubdivision, omtg_tin, omtg_tesselation,
      omtg_sambple, omtg_uniline, omtg_biline}'::text[]) into res;

   IF res THEN
      return 'TRUE';
   ELSE
      return 'FALSE';
   END IF;

END;
$$  LANGUAGE plpgsql;



--
-- This function checks if the argument text can be converted to a numeric type
--
CREATE OR REPLACE FUNCTION _omtg_isnumeric(text) RETURNS BOOLEAN AS $$
DECLARE
   x NUMERIC;
BEGIN
    x = $1::NUMERIC;
    RETURN TRUE;
EXCEPTION WHEN others THEN
    RETURN FALSE;
END;
$$  LANGUAGE plpgsql;


--
-- This function parses a trigger and extracts its information.
-- (Adapted from the work done by Jim Nasby, @see https://github.com/decibel/cat_tools)
--
CREATE OR REPLACE  FUNCTION _omtg_triggerParser(
  in trigger_oid oid,
  out timing text,
  out events text[],
  out defer text,
  out row_statement text,
  out when_clause text,
  out function_arguments text[],
  out function_name text,
  out table_name text
) AS $$
DECLARE
  r_trigger pg_catalog.pg_trigger;
  v_triggerdef text;
  v_create_stanza text;
  v_on_clause text;
  v_execute_clause text;

  v_work text;
  v_array text[];
BEGIN
   -- Do this first to make sure trigger exists
   v_triggerdef := pg_catalog.pg_get_triggerdef(trigger_oid, true);
   SELECT * INTO STRICT r_trigger FROM pg_catalog.pg_trigger WHERE oid = trigger_oid;

   v_create_stanza := format(
       'CREATE %sTRIGGER %I '
       , CASE WHEN r_trigger.tgconstraint=0 THEN '' ELSE 'CONSTRAINT ' END
       , r_trigger.tgname
   );
   -- Strip CREATE [CONSTRAINT] TRIGGER ... off
   v_work := replace( v_triggerdef, v_create_stanza, '' );

   -- Get BEFORE | AFTER | INSTEAD OF
   timing := split_part( v_work, ' ', 1 );
   timing := timing || CASE timing WHEN 'INSTEAD' THEN ' OF' ELSE '' END;

   -- Strip off timing clause
   v_work := replace( v_work, timing || ' ', '' );

   -- Get array of events (INSERT, UPDATE [OF column, column], DELETE, TRUNCATE)
   v_on_clause := ' ON ' || r_trigger.tgrelid::regclass || ' ';
   v_array := regexp_split_to_array( v_work, v_on_clause );
   events := string_to_array( v_array[1], ' OR ' );

   -- Get the name of the table that fires the trigger
   table_name := r_trigger.tgrelid::regclass;

   -- Get everything after ON table_name
   v_work := v_array[2];
   --    RAISE DEBUG 'v_work "%"', v_work;

   -- Strip off FROM referenced_table if we have it
   IF r_trigger.tgconstrrelid<>0 THEN
      v_work := replace(
         v_work
         , 'FROM ' || r_trigger.tgconstrrelid::regclass || ' '
         , ''
    );
   END IF;
   --    RAISE DEBUG 'v_work "%"', v_work;

   -- Get function name
   function_name := r_trigger.tgfoid::regproc;

   -- Get function arguments
   v_execute_clause := ' EXECUTE PROCEDURE ' || r_trigger.tgfoid::regproc || E'\\(';
   v_array := regexp_split_to_array( v_work, v_execute_clause );
   function_arguments :=  array_remove(regexp_split_to_array(rtrim( v_array[2], ')' ), '\W+'), '');

   -- Get everything prior to EXECUTE PROCEDURE ...
   v_work := v_array[1];
   --    RAISE DEBUG 'v_work "%"', v_work;

   row_statement := (regexp_matches( v_work, 'FOR EACH (ROW|STATEMENT)' ))[1];

   -- Get [ NOT DEFERRABLE | [ DEFERRABLE ] { INITIALLY IMMEDIATE | INITIALLY DEFERRED } ]
   v_array := regexp_split_to_array( v_work, 'FOR EACH (ROW|STATEMENT)' );
   --    RAISE DEBUG 'v_work = "%", v_array = "%"', v_work, v_array;
   defer := rtrim(v_array[1]);

   IF r_trigger.tgqual IS NOT NULL THEN
      when_clause := rtrim(
         (regexp_split_to_array( v_array[2], E' WHEN \\(' ))[2]
         , ')'
      );
   END IF;

   RETURN;
END;
$$  LANGUAGE plpgsql;

--
-- Convert array of text to lowercase
--
CREATE FUNCTION _omtg_arraylower(p_input text[]) RETURNS text[] AS $$
DECLARE
   el text;
   r text[];
BEGIN
   FOREACH el IN ARRAY p_input LOOP
      r := r || btrim(lower(el))::text;
   END LOOP;
   RETURN r;
END;
$$  LANGUAGE plpgsql;


--
-- Check if the operator is a valid topological relationship
--
CREATE FUNCTION _omtg_isTopologicalRelationship(operator text) RETURNS BOOLEAN AS $$
DECLARE
   tr _omtg_topologicalrelationship;
BEGIN
   tr := operator;
   RETURN TRUE;
EXCEPTION
   WHEN invalid_text_representation THEN
      RETURN FALSE;
END;
$$  LANGUAGE plpgsql;
