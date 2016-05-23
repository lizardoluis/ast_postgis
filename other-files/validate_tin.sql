DROP TABLE IF EXISTS tin_results;
CREATE TABLE tin_results (
  id SERIAL,
  result boolean,
  comments TEXT
);

-- Test 1 - 8 triangles valid

delete from Temperature;

INSERT INTO Temperature(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 0, 1 1, 1 0, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 1 0))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 2 1, 2 0, 1 0))') );


INSERT INTO Temperature(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (6, 'F', ST_GeomFromText('POLYGON((0 1, 1 2, 1 1, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (7, 'G', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 1 1))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (8, 'H', ST_GeomFromText('POLYGON((1 1, 2 2, 2 1, 1 1))') );


INSERT INTO tin_results(result, comments)
	VALUES (omtg_validatetin('Temperature', 'geom'), '8 triangles valid');




-- Test 2 - 7 triangles and 1 square

delete from Temperature;

INSERT INTO Temperature(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 0, 1 1, 1 0, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 1 0))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 2 1, 2 0, 1 0))') );


INSERT INTO Temperature(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (6, 'F', ST_GeomFromText('POLYGON((0 1, 1 2, 1 1, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (7, 'G', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 1 1))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (8, 'H', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );


INSERT INTO tin_results(result, comments)
	VALUES (omtg_validatetin('Temperature', 'geom'), '7 triangles and 1 square');


-- Test 3 - 8 triangles with overlap

delete from Temperature;

INSERT INTO Temperature(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 0, 1 1, 1 0, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 1 0))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 2 1, 2 0, 1 0))') );


INSERT INTO Temperature(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (6, 'F', ST_GeomFromText('POLYGON((0 1, 1 2, 1 1, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (7, 'G', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 1 1))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (8, 'H', ST_GeomFromText('POLYGON((0 0, 0 2, 2 2, 0 0))') );


INSERT INTO tin_results(result, comments)
	VALUES (omtg_validatetin('Temperature', 'geom'), '7 triangles with overlap');


-- Test 4 - 8 triangles valid

delete from Temperature;

INSERT INTO Temperature(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 0, 1 1, 1 0, 0 0))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 1 0))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 2 1, 2 0, 1 0))') );


INSERT INTO Temperature(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (6, 'F', ST_GeomFromText('POLYGON((0 1, 1 2, 1 1, 0 1))') );

INSERT INTO Temperature(id, name, geom)
    VALUES (7, 'G', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 1 1))') );
    
INSERT INTO Temperature(id, name, geom)
    VALUES (8, 'H', ST_GeomFromText('POLYGON((1 1, 4 4, 4 1, 1 1))') );


INSERT INTO tin_results(result, comments)
	VALUES (omtg_validatetin('Temperature', 'geom'), '8 triangles valid');



SELECT * FROM tin_results;