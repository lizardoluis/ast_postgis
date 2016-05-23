CREATE TABLE Curvas (
  id SERIAL,
  name VARCHAR(50),
  geom OMTG_ISOLINE,
  CONSTRAINT pk_Temperature PRIMARY KEY (id)
);

-- Create the spatial index on geom column of Temperature
CREATE INDEX Curvas_IDX
  ON Curvas
  USING GIST (geom);



-- Test 1 - Separated

delete from Curvas;

INSERT INTO Curvas(name, geom)
    VALUES ( 'A', ST_GeomFromText('LINESTRING(0 0, 1 1, 2 0, 3 0)') );

INSERT INTO Curvas(name, geom)
    VALUES ( 'B', ST_GeomFromText('LINESTRING(0 1, 1 2, 2 1, 3 1)') );

INSERT INTO Curvas(name, geom)
    VALUES ( 'C', ST_GeomFromText('LINESTRING(0 2, 1 3, 2 2, 3 2)') );




-- Test 2 - Separated with touch

delete from Curvas;

INSERT INTO Curvas(name, geom)
    VALUES ( 'A', ST_GeomFromText('LINESTRING(0 0, 1 0, 2 1, 3 0)') );

INSERT INTO Curvas(name, geom)
    VALUES ( 'B', ST_GeomFromText('LINESTRING(0 1, 1 1, 2 2, 3 1)') );

INSERT INTO Curvas(name, geom)
    VALUES ( 'C', ST_GeomFromText('LINESTRING(0 2, 1 2, 2 2, 3 2)') );


-- Test 3 - Double Square

delete from Curvas;

INSERT INTO Curvas( name, geom)
    VALUES ('A', ST_GeomFromText('LINESTRING(0 0, 0 3, 3 3, 3 0, 0 0)') );

INSERT INTO Curvas(name, geom)
    VALUES ('B', ST_GeomFromText('LINESTRING(1 1, 1 2, 2 2, 2 1, 1 1)') );


-- Test 4 - Square and half square overlap

delete from Curvas;

INSERT INTO Curvas(name, geom)
    VALUES ('A', ST_GeomFromText('LINESTRING(0 0, 0 3, 3 3, 0 0)') );

INSERT INTO Curvas(name, geom)
    VALUES ( 'B', ST_GeomFromText('LINESTRING(1 1, 1 2, 2 2, 2 1, 1 1)') );


-- Test 5 - Swastika

delete from Curvas;

INSERT INTO Curvas(name, geom)
    VALUES ('A', ST_GeomFromText('LINESTRING(0 0, 0 1, 1 1, 2 1, 2 2)') );

INSERT INTO Curvas(name, geom)
    VALUES ('B', ST_GeomFromText('LINESTRING(0 2, 1 2, 1 1, 1 0, 2 0)') );
