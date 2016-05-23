--
-- Isoline
--
CREATE FUNCTION omtg_check_isoline() RETURNS TRIGGER AS $$
    DECLARE
        res BOOLEAN;
        tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
        cgeom CONSTANT TEXT := omtg_getGeomColumnName(tbl, 'omtg_isoline');
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
CREATE FUNCTION omtg_check_planarsubdivision() RETURNS TRIGGER AS $$
    DECLARE
        res BOOLEAN;
        tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
        cgeom CONSTANT TEXT := omtg_getGeomColumnName(tbl, 'omtg_planarsubdivision');
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
CREATE FUNCTION omtg_check_sample() RETURNS TRIGGER AS $$
    DECLARE
        res BOOLEAN;
        tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
        cgeom CONSTANT TEXT := omtg_getGeomColumnName(tbl, 'omtg_sample');
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
CREATE FUNCTION omtg_check_tin() RETURNS TRIGGER AS $$
    DECLARE
        res BOOLEAN;
        tbl CONSTANT TEXT := quote_ident(TG_TABLE_NAME);
        cgeom CONSTANT TEXT := omtg_getGeomColumnName(tbl, 'omtg_tin');
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
--
-- Polygon
--
create domain OMTG_POLYGON as GEOMETRY(POLYGON)
    constraint simple_polygon_constraint check (omtg_isSimpleGeometry(VALUE));

--
-- Line
--
create domain OMTG_LINE as GEOMETRY(LINESTRING)
    constraint simple_line_constraint check (omtg_isSimpleGeometry(VALUE));

--
-- Point
--
create domain OMTG_POINT as GEOMETRY(POINT);

--
-- Node
--
create domain OMTG_NODE as GEOMETRY(POINT);

--
-- Isoline
--
create domain OMTG_ISOLINE as GEOMETRY(LINESTRING)
    constraint simple_isoline_constraint check (omtg_isSimpleGeometry(VALUE));

--
-- Planar subdivision
--
create domain OMTG_PLANARSUBDIVISION as GEOMETRY(POLYGON)
    constraint simple_planarsubdivision_constraint check (omtg_isSimpleGeometry(VALUE));
--
-- TIN
--
create domain OMTG_TIN as GEOMETRY(POLYGON)
    constraint simple_tin_constraint check (omtg_isSimpleGeometry(VALUE))
    constraint triangle_tin_constraint check (omtg_isTriangle(VALUE));

--
-- Tesselation
--
create domain OMTG_TESSELATION as RASTER;

--
-- Sample
--
create domain OMTG_SAMPLE as GEOMETRY(POINT);

--
-- Unidirectional Line
--
create domain OMTG_UNILINE as GEOMETRY(LINESTRING)
    constraint simple_uniline_constraint check (omtg_isSimpleGeometry(VALUE));

--
-- Bidirectional Line
--
create domain OMTG_BILINE as GEOMETRY(LINESTRING)
    constraint simple_biline_constraint check (omtg_isSimpleGeometry(VALUE));
--
-- Event trigger to add constraints automatic to tables with OMT-G types
--
CREATE EVENT TRIGGER omtg_add_class_constraint_trigger
    ON ddl_command_end
    WHEN tag IN ('create table', 'alter table')
    EXECUTE PROCEDURE omtg_addClassConstraint();--
-- Spatial error log table
--
CREATE TABLE omtg_violation (
    time timestamp,
    type VARCHAR(50),
    description TEXT
);

--
-- Mark the omtg_violation table as a configuration table, which will cause pg_dump to include the table's contents (not its definition) in dumps.
--
SELECT pg_catalog.pg_extension_config_dump('omtg_violation', '');