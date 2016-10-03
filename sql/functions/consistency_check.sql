--
-- This function checks if all the elements of b_tbl is within the buffer
-- distance from the elements of a_tbl.
--
create function omtg_isNearValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(b_tbl);
   res boolean;
begin

   execute 'insert into omtg_violation_log (time, type, description) (
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
-- This function checks if the topolotical relationship is violated.
--
create function omtg_isTopologicalRelationshipValid(a_tbl text, a_geom text, b_tbl text, b_geom text, relation _omtg_topologicalrelationship)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(a_tbl);
   res boolean;
begin

   execute 'insert into omtg_violation_log (time, type, description) (
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
-- This function checks if the arc-node network is violated.
--
create function omtg_isNetworkValid(arc_tbl text, arc_geom text, node_tbl text, node_geom text)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(arc_tbl);
   res1 boolean;
   res2 boolean;
begin

   execute 'insert into omtg_violation_log (time, type, description) (
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

   execute 'insert into omtg_violation_log (time, type, description) (
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
