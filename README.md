AST-PostGIS
===========

The AST-PostGIS is an extension for PostgreSQL/PostGIS that incorporates advanced spatial data types and implements spatial integrity constraints. The extension reduces the distance between the conceptual and the physical designs of spatial databases, by providing richer representations for geo-object and geo-field geometries. It also offers procedures to assert the consistency of spatial relationships during data updates. Such procedures can also be used before enforcing spatial integrity constraints for the first time.

Motivation
----------

Geometric primitives defined by OGC and ISO standards, implemented in most modern spatially-enabled database management systems (DBMS), are unable to capture the semantics of richer representation types, as found in current geographic data models. Moreover, relational DBMSs do not extend referential integrity mechanisms to cover spatial relationships and to support spatial integrity constraints. Rather, they usually assume that all spatial integrity checking will be carried out by the application, during the data entry process. This is not practical if the DBMS supports many applications, and can lead to redundant work.


Compatibility
=============

This module has been tested on:

* **Postgres 9.5**
* **PostGIS 2.2**

And requires the extensions:

* **postgis**


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

      postgres=# CREATE EXTENSION ast_postgis;

## Docker ##

Build the docker using:

```
docker build --rm -f Dockerfile -t ast_postgis:9.5-2.2-1.0 .
```

Run the server using:

```
docker run -v ${HOME}/pgdata:/var/lib/postgresql/data --net=host ast_postgis:9.5-2.2-1.0
```

Usage
=====

Here is explained how the extension works.


Advanced Spatial Data Types
---------------------------

Advanced Spatial Types are essentially the primitive geometric types of PostGIS together with a set of spatial integrity constraints to control their behavior. These new spatial data types can be handled in the same way the primitive types are, as they can be employed as column definition of tables, as variables in PL/pgSQL scripts or as arguments of functions or stored procedures. They can also be stored, retrieved and updated with the geometry processing functions of PostGIS.

The following table shows the eleven advanced spatial data types implemented by the extension and how they are mapped to the PostGIS types. These types are derived from the concepts of geo-objects and geo-fields classes of the [OMT-G data model](http://link.springer.com/article/10.1023/A:1011482030093).

<table>
   <thead>
      <th>Spatial Class</th>
      <th>Advanced spatial datatypes</th>
      <th>PostGIS Type</th>
   </thead>
   <tr>
      <td>Polygon</td>
      <td><code>ast_polygon</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Line</td>
      <td><code>ast_line</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Point</td>
      <td><code>ast_point</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Node</td>
      <td><code>ast_node</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Isoline</td>
      <td><code>ast_isoline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Planar subdivision</td>
      <td><code>ast_planarsubdivision</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Triangular Irregular Network (TIN)</td>
      <td><code>ast_tin</code></td>
      <td><code>geometry(polygon)</code></td>
   </tr>
   <tr>
      <td>Tesselation</td>
      <td><code>ast_tesselation</code></td>
      <td><code>raster</code></td>
   </tr>
   <tr>
      <td>Sample</td>
      <td><code>ast_sample</code></td>
      <td><code>geometry(point)</code></td>
   </tr>
   <tr>
      <td>Unidirectional line</td>
      <td><code>ast_uniline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
   <tr>
      <td>Bidirectional line</td>
      <td><code>ast_biline</code></td>
      <td><code>geometry(linestring)</code></td>
   </tr>
</table>


Trigger procedures for relationship integrity constraints
---------------------------------------------------------

The following procedures can be called by triggers to assert the consistency of spatial relationships, like topological relationship, arc-node and arc-arc networks or spatial aggregation.

<table>
   <thead>
      <th>Spatial Relationship</th>
      <th>Trigger Procedure</th>
   </thead>
   <tr>
      <td>Topological Relationship</td>
      <td><code>ast_topologicalrelationship(a_tbl, a_geom, b_tbl, b_geom, spatial_relation)</code></td>
   </tr>
   <tr>
      <td>Topological Relationship (distant, near)</td>
      <td><code>ast_topologicalrelationship(a_tbl, a_geom, b_tbl, b_geom, spatial_relation, distance)</code></td>
   </tr>
   <tr>
      <td>Arc-Node Network</td>
      <td><code>ast_arcnodenetwork(arc_tbl, arc_geom, node_tbl, node_geom)</code></td>
   </tr>
   <tr>
      <td>Arc-Arc Network</td>
      <td><code>ast_arcnodenetwork(arc_tbl, arc_geom)</code></td>
   </tr>
   <tr>
      <td>Spatial Aggregation</td>
      <td><code>ast_aggregation(part_tbl, part_geom, whole_tbl, whole_geom)</code></td>
   </tr>
</table>

The `spatial_relation` argument, which are passed as an argument to the topological relationship procedure, can be one of the following:

* contains
* containsproperly
* covers
* coveredby
* crosses
* disjoint
* distant
* intersects
* near
* overlaps
* touches
* within


Consistency check functions
---------------------------

The SQL functions listed in this section can be called to analyze the consistency of the spatial database before the initial enforcement of constraints. These functions return the state of the database (`true` = valid, `false` = invalid) and register, in the `ast_validation_log` table, the details of each inconsistency encountered.

<table>
   <thead>
      <th>Spatial Relationship</th>
      <th>Check functions</th>
   </thead>
   <tr>
      <td>Topological Relationship</td>
      <td><code>ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation text)</code></td>
    </tr>
    <tr>
      <td>Topological Relationship (near)</td>
      <td><code>ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real)</code></td>
   </tr>
   <tr>
      <td>Arc-Node Network</td>
      <td><code>ast_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text)</code></td>
   </tr>
   <tr>
      <td>Arc-Arc Network</td>
      <td><code>ast_isNetworkValid(arc_tbl text, arc_geom text)</code></td>
   </tr>
   <tr>
      <td>Spatial Aggregation</td>
      <td><code>ast_isSpatialAggregationValid(part_tbl text, part_geom text, whole_tbl text, whole_geom text)</code></td>
   </tr>
