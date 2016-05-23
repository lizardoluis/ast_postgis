-- Create table Temperature
CREATE TABLE Temperature (
  id NUMERIC,
  name VARCHAR(100),
  grades NUMERIC,
  geom GEOMETRY(POLYGON),
  CONSTRAINT pk_Temperature PRIMARY KEY (id)
);

-- Create the spatial index on geom column of Temperature
CREATE INDEX Temperature_IDX
  ON Temperature
  USING GIST (geom);