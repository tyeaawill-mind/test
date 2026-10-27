# mindRID staging release gates — scaling preparation

Status: **Required checklist; staging has not been verified from this package.** A checked item requires saved evidence from the intended Supabase project and deployed staging build.

## Gate 0 — Source and release integrity
- [ ] Record baseline and candidate ZIP SHA-256 hashes.
- [ ] Run every `tests/*.js` script from the repository root.
- [ ] Confirm CSS and JS cache query keys match the candidate release identifier.
- [ ] Inspect the built site in desktop, tablet, narrow mobile and keyboard-only use.
- [ ] Confirm rollback artifact and exact rollback procedure are available.

## Gate 1 — Authorization and privacy
- [ ] Run `DIAGNOSTIC-SUPABASE-PERMISSIONS.sql` against the intended staging project and save the output.
- [ ] Compare grants, column grants, RLS state, policies and SECURITY DEFINER execute ACLs with `schema.sql` and migrations.
- [ ] Test with at least two ordinary accounts, an anonymous visitor, a blocked pair, a deactivated account, a Whisper owner, a selected recipient and an unrelated authenticated viewer.
- [ ] Verify private/selected Whispers, replies, tags, media, recipients, messages, Circle membership and notification rows cannot be read or mutated outside intended permissions.
- [ ] Verify group join/invitation flows cannot self-add to restricted Circles; confirm membership visibility follows the approved Circle model.
- [ ] Verify profile edits can update approved fields only; identity, moderation and account status cannot be self-modified through ordinary profile updates.
- [ ] Verify every SECURITY DEFINER function has a fixed safe `search_path`, minimal execute grants, and authorization based on `auth.uid()` rather than trusting caller-supplied viewer IDs.
- [ ] Do not run proposed GRANT/REVOKE/policy SQL until a reviewed diff and rollback plan are approved.

## Gate 2 — Functional regression
- [ ] Home shows the approved title, composer, mobile composer trigger, feed-mode navigation and feed container.
- [ ] For You, Following and Latest route correctly and preserve the approved guest landing page.
- [ ] Sign-in/out, account recovery, profile settings, Messages, Circles and back navigation work.
- [ ] Whisper creation/edit/delete, visibility, selected recipients, media previews, replies, Like, Memory, Share, Why, Report, follow/unfollow and notifications work.
- [ ] No private content appears after logout or through stale client state.
- [ ] Test small screens on real iOS and Android devices or representative browser/device emulation; check keyboard, focus, scroll, safe areas and tap targets.

## Gate 3 — Performance and load
- [ ] Record baseline median and p95 latency for sign-in, Home first page, next page, open Whisper, replies, Messages and media access.
- [ ] Run controlled concurrent-user tests at agreed initial, expected and peak levels; record error rate, p95 latency, database connections, CPU, memory, storage and egress.
- [ ] Test pagination with tied timestamps, new rows during traversal, route changes and retry behavior.
- [ ] Inspect slow queries and query plans before proposing indexes.
- [ ] Verify rate limits and upload limits for auth, search, messages, reports, media and AI-related endpoints.
- [ ] Agree numerical release thresholds before running the test; do not declare pass without the actual measurements.

## Gate 4 — Recovery and operations
- [ ] Confirm automated backup/PITR availability and retention from the actual plan/configuration.
- [ ] Perform a restore/recovery exercise in a non-production target and record recovery time and data-loss window.
- [ ] Verify monitoring and alerting for API errors, failed auth, database saturation, storage errors and edge-function failures.
- [ ] Document incident contact/owner, rollback steps, migration reversibility and how to disable a faulty release.
- [ ] Confirm the release has no pending unreviewed destructive migrations.

## Evidence status for this package

- Static Node checks: recorded separately in the package audit.
- Browser/device tests: not run here.
- Live Supabase permissions/RLS tests: not run here.
- Load/performance tests: not run here.
- Backup recovery test: not run here.
- Production deployment: not performed.
