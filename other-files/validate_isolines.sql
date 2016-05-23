DROP TABLE IF EXISTS isolines_results;
CREATE TABLE isolines_results (
  id SERIAL,
  result boolean,
  comments TEXT
);

-- Test 1 - Separated

delete from Curvas;

INSERT INTO Curvas(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('LINESTRING(0 0, 1 1, 2 0, 3 0)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('LINESTRING(0 1, 1 2, 2 1, 3 1)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('LINESTRING(0 2, 1 3, 2 2, 3 2)') );


INSERT INTO isolines_results(result, comments)
	VALUES (omtg_validateisolines('Curvas', 'geom'), 'Separated');




-- Test 2 - Separated with touch

delete from Curvas;

INSERT INTO Curvas(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('LINESTRING(0 0, 1 0, 2 1, 3 0)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('LINESTRING(0 1, 1 1, 2 2, 3 1)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (3, 'C', ST_GeomFromText('LINESTRING(0 2, 1 2, 2 2, 3 2)') );


INSERT INTO isolines_results(result, comments)
	VALUES (omtg_validateisolines('Curvas', 'geom'), 'Separated with touch');

	

-- Test 3 - Double Square

delete from Curvas;

INSERT INTO Curvas(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('LINESTRING(0 0, 0 3, 3 3, 3 0, 0 0)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('LINESTRING(1 1, 1 2, 2 2, 2 1, 1 1)') );


INSERT INTO isolines_results(result, comments)
	VALUES (omtg_validateisolines('Curvas', 'geom'), 'Double Square');



-- Test 4 - Square and half square overlap

delete from Curvas;

INSERT INTO Curvas(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('LINESTRING(0 0, 0 3, 3 3, 0 0)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('LINESTRING(1 1, 1 2, 2 2, 2 1, 1 1)') );


INSERT INTO isolines_results(result, comments)
	VALUES (omtg_validateisolines('Curvas', 'geom'), 'Square and half square overlap');	



-- Test 5 - Swastika

delete from Curvas;

INSERT INTO Curvas(id, name, geom)
    VALUES (1, 'A', ST_GeomFromText('LINESTRING(0 0, 0 1, 1 1, 2 1, 2 2)') );

INSERT INTO Curvas(id, name, geom)
    VALUES (2, 'B', ST_GeomFromText('LINESTRING(0 2, 1 2, 1 1, 1 0, 2 0)') );


INSERT INTO isolines_results(result, comments)
	VALUES (omtg_validateisolines('Curvas', 'geom'), 'Swastika');


	

SELECT * FROM isolines_results;