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
