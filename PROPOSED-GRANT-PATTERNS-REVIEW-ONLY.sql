-- mindRID: PROPOSAL ONLY — DO NOT EXECUTE AS A MIGRATION.
-- These are review patterns, not a production-ready permission patch.
-- First run DIAGNOSTIC-SUPABASE-PERMISSIONS.sql against the intended project,
-- compare live output with all migrations, and verify each UI operation.

-- Pattern A: a private owner-scoped table that should not be anonymously accessible.
-- Example only; replace table name and operations only after a table-specific review.
-- ALTER TABLE public.example_private_table ENABLE ROW LEVEL SECURITY;
-- REVOKE ALL ON TABLE public.example_private_table FROM PUBLIC, anon, authenticated;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.example_private_table TO authenticated;
-- Then add owner-scoped RLS policies for each permitted operation.
-- This pattern is not appropriate for every table and does not itself secure rows.

-- Pattern B: profile editing — candidate only after confirming all profile-edit flows
-- and the live column list. Keep table-wide UPDATE revoked and grant only approved fields.
-- REVOKE UPDATE ON TABLE public.profiles FROM authenticated;
-- GRANT UPDATE (username, display_name, bio, location_country, location_city,
--               background, interests, avatar_path, background_path, theme_key,
--               last_whisper_vibe)
-- ON TABLE public.profiles TO authenticated;
-- Review whether avatar_url or any later-added field is legitimately editable before use.
-- Ensure no table-level UPDATE is inherited through another role or PUBLIC grant.

-- Pattern C: genuinely public read-only lookup data, if a specific table qualifies.
-- GRANT SELECT ON TABLE public.example_public_lookup TO anon, authenticated;
-- Use only with explicit review that every row/column in the table is public.

-- Pattern D: server-only tables/functions.
-- Prefer no direct anon/authenticated table grant; expose a narrowly scoped server-side
-- function or Edge Function that validates the authenticated identity and authorization.
-- Never put service_role credentials in browser code.

-- Required before applying any approved patch:
-- 1) Diff live ACLs/policies against canonical schema and migrations.
-- 2) Test owner, unrelated user, anon, selected recipient, blocked user and deactivated user.
-- 3) Verify frontend flows that depend on the privilege being changed.
-- 4) Capture rollback SQL and take a backup/restore point appropriate to the project.
-- 5) Apply in staging, run tests, then request separate explicit approval for production.
