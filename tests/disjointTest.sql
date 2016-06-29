create table tablea (
   id integer primary key,
   geom omtg_polygon
);

create table tableb (
   id integer primary key,
   geom omtg_point
);

delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('POLYGON((0 0, 0 1, 1 1, 1 0, 0 0))') ),
   (2, ST_GeomFromText('POLYGON((1 0, 1 1, 2 1, 2 0, 1 0))') );


delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (10, ST_GeomFromText('POINT(0.5 0.5)'));


   select not exists (
         select 1
         from tablea as a
         left join tableb as b
         on st_disjoint(a.geom, b.geom)
         where b.geom is null
         );
