drop table if exists cities;

create table cities (
    id SERIAL,
    name VARCHAR(20),
    geom ast_PLANARSUBDIVISION
);

-- Test 1 - No gaps

delete from cities;

INSERT INTO cities(name, geom)
VALUES ('A', ST_GeomFromText('MULTIPOLYGON(((0 0, 0 1, 1 1, 1 0, 0 0)))') );

INSERT INTO cities(name, geom)
VALUES ('B', ST_GeomFromText('MULTIPOLYGON(((0 1, 0 2, 1 2, 1 1, 0 1)))') );

INSERT INTO cities(name, geom)
VALUES ('C', ST_GeomFromText('MULTIPOLYGON(((1 1, 1 2, 2 2, 2 1, 1 1)))') );

INSERT INTO cities(name, geom)
VALUES ('D', ST_GeomFromText('MULTIPOLYGON(((1 0, 1 1, 2 1, 2 0, 1 0)))') );

INSERT INTO cities(name, geom)
VALUES ('E', ST_GeomFromText('MULTIPOLYGON(((2 0, 2 2, 3 2, 3 0, 2 0)))') );


-- Test 3 - No gaps - 1 overlap

delete from cities;

INSERT INTO cities(name, geom)
VALUES ('A', ST_GeomFromText('MULTIPOLYGON(((0 0, 0 1, 1 1, 1 0, 0 0)))') );

INSERT INTO cities(name, geom)
VALUES ('B', ST_GeomFromText('MULTIPOLYGON(((0 1, 0 2, 1 2, 1 1, 0 1)))') );

INSERT INTO cities(name, geom)
VALUES ('C', ST_GeomFromText('MULTIPOLYGON(((1 1, 1 2, 2 2, 2 1, 1 1)))') );

INSERT INTO cities(name, geom)
VALUES ('D', ST_GeomFromText('MULTIPOLYGON(((1 0, 1 1, 2 1, 2 0, 1 0)))') );

INSERT INTO cities(name, geom)
VALUES ('F', ST_GeomFromText('MULTIPOLYGON(((1.5 1.5, 1.5 2.5, 2.5 2.5, 2.5 1.5, 1.5 1.5)))') );
