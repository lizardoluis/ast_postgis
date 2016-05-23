--
-- This function checks if the geometry is simple.
--
CREATE FUNCTION omtg_isSimpleGeometry(geom geometry)
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
CREATE FUNCTION omtg_isTriangle(geom geometry)
RETURNS BOOLEAN AS $$
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
CREATE FUNCTION omtg_getGeomColumnName(tbl regclass, omtgClass text) RETURNS TEXT AS $$
DECLARE
    column TEXT := '';
BEGIN
    SELECT attname::text AS type INTO column
    FROM pg_attribute
    WHERE  attrelid = tbl AND attnum > 0 AND NOT attisdropped AND format_type(atttypid, atttypmod) = omtgClass
    LIMIT 1;

    RETURN column;
END;
$$  LANGUAGE plpgsql;



--
-- This function returns the name of the column given its type.
--
CREATE FUNCTION omtg_createTriggerOnTable(tname text, omtgClass text) RETURNS void AS $$
BEGIN

    EXECUTE 'CREATE TRIGGER '|| tname ||'_'|| omtgClass ||'_trigger
        AFTER INSERT OR UPDATE OR DELETE ON '|| tname ||'
        FOR EACH STATEMENT EXECUTE PROCEDURE omtg_check_'|| omtgClass ||'();';

END;
$$  LANGUAGE plpgsql;



--
-- This function adds the right trigger to a table with a geometry omtg column.
--
CREATE FUNCTION omtg_addClassConstraint() RETURNS event_trigger AS $$
DECLARE
    r record;
    tname text;
    coltypes text array;
    c text;
BEGIN
    FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP

        SELECT r.object_identity::regclass INTO tname;

        -- verify that tags match
        IF r.command_tag = 'CREATE TABLE' THEN

            coltypes := array(
                SELECT format_type(atttypid, atttypmod) AS type
                FROM pg_attribute
                WHERE  attrelid = r.objid AND attnum > 0 AND NOT attisdropped and format_type(atttypid, atttypmod) like 'omtg_%'
            );

            -- checks if there are more than one geometry column with OMTG definitions
            FOREACH c IN ARRAY coltypes LOOP
                CASE c
                    WHEN 'omtg_isoline' THEN
                        PERFORM omtg_createTriggerOnTable(tname, 'isoline');

                    WHEN 'omtg_planarsubdivision' THEN
                        PERFORM omtg_createTriggerOnTable(tname, 'planarsubdivision');

                    WHEN 'omtg_sample' THEN
                        PERFORM omtg_createTriggerOnTable(tname, 'sample');

                    WHEN 'omtg_tesselation' THEN
                        PERFORM omtg_createTriggerOnTable(tname, 'tesselation');

                    WHEN 'omtg_tin' THEN
                        PERFORM omtg_createTriggerOnTable(tname, 'tin');

                    ELSE RETURN;
                END CASE;
            END LOOP;

        END IF;

    END LOOP;

END;
$$ LANGUAGE plpgsql;
