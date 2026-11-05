-- mindRID V19.1 Circle security diagnostics
-- READ ONLY. Run in Supabase SQL Editor. No data or permissions are changed.

-- 1) Circle and membership table definitions.
SELECT
  c.relname AS table_name,
  a.attnum AS ordinal_position,
  a.attname AS column_name,
  pg_catalog.format_type(a.atttypid, a.atttypmod) AS data_type,
  a.attnotnull AS not_null,
  pg_get_expr(ad.adbin, ad.adrelid) AS default_expression
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_attribute a ON a.attrelid = c.oid
LEFT JOIN pg_attrdef ad ON ad.adrelid = c.oid AND ad.adnum = a.attnum
WHERE n.nspname = 'public'
  AND c.relname IN ('groups', 'group_members')
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;

-- 2) All policies on Circle-related tables.
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('groups', 'group_members', 'circle_messages')
ORDER BY tablename, policyname;

-- 3) Table and column grants for Circle-related tables.
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('groups', 'group_members', 'circle_messages')
ORDER BY table_name, grantee, privilege_type;

SELECT grantee, table_name, column_name, privilege_type
FROM information_schema.role_column_grants
WHERE table_schema = 'public'
  AND table_name IN ('groups', 'group_members', 'circle_messages')
ORDER BY table_name, column_name, grantee, privilege_type;

-- 4) Constraints and indexes (including uniqueness and foreign keys).
SELECT
  tbl.relname AS table_name,
  con.conname AS constraint_name,
  con.contype AS constraint_type,
  pg_get_constraintdef(con.oid) AS definition
FROM pg_constraint con
JOIN pg_class tbl ON tbl.oid = con.conrelid
JOIN pg_namespace n ON n.oid = tbl.relnamespace
WHERE n.nspname = 'public'
  AND tbl.relname IN ('groups', 'group_members', 'circle_messages')
ORDER BY tbl.relname, con.conname;

-- 5) Relevant function definitions and execute ACLs.
SELECT
  p.oid::regprocedure AS function_signature,
  p.prosecdef AS security_definer,
  p.proconfig AS function_settings,
  p.proacl AS execute_acl,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'mindrid_join_group', 'mindrid_leave_group', 'mindrid_create_group'
  )
ORDER BY p.proname, p.oid::regprocedure::text;
