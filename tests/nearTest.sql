drop table tablea;
create table tablea (
   id integer primary key,
   geom ast_point
);

drop table tableb;
create table tableb (
   id integer primary key,
   geom ast_point
);

delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (10, ST_GeomFromText('POINT(0 0)')),
	(11, ST_GeomFromText('POINT(10 0)'));


delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('POINT(1 0)')),
	(2, ST_GeomFromText('POINT(2 0)')),
	(3, ST_GeomFromText('POINT(3 0)')),
	(4, ST_GeomFromText('POINT(4 0)')),
	(5, ST_GeomFromText('POINT(5 0)'));

delete from tablec;
   INSERT INTO tablec(id, geom)
      VALUES (ST_GeomFromText('LINESTRING(0 0, 20 0)') );


select exists(
   select 1
   from tablea as a
   left join tableb as b
   on st_dwithin(a.geom, b.geom, 0.5)
   where b.geom is not null
);
