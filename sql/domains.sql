--
-- Polygon
--
create domain AST_POLYGON as GEOMETRY(MULTIPOLYGON)
    constraint simple_polygon_constraint check (_ast_isSimpleGeometry(VALUE));

--
-- Line
--
create domain AST_LINE as GEOMETRY(MULTILINESTRING)
    constraint simple_line_constraint check (_ast_isSimpleGeometry(VALUE));

--
-- Point
--
create domain AST_POINT as GEOMETRY(POINT);

--
-- Node
--
create domain AST_NODE as GEOMETRY(POINT);

--
-- Isoline
--
create domain AST_ISOLINE as GEOMETRY(LINESTRING)
    constraint simple_isoline_constraint check (_ast_isSimpleGeometry(VALUE));

--
-- Planar subdivision
--
create domain AST_PLANARSUBDIVISION as GEOMETRY(MULTIPOLYGON)
    constraint simple_planarsubdivision_constraint check (_ast_isSimpleGeometry(VALUE));
--
-- TIN
--
create domain AST_TIN as GEOMETRY(POLYGON)
    constraint simple_tin_constraint check (_ast_isSimpleGeometry(VALUE))
    constraint triangle_tin_constraint check (_ast_isTriangle(VALUE));

--
-- Tesselation
--
create domain AST_TESSELATION as RASTER;

--
-- Sample
--
create domain AST_SAMPLE as GEOMETRY(POINT);

--
-- Unidirectional Line
--
create domain AST_UNILINE as GEOMETRY(LINESTRING)
    constraint simple_uniline_constraint check (_ast_isSimpleGeometry(VALUE));

--
-- Bidirectional Line
--
create domain AST_BILINE as GEOMETRY(LINESTRING)
    constraint simple_biline_constraint check (_ast_isSimpleGeometry(VALUE));
