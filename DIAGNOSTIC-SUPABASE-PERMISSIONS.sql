-- mindRID scaling preparation: READ-ONLY permission inventory.
-- Safe to run in the intended Supabase project's SQL Editor.
-- This script does not grant, revoke, alter, or delete anything.

-- 1) Table-level privileges for API-facing roles, including effective ACL entries.
select
  n.nspname as schema_name,
  c.relname as table_name,
  case when x.grantee = 0 then 'PUBLIC' else r.rolname end as grantee,
  x.privilege_type,
  x.is_grantable
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) x
left join pg_roles r on r.oid = x.grantee
where n.nspname = 'public'
  and c.relkind in ('r','p','v','m','f')
  and (x.grantee = 0 or r.rolname in ('anon','authenticated','service_role','postgres'))
order by c.relname, r.rolname, x.privilege_type;

-- 2) Column-level privileges. These matter when table-wide UPDATE has been revoked.
select table_schema, table_name, column_name, grantee, privilege_type, is_grantable
from information_schema.column_privileges
where table_schema = 'public'
  and grantee in ('anon','authenticated','service_role','postgres')
order by table_name, grantee, column_name, privilege_type;

-- 3) RLS enabled/forced state for all public tables.
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r','p')
order by c.relname;

-- 4) Policy definitions and role scope.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- 5) SECURITY DEFINER functions and their execute ACLs.
select n.nspname as schema_name,
       p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as identity_arguments,
       pg_get_userbyid(p.proowner) as owner,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       coalesce(array_to_string(array(
         select case when a.grantee = 0 then 'PUBLIC' else gr.rolname end || ':' || a.privilege_type || ':grantable=' || a.is_grantable
         from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
         left join pg_roles gr on gr.oid = a.grantee
         order by 1
       ), '; '), '') as execute_acl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.prosecdef
order by p.proname, identity_arguments;

-- 6) Sequences and their API-facing privileges, if any.
select object_schema as sequence_schema, object_name as sequence_name, grantee, privilege_type, is_grantable
from information_schema.role_usage_grants
where object_schema = 'public'
  and object_type = 'SEQUENCE'
  and grantee in ('anon','authenticated','service_role','postgres')
order by sequence_name, grantee, privilege_type;

-- Interpretation reminders:
-- * A grant is not a row-authorization policy. Review GRANT and RLS together.
-- * Supabase service_role normally bypasses RLS; never expose its key to clients.
-- * PUBLIC is a PostgreSQL pseudo-role and may not appear in pg_roles joins; inspect
--   ACL text or use has_table_privilege checks if PUBLIC grants are suspected.
-- * Compare this live output with schema.sql and every migration before drafting fixes.
