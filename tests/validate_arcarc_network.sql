DROP TABLE IF EXISTS arc_arc_network_results;
CREATE TABLE arc_arc_network_results (
  id SERIAL,
  result boolean,
  comments TEXT
);


-- Test 1 - Valid

delete from Trecho;

INSERT INTO Trecho(id, geom)
    VALUES (10, ST_GeomFromText('LINESTRING(0 1, 0.5 1.0, 1 1)') );

INSERT INTO Trecho(id, geom)
    VALUES (11, ST_GeomFromText('LINESTRING(1 2, 1.0 1.5, 1 1)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (12, ST_GeomFromText('LINESTRING(1 1, 1.0 0.5, 1 0)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (13, ST_GeomFromText('LINESTRING(1 1, 1.5 1.0, 2 1)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (14, ST_GeomFromText('LINESTRING(1 0, 1.5 0.0, 2 0)') );



INSERT INTO arc_arc_network_results(result, comments)
	VALUES (omtg_arcarcnetwork('Trecho', 'geom'), 'Valid');


	-- Test 2 - Valid

delete from Trecho;

INSERT INTO Trecho(id, geom)
    VALUES (10, ST_GeomFromText('LINESTRING(0 1, 0.5 1.0, 1 1)') );

INSERT INTO Trecho(id, geom)
    VALUES (11, ST_GeomFromText('LINESTRING(1 2, 1.0 1.5, 1 1)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (12, ST_GeomFromText('LINESTRING(1 1, 1.0 0.5, 1 0)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (13, ST_GeomFromText('LINESTRING(1 1, 1.5 1.0, 2 1)') );
    
INSERT INTO Trecho(id, geom)
    VALUES (14, ST_GeomFromText('LINESTRING(1 0, 1.5 0.0, 2 0)') );

INSERT INTO Trecho(id, geom)
    VALUES (15, ST_GeomFromText('LINESTRING(10 10, 10.5 10.0, 20 10)') );



INSERT INTO arc_arc_network_results(result, comments)
	VALUES (omtg_arcarcnetwork('Trecho', 'geom'), 'Trecho desconexo');


SELECT * FROM arc_arc_network_results;