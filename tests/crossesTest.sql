drop table tablea;
drop table tableb;

create table tablea (
   id integer primary key,
   geom ast_line
);

drop table tableb;
create table tableb (
   id integer primary key,
   geom ast_polygon
);

delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('LINESTRING(1 1, 5 1)') ),
   (2, ST_GeomFromText('LINESTRING(1 3, 5 3)') );


delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (10, ST_GeomFromText('MULTIPOLYGON(((0 0, 0 2, 2 2, 2 0, 0 0)))') ),
   (20, ST_GeomFromText('MULTIPOLYGON(((2 0, 2 2, 4 2, 4 0, 2 0)))') );


   CREATE TRIGGER crosses_trigger
   AFTER INSERT OR UPDATE ON tablea
   	FOR EACH STATEMENT
   	EXECUTE PROCEDURE ast_spatialrelationship('tablea', 'geom', 'tableb', 'geom', 'crosses');


   select not exists(
      select 1
      from tablea as a
      left join tableb as b
      on st_crosses(a.geom, b.geom)
      where b.geom is null
   );
