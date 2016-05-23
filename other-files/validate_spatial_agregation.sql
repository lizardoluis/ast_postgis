DROP TABLE IF EXISTS spatial_agregation_results;
CREATE TABLE spatial_agregation_results (
  id SERIAL,
  result boolean,
  comments TEXT
);

delete from Quadra;

INSERT INTO Quadra(id_quadra, geom)
    VALUES (1, ST_GeomFromText('POLYGON((0 0, 0 2, 3 2, 3 0, 0 0))') );



-- Test 1 - No gaps no overlap


delete from Lote;


INSERT INTO Lote(id_lote, geom)
    VALUES (1, ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (2, ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (3, ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Lote(id_lote, geom)
    VALUES (4, ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (5, ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO spatial_agregation_results(result, comments)
	VALUES ( (select omtg_validatespatialagregationrel(q.geom, 'Lote', 'geom') from Quadra as q), 'No gaps no overlap');



-- Test 2 - Lotes With 1 gaps


delete from Lote;


INSERT INTO Lote(id_lote, geom)
    VALUES (1, ST_GeomFromText('POLYGON((0 0, 0 1, 0.5 1, 1 0.5, 1 0, 0 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (2, ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (3, ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Lote(id_lote, geom)
    VALUES (4, ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (5, ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO spatial_agregation_results(result, comments)
	VALUES ( (select omtg_validatespatialagregationrel(q.geom, 'Lote', 'geom') from Quadra as q), 'Lotes With 1 gaps');



-- Test 3 - Lotes With 2 gaps


delete from Lote;


INSERT INTO Lote(id_lote, geom)
    VALUES (1, ST_GeomFromText('POLYGON((0 0, 0 1, 0.5 1, 1 0.5, 1 0, 0 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (2, ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (3, ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1.5, 1.5 1, 1 1))') );
    
INSERT INTO Lote(id_lote, geom)
    VALUES (4, ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (5, ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO spatial_agregation_results(result, comments)
	VALUES ( (select omtg_validatespatialagregationrel(q.geom, 'Lote', 'geom') from Quadra as q), 'Lotes With 2 gaps');




-- Test 4 - Lotes With 1 overlap


delete from Lote;


INSERT INTO Lote(id_lote, geom)
    VALUES (1, ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (2, ST_GeomFromText('POLYGON((0 1, 0 2, 1 2, 1 1, 0 1))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (3, ST_GeomFromText('POLYGON((1 1, 1 2, 2 2, 2 1, 1 1))') );
    
INSERT INTO Lote(id_lote, geom)
    VALUES (4, ST_GeomFromText('POLYGON((1 0, 1 1, 1.5 1, 2 1.5, 2 1, 2 0, 1 0))') );

INSERT INTO Lote(id_lote, geom)
    VALUES (5, ST_GeomFromText('POLYGON((2 0, 2 2, 3 2, 3 0, 2 0))') );


INSERT INTO spatial_agregation_results(result, comments)
	VALUES ( (select omtg_validatespatialagregationrel(q.geom, 'Lote', 'geom') from Quadra as q), 'Lotes with 1 overlap');




SELECT * FROM spatial_agregation_results;