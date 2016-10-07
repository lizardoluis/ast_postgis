--
-- Spatial error log table
--
CREATE TABLE omtg_violation_log (
   time timestamp,
   type VARCHAR(50),
   description VARCHAR(150)
);

--
-- Mark the omtg_violation table as a configuration table, which will cause
-- pg_dump to include the table's contents (not its definition) in dumps.
--
SELECT pg_catalog.pg_extension_config_dump('omtg_violation_log', '');
CREATE TYPE _omtg_topologicalrelationship AS ENUM
(
    'contains',
    'containsproperly',
    'covers',
    'coveredby',
    'crosses',
    'disjoint',
    'intersects',
    'overlaps',
    'touches',
    'within'
);
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
-- This function returns the primary key column name.
-- Returns only the first column of composite keys.
--
CREATE FUNCTION _omtg_getPrimaryKeyColumn(tname text) RETURNS text AS $$
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
-- Isoline
--
CREATE FUNCTION _omtg_check_isoline() RETURNS TRIGGER AS $$
   DECLARE
      res BOOLEAN;
      tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
      cgeom CONSTANT TEXT := _omtg_getGeomColumnName(tbl, 'omtg_isoline');
   BEGIN

      -- Checks if isolines are disjoint
      EXECUTE 'SELECT EXISTS (
         SELECT 1
         FROM '|| tbl ||' AS t1, '|| tbl ||' AS t2
         WHERE t1.CTID < t2.CTID AND NOT
         ST_Disjoint(t1.'|| cgeom ||', t2.'|| cgeom ||')
      )' into res;

      IF res THEN
      	RAISE EXCEPTION 'OMT-G Isolines integrity constraint violation.'
      		USING DETAIL = 'Isolines must be disjoint from each other.';
      END IF;

      RETURN NULL; -- result is ignored since this is an AFTER trigger
   END;
$$ LANGUAGE plpgsql;



--
-- Planar Subdivision
--
CREATE FUNCTION _omtg_check_planarsubdivision() RETURNS TRIGGER AS $$
   DECLARE
      res BOOLEAN;
      tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
      cgeom CONSTANT TEXT := _omtg_getGeomColumnName(tbl, 'omtg_planarsubdivision');
   BEGIN
      -- Checks for overlaps
      EXECUTE 'SELECT EXISTS (
         SELECT 1
         FROM '|| tbl ||' as t1, '|| tbl ||' as t2
         WHERE t1.CTID < t2.CTID AND
            NOT ST_Touches(t1.'|| cgeom ||', t2.'|| cgeom ||') AND
            NOT ST_Disjoint(t1.'|| cgeom ||', t2.'|| cgeom ||')
      )' into res;

      IF res THEN
			RAISE EXCEPTION 'OMT-G Planar Subdivision integrity constraint violation.'
		      USING DETAIL = 'Planar Subdivision polygons cannot have overlaps.';
      END IF;

      RETURN NULL; -- result is ignored since this is an AFTER trigger

   END;
$$ LANGUAGE plpgsql;



--
-- Sample
--
CREATE FUNCTION _omtg_check_sample() RETURNS TRIGGER AS $$
   DECLARE
      res BOOLEAN;
      tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
      cgeom CONSTANT TEXT := _omtg_getGeomColumnName(tbl, 'omtg_sample');
   BEGIN

      -- Checks for overlaps
      EXECUTE 'SELECT EXISTS (
         SELECT 1
         FROM '|| tbl ||' as t1, '|| tbl ||' as t2
         WHERE t1.CTID < t2.CTID AND
            ST_Intersects(t1.'|| cgeom ||', t2.'|| cgeom ||')
      )' into res;

      IF res THEN
   		RAISE EXCEPTION 'OMT-G Sample integrity constraint violation.'
   			USING DETAIL = 'Sample points cannot have overlaps.';
      END IF;

      RETURN NULL; -- result is ignored since this is an AFTER trigger

   END;
