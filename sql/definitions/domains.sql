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
