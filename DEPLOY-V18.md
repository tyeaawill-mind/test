# V18 deployment and staging gate

## Before deployment
1. Confirm this is the intended repository/branch and preserve the current V17.3 release as a rollback point.
2. Deploy this package to a staging site first; do not replace production until all gates below pass.
3. Review `MIGRATION-V17.sql`, `MIGRATION-V18.1.sql`, `MIGRATION-V18.2.sql` against the actual staging database. Apply only migrations not already applied, in dependency order, and inspect errors. Do not assume the supplied `schema.sql` should be re-run over an existing database.

## Static checks

Run `node --check app.js`, then `for f in tests/*.js; do node "$f"; done`, then `unzip -t` on the release ZIP.

## Required browser/device checks

- Guest landing page appearance and links remain unchanged.
- Test signed-in and signed-out behavior.
- Test 320px, 360px, 390px, tablet, and desktop widths. The mobile composer prompt stays on one line with ellipsis if needed; the avatar remains circular and compact.
- Tap Home from Discover, Following, Messages, and Me; on Home, tap Home again and confirm the composer is easy to reach.
- Test For You, Following, and Latest; confirm empty/loading/error states.
- Test Like, Reply, Memory, Share, Why this?, Report, media, person Follow/Unfollow, and Follow post/Following post.
- With two test accounts, verify post-subscription notifications and unsubscribe behavior.
- Verify selected-recipient visibility, anonymous Whisper behavior, blocking/reporting, database RLS, and browser console/network errors.

## Release gate

Do not promote to production until browser tests and Supabase/RLS/notification checks pass. This package has not been tested on a physical phone or against the live database by this build step.
