# mindRID V20.0 — Mind Compass Test Build

**Release type:** user-facing, local-first prototype for owner testing.
**Baseline:** V19.2 Circle Access Control Preparation.

## Included
- Mind Compass navigation route (`#compass`).
- Four starter directions: Present, Future, Background, Ultimate.
- Select a direction and begin/end one reflection session at a time.
- Save and delete text waypoints, associated with a direction.
- Private weekly activity summary: sessions and waypoints created in the last seven days.
- Responsive desktop/mobile layout.

## Data and privacy boundary
Compass data is stored in browser `localStorage`, partitioned by authenticated user ID. It is not written to Supabase, does not sync across devices, is not included in account export/deletion, and may be lost if browser storage is cleared. Do not store highly sensitive thoughts in this test build. The localStorage partition is an organizational convenience, not a security boundary against someone with access to the same browser profile.

## Engagement research purpose
This build allows observation of voluntary discovery and use: whether a user selects a direction, begins/ends a session, saves a waypoint, and returns to review it. It deliberately avoids streaks, scores, push prompts, guilt, dwell-time inference, and automated psychological interpretation. No covert analytics are added.

## Test
1. Sign in and open **Mind Compass** in the left navigation.
2. Select each of the four directions.
3. Begin and end a session.
4. Save a waypoint under a direction; refresh and confirm it remains.
5. Delete a waypoint and confirm it disappears.
6. Check the weekly counts and responsive layout on mobile.
7. Sign out/in and verify records remain in that browser.

## Release limits
This is a functional front-end test experience, not the final integrated V20 platform release. There is no server-side Compass schema, cross-device sync, scheduled reflection, shared Waypoint, editing of direction labels, AI Mirror, or automated Mind Map analysis. Those require separate security, product and implementation phases. No live Supabase changes were made.
