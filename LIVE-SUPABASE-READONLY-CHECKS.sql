-- mindRID V19.0 read-only evidence collection.
-- Run in Supabase SQL Editor on the LIVE project. No changes are made.
-- Do not include project secrets, API keys, user emails, or message/content rows in shared output.

-- 1) Table RLS state for public tables used by mindRID.
select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled,
       c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relkind='r'
  and c.relname in (
    'profiles','private_identity','whispers','whisper_recipients','comments','reports','blocks',
    'conversations','conversation_members','messages','likes','saves','whisper_media','comment_media',
    'comment_reactions','connections','follows','whisper_history','groups','group_members',
    'whisper_tags','circle_messages','notifications','whisper_links','recommendation_feedback',
    'whisper_subscriptions'
  )
order by c.relname;

-- 2) Installed RLS policies for public mindRID tables.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname='public'
  and tablename in (
    'profiles','private_identity','whispers','whisper_recipients','comments','reports','blocks',
    'conversations','conversation_members','messages','likes','saves','whisper_media','comment_media',
    'comment_reactions','connections','follows','whisper_history','groups','group_members',
    'whisper_tags','circle_messages','notifications','whisper_links','recommendation_feedback',
    'whisper_subscriptions'
  )
order by tablename, policyname;

-- 3) Critical columns and media bucket privacy.
select table_name, column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema='public'
  and ((table_name='whisper_media' and column_name in ('is_preview','preview_mode','storage_path','public_url'))
    or (table_name='private_identity' and column_name in ('user_id','identification'))
    or (table_name='whispers' and column_name in ('author_id','identity_mode','visibility')))
order by table_name, ordinal_position;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id='mindrid-media';

-- 4) Installed security-definer functions: definitions and grants.
select n.nspname as schema_name, p.proname as function_name,
       pg_get_function_identity_arguments(p.oid) as arguments,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       pg_get_functiondef(p.oid) as definition,
       array(
         select case when x.grantee=0 then 'PUBLIC'
                     else pg_get_userbyid(x.grantee) end || ':' || x.privilege_type
         from aclexplode(coalesce(p.proacl, acldefault('f',p.proowner))) x
         order by 1
       ) as privileges
from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef
  and p.proname like 'mindrid_%'
order by p.proname;

-- 5) Migration history table, if your project uses one.
-- If this returns no rows or the relation does not exist, use your repository/deployment log
-- and Supabase migration history instead. Do not create a migration-history table for this check.
select to_regclass('supabase_migrations.schema_migrations') as migration_history_relation;

-- Dashboard-only checks (not available from this SQL):
-- Auth > Providers: Google enabled? redirect URL allowlist? email confirmation? MFA policy?
-- Storage > Policies and Auth > URL/config settings should be compared with source.
