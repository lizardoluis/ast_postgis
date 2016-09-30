--
-- This function checks if all the elements of b_tbl is within the buffer
-- distance from the elements of a_tbl.
--
create or replace function omtg_isNearValid(a_tbl text, a_geom text, b_tbl text, b_geom text, dist real)
   returns boolean as $$
declare
   pkColumn text := _omtg_getPrimaryKeyColumn(b_tbl);
   res boolean;
begin

   EXECUTE 'INSERT into omtg_violation_log (time, type, description) (
         select now(),
               ''Near buffer violation'',
               ''Table ´'|| b_tbl ||'´ tuple with primary key ´''|| b.'|| pkColumn ||' ||''´ is outside the buffer distance of ´'|| dist ||'´ from table ´'|| a_tbl ||'´.''
         from tableb b
         where b.id not in
         (
            select b.id
            from tablea a, tableb b
            where st_dwithin(a.geom, b.geom, '|| dist ||')
         )
      ) RETURNING true;' into res;

      if res then return true;
      else return false;
      end if;
end;
$$  language plpgsql;
