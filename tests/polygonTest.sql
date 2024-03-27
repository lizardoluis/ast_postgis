drop table if exists cities;

create table cities (
    id SERIAL,
    name VARCHAR(20),
    geom ast_POLYGON
);

INSERT INTO cities(name, geom)
VALUES ('A', ST_GeomFromText('MULTIPOLYGON(((0 0, 0 1, 1 1, 1 0, 0 0)))') );

INSERT INTO cities(name, geom)
VALUES ('B', ST_GeomFromText('MULTIPOLYGON(((1 2, 1 3, 2 3, 2 2, 1 2)))') );

INSERT INTO cities(name, geom)
VALUES ('c', ST_GeomFromText('MULTIPOLYGON(((0.5 0.5, 0 1, 1 1, 1 0, 0.5 0.5)))') );