</table>


Use Case
========

This section shows an use case example (also available in the `examples` folder) intended to clarify the use of this extension.

Transportation system
---------------------

The following figure shows a schema fragment for a bus transportation network (nodes at bus stops and unidirectional arcs corresponding to route segments) that serves a set of school districts. A conventional class holds the attributes for the bus line. The schema embeds spatial integrity constraints for (1) the network relationship (each route segment must be related to two bus stops), (2) a “contains” relationship (school district cannot exists without a bus stop), and (3) the geometry of route segments and school districts (lines and polygons must be simple, i.e., with no self-intersections).

<img src="https://github.com/lizardoluis/ast_postgis/blob/master/examples/transportation_system/schema.png" alt="Transportation system schema" width="50%">

The implementation of this schema that uses the `ast_postgis` extension and considers all the spatial constraints is as follows:

      create table bus_line (
         line_number integer primary key,
         description varchar(50),
         operator varchar(50)
      );

      create table school_district (
         district_name varchar(50) primary key,
         school_capacity integer,
         geom ast_polygon
      );

      create table bus_stop (
         stop_id integer primary key,
         shelter_type varchar(50),
         geom ast_point
      );

      create table bus_route_segment (
         traverse_time real,
         segment_number integer,
         busline integer references bus_line (line_number),
         geom ast_uniline
      );

      -- school_district and bus_stop topological relationship constraints:
      create trigger school_district_contains_trigger
         after insert or update on school_district
         for each statement
         execute procedure ast_topologicalrelationship('school_district', 'geom', 'bus_stop', 'geom', 'contains');

      -- bus_route_segment and bus_stop arc-node network constraints:
      create trigger busroute_insert_update_trigger
         after insert or update on bus_route_segment
      	for each statement
      	execute procedure ast_arcnodenetwork('bus_route_segment', 'geom', 'bus_stop', 'geom');


License and Copyright
=====================

AST-PostGIS is released under a [MIT license](doc/LICENSE).

Copyright (c) 2016 Luís Eduardo Oliveira Lizardo.
