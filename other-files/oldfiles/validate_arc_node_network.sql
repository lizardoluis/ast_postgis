--
-- Validates arc-node network
-- 
CREATE OR REPLACE FUNCTION omtg_arcnodenetwork(arc regclass, node regclass, arc_geom text default 'geom', node_geom text default 'geom') RETURNS BOOLEAN as $omtg_arcnodenetwork$
    DECLARE
		res BOOLEAN;
		a_geom CONSTANT TEXT := quote_ident(arc_geom);
		n_geom CONSTANT TEXT := quote_ident(node_geom);
    BEGIN    	

	-- Checks if table is not null
	IF arc IS NULL OR node IS NULL THEN
		RAISE EXCEPTION 'Arc-node network exception: Invalid table';
	END IF;

	-- Checks if for each node, exists at least one arc and if for each arc, exists at least 2 nodes.
	EXECUTE 'WITH Points AS (
			SELECT ST_StartPoint('|| a_geom ||') AS point FROM '|| arc ||'
			UNION
			SELECT ST_EndPoint('|| a_geom ||') AS point FROM '|| arc ||'
		)
		SELECT EXISTS(
			SELECT 1 FROM '|| node ||' AS N 
			LEFT JOIN Points AS P ON ST_Intersects(N.'|| n_geom ||', P.point) = TRUE WHERE P.point IS NULL
		)
		OR EXISTS(
			SELECT 1 FROM Points AS P 
			LEFT JOIN '|| node ||' AS N ON ST_EQUALS(P.point, N.'|| n_geom ||') WHERE N.'|| n_geom ||' IS NULL
		)' INTO res;

	IF res THEN		
		RAISE WARNING 'Arc-node network constraint error: arc-node contains nodes without arcs'; 
		RETURN 'FALSE';
	END IF;

	RETURN 'TRUE';
  
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RAISE EXCEPTION 'Arc-node network exception: No data found';
          
    END;
    $omtg_arcnodenetwork$ LANGUAGE plpgsql;
