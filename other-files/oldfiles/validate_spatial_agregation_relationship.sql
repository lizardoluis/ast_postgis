--
-- Validates spatial-agregation relationship
-- 
CREATE OR REPLACE FUNCTION omtg_validatespatialagregationrel(W_geom geometry, p regclass, c text default 'geom') RETURNS BOOLEAN as $omtg_validatespatialagregationrel$
    DECLARE
		res BOOLEAN;
		geom_column CONSTANT TEXT := quote_ident(c);
		united_geom GEOMETRY;
    BEGIN    	

	-- Checks if table is not null
	IF W_geom IS NULL or p IS NULL THEN
		RAISE EXCEPTION 'Spatial Agregation constraint exception: Invalid tables';
	END IF;

	-- Calculates the union of the geometries
	EXECUTE 'SELECT ST_Union('|| geom_column ||') FROM '|| p INTO united_geom;


	-- (1) P_i \intercects W = P_i for all i | 0 <= i <= n
	IF NOT ST_IsEmpty(ST_Difference(W_geom, united_geom)) THEN		
		RAISE WARNING 'Spatial-agregation constraint error: some areas of whole do not belong to the parts.'; 
		RETURN 'FALSE';
	END IF;
		

	-- (2) (W \intercects(\union P_i)) = W
	IF NOT ST_EQUALS(W_geom, united_geom) THEN		
		RAISE WARNING 'Spatial-agregation constraint error: some parts are outside the whole.'; 
		RETURN 'FALSE';
	END IF;


	-- (3) ((P_i \touches P_j ) OR (P_i \disjoint P_j )) = True for all i, j and i ≠ j
	EXECUTE 'SELECT EXISTS (SELECT 1 
		FROM '|| p ||' as p1, '|| p ||' as p2 
		WHERE p1.CTID <> p2.CTID AND 
			NOT ST_Touches(p1.'|| geom_column ||', p2.'|| geom_column ||') AND 
			NOT ST_Disjoint(p1.'|| geom_column ||', p2.'|| geom_column ||'))' INTO res;

	IF res THEN		
		RAISE WARNING 'Spatial-agregation constraint error: some parts overlap each other.'; 
		RETURN 'FALSE';
	END IF;

	RETURN 'TRUE';
  
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RAISE EXCEPTION 'Spatial-agregation exception: No data found';
          
    END;
    $omtg_validatespatialagregationrel$ LANGUAGE plpgsql;
