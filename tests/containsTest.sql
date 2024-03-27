drop table tablea;
create table tablea (
   id integer primary key,
   geom ast_polygon
);

drop table tableb;
create table tableb (
   id integer primary key,
   geom ast_point
);

delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('MULTIPOLYGON(((0 0, 0 1, 1 1, 1 0, 0 0)))') ),
   (2, ST_GeomFromText('MULTIPOLYGON(((1 0, 1 1, 2 1, 2 0, 1 0)))') ),
   (3, ST_GeomFromText('MULTIPOLYGON(((1 1, 1 2, 2 2, 2 1, 1 1)))') );

delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (10, ST_GeomFromText('POINT(0.5 0.5)')),
	(11, ST_GeomFromText('POINT(1.5 0.5)')),
	(12, ST_GeomFromText('POINT(1.7 0.2)'));


   select a.id
   from tablea as a
   left join tableb as b
   on st_contains(a.geom, b.geom)
   where b.geom is null;
