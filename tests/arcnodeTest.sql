drop table node;
CREATE TABLE node (
	id serial primary key,
	geom omtg_node
);

drop table arc;
CREATE TABLE arc (
	id serial primary key,
	geom omtg_uniline
   spatial_constraint(network, node(geom))
);

CREATE TRIGGER check_arcnode_trigger
AFTER INSERT OR UPDATE OR DELETE ON arc
	FOR EACH STATEMENT
	EXECUTE PROCEDURE omtg_arcnodenetwork('arc', 'geom', 'node', 'geom');

INSERT INTO node(geom)
	VALUES (ST_GeomFromText('POINT(0 1)')),
	(ST_GeomFromText('POINT(1 1)')),
	(ST_GeomFromText('POINT(1 2)')),
	(ST_GeomFromText('POINT(2 1)')),
	(ST_GeomFromText('POINT(1 0)')),
	(ST_GeomFromText('POINT(2 0)'));

INSERT INTO arc(geom)
    VALUES (ST_GeomFromText('LINESTRING(0 1, 0.5 1.0, 1 1)') ),
    (ST_GeomFromText('LINESTRING(1 2, 1.0 1.5, 1 1)') ),
    (ST_GeomFromText('LINESTRING(1 1, 1.0 0.5, 1 0)') ),
    (ST_GeomFromText('LINESTRING(1 1, 1.5 1.0, 2 1)') ),
    (ST_GeomFromText('LINESTRING(1 0, 1.5 0.0, 2 0)') );
