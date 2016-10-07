--
-- This function checks if all the elements of b_tbl is within the buffer
-- distance from the elements of a_tbl.
--
create function ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real)
   returns boolean as $$
declare
   pkColumn text := _ast_getPrimaryKeyColumn(b_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'AST_isTopologicalRelationshipValid function error.'
         using detail = 'Table passed as first parameter does not have primary key and without it is not possible to validate the topological relationship.';
      return false;
   end if;

   if not _ast_isOMTGDomain(a_tbl, a_geom) or not _ast_isOMTGDomain(b_tbl, b_geom) then
      raise exception 'AST_isTopologicalRelationshipValid error! Invalid parameters.'
         using detail = 'Usage: SELECT ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real);';
   end if;

   execute 'insert into ast_violation_log (time, type, description) (
      select now(),
            ''Near buffer violation'',
            ''Table ´'|| b_tbl ||'´ tuple with primary key ´''|| b.'|| pkColumn ||' ||''´ is outside the buffer distance of ´'|| dist ||'´ from table ´'|| a_tbl ||'´.''
         from '|| b_tbl ||' b
         where b.'|| pkColumn ||' not in
         (
            select distinct b.'|| pkColumn ||'
            from '|| a_tbl ||' a, '|| b_tbl ||' b
            where st_dwithin(a.'|| a_geom ||', b.'|| b_geom ||', '|| dist ||')
         )
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the topolotical relationship is valid.
--
create function ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation text)
   returns boolean as $$
declare
   pkColumn text := _ast_getPrimaryKeyColumn(a_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'AST_isTopologicalRelationshipValid function error.'
         using detail = 'Table passed as first parameter does not have primary key and without it is not possible to validate the topological relationship.';
   end if;

   if not _ast_isOMTGDomain(a_tbl, a_geom) or not _ast_isOMTGDomain(b_tbl, b_geom) or not _ast_isTopologicalRelationship(relation)  then
      raise exception 'AST_isTopologicalRelationshipValid error! Invalid parameters.'
         using detail = 'Usage: SELECT ast_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation text);';
   end if;

   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
               ''Topological relationship violation'',
               ''Topological relationship ('|| relation ||') between ´'|| a_tbl ||'´ and ´'|| b_tbl ||'´ is violated by the tuple of ´'|| a_tbl ||'´ with primary key ´''|| a.'|| pkColumn ||' ||''´.''
         from '|| a_tbl ||' a
         where a.'|| pkColumn ||' not in
         (
            select distinct a.'|| pkColumn ||'
            from '|| a_tbl ||' a, '|| b_tbl ||' b
            where st_'|| relation ||'(a.'|| a_geom ||', b.'|| b_geom ||')
         )
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the arc-node network is valid.
--
create function ast_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text)
   returns boolean as $$
declare
   pkColumn text := _ast_getPrimaryKeyColumn(arc_tbl);
   res1 boolean;
   res2 boolean;
begin

   if pkColumn = '' then
      raise exception 'AST_isNetworkValid function error.'
         using detail = 'ARC table does not have primary key and without it is not possible to validate the network.';
   end if;

   if not _ast_isOMTGDomain(arc_tbl, arc_geom) then
      raise exception 'AST_isNetworkValid error! Invalid parameters.'
         using detail = 'Usage: SELECT ast_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text);';
   end if;

   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
               ''Arc-Node Network violation'',
               ''Start point of arc with primary key ´''|| '|| pkColumn ||' ||''´ does not intersect any node.''
         from '|| arc_tbl ||'
         where '|| pkColumn ||' not in (
         	select distinct a.'|| pkColumn ||'
         	from '|| arc_tbl ||' a, '|| node_tbl ||' n
         	where st_intersects(st_startpoint(a.'|| arc_geom ||'), n.'|| node_geom ||')
         )
      ) returning true;' into res1;

   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
               ''Arc-Node Network violation'',
               ''End point of arc with primary key ´''|| '|| pkColumn ||' ||''´ does not intersect any node.''
         from '|| arc_tbl ||'
         where '|| pkColumn ||' not in (
         	select distinct a.'|| pkColumn ||'
         	from '|| arc_tbl ||' a, '|| node_tbl ||' n
         	where st_intersects(st_endpoint(a.'|| arc_geom ||'), n.'|| node_geom ||')
         )
      ) returning true;' into res2;

   if res1 or res2 then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the arc-arc network is valid.
