-- Run before and after migration. The post-migration result should show both expected columns.
SELECT current_database() AS database_name, current_schema() AS current_schema;
SELECT table_schema, table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema='public' AND table_name='whisper_media'
  AND column_name IN ('is_preview','preview_mode') ORDER BY column_name;
SELECT conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE conrelid=to_regclass('public.whisper_media')
  AND conname='whisper_media_preview_mode_check';
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema='public' AND table_name='whisper_media'
ORDER BY grantee, privilege_type;