$$ LANGUAGE plpgsql;



--
-- TIN
--
CREATE FUNCTION _omtg_check_tin() RETURNS TRIGGER AS $$
   DECLARE
      res BOOLEAN;
      tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
      cgeom CONSTANT TEXT := _omtg_getGeomColumnName(tbl, 'omtg_tin');
   BEGIN

      -- Checks for overlaps
      EXECUTE 'SELECT EXISTS (
         SELECT 1
         FROM '|| tbl ||' as t1, '|| tbl ||' as t2
         WHERE t1.CTID < t2.CTID AND
            NOT ST_Touches(t1.'|| cgeom ||', t2.'|| cgeom ||') AND
            NOT ST_Disjoint(t1.'|| cgeom ||', t2.'|| cgeom ||')
      )' into res;

      IF res THEN
			RAISE EXCEPTION 'OMT-G TIN integrity constraint violation.'
				USING DETAIL = 'TIN polygons must be triangles and cannot contain overlaps.';
      END IF;

      RETURN NULL; -- result is ignored since this is an AFTER trigger
   END;
$$ LANGUAGE plpgsql;



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
-- Polygon
--
create domain OMTG_POLYGON as GEOMETRY(POLYGON)
    constraint simple_polygon_constraint check (_omtg_isSimpleGeometry(VALUE));

--
-- Line
--
create domain OMTG_LINE as GEOMETRY(LINESTRING)
    constraint simple_line_constraint check (_omtg_isSimpleGeometry(VALUE));

--
-- Point
--
create domain OMTG_POINT as GEOMETRY(POINT);

--
-- Node
--
create domain OMTG_NODE as GEOMETRY(POINT);

--
-- Isoline
--
create domain OMTG_ISOLINE as GEOMETRY(LINESTRING)
    constraint simple_isoline_constraint check (_omtg_isSimpleGeometry(VALUE));

--
-- Planar subdivision
--
create domain OMTG_PLANARSUBDIVISION as GEOMETRY(POLYGON)
    constraint simple_planarsubdivision_constraint check (_omtg_isSimpleGeometry(VALUE));
--
-- TIN
--
create domain OMTG_TIN as GEOMETRY(POLYGON)
    constraint simple_tin_constraint check (_omtg_isSimpleGeometry(VALUE))
    constraint triangle_tin_constraint check (_omtg_isTriangle(VALUE));

--
-- Tesselation
--
create domain OMTG_TESSELATION as RASTER;

--
-- Sample
--
create domain OMTG_SAMPLE as GEOMETRY(POINT);

--
-- Unidirectional Line
--
create domain OMTG_UNILINE as GEOMETRY(LINESTRING)
    constraint simple_uniline_constraint check (_omtg_isSimpleGeometry(VALUE));

--
-- Bidirectional Line
--
create domain OMTG_BILINE as GEOMETRY(LINESTRING)
    constraint simple_biline_constraint check (_omtg_isSimpleGeometry(VALUE));
--
-- Arc-Node relationship. Check if arcs are valid
--
CREATE FUNCTION _omtg_arcnodenetwork_onarc(arc regclass, node regclass, ageom text, ngeom text)
RETURNS BOOLEAN AS $$
   DECLARE
      res BOOLEAN;
      a_geom CONSTANT TEXT := quote_ident(ageom);
      n_geom CONSTANT TEXT := quote_ident(ngeom);
   BEGIN

      -- Checks if for each arc there are at least 2 nodes.
      EXECUTE 'WITH Points AS (
            SELECT ST_StartPoint('|| a_geom ||') AS point FROM '|| arc ||'
               UNION
            SELECT ST_EndPoint('|| a_geom ||') AS point FROM '|| arc ||'
         )
         SELECT NOT EXISTS(
            SELECT 1 FROM Points AS P
            LEFT JOIN '|| node ||' AS N ON ST_INTERSECTS(P.point, N.'|| n_geom ||') WHERE N.'|| n_geom ||' IS NULL
      )' INTO res;

      RETURN res;
   END;
