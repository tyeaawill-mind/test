# Deployment — mindRID V18.2

1. Back up the currently hosted files and export the current Supabase schema/migrations.
2. In Supabase SQL Editor, run `MIGRATION-V18.2.sql`. It adds preview metadata to `public.whisper_media`.
3. Upload the contents of this package to the existing hosting service, preserving the existing domain configuration.
4. The guest landing content/design remains as it was; the `app.js` URL query was changed to bypass stale cached JavaScript.
5. Test on desktop and iPhone with an authenticated account:
   - Like and unlike a Whisper.
   - Save/remove from Memory and verify the icon is a bookmark-like symbol, not a heart.
   - Reply, share/copy link, open “Why this?”, submit a test report, and expand attached media.
   - Use the left-side +Reflect/compose control and the mobile compose button.
   - Upload multiple media files; try Small previews and Choose a cover; remove a selected item; post and reload to confirm preview persistence.
   - Select preset and custom Feeling/Idea/Vibe values.
   - Test location search and “Use my location” only after explicit permission; verify manual entry still works when permission is denied.
6. Repeat with a second test account. Confirm private/selected visibility and anonymous identity do not leak.
7. If any DB call fails, capture the browser console error and the Supabase error text before changing policies.

## Rollback
Restore the backed-up app files if needed. The added preview columns are additive and can remain safely during rollback. Do not drop them during an incident; a later migration can remove them if required.

## Status
JavaScript syntax and static regression checks pass. A live Supabase/browser/device end-to-end test has not been performed in this build environment. Treat as a controlled staging candidate until verified.
