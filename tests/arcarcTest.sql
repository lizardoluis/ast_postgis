drop table arc;
create table arc (
	id integer,
	geom omtg_biline
);

create trigger arcarc_trigger
AFTER INSERT OR UPDATE OR DELETE ON arc
	FOR EACH STATEMENT
	EXECUTE PROCEDURE omtg_arcarcnetwork('arc', 'geom');

delete from arc;
insert into arc (id, geom) values
	(1, ST_GeomFromText('LINESTRING(1 1, 1 2)')),
	(2, ST_GeomFromText('LINESTRING(1 1, 2 1)')),
	(3, ST_GeomFromText('LINESTRING(2 1, 2 2)')),
	(4, ST_GeomFromText('LINESTRING(1 2, 3 2)')),
	(6, ST_GeomFromText('LINESTRING(1 3, 3 3)'));