$$ LANGUAGE plpgsql;



--
-- Arc-Node relationship. Check if nodes are valid
--
CREATE FUNCTION _omtg_arcnodenetwork_onnode(arc regclass, node regclass, ageom text, ngeom text)
RETURNS BOOLEAN AS $$
   DECLARE
      res BOOLEAN;
      a_geom CONSTANT TEXT := quote_ident(ageom);
      n_geom CONSTANT TEXT := quote_ident(ngeom);
   BEGIN

      -- Checks if for each node, there is at least one arc.
      EXECUTE 'WITH Points AS (
            SELECT ST_StartPoint('|| a_geom ||') AS point FROM '|| arc ||'
               UNION
            SELECT ST_EndPoint('|| a_geom ||') AS point FROM '|| arc ||'
         )
         SELECT NOT EXISTS(
            SELECT 1 FROM '|| node ||' AS N
            LEFT JOIN Points AS P ON ST_INTERSECTS(N.'|| n_geom ||', P.point) = TRUE WHERE P.point IS NULL
      )' INTO res;

      RETURN res;
   END;
$$ LANGUAGE plpgsql;



--
-- Arc-Node network.
--
CREATE FUNCTION omtg_arcnodenetwork() RETURNS TRIGGER AS $$
DECLARE
   arc_tbl CONSTANT REGCLASS := TG_ARGV[0];
   arc_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   node_tbl CONSTANT REGCLASS := TG_ARGV[2];
   node_geom CONSTANT TEXT := quote_ident(TG_ARGV[3]);

   arc_domain CONSTANT TEXT := _omtg_getGeomColumnDomain(arc_tbl, arc_geom);
   node_domain CONSTANT TEXT := _omtg_getGeomColumnDomain(node_tbl, node_geom);

