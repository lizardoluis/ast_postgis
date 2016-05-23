-- Create table Temperature
CREATE TABLE Cruzamento (
  id NUMERIC,
  geom GEOMETRY(POINT),
  CONSTRAINT id_cruzamento PRIMARY KEY (id)
);

CREATE TABLE Trecho (
  id NUMERIC,
  geom GEOMETRY(LINESTRING),
  CONSTRAINT id_trecho PRIMARY KEY (id)
);

-- Create the spatial index on geom column of Temperature
CREATE INDEX Cruzamento_IDX
  ON Cruzamento
  USING GIST (geom);

CREATE INDEX Trecho_IDX
  ON Trecho
  USING GIST (geom);