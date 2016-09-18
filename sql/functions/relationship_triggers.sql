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