BEGIN

   -- Validate trigger settings
   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

    -- Validate input parameters
   IF TG_NARGS != 4 OR node_domain != 'omtg_node' OR (arc_domain != 'omtg_uniline' AND arc_domain != 'omtg_biline' ) THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
         USING DETAIL = 'Invalid parameters.';
   END IF;


   IF TG_OP = 'INSERT' OR TG_OP ='UPDATE' THEN

      -- Check which table fired the trigger
      IF TG_TABLE_NAME = arc_tbl::TEXT THEN
         IF NOT _omtg_arcnodenetwork_onarc(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'For each arc at least two nodes must exist at the arc extrem points.';
         END IF;
      ELSIF TG_TABLE_NAME = node_tbl::TEXT THEN
         IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'For each node at least one arc must exist.';
         END IF;
      ELSE
         IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
               USING DETAIL = 'Was not possible to identify the table which fired the trigger.';
         END IF;
      END IF;

   ELSIF TG_OP = 'DELETE' THEN

      IF TG_TABLE_NAME = arc_tbl::TEXT THEN
         IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'Cannot delete the arc because there are nodes connected to it.';
         END IF;
      ELSIF TG_TABLE_NAME = node_tbl::TEXT THEN
         IF NOT _omtg_arcnodenetwork_onarc(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'Cannot delete the node because there are arcs connected to it.';
         END IF;
      ELSE
         IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
               USING DETAIL = 'Was not possible to identify the table which fired the trigger.';
         END IF;
      END IF;

   ELSE
      RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
         USING DETAIL = 'Event not supported. Please create a trigger with INSERT, UPDATE or a DELETE event.';
   END IF;

   RETURN NULL;
END;
$$ LANGUAGE plpgsql;



--
-- Arc-Arc network.
--
CREATE FUNCTION omtg_arcarcnetwork() RETURNS TRIGGER AS $$
DECLARE
   arc_tbl CONSTANT REGCLASS := TG_ARGV[0];
   arc_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   arc_domain CONSTANT TEXT := _omtg_getGeomColumnDomain(arc_tbl, arc_geom);

   res BOOLEAN;
BEGIN

   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcarcnetwork.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcarcnetwork.'
        USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 2 OR TG_TABLE_NAME != arc_tbl::TEXT OR (arc_domain != 'omtg_uniline' AND arc_domain != 'omtg_biline' ) THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcarcnetwork.'
         USING DETAIL = 'Invalid parameters.';
   END IF;

   EXECUTE 'select exists(
      select 1
      from '|| arc_tbl ||' as a, '|| arc_tbl ||' as b
      where a.ctid < b.ctid
      	and st_intersects(a.'|| arc_geom ||', b.'|| arc_geom ||')
      	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
      	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
      	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
      	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
      );' into res;

   IF res THEN
      RAISE EXCEPTION 'OMT-G Arc-Arc network constraint violation at table %.', TG_TABLE_NAME
         USING DETAIL = 'Each arc can only be connected to another arc on its start or end point.';
   END IF;

   RETURN NULL;
END;
$$ LANGUAGE plpgsql;



--
-- Topological relationship.
--
CREATE FUNCTION omtg_topologicalrelationship() RETURNS TRIGGER AS $$
DECLARE
   a_tbl CONSTANT REGCLASS := TG_ARGV[0];
   a_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   b_tbl CONSTANT REGCLASS := TG_ARGV[2];
   b_geom CONSTANT TEXT := quote_ident(TG_ARGV[3]);

   operator _omtg_topologicalrelationship;
   dist REAL;

   res BOOLEAN;
BEGIN

   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 5 OR NOT _omtg_isOMTGDomain(a_tbl, a_geom) OR NOT _omtg_isOMTGDomain(b_tbl, b_geom) THEN
      RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
         USING DETAIL = 'Invalid parameters.';
   END IF;


   IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN

      -- Trigger table must be the same used on the first parameter
      IF TG_TABLE_NAME != a_tbl::TEXT THEN
         RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
            USING DETAIL = 'Invalid parameters. Table that fires the trigger must be the first parameter of the function when firing after INSERT or UPDATE.';
      END IF;

   ELSIF TG_OP = 'DELETE' THEN

      -- Trigger table must be the same used on the second parameter
      IF TG_TABLE_NAME != b_tbl::TEXT THEN
         RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
            USING DETAIL = 'Invalid parameters. Table that fires the trigger must be the second parameter of the function when firing after a DELETE.';
      END IF;

   ELSE
      RAISE EXCEPTION 'OMT-G error at omtg_topologicalrelationship.'
         USING DETAIL = 'Event not supported. Please create a trigger with INSERT, UPDATE or a DELETE event.';
   END IF;


   -- Checks if the fourth argument is a number to perform near function or normal.
   IF _omtg_isnumeric(TG_ARGV[4]) THEN
      dist := TG_ARGV[4];

      -- Near check
      EXECUTE 'SELECT NOT EXISTS(
         SELECT 1
         FROM '|| a_tbl ||' AS a
         LEFT JOIN '|| b_tbl ||' AS b
         ON ST_DWITHIN(a.'|| a_geom ||', b.'|| b_geom ||', '|| dist ||')
         WHERE b.'|| b_geom ||' IS NOT NULL
      );' into res;

      IF res THEN
         RAISE EXCEPTION 'OMT-G Topological Relationship constraint violation between tables % and %.', a_tbl, b_tbl
            USING DETAIL = 'Spatial object is not within the given distance.';
      END IF;

   ELSE
      operator := quote_ident(TG_ARGV[4]);

      -- Topological test
      EXECUTE 'SELECT EXISTS(
         SELECT 1
         FROM '|| a_tbl ||' AS a
         LEFT JOIN '|| b_tbl ||' AS b
         ON st_'|| operator ||'(a.'|| a_geom ||', b.'|| b_geom ||')
         WHERE b.'|| b_geom ||' IS NULL
      );' into res;

      IF res THEN
         RAISE EXCEPTION 'OMT-G Topological Relationship constraint violation (%) between tables % and %.', operator::text, a_tbl, b_tbl;
      END IF;

   END IF;

   RETURN NULL;
