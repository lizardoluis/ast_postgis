create table school (
   id integer primary key,
   geom ast_point
);

create table gas_station (
   id integer primary key,
   geom ast_point
);

CREATE TRIGGER distant_trigger
AFTER INSERT OR UPDATE ON school
   FOR EACH STATEMENT
   EXECUTE PROCEDURE ast_spatialrelationship('school', 'geom', 'gas_station', 'geom', 'distant', 2);


delete from school;
INSERT INTO school(id, geom) VALUES
   (10, ST_GeomFromText('POINT(0 0)')),
	(11, ST_GeomFromText('POINT(10 0)'));


delete from gas_station;
INSERT INTO gas_station(id, geom) VALUES
	(3, ST_GeomFromText('POINT(3 0)')),
	(4, ST_GeomFromText('POINT(4 0)')),
	(5, ST_GeomFromText('POINT(5 0)'));
   (6, ST_GeomFromText('POINT(6 0)')),
   (7, ST_GeomFromText('POINT(7 0)'));
