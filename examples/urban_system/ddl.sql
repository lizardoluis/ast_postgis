--
-- URBAN SYSTEM
--


-- Tables creation
CREATE TABLE City (
   id integer PRIMARY KEY,
   name varchar(50),
   geom_point ast_point,
   geom_boundary ast_polygon
);

CREATE TABLE Relief (
   altitude integer,
   geom ast_isoline
);

CREATE TABLE Block (
   zoning_type varchar(50),
   geom ast_polygon
);

CREATE TABLE Parcel (
   id integer PRIMARY KEY,
   size integer,
   geom ast_polygon
);

CREATE TABLE Industry (
   name varchar(50) PRIMARY KEY,
   production_type varchar(50),
   geom ast_point
);

CREATE TABLE Nature_Reserve (
   name varchar(50) PRIMARY KEY,
   geom ast_polygon
);

CREATE TABLE Neighborhood (
   id integer PRIMARY KEY,
   name varchar(50),
   geom ast_planarsubdivision
);

CREATE TABLE Thoroughfare (
   name varchar(50) PRIMARY KEY,
   speed_limit integer
);

CREATE TABLE Address (
   number integer,
   thoroughfare varchar(50)
   REFERENCES Thoroughfare(name),
   geom ast_point
);

CREATE TABLE Street_Segment (
   paviment varchar(50),
   thoroughfare varchar(50)
   REFERENCES Thoroughfare(name),
   geom ast_biline
);

CREATE TABLE Crossing (
   geom ast_node
);

--
-- Spatial aggregation between Block and Parcel
--
CREATE TRIGGER Aggr_Block_Parcel
   AFTER INSERT OR UPDATE OR DELETE ON Parcel
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_aggregation('Parcel', 'geom', 'Block', 'geom');

--
-- Spatial aggregation between City and Neighborhood
--
CREATE TRIGGER Aggr_Boundary_Neighborhood
   AFTER INSERT OR UPDATE OR DELETE ON Neighborhood
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_aggregation('Neighborhood', 'geom', 'City', 'geom_boundary');

--
-- Topological relationship between Industry and Parcel
--
CREATE TRIGGER Industry_Parcel_Within
   AFTER INSERT OR UPDATE ON Industry
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_topologicalrelationship('Industry', 'geom', 'Parcel', 'geom', 'within');

--
-- Topological relationship between Block and City
--
CREATE TRIGGER Block_City_Boundary_Within
   AFTER INSERT OR UPDATE ON Block
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_topologicalrelationship('Block', 'geom', 'City', 'geom_boundary', 'within');

--
-- Topological relationship between Parcel and  Address
--
CREATE TRIGGER Parcel_Address_Contains
   AFTER INSERT OR UPDATE ON Parcel
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_topologicalrelationship('Parcel', 'geom', 'Address', 'geom', 'contains');

--
-- Topological relationship between Nature_Reserve and Industry
--
CREATE TRIGGER Nature_Reserve_Industry_Distant
   AFTER INSERT OR UPDATE ON Nature_Reserve
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_topologicalrelationship('Nature_Reserve', 'geom', 'Industry', 'geom', 'distant', '800');

--
-- Arc-Node network between Street_Segment and Crossing
--
CREATE TRIGGER Street_Segment_Crossing_network
   AFTER INSERT OR UPDATE ON Street_Segment
   FOR EACH STATEMENT EXECUTE PROCEDURE
      ast_arcnodenetwork('Street_Segment', 'geom', 'Crossing', 'geom');