END;
$$ LANGUAGE plpgsql;



--
-- Aggregation.
--
CREATE FUNCTION omtg_aggregation() RETURNS TRIGGER AS $$
DECLARE

   part_tbl CONSTANT REGCLASS := TG_ARGV[0];
   part_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   whole_tbl CONSTANT REGCLASS := TG_ARGV[2];
   whole_geom CONSTANT TEXT := quote_ident(TG_ARGV[3]);

   res1 BOOLEAN;
   res2 BOOLEAN;
   res3 BOOLEAN;
BEGIN

   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_aggregation.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_aggregation.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 4 OR TG_TABLE_NAME != part_tbl::TEXT OR NOT _omtg_isOMTGDomain(whole_tbl, whole_geom) OR NOT _omtg_isOMTGDomain(part_tbl, part_geom) THEN
      RAISE EXCEPTION 'OMT-G error at omtg_aggregation.'
         USING DETAIL = 'Invalid parameters.';
   END IF;

   -- 1. Pi intersection W = Pi, for all i such as 0 <= i <= n
   EXECUTE 'SELECT EXISTS (
      select 1
      from '|| part_tbl ||' c
      where c.CTID not in
      (
         select b.CTID
         from '|| whole_tbl ||' a, '|| part_tbl ||' b
         where ST_Equals(ST_Intersection(a.'|| whole_geom ||', b.'|| part_geom ||'), b.'|| part_geom ||')
      )
   );' into res1;

   IF res1 THEN
      RAISE EXCEPTION 'OMT-G Aggregation constraint violation with tables % and %.', whole_tbl, part_tbl
         USING DETAIL = 'The geometry of each PART should be entirely contained within the geometry of the WHOLE.';
   END IF;

   -- 3. ((Pi touch Pj) or (Pi disjoint Pj)) = T for all i, j such as i != j
   EXECUTE 'SELECT EXISTS (
      select 1
      from '|| part_tbl ||' b1, '|| part_tbl ||' b2
      where b1.ctid < b2.ctid and
      (not st_touches(b1.'|| part_geom ||', b2.'|| part_geom ||') and not st_disjoint(b1.'|| part_geom ||', b2.'|| part_geom ||'))
   );' into res2;

   IF res2 THEN
      RAISE EXCEPTION 'OMT-G Aggregation constraint violation with tables % and %.', whole_tbl, part_tbl
         USING DETAIL = 'Overlapping among the PARTS is not allowed.';
   END IF;

   -- 2. (W intersection all P) = W
   EXECUTE 'SELECT NOT st_equals(st_union(a.'|| whole_geom ||'), st_union(b.'|| part_geom ||'))
   FROM '|| whole_tbl ||' a, '|| part_tbl ||' b' into res3;

   IF res3 THEN
      RAISE EXCEPTION 'OMT-G Aggregation constraint violation with tables % and %.', whole_tbl, part_tbl
         USING DETAIL = 'The geometry of the WHOLE should be fully covered by the geometry of the PARTS.';
   END IF;


   RETURN NULL;
END;
$$ LANGUAGE plpgsql;



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
CREATE FUNCTION _omtg_validateTrigger() RETURNS event_trigger AS $$
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
--
-- Event trigger to add constraints automatic to tables with OMT-G types
--
CREATE EVENT TRIGGER omtg_add_class_constraint_trigger
   ON ddl_command_end
   WHEN tag IN ('create table', 'alter table')
   EXECUTE PROCEDURE _omtg_addClassConstraint();



--
-- Event trigger to validate user triggers
--
CREATE EVENT TRIGGER omtg_validate_triggers
   ON ddl_command_end
   WHEN tag IN ('create trigger')
   EXECUTE PROCEDURE _omtg_validateTrigger();
