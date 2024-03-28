drop table tablea;
create table tablea (
   id integer primary key,
   geom ast_polygon
);

drop table tableb;
create table tableb (
   id integer primary key,
   geom ast_polygon
);

delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('MULTIPOLYGON(((1 0, 1 1, 2 1, 2 0, 1 0)))') ),
   (2, ST_GeomFromText('MULTIPOLYGON(((4 0, 4 1, 5 1, 5 0, 4 0)))') ),
   (3, ST_GeomFromText('MULTIPOLYGON(((6 0, 6 1, 7 1, 7 0, 6 0)))') );



delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (10, ST_GeomFromText('MULTIPOLYGON(((0 0, 0 1, 1 1, 1 0, 0 0)))') ),
   (20, ST_GeomFromText('MULTIPOLYGON(((3 0, 3 1, 4 1, 4 0, 3 0)))') );



select not exists(
      select 1
      from tablea as a
      left join tableb as b
      on st_touches(a.geom, b.geom)
      where b.geom is null
   );
