# mindRID V18 — Future-centric social experience

**Release status: staging candidate; not production-verified.**

V18 consolidates the approved V18.1–V18.4 interaction work into one runtime, based on the corrected V17.3 mobile-composer fix. The guest landing-page design is preserved.

## Product distinction

mindRID is built around the life of a Whisper—not only a stream of posts. The intended loop is **Express → Encounter → Develop → Preserve → Return**.

- **Whisper** is the act of expression and the published contribution.
- **Reflection** is the subject explored, connected, and revisited.
- **Reply** develops dialogue; **Memory** preserves a Whisper intentionally.
- **Following** is for people; **Follow post** subscribes to a discussion.

## Simplified navigation

Five primary mobile destinations: **Home, Discover, Following, Messages, Me**. Home is composer-first and offers **For You, Following, Latest** feed modes. Circles and supporting destinations remain available in the wider navigation; duplicate legacy routes redirect to canonical destinations.

## Included in this release

- Home/feed modes and mobile navigation state
- Whisper composer and media preview controls
- Like, Reply, Memory, Share, Why am I seeing this?, and Report
- Person Follow/Unfollow and discussion Follow post/Following post
- Existing optional location/feeling/idea/vibe metadata
- Corrected mobile composer prompt sizing and avatar dimensions from V17.3
- Consolidated regression tests and V18–V21 roadmap

## Files

- `index.html`, `app.js`, `styles.css`, assets: runtime
- `schema.sql`, `MIGRATION-V17.sql`, `MIGRATION-V18.1.sql`, `MIGRATION-V18.2.sql`: database schema/migrations
- `DEPLOY-V18.md`: single deployment and staging checklist
- `AUDIT-V18.md`: scope and verification boundary
- `ROADMAP-V18-TO-V21.md`: future phases; not all are part of V18
- `docs/release-history/`: retained historical notes, not competing instructions

## Verification

Run from this folder: `for f in tests/*.js; do node "$f"; done`

Static tests and archive integrity do not prove real-device rendering, Supabase RLS correctness, or live notifications. Complete the staging checklist before production deployment. Do not apply database migrations blindly to production.


## V18.5 mobile Home frame restoration
The V18.5 patch restores the signed-in mobile Home layout to the supplied reference: full-width feed tabs and a compact one-line Whisper composer row. See `AUDIT-V18.5-HOME-FRAME.md`. Browser/device and live Supabase validation remain required before production.