--
-- This function checks if all the elements of b_tbl is within the buffer
-- distance from the elements of a_tbl.
--
create function omtg_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(b_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'OMTG_isTopologicalRelationshipValid function error.'
         using detail = 'Table passed as first parameter does not have primary key and without it is not possible to validate the topological relationship.';
      return false;
   end if;

   if not _omtg_isOMTGDomain(a_tbl, a_geom) or not _omtg_isOMTGDomain(b_tbl, b_geom) then
      raise exception 'OMTG_isTopologicalRelationshipValid error! Invalid parameters.'
         using detail = 'Usage: SELECT omtg_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real);';
   end if;

   execute 'insert into omtg_violation_log (time, type, description) (
      select now(),
            ''Near buffer violation'',
            ''Table ´'|| b_tbl ||'´ tuple with primary key ´''|| b.'|| pkColumn ||' ||''´ is outside the buffer distance of ´'|| dist ||'´ from table ´'|| a_tbl ||'´.''
         from '|| b_tbl ||' b
         where b.'|| pkColumn ||' not in
         (
            select distinct b.'|| pkColumn ||'
            from '|| a_tbl ||' a, '|| b_tbl ||' b
            where st_dwithin(a.'|| a_geom ||', b.'|| b_geom ||', '|| dist ||')
         )
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the topolotical relationship is valid.
--
create function omtg_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation text)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(a_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'OMTG_isTopologicalRelationshipValid function error.'
         using detail = 'Table passed as first parameter does not have primary key and without it is not possible to validate the topological relationship.';
   end if;

   if not _omtg_isOMTGDomain(a_tbl, a_geom) or not _omtg_isOMTGDomain(b_tbl, b_geom) or not _omtg_isTopologicalRelationship(relation)  then
      raise exception 'OMTG_isTopologicalRelationshipValid error! Invalid parameters.'
         using detail = 'Usage: SELECT omtg_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation text);';
   end if;

   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
               ''Topological relationship violation'',
               ''Topological relationship ('|| relation ||') between ´'|| a_tbl ||'´ and ´'|| b_tbl ||'´ is violated by the tuple of ´'|| a_tbl ||'´ with primary key ´''|| a.'|| pkColumn ||' ||''´.''
         from '|| a_tbl ||' a
         where a.'|| pkColumn ||' not in
         (
            select distinct a.'|| pkColumn ||'
            from '|| a_tbl ||' a, '|| b_tbl ||' b
            where st_'|| relation ||'(a.'|| a_geom ||', b.'|| b_geom ||')
         )
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the arc-node network is valid.
--
create function omtg_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(arc_tbl);
   res1 boolean;
   res2 boolean;
begin

   if pkColumn = '' then
      raise exception 'OMTG_isNetworkValid function error.'
         using detail = 'ARC table does not have primary key and without it is not possible to validate the network.';
   end if;

   if not _omtg_isOMTGDomain(arc_tbl, arc_geom) then
      raise exception 'OMTG_isNetworkValid error! Invalid parameters.'
         using detail = 'Usage: SELECT omtg_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text);';
   end if;

   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
               ''Arc-Node Network violation'',
               ''Start point of arc with primary key ´''|| '|| pkColumn ||' ||''´ does not intersect any node.''
         from '|| arc_tbl ||'
         where '|| pkColumn ||' not in (
         	select distinct a.'|| pkColumn ||'
         	from '|| arc_tbl ||' a, '|| node_tbl ||' n
         	where st_intersects(st_startpoint(a.'|| arc_geom ||'), n.'|| node_geom ||')
         )
      ) returning true;' into res1;

   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
               ''Arc-Node Network violation'',
               ''End point of arc with primary key ´''|| '|| pkColumn ||' ||''´ does not intersect any node.''
         from '|| arc_tbl ||'
         where '|| pkColumn ||' not in (
         	select distinct a.'|| pkColumn ||'
         	from '|| arc_tbl ||' a, '|| node_tbl ||' n
         	where st_intersects(st_endpoint(a.'|| arc_geom ||'), n.'|| node_geom ||')
         )
      ) returning true;' into res2;

   if res1 or res2 then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the arc-arc network is valid.
