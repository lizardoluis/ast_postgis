-- Create table Curvas
CREATE TABLE Curvas (
  id NUMERIC,
  name VARCHAR(100),
  cota NUMERIC,
  geom GEOMETRY(LINESTRING),
  CONSTRAINT pk_Curvas PRIMARY KEY (id)
);

-- Create the spatial index on geom column of Bairros
CREATE INDEX sidx_Curvas
  ON Curvas
  USING GIST (geom);