--
create function ast_isNetworkValid(arc_tbl text, arc_geom text)
   returns boolean as $$
declare
   pkColumn text := _ast_getPrimaryKeyColumn(arc_tbl);
   res boolean;
begin

   if pkColumn = '' then
      raise exception 'AST_isNetworkValid function error.'
         using detail = 'ARC table does not have primary key and without it is not possible to validate the network.';
   end if;

   if not _ast_isOMTGDomain(arc_tbl, arc_geom) then
      raise exception 'AST_isNetworkValid error! Invalid parameters.'
         using detail = 'Usage: SELECT ast_isNetworkValid(arc_tbl text, arc_geom text);';
   end if;

   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
               ''Arc-Arc Network violation'',
               ''Arcs ´''|| a.'|| pkColumn ||' ||''´ and ´''|| b.'|| pkColumn ||' ||''´ intersect each other on middle points.''
               from '|| arc_tbl ||' as a, '|| arc_tbl ||' as b
            where a.ctid < b.ctid
            	and st_intersects(a.'|| arc_geom ||', b.'|| arc_geom ||')
            	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_startpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_startpoint(b.'|| arc_geom ||'))
            	and not st_intersects(st_endpoint(a.'|| arc_geom ||'), st_endpoint(b.'|| arc_geom ||'))
      ) returning true;' into res;

   if res then return false;
   else return true;
   end if;
end;
$$  language plpgsql;



--
-- This function checks if the spatial aggregation is valid.
--
create function ast_isSpatialAggregationValid(part_tbl text, part_geom text, whole_tbl text, whole_geom text)
   returns boolean as $$
declare
   pkColumn text := _ast_getPrimaryKeyColumn(part_tbl);
   res1 boolean;
   res2 boolean;
   res3 boolean;
begin

   if pkColumn = '' then
      raise exception 'AST_isSpatialAggregationValid function error.'
         using detail = 'PART table does not have primary key and without it is not possible to validate the spatial aggregation.';
   end if;

   if not _ast_isOMTGDomain(part_tbl, part_geom) or not _ast_isomtgdomain(whole_tbl, whole_geom) then
      raise exception 'AST_isSpatialAggregationValid error! Invalid parameters.'
         using detail = 'Usage: SELECT ast_isSpatialAggregationValid(part_tbl text, part_geom text, whole_tbl text, whole_geom text);';
   end if;

   -- 1. Pi intersection W = Pi, for all i such as 0 <= i <= n
   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
            ''Spatial Aggregation violation'',
            ''The geometry of the PART with primary key ´''|| c.'|| pkColumn ||' ||''´ is not entirely contained within the geometry of the WHOLE.''
         from '|| part_tbl ||' c
         where c.ctid not in
         (
         	select b.ctid
         	from '|| whole_tbl ||' a, '|| part_tbl ||' b
         	where ST_Equals(ST_Intersection(a.'|| whole_geom ||', b.'|| part_geom ||'), b.'|| part_geom ||')
         )
      ) returning true;' into res1;


   -- 3. ((Pi touch Pj) or (Pi disjoint Pj)) = T for all i, j such as i != j
   execute 'insert into ast_violation_log (time, type, description) (
         select now(),
            ''Spatial Aggregation violation'',
            ''The geometries of the parts ´''|| b1.'|| pkColumn ||' ||''´ and ´''|| b2.'|| pkColumn ||' ||''´ are overlapping.''
         from '|| part_tbl ||' b1, '|| part_tbl ||' b2
         where b1.ctid < b2.ctid and
         (not st_touches(b1.'|| part_geom ||', b2.'|| part_geom ||') and not st_disjoint(b1.'|| part_geom ||', b2.'|| part_geom ||'))
      ) returning true;' into res2;


   -- 2. (W intersection all P) = W
   execute 'select not st_equals(st_union(a.geom), st_union(b.geom))
      from tablea a, tableb b;' into res3;

   if res3 then
      execute 'insert into ast_violation_log (time, type, description) (
         select now(),
         ''Spatial Aggregation violation'',
         ''The geometry of the WHOLE is not fully covered by the geometry of the PARTS.''
      )';
      return false;
   end if;

   if res1 or res2 then return false;
   else return true;
   end if;
end;
$$  language plpgsql;
