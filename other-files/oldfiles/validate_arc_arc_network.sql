--
-- Validates arc-arc network
-- 
CREATE OR REPLACE FUNCTION omtg_arcarcnetwork(arc regclass, arc_geom text default 'geom') RETURNS BOOLEAN as $omtg_arcarcnetwork$
    DECLARE
		res BOOLEAN;
		a_geom CONSTANT TEXT := quote_ident(arc_geom);
    BEGIN    	

	-- Checks if table is not null
	IF arc IS NULL THEN
		RAISE EXCEPTION 'Arc-arc network exception: Invalid table';
	END IF;

	-- Checks if for each node, exists at least one arc and if for each arc, exists at least 2 nodes.
	EXECUTE 'SELECT EXISTS (
			SELECT T.CTID FROM Trecho AS T
			EXCEPT
			SELECT DISTINCT A.CTID FROM '|| arc||' AS A 
			LEFT JOIN '|| arc ||' AS B 
			ON A.CTID != B.CTID
			WHERE St_Equals(ST_EndPoint(A.'|| a_geom ||'), ST_StartPoint(B.'|| a_geom ||')) 
				OR St_Equals(ST_StartPoint(A.'|| a_geom ||'), ST_EndPoint(B.'|| a_geom ||')) 
				OR St_Equals(ST_StartPoint(A.'|| a_geom ||'), ST_StartPoint(B.'|| a_geom ||')) 
				OR St_Equals(ST_EndPoint(A.'|| a_geom ||'), ST_EndPoint(B.'|| a_geom ||'))
		)' INTO res;

	IF res THEN		
		RAISE WARNING 'Arc-arc network constraint error: network contains arcs without connection to other arcs'; 
		RETURN 'FALSE';
	END IF;

	RETURN 'TRUE';
  
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RAISE EXCEPTION 'Arc-arc network exception: No data found';
          
    END;
    $omtg_arcarcnetwork$ LANGUAGE plpgsql;
