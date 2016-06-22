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
   -- TODO: identify automatically the argments

   -- RAISE WARNING 'Hello world %, %.', TG_OP, TG_LEVEL;
   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
        USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_OP = 'INSERT' OR TG_OP ='UPDATE' THEN

       -- Validate input parameters
       IF TG_NARGS != 4 OR node_domain != 'omtg_node' OR (arc_domain != 'omtg_uniline' AND arc_domain != 'omtg_biline' ) THEN
          RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
             USING DETAIL = 'Invalid parameters.';
       END IF;

       -- Check which table fired the trigger
       IF TG_TABLE_NAME = arc_tbl::TEXT THEN

          IF NOT _omtg_arcnodenetwork_onarc(arc_tbl, node_tbl, arc_geom, node_geom) THEN
             RAISE EXCEPTION 'OMT-G Arc-Node constraint violation at table %.', TG_TABLE_NAME
                USING DETAIL = 'For each arc at least two nodes must exist at the arc extrem points.';
          END IF;

       ELSIF TG_TABLE_NAME = node_tbl::TEXT THEN

          IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
             RAISE EXCEPTION 'OMT-G Arc-Node constraint violation at table %.', TG_TABLE_NAME
                USING DETAIL = 'For each node at least one arc must exist.';
          END IF;

       ELSE

          IF NOT _omtg_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
             RAISE EXCEPTION 'OMT-G error at omtg_arcnodenetwork.'
                USING DETAIL = 'Was not possible to identify the table which fired the trigger.';
          END IF;

       END IF;
   END IF;

   RETURN NULL;
END;
$$ LANGUAGE plpgsql;
--
-- This function checks if the geometry is simple.
--
CREATE FUNCTION _omtg_isSimpleGeometry(geom geometry)
RETURNS BOOLEAN AS $$
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
-- This function returns the name of the column given its type.
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

               WHEN 'omtg_tesselation' THEN
                  PERFORM _omtg_createTriggerOnTable(tname, 'tesselation', omtg_column.cname);

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
-- Event trigger to add constraints automatic to tables with OMT-G types
--
CREATE EVENT TRIGGER omtg_add_class_constraint_trigger
   ON ddl_command_end
   WHEN tag IN ('create table', 'alter table')
   EXECUTE PROCEDURE _omtg_addClassConstraint();
--
-- Spatial error log table
--
--CREATE TABLE omtg_violation (
--    time timestamp,
--    type VARCHAR(50),
--    description TEXT
--);

--
-- Mark the omtg_violation table as a configuration table, which will cause pg_dump to include the table's contents (not its definition) in dumps.
--
--SELECT pg_catalog.pg_extension_config_dump('omtg_violation', '');