--
create function omtg_isNetworkValid(arc_tbl text, arc_geom text)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(arc_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'OMTG_isNetworkValid function error.'
         using detail = 'ARC table does not have primary key and without it is not possible to validate the network.';
   end if;

   if not _omtg_isOMTGDomain(arc_tbl, arc_geom) then
      raise exception 'OMTG_isNetworkValid error! Invalid parameters.'
         using detail = 'Usage: SELECT omtg_isNetworkValid(arc_tbl text, arc_geom text);';
   end if;

   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
               ''Arc-Arc Network violation'',
               ''Arcs ´''|| a.'|| pkColumn ||' ||''´ and ´''|| b.'|| pkColumn ||' ||''´ intersect each other on middle points.''
               from '|| arc_tbl ||' as a, '|| arc_tbl ||' as b
            where a.ctid < b.ctid
            	and st_intersects(a.'|| arc_geom ||', b.'|| arc_geom ||')
            	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the spatial aggregation is valid.
--
create function omtg_isSpatialAggregationValid(part_tbl text, part_geom text, whole_tbl text, whole_geom text)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(part_tbl);
   res1 boolean;
   res2 boolean;
   res3 boolean;
begin

   if pkColumn = '' then
      raise exception 'OMTG_isSpatialAggregationValid function error.'
         using detail = 'PART table does not have primary key and without it is not possible to validate the spatial aggregation.';
   end if;

   if not _omtg_isOMTGDomain(part_tbl, part_geom) or not _omtg_isomtgdomain(whole_tbl, whole_geom) then
      raise exception 'OMTG_isSpatialAggregationValid error! Invalid parameters.'
         using detail = 'Usage: SELECT omtg_isSpatialAggregationValid(part_tbl text, part_geom text, whole_tbl text, whole_geom text);';
   end if;

   -- 1. Pi intersection W = Pi, for all i such as 0 <= i <= n
   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
            ''Spatial Aggregation violation'',
            ''The geometry of the PART with primary key ´''|| c.'|| pkColumn ||' ||''´ is not entirely contained within the geometry of the WHOLE.''
         from '|| part_tbl ||' c
         where c.ctid not in
         (
         	select b.ctid
         	from '|| whole_tbl ||' a, '|| part_tbl ||' b
         	where ST_Equals(ST_Intersection(a.'|| whole_geom ||', b.'|| part_geom ||'), b.'|| part_geom ||')
         )
      ) returning true;' into res1;


   -- 3. ((Pi touch Pj) or (Pi disjoint Pj)) = T for all i, j such as i != j
   execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
            ''Spatial Aggregation violation'',
            ''The geometries of the parts ´''|| b1.'|| pkColumn ||' ||''´ and ´''|| b2.'|| pkColumn ||' ||''´ are overlapping.''
         from '|| part_tbl ||' b1, '|| part_tbl ||' b2
         where b1.ctid < b2.ctid and
         (not st_touches(b1.'|| part_geom ||', b2.'|| part_geom ||') and not st_disjoint(b1.'|| part_geom ||', b2.'|| part_geom ||'))
      ) returning true;' into res2;


   -- 2. (W intersection all P) = W
   execute 'select not st_equals(st_union(a.geom), st_union(b.geom))
      from tablea a, tableb b;' into res3;

   if res3 then
      execute 'insert into omtg_violation_log (time, type, description) (
         select now(),
         ''Spatial Aggregation violation'',
         ''The geometry of the WHOLE is not fully covered by the geometry of the PARTS.''
      )';
      return false;
   end if;

   if res1 or res2 then return false;
   else return true;
   end if;
end;
$$  language plpgsql;
