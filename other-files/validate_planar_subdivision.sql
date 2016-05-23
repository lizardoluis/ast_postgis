DROP TABLE IF EXISTS planar_subdivision_results;
CREATE TABLE planar_subdivision_results (
  id SERIAL,
  result boolean,
  comments TEXT
);

-- Test 1 - No gaps

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), 'No gaps');



-- Test 2 - Separated

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), 'Separated');




-- Test 3 - No gaps - 1 overlap

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'F', ST_GeomFromText('POLYGON((1.5 1.5, 1.5 2.5, 2.5 2.5, 2.5 1.5, 1.5 1.5))') );



INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), 'No gaps - 1 overlap');



-- Test 4 - With 1 gap

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 0.5 1, 1 0.5, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), 'With 1 gap');



-- Test 5 - With 2 gap 

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 0.5 1, 1 0.5, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1.5, 1.5 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), 'With 2 gaps');



-- Test 6 - 1 Overlap - false

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 1.5 1, 2 1.5, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), '1 Overlap');



-- Test 7 - 1 gap and 1 Overlap 

delete from Bairros;

INSERT INTO Bairros(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('POLYGON((0 0, 0 1, 0.5 1, 1 0.5, 1 0, 0 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Bairros(id, name, geom)
    VALUES (4, 'D', ST_GeomFromText('POLYGON((1 0, 1 1, 1.5 1, 2 1.5, 2 1, 2 0, 1 0))') );

INSERT INTO Bairros(id, name, geom)
    VALUES (5, 'E', ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO planar_subdivision_results(result, comments)
	VALUES (omtg_validateplanarsubdivision('Bairros', 'geom'), '1 gap and 1 Overlap');

	



SELECT * FROM planar_subdivision_results;