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
