--
-- Arc-Node relationship. Check if arcs are valid
--
CREATE FUNCTION _ast_arcnodenetwork_onarc(arc regclass, node regclass, ageom text, ngeom text)
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
CREATE FUNCTION _ast_arcnodenetwork_onnode(arc regclass, node regclass, ageom text, ngeom text)
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
CREATE FUNCTION ast_arcnodenetwork() RETURNS TRIGGER AS $$
DECLARE
   arc_tbl CONSTANT REGCLASS := TG_ARGV[0];
   arc_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   node_tbl CONSTANT REGCLASS := TG_ARGV[2];
   node_geom CONSTANT TEXT := quote_ident(TG_ARGV[3]);

   arc_domain CONSTANT TEXT := _ast_getGeomColumnDomain(arc_tbl, arc_geom);
   node_domain CONSTANT TEXT := _ast_getGeomColumnDomain(node_tbl, node_geom);

BEGIN

   -- Validate trigger settings
   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

    -- Validate input parameters
   IF TG_NARGS != 4 OR node_domain != 'ast_node' OR (arc_domain != 'ast_uniline' AND arc_domain != 'ast_biline' ) THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
         USING DETAIL = 'Invalid parameters.';
   END IF;


   IF TG_OP = 'INSERT' OR TG_OP ='UPDATE' THEN

      -- Check which table fired the trigger
      IF TG_TABLE_NAME = arc_tbl::TEXT THEN
         IF NOT _ast_arcnodenetwork_onarc(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'For each arc at least two nodes must exist at the arc extrem points.';
         END IF;
      ELSIF TG_TABLE_NAME = node_tbl::TEXT THEN
         IF NOT _ast_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'For each node at least one arc must exist.';
         END IF;
      ELSE
         IF NOT _ast_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
               USING DETAIL = 'Was not possible to identify the table which fired the trigger.';
         END IF;
      END IF;

   ELSIF TG_OP = 'DELETE' THEN

      IF TG_TABLE_NAME = arc_tbl::TEXT THEN
         IF NOT _ast_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'Cannot delete the arc because there are nodes connected to it.';
         END IF;
      ELSIF TG_TABLE_NAME = node_tbl::TEXT THEN
         IF NOT _ast_arcnodenetwork_onarc(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G Arc-Node network constraint violation at table %.', TG_TABLE_NAME
               USING DETAIL = 'Cannot delete the node because there are arcs connected to it.';
         END IF;
      ELSE
         IF NOT _ast_arcnodenetwork_onnode(arc_tbl, node_tbl, arc_geom, node_geom) THEN
            RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
               USING DETAIL = 'Was not possible to identify the table which fired the trigger.';
         END IF;
      END IF;

   ELSE
      RAISE EXCEPTION 'OMT-G error at ast_arcnodenetwork.'
         USING DETAIL = 'Event not supported. Please create a trigger with INSERT, UPDATE or a DELETE event.';
   END IF;

   RETURN NULL;
END;
$$ LANGUAGE plpgsql;



--
-- Arc-Arc network.
--
CREATE FUNCTION ast_arcarcnetwork() RETURNS TRIGGER AS $$
DECLARE
   arc_tbl CONSTANT REGCLASS := TG_ARGV[0];
   arc_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   arc_domain CONSTANT TEXT := _ast_getGeomColumnDomain(arc_tbl, arc_geom);

   res BOOLEAN;
BEGIN

   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcarcnetwork.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcarcnetwork.'
        USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 2 OR TG_TABLE_NAME != arc_tbl::TEXT OR (arc_domain != 'ast_uniline' AND arc_domain != 'ast_biline' ) THEN
      RAISE EXCEPTION 'OMT-G error at ast_arcarcnetwork.'
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
CREATE FUNCTION ast_topologicalrelationship() RETURNS TRIGGER AS $$
DECLARE
   a_tbl CONSTANT REGCLASS := TG_ARGV[0];
   a_geom CONSTANT TEXT := quote_ident(TG_ARGV[1]);

   b_tbl CONSTANT REGCLASS := TG_ARGV[2];
   b_geom CONSTANT TEXT := quote_ident(TG_ARGV[3]);

   operator _ast_topologicalrelationship := quote_ident(TG_ARGV[4]);
   dist REAL;

   res BOOLEAN;
BEGIN

   IF TG_WHEN != 'AFTER' THEN
      RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 5 OR NOT _ast_isOMTGDomain(a_tbl, a_geom) OR NOT _ast_isOMTGDomain(b_tbl, b_geom) THEN
      RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
         USING DETAIL = 'Invalid parameters.';
   END IF;


   IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN

      -- Trigger table must be the same used on the first parameter
      IF TG_TABLE_NAME != a_tbl::TEXT THEN
         RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
            USING DETAIL = 'Invalid parameters. Table that fires the trigger must be the first parameter of the function when firing after INSERT or UPDATE.';
      END IF;

   ELSIF TG_OP = 'DELETE' THEN

      -- Trigger table must be the same used on the second parameter
      IF TG_TABLE_NAME != b_tbl::TEXT THEN
         RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
            USING DETAIL = 'Invalid parameters. Table that fires the trigger must be the second parameter of the function when firing after a DELETE.';
      END IF;

   ELSE
      RAISE EXCEPTION 'OMT-G error at ast_topologicalrelationship.'
         USING DETAIL = 'Event not supported. Please create a trigger with INSERT, UPDATE or a DELETE event.';
   END IF;


   -- Checks if the fourth argument is a number to perform near function or normal.
   IF operator = 'near' THEN
      dist := TG_ARGV[5];

      -- Near check
      EXECUTE 'SELECT EXISTS(
         SELECT 1
         FROM '|| a_tbl ||' AS a
         RIGHT JOIN '|| b_tbl ||' AS b
         ON ST_DWITHIN(a.'|| a_geom ||', b.'|| b_geom ||', '|| dist ||')
         WHERE a.'|| a_geom ||' IS NULL
      );' into res;

      IF res THEN
         RAISE EXCEPTION 'OMT-G Topological Relationship constraint violation between tables % and %.', a_tbl, b_tbl
            USING DETAIL = 'Spatial objects are not inside the given distance.';
      END IF;

   ELSIF operator = 'distant' THEN
      dist := TG_ARGV[5];

      -- Distant check
      EXECUTE 'SELECT EXISTS(
         SELECT 1
         FROM '|| a_tbl ||' AS a
         LEFT JOIN '|| b_tbl ||' AS b
         ON ST_DWITHIN(a.'|| a_geom ||', b.'|| b_geom ||', '|| dist ||')
         WHERE b.'|| b_geom ||' IS NOT NULL
      );' into res;

      IF res THEN
         RAISE EXCEPTION 'OMT-G Topological Relationship constraint violation between tables % and %.', a_tbl, b_tbl
            USING DETAIL = 'Spatial objects are not outside the given distance.';
      END IF;


   ELSE
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
CREATE FUNCTION ast_aggregation() RETURNS TRIGGER AS $$
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
      RAISE EXCEPTION 'OMT-G error at ast_aggregation.'
         USING DETAIL = 'Trigger must be fired with AFTER statement.';
   END IF;

   IF TG_LEVEL != 'STATEMENT' THEN
      RAISE EXCEPTION 'OMT-G error at ast_aggregation.'
         USING DETAIL = 'Trigger must be of STATEMENT level.';
   END IF;

   IF TG_NARGS != 4 OR TG_TABLE_NAME != part_tbl::TEXT OR NOT _ast_isOMTGDomain(whole_tbl, whole_geom) OR NOT _ast_isOMTGDomain(part_tbl, part_geom) THEN
      RAISE EXCEPTION 'OMT-G error at ast_aggregation.'
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
CREATE FUNCTION _ast_createOnDeleteTriggerOnTable(tgrname text, tname text, procedure text) RETURNS void AS $$
BEGIN
   -- Check if trigger already exists
   IF NOT _ast_isTriggerEnable(tgrname) THEN
      -- Suspend event trigger to avoid loop
      EXECUTE 'ALTER EVENT TRIGGER ast_validate_triggers DISABLE;';

      EXECUTE 'CREATE TRIGGER '|| tgrname ||' AFTER DELETE ON '|| tname ||'
          FOR EACH STATEMENT EXECUTE PROCEDURE '|| procedure ||';';

      --RAISE NOTICE 'Trigger created AFTER DELETE on table % with % procedure.', tname, procedure;

      -- Enable event trigger again
      EXECUTE 'ALTER EVENT TRIGGER ast_validate_triggers ENABLE;';
   END IF;

