--
-- This function checks if the geometry is simple.
--
CREATE FUNCTION _ast_isSimpleGeometry(geom geometry) RETURNS BOOLEAN AS $$
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
CREATE FUNCTION _ast_isTriangle(geom geometry) RETURNS BOOLEAN AS $$
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
CREATE FUNCTION _ast_getGeomColumnName(tbl regclass, omtgClass text) RETURNS TEXT AS $$
DECLARE
   geoms text array;
BEGIN

   geoms := array(
      SELECT attname::text AS type
      FROM pg_attribute
      WHERE  attrelid = tbl AND attnum > 0 AND NOT attisdropped AND format_type(atttypid, atttypmod) = omtgClass
   );

   IF array_length(geoms, 1) < 1 THEN
      RAISE EXCEPTION 'OMT-G extension error at _ast_getGeomColumnName'
         USING DETAIL = 'Table has no column with the given OMT-G domain.';
   ELSIF array_length(geoms, 1) > 1 THEN
      RAISE EXCEPTION 'OMT-G extension error at _ast_getGeomColumnName'
         USING DETAIL = 'Table has multiple columns with the given OMT-G domain.';
   END IF;

   RETURN geoms[1];
END;
$$  LANGUAGE plpgsql;



--
-- This function checks if the geometry is a triangle.
--
CREATE FUNCTION _ast_isTriggerEnable(tgrname TEXT) RETURNS BOOLEAN AS $$
BEGIN
   IF EXISTS (SELECT  tgenabled
      FROM pg_trigger WHERE tgname=tgrname AND tgenabled != 'D') THEN
         RETURN 'TRUE';
   END IF;
   RETURN 'FALSE';
END;
$$  LANGUAGE plpgsql;



--
-- This function checks if the argument text can be converted to a numeric type
--
CREATE OR REPLACE FUNCTION _ast_isnumeric(text) RETURNS BOOLEAN AS $$
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
CREATE OR REPLACE  FUNCTION _ast_triggerParser(
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
   v_execute_clause := ' EXECUTE FUNCTION ' || r_trigger.tgfoid::regproc || E'\\(';
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
CREATE FUNCTION _ast_arraylower(p_input text[]) RETURNS text[] AS $$
DECLARE
   el text;
   r text[];
BEGIN
   IF p_input IS NULL THEN
      RETURN NULL;
   END IF;

   FOREACH el IN ARRAY p_input LOOP
      r := r || btrim(lower(el))::text;
   END LOOP;
   RETURN r;
END;
$$  LANGUAGE plpgsql;



--
-- This function returns the primary key column name.
-- Returns only the first column of composite keys.
--
CREATE FUNCTION _ast_getPrimaryKeyColumn(tname text) RETURNS text AS $$
DECLARE
   cname text;
BEGIN

   EXECUTE 'SELECT a.attname
   FROM   pg_index i
   JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
   WHERE  i.indrelid = '''|| tname ||'''::regclass
   AND    i.indisprimary;' into cname;

   IF char_length(cname) > 0 THEN
      return cname;
   else
      return '';
   END IF;

END;
$$  LANGUAGE plpgsql;
