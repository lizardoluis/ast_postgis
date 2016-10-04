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
