DROP TABLE IF EXISTS arc_node_network_results;
CREATE TABLE arc_node_network_results (
  id SERIAL,
  result boolean,
  comments TEXT
);


-- Test 1 - Valid

delete from Cruzamento;


INSERT INTO Cruzamento(id, geom)
    VALUES (1, ST_GeomFromText('POINT(0 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (2, ST_GeomFromText('POINT(1 2)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (3, ST_GeomFromText('POINT(1 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (4, ST_GeomFromText('POINT(1 0)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (5, ST_GeomFromText('POINT(2 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (6, ST_GeomFromText('POINT(2 0)') );


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



INSERT INTO arc_node_network_results(result, comments)
	VALUES (omtg_arcnodenetwork('Trecho', 'Cruzamento', 'geom', 'geom'), 'Valid');




-- Test 2 - Extra point

delete from Cruzamento;


INSERT INTO Cruzamento(id, geom)
    VALUES (1, ST_GeomFromText('POINT(0 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (2, ST_GeomFromText('POINT(1 2)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (3, ST_GeomFromText('POINT(1 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (4, ST_GeomFromText('POINT(1 0)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (5, ST_GeomFromText('POINT(2 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (6, ST_GeomFromText('POINT(2 0)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (7, ST_GeomFromText('POINT(0 0)') );

    
INSERT INTO Cruzamento(id, geom)
    VALUES (8, ST_GeomFromText('POINT(10 0)') );


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



INSERT INTO arc_node_network_results(result, comments)
	VALUES (omtg_arcnodenetwork('Trecho', 'Cruzamento', 'geom', 'geom'), 'Extra point');



-- Test 3 - Extra arc

delete from Cruzamento;


INSERT INTO Cruzamento(id, geom)
    VALUES (1, ST_GeomFromText('POINT(0 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (2, ST_GeomFromText('POINT(1 2)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (3, ST_GeomFromText('POINT(1 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (4, ST_GeomFromText('POINT(1 0)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (5, ST_GeomFromText('POINT(2 1)') );

INSERT INTO Cruzamento(id, geom)
    VALUES (6, ST_GeomFromText('POINT(2 0)') );


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
    VALUES (15, ST_GeomFromText('LINESTRING(2 1, 10 10, 20 10)') );
    

INSERT INTO arc_node_network_results(result, comments)
	VALUES (omtg_arcnodenetwork('Trecho', 'Cruzamento', 'geom', 'geom'), 'Extra arc');
	

SELECT * FROM arc_node_network_results;