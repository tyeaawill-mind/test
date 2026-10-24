# mindRID V18.6 Media Preview Recovery — Audit Report

## Scope
Based on supplied V18.5 source and the two mobile screenshots reporting missing `whisper_media.is_preview` and `whisper_media.preview_mode` in the Supabase schema cache. The supplied source expects both fields in media inserts and feed-media selects. The previously supplied V18.6 migration added them, but the user reports the problem persists after a database grant change. Grants do not create columns and are not the direct remedy for a missing-column schema-cache error.

## Changes in this recovery package
- Preserves the V18.5 site files except `app.js`.
- Adds a narrowly scoped compatibility fallback: if PostgREST reports the optional preview metadata columns are missing from schema/cache, media-row inserts retry without those two fields; feed-media reads retry without those fields and default to small previews. Other errors are not swallowed or retried.
- Adds an idempotent SQL migration to create/backfill/default/constrain the expected columns and reload PostgREST schema cache.
- Adds a diagnostic SQL script that prints database identity, column state, constraint and table grants.

## Why this should address the reported failure
The frontend no longer depends absolutely on those optional columns to finish a media insert or read media metadata during a stale/mismatched schema period. The migration repairs the intended schema, restoring persistent cover-preview metadata once the schema is visible.

## Deployment
1. Back up the correct Supabase project.
2. Run `DIAGNOSTIC-V18.6-MEDIA-PREVIEW-RECOVERY.sql`; confirm the project/database identity.
3. Run `MIGRATION-V18.6-MEDIA-PREVIEW-RECOVERY.sql`.
4. Run diagnostics again; both columns should be present, NOT NULL, with defaults and the check constraint.
5. Replace the deployed site files with this package, preserving the same Supabase URL and anon key configuration. Ensure the host actually deploys the updated `app.js` (not a cached/old build).
6. Hard refresh the mobile site; create a Reflection with one media item, publish, and verify it appears in the feed.

## Verification performed locally
- Source ZIP integrity checked before extraction.
- JavaScript syntax checked with Node.js.
- Static assertions check fallback helper and both insert/read fallback paths.
- Package ZIP integrity checked after build.

## Not verified
No connection to the live Supabase project or hosting deployment was available. Therefore this is not a claim that the production issue is already fixed. If the exact same error remains after deploying this package, the likely next checks are wrong Supabase project URL/key, stale deployed app.js/CDN cache, or SQL run against a different project. Capture the failing network response and the post-migration diagnostic output.

## Scope guard
No RLS policies, grants, storage policies, or account-deletion code are changed in this release. The broad grants audit is a separate security task; it is not mixed into the media repair to avoid breaking working functionality.
