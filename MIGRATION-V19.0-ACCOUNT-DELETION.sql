-- mindRID V19.0: harden media writes during account deletion and disable the legacy client-callable RPC.
-- Deploy the Edge Function first, apply this migration second, and deploy the updated website third.
-- This creates a brief safe switch-over window in which the old delete button is unavailable.
-- This does not delete user data or disable Supabase Storage protections.

BEGIN;

-- Block new media uploads/updates after the Edge Function temporarily marks
-- the profile deactivated during deletion. Storage API deletion by service_role
-- remains available; owner DELETE policy is intentionally unchanged.
DROP POLICY IF EXISTS mindrid_media_storage_insert ON storage.objects;
CREATE POLICY mindrid_media_storage_insert ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'mindrid-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_deactivated = false
  )
);

DROP POLICY IF EXISTS mindrid_media_storage_update ON storage.objects;
CREATE POLICY mindrid_media_storage_update ON storage.objects FOR UPDATE
USING (
  bucket_id = 'mindrid-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_deactivated = false
  )
)
WITH CHECK (
  bucket_id = 'mindrid-media'
  AND (storage.foldername(name))[1] = auth.uid()::text
  AND EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.is_deactivated = false
  )
);

-- Disable the legacy client-callable deletion RPC after the replacement Edge Function is deployed.
-- Deploy the updated website immediately after this migration.
REVOKE EXECUTE ON FUNCTION public.mindrid_delete_account() FROM PUBLIC, anon, authenticated;

COMMIT;

-- Verification (run separately):
-- SELECT
--   has_function_privilege('anon', 'public.mindrid_delete_account()', 'EXECUTE') AS anon_can_execute,
--   has_function_privilege('authenticated', 'public.mindrid_delete_account()', 'EXECUTE') AS authenticated_can_execute,
--   has_function_privilege('service_role', 'public.mindrid_delete_account()', 'EXECUTE') AS service_role_can_execute;
-- Expected: false, false, true (service_role may remain explicitly granted).
