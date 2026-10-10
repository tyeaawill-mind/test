# Deploy mindRID V18.1

1. Back up the deployed site and database state.
2. In Supabase SQL Editor, run `MIGRATION-V18.1.sql` once. It creates the discussion subscription table, row-level security policies, and a trigger that notifies subscribers about new replies.
3. Confirm the project already has the V17 tables/functions used by this migration, including `whispers`, `comments`, `notifications`, and `mindrid_can_view_whisper(uuid,text,uuid,uuid)`.
4. Upload the contents of this ZIP to the existing static host. Do not replace Supabase project keys.
5. Clear the browser/site cache or use a private tab; the app script URL is cache-busted.
6. Sign in and test Home → For You / Following / Latest, Discover, Circles, Messages, Me, Memory, My reflections, follow/unfollow person, Like/unlike, save/remove Memory, share, reply, report, “Why am I seeing this?”, Follow discussion/unfollow, notifications, and sign-out.
7. Verify that the landing page still looks unchanged.

## Rollback
Restore the backed-up site files. The new subscription table and trigger are additive; if rolling back the code, the table may remain unused. Do not drop it without confirming no subscriptions need to be retained.

## Verification boundary
Syntax, static invariants, ZIP integrity, and a browser smoke simulation are checked in this build. The live Supabase migration and real-account end-to-end behavior still require verification in the production project.
