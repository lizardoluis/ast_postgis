--
-- Validates topological relationship
--
CREATE OR REPLACE FUNCTION omtg_validatetopologicalrel() RETURNS TRIGGER AS $omtg_validatetopologicalrel$
DECLARE
		res BOOLEAN;
		table_name CONSTANT REGCLASS := TG_ARGV[0];
		geom_column CONSTANT TEXT := quote_ident(TG_ARGV[1]);
		spatial_relation CONSTANT TEXT := quote_ident(TG_ARGV[2]);
BEGIN

	-- Checks if table is not null
	IF t IS NULL THEN
		RAISE EXCEPTION 'Isolines exception: Invalid table';
	END IF;

	-- Validates spatial relationship
	EXECUTE 'SELECT EXISTS (SELECT 1 
		FROM '|| table_name ||' AS w
		WHERE '|| spatial_relation ||'(w.'|| geom_column ||', NEW.'|| geom_column ||'))' into res;

	IF res THEN
            RETURN NEW;
        END IF;

        RAISE NOTICE 'Topological integrity constraint violation at: %', NEW;
        RETURN NULL;

    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          RAISE EXCEPTION 'Topological integrity constraint exception: No data found.';
    END;
    $omtg_validatetopologicalrel$ LANGUAGE plpgsql;


--
-- Validates topological relationship
--
CREATE OR REPLACE FUNCTION omtg_validatetopologicalnearrel() RETURNS TRIGGER AS $omtg_validatetopologicalnearrel$
    DECLARE
		res BOOLEAN;
		table_name CONSTANT REGCLASS := TG_ARGV[0];
		geom_column CONSTANT TEXT := quote_ident(TG_ARGV[1]);
		dist CONSTANT FLOAT := TG_ARGV[2];
    BEGIN

	-- Checks if table is not null
	IF t IS NULL THEN
		RAISE EXCEPTION 'Isolines exception: Invalid table';
	END IF;

	-- Validates spatial relationship
	EXECUTE 'SELECT EXISTS (SELECT 1
		FROM '|| table_name ||' AS w
		WHERE ST_DWithin(w.'|| geom_column ||', NEW.'|| geom_column ||', '|| dist ||'))' into res;

	     IF res THEN
            RETURN NEW;
        END IF;

        RAISE NOTICE 'Topological integrity constraint violation at: %', NEW;
        RETURN NULL;

    EXCEPTION
       WHEN NO_DATA_FOUND THEN
          RAISE EXCEPTION 'Topological integrity constraint exception: No data found.';
    END;
    $omtg_validatetopologicalnearrel$ LANGUAGE plpgsql;
