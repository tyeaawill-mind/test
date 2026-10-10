# mindRID V18.2 — Whisper UX and interaction fix

## Language proposition
Keep **Whisper** as the product's distinctive expression word and the name of an authored post. Use **reflection** to describe the kind of content or the act of revisiting/developing an idea. Examples:
- Composer prompt: “What’s going through your mind?”
- Primary action: “Whisper”
- Object: “Whisper” / “this Whisper”
- Content description: “a reflection” / “related reflections”
- Thread actions: “Reply”, “Develop this reflection”, “Has your thinking changed?”
This preserves the founder's emotional attachment and brand distinction without forcing “whisper” into every sentence.

## Critical defect found and fixed
The feed cards use document-level delegated click handling. Their action buttons had inline `onclick="event.stopPropagation()"`; this stopped the event before it reached the document handler. That explains why Like, Memory, Reply, Share, Why this?, Report, media expansion, and potentially other card actions appeared unresponsive. Removed the inline propagation blockers. The delegated handler resolves the innermost `[data-action]`, so it does not invoke the article's open action when a button is clicked.

## Changes
- Like and Memory now have distinct symbols (heart vs bookmark-like square) and distinct labels.
- Composer submit action is “Whisper”; existing landing page copy/design was not intentionally redesigned. Only the app.js cache query was changed so clients request the fixed code.
- Media picker shows local thumbnails for images, video/audio type indicators, remove controls, and an optional cover selection. `is_preview` and `preview_mode` persist on `whisper_media`; selected cover is shown first and larger, while automatic small previews remain compact.
- Feeling, Idea, and Vibe now have sensible presets plus Custom. Tags are optional; the composer remains usable without selecting them.
- Location is optional and manual. Search suggestions and reverse geocoding use OpenStreetMap Nominatim; “Use my location” invokes the browser permission prompt only after the user clicks. The user must review the place before sharing.
- Mobile composer fields stack vertically; desktop fields use a compact grid.

## Database change
Run `MIGRATION-V18.2.sql` once in Supabase SQL Editor before deploying this version. It adds `is_preview` and `preview_mode` to `public.whisper_media`. The migration is idempotent. `schema.sql` is updated for fresh installs.

## Limitations and external service notes
- Location suggestions use OpenStreetMap's public Nominatim endpoint. This is an MVP integration, not a service-level-guaranteed geocoder. For scale, configure a provider contract/key and rate limiting, or operate a compliant geocoding service. Location is never requested until the user presses “Use my location”; place search only runs after text entry of at least three characters.
- Geolocation may be denied, unavailable, or require HTTPS. Manual location entry remains available.
- The cover choice selects which attached image/video is visually emphasized; it does not generate a video poster frame. Video uses the browser's own metadata frame unless a future thumbnail-generation pipeline is added.
- No live Supabase credentials were available. SQL/RLS behavior and real-device behavior cannot be certified from static checks.

## Test results
Run from this directory:
```sh
node --check app.js
node tests/audit-smoke.js
node tests/v182-regression.js
```
These are syntax/static regression checks, not end-to-end proof against production. Test on a staging deployment with two accounts before public rollout.
