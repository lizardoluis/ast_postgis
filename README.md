Overview
========

This PostgreSQL extension incorporates into PostgreSQL advanced spatial data types and also spatial integrity constraints, that are defined in [OMT-G](http://homepages.dcc.ufmg.br/~clodoveu/DocuWiki/doku.php?id=omtg), an object-oriented data model for geographic applications.

Motivation
----------

Although relational database management systems already offer several resources and features to store and manage spatial data, the semantic gap between the conceptual models and their implementaion in RDBMS is still big. RDBMSs lack support for semantically rich spatial datatype and spatial integrity constraints. Those constraints differ from those used on relational data, because they do not make use of foreign keys to relate two tables. Usually the spatial relationships are made using the spatial characteristics of the data. For instance, 'Schools must be 500 meters away from gas stations'.


Compatibility
=============

This module has been tested on:

* **Postgres 9.5**
* **PostGIS 2.2**

And requires the extensions:

* **postgis**
* **postgis_topology**



Build and Install
=================

## From source ##

If you aren't using the `pg_config` on your path (or don't have it on your path), specify the correct one to build against:

        PG_CONFIG=/Library/PostgreSQL/9.5/bin/pg_config make

Or to build with what's on your path, just:

        make

Then install:

       sudo make install

After you've built and installed the artifacts, fire up `psql`:

      postgres=# CREATE EXTENSION postgis_omtg;
      CREATE EXTENSION



Usage
=====

Here is explained how this extension works.

Domains
-------

The following table shows all the OMT-G domains implemented in the extension and how they are mapped to the PostGIS:

<table>
   <thead>
      <th>OMT-G Class</th>
      <th>Advanced spatial datatypes</th>
      <th>PostGIS Type</th>
   </thead>
   <tr>
      <td>Polygon</td>
      <td><code>omtg_polygon</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Line</td>
      <td><code>omtg_line</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Point</td>
      <td><code>omtg_point</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Node</td>
      <td><code>omtg_node</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Isoline</td>
      <td><code>omtg_isoline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Planar subdivision</td>
      <td><code>omtg_planarsubdivision</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Triangular Irregular Network (TIN)</td>
      <td><code>omtg_tin</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Tesselation</td>
      <td><code>omtg_tesselation</code></td>
      <td><code>raster</code></td>
   </tr>
   <tr>
      <td>Sample</td>
      <td><code>omtg_sample</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Unidirectional line</td>
      <td><code>omtg_uniline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Bidirectional line</td>
      <td><code>omtg_biline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
</table>

Spatial relationships trigger functions
---------------------------------------

The trigger functions used for spatial relationship constraints are:

<table>
   <thead>
      <th>OMT-G Relationship</th>
      <th>Trigger Function</th>
   </thead>
   <tr>
      <td>Topological Relationship</td>
      <td><code>omtg_topologicalrelationship(a_tbl, a_geom, b_tbl, b_geom, spatial_relation)</code></td>
   </tr>
   <tr>
      <td>Topological Relationship (near)</td>
      <td><code>omtg_topologicalrelationship(a_tbl, a_geom, b_tbl, b_geom, distance)</code></td>
   </tr>
   <tr>
      <td>Arc-Node Network</td>
      <td><code>omtg_arcnodenetwork(arc_tbl, arc_geom, node_tbl, node_geom)</code></td>
   </tr>
   <tr>
      <td>Arc-Arc Network</td>
      <td><code>omtg_arcnodenetwork(arc_tbl, arc_geom)</code></td>
   </tr>
   <tr>
      <td>Aggregation</td>
      <td><code>omtg_aggregation(part_tbl, part_geom, whole_tbl, whole_geom)</code></td>
   </tr>
</table>

The available `spatial_relations` are:

* contains
* containsproperly
* covers
* coveredby
* crosses
* disjoint
* intersects
* overlaps
* touches
* within

The next section shows an use case example (also available in the `examples` folder) intended to clarify the use of this extension.


Use Case
========

Transportation system
---------------------

The following figure shows a schema fragment for a bus transportation network (nodes at bus stops and unidirectional arcs corresponding to route segments) that serves a set of school districts. A conventional class holds the attributes for the bus line. The schema embeds spatial integrity constraints for (1) the network relationship (each route segment must be related to two bus stops), (2) a “contains” relationship (school district cannot exists without a bus stop), and (3) the geometry of route segments and school districts (lines and polygons must be simple, i.e., with no self-intersections).

<img src="https://github.com/lizardoluis/postgis_omtg/blob/master/examples/transportation_system/squema.png" alt="Transportation system schema" width="50%">

The implementation of this schema that uses the `postgis_omtg` extension and considerers all the spatial constraints is as follows:

      create table bus_line (
         line_number integer primary key,
         description varchar(50),
         operator varchar(50)
      );

      create table school_district (
         district_name varchar(50) primary key,
         school_capacity integer,
         geom omtg_polygon
      );

      create table bus_stop (
         stop_id integer primary key,
         shelter_type varchar(50),
         geom omtg_point
      );

      create table bus_route_segment (
         traverse_time real,
         segment_number integer,
         busline integer references bus_line (line_number),
         geom omtg_uniline
      );

      -- School_district and bus_stop topological relationship constraints:
      CREATE TRIGGER school_district_contains_trigger
         AFTER INSERT OR UPDATE ON school_district
         FOR EACH STATEMENT
         EXECUTE PROCEDURE omtg_topologicalrelationship('school_district', 'geom', 'bus_stop', 'geom', 'contains');


License and Copyright
=====================

postgis_omtg is released under a [MIT license](doc/LICENSE).

Copyright (c) 2016 Luis Eduardo Oliveira Lizardo.