END;
$$  LANGUAGE plpgsql;



--
-- This function adds the right trigger to a table with a geometry omtg column.
--
CREATE FUNCTION _ast_validateTrigger() RETURNS event_trigger AS $$
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

         timing := (_ast_triggerParser(r.objid)).timing;
         function_name := (_ast_triggerParser(r.objid)).function_name;
         row_statement := (_ast_triggerParser(r.objid)).row_statement;
         function_arguments := _ast_arraylower((_ast_triggerParser(r.objid)).function_arguments);
         table_name := (_ast_triggerParser(r.objid)).table_name;
         events := _ast_arraylower((_ast_triggerParser(r.objid)).events);

         -- trigger must be fired after an statement
         IF timing != 'AFTER' or row_statement != 'STATEMENT'  THEN
            RAISE EXCEPTION 'OMT-G error on trigger %.', r.object_identity
               USING DETAIL = 'Trigger must be fired AFTER a STATEMENT.';
         END IF;

         CASE function_name

            WHEN 'ast_arcarcnetwork' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 2 THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: ast_arcarcnetwork(''arc_tbl'', ''arc_geom'').';
               END IF;

               -- table that fired the trigger must be the same of the parameter
               IF function_arguments[1] != table_name THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Table associated with the trigger must be passed as the first parameter. Usage: ast_arcarcnetwork(''arc_table'', ''arc_geometry'').';
               END IF;

               -- domain must be an arc
               arc_domain := _ast_getGeomColumnDomain(function_arguments[1], function_arguments[2]);
               IF arc_domain != 'ast_uniline' AND arc_domain != 'ast_biline' THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table passed as parameter does not contain an arc geometry (ast_uniline or ast_biline).';
               END IF;

               -- trigger events must be insert, delete and update
               IF not events @> '{insert}' or not events @> '{delete}' or not events @> '{update}' THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-ARC NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'ARC-ARC trigger events must be INSERT OR UPDATE OR DELETE.';
               END IF;


            WHEN 'ast_arcnodenetwork' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 4 THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: ast_arcnodenetwork(''arc_tbl'', ''arc_geom'', ''node_tbl'', ''node_geom'').';
               END IF;

               -- domain must be arc and node
               arc_domain := _ast_getGeomColumnDomain(function_arguments[1], function_arguments[2]);
               node_domain := _ast_getGeomColumnDomain(function_arguments[3], function_arguments[4]);
               IF node_domain != 'ast_node' OR (arc_domain != 'ast_uniline' AND arc_domain != 'ast_biline' ) THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Arc table must have AST_UNILINE or AST_BILINE geometry. Node table must have AST_NODE geometry.';
               END IF;

               IF table_name != function_arguments[1] AND table_name != function_arguments[3] THEN
                  RAISE EXCEPTION 'OMT-G error at ARC-NODE NETWORK constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table that fires the trigger must be passed as a parameter.';
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

               PERFORM _ast_createOnDeleteTriggerOnTable(
                  split_part(r.object_identity, ' ', 1) ||'_auto',
                  on_tbl,
                  'ast_arcnodenetwork('|| function_arguments[1] ||', '|| function_arguments[2] ||', '|| function_arguments[3] ||', '|| function_arguments[4] ||')'
               );


            WHEN 'ast_topologicalrelationship' THEN

               -- number of arguments
               IF (array_length(function_arguments, 1) != 5 AND array_length(function_arguments, 1) != 6)
                  OR NOT _ast_isOMTGDomain(function_arguments[1], function_arguments[2])
                  OR NOT _ast_isOMTGDomain(function_arguments[3], function_arguments[4])
                  OR (array_length(function_arguments, 1) = 6 AND NOT _ast_isnumeric(function_arguments[6]))
               THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: ast_topologicalrelationship(''a_tbl'', ''a_geom'', ''b_tbl'', ''b_geom'', ''spatial_relation'', ''''distance'''').';
               END IF;

               IF table_name != function_arguments[1] AND table_name != function_arguments[3] THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Table that fires the trigger must be passed as the first parameter of the procedure.';
               END IF;

               -- only insert or update
               IF (not events @> '{insert}' or not events @> '{update}' or events @> '{delete}') THEN
                  RAISE EXCEPTION 'OMT-G error at TOPOLOGICAL RELATIONSHIP constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'TOPOLOGICAL RELATIONSHIP trigger events must be INSERT OR UPDATE.';
               END IF;

               PERFORM _ast_createOnDeleteTriggerOnTable(
                  split_part(r.object_identity, ' ', 1) ||'_auto',
                  function_arguments[3],
                  'ast_topologicalrelationship('|| function_arguments[1] ||', '|| function_arguments[2] ||', '|| function_arguments[3] ||', '|| function_arguments[4] ||', '|| function_arguments[5] ||')'
               );


            WHEN 'ast_aggregation' THEN

               -- number of arguments
               IF array_length(function_arguments, 1) != 4 OR NOT _ast_isOMTGDomain(function_arguments[1], function_arguments[2]) OR NOT _ast_isOMTGDomain(function_arguments[3], function_arguments[4]) THEN
                  RAISE EXCEPTION 'OMT-G error at AGGREGATION constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Invalid procedure parameters. Usage: ast_aggregation(''part_tbl'', ''part_geom'', ''whole_tbl'', ''whole_geom'').';
               END IF;

               IF table_name != function_arguments[1] THEN
                  RAISE EXCEPTION 'OMT-G error at AGGREGATION constraint, on trigger %.', r.object_identity
                     USING DETAIL = 'Part table that fires the trigger must be passed as the first parameter of the procedure.';
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
