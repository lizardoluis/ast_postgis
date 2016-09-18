drop table tablea;
create table tablea (
   id integer primary key,
   geom omtg_polygon
);

drop table tableb;
create table tableb (
   id integer primary key,
   geom omtg_polygon
);

CREATE TRIGGER aggregation_trigger
AFTER INSERT OR UPDATE OR DELETE ON tableb
   FOR EACH STATEMENT
   EXECUTE PROCEDURE omtg_aggregation('tableb', 'geom', 'tablea', 'geom');



delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('POLYGON((1 1, 1 4, 4 4, 4 1, 1 1))') );

delete from tableb;
INSERT INTO tableb(id, geom) VALUES
   (1, ST_GeomFromText('POLYGON((1 3, 1 4, 4 4, 4 3, 1 3))') ),
   (2, ST_GeomFromText('POLYGON((2 2, 2 3, 3 3, 3 2, 2 2))') ),
   (3, ST_GeomFromText('POLYGON((1 1, 1 3, 2 3, 2 1, 1 1))') ),
   (4, ST_GeomFromText('POLYGON((2 1, 2 2, 3 2, 3 3, 4 3, 4 1, 2 1))') );



   create table tabled (
      id integer primary key,
      geom omtg_polygon
   );

   delete from tabled;
   INSERT INTO tabled(id, geom) VALUES
      (1, ST_GeomFromText('POLYGON((1 3, 1 4, 4 4, 4 3, 1 3))') ),
      (2, ST_GeomFromText('POLYGON((2 2, 2 3, 3 3, 3 2, 2 2))') ),
      (3, ST_GeomFromText('POLYGON((1 1, 1 3, 2 3, 2 1, 1 1))') ),
      (4, ST_GeomFromText('POLYGON((2 1, 2 2, 3 2, 3 3, 4 3, 4 1, 2 1))') ),
      (5, ST_GeomFromText('POLYGON((0.5 0.5, 0.5 3.5, 2.5 3.5, 2.5 0.5, 0.5 0.5))') );


   SELECT *
FROM tablea AS a
LEFT JOIN tableb AS b
ON NOT ST_COVERS(a.geom, b.geom)
WHERE b.geom IS NOT NULL



-- 1. Pi intersection W = Pi, for all i such as 0 <= i <= n
SELECT EXISTS (
      select 1
      from tablec c
      where c.CTID not in
      (
         select b.CTID
         from tablea a, tablec b
         where ST_Equals(ST_Intersection(a.geom, b.geom), b.geom)
      )
   );

-- 3. ((Pi touch Pj) or (Pi disjoint Pj)) = T for all i, j such as i != j
select *
from tabled b1, tabled b2
where b1.ctid < b2.ctid and
(not st_touches(b1.geom, b2.geom) and not st_disjoint(b1.geom, b2.geom));

--2. (W intersection all P) = W
WITH union_geom AS (
	select st_union(geom) as geom
	from tableb
)
select st_equals(a.geom, b.geom)
from tablea a, union_geom b;

WITH union_geom AS (
	select st_union(geom) as geom
	from tablec
)
select st_equals(a.geom, b.geom)
from tablea a left join union_geom b
on st_intersects(a.geom, b.geom);



delete from tablea;
INSERT INTO tablea(id, geom) VALUES
   (1, ST_GeomFromText('POLYGON((1 1, 1 4, 4 4, 4 1, 1 1))') ),
   (2, ST_GeomFromText('POLYGON((5 5, 5 6, 6 6, 6 5, 5 5))') );

delete from tableb;
INSERT INTO tableb(id, geom) VALUES
      (1, ST_GeomFromText('POLYGON((1 3, 1 4, 4 4, 4 3, 1 3))') ),
      (2, ST_GeomFromText('POLYGON((2 2, 2 3, 3 3, 3 2, 2 2))') ),
      (3, ST_GeomFromText('POLYGON((1 1, 1 3, 2 3, 2 1, 1 1))') ),
      (4, ST_GeomFromText('POLYGON((2 1, 2 2, 3 2, 3 3, 4 3, 4 1, 2 1))') ),
      (5, ST_GeomFromText('POLYGON((5 5, 5 6, 6 6, 6 5, 5 5))') );
