# mindRID V18.3 — deployment and staging checks

## Changes
- Mobile Home opens the Whispering page; mobile navigation now includes Discover and Following instead of a duplicate For You destination.
- Home, For You, Following and Latest have separate routes. For You uses recommendation scoring; Following filters by followed authors; Latest uses the newest public feed. Following/Latest are feed-only pages, not composer pages.
- Feed-mode links sit in a compact top-right selector on desktop and a compact row on mobile.
- Location attribution text is shortened to one line.
- Preview selectors, tag dropdowns, media controls and pending-media boxes use smaller text/spacing.
- People I choose now provides searchable recipient suggestions; selecting a suggestion adds the username to the recipient list.
- Guest landing page visuals remain unchanged; only the app.js cache-busting URL was updated.
- `PLATFORM-ROADMAP-V1.md` records larger integrations and the dependencies/security gates.

## Deploy
1. Back up the current website files and Supabase schema.
2. Replace website files with this package. No SQL migration is introduced in V18.3.
3. Hard-refresh on desktop and mobile (or clear site cache).
4. Test as a signed-in user with at least two accounts and a separate browser session.

## Required staging tests
- Home opens Whispering composer. On mobile, tap Home from For You, Following, Discover, Messages and Me.
- For You shows recommended feed; Following shows only eligible Whispers by followed people; Latest sorts newest-first. Verify these routes do not simply display the same content.
- Follow/unfollow a second account and confirm the Following feed changes.
- Choose People I choose, type two or more letters, select a suggestion, and publish. Confirm only selected recipients can read it; test by opening a second account. If recipient RLS/visibility fails, stop deployment.
- Verify location copy stays on one line on narrow phones, dropdown text is compact, media boxes do not overflow, and selected cover persists after reload.
- Test privacy, anonymous identity, report, block, media permissions and browser-console errors.

## Limits / not yet implemented
- Mention/tag approval settings and accept/decline workflow require database/RLS/notification changes.
- Translation, summarisation and other AI scopes need a trusted server-side provider integration, privacy consent, rate limiting and cost controls.
- Social sign-in buttons should only be added after provider registration and complete OAuth tests. Google is the recommended first provider; Yahoo/WhatsApp/Threads/X/TikTok/WeChat do not all offer the same kind of supported sign-in flow.
- Cross-platform share can use Web Share and copy-link fallback in a subsequent implementation.
- App Lab / app creation requires a separate permissioned, sandboxed platform, not arbitrary browser-side code execution.

Static syntax and regression tests do not replace browser end-to-end tests or live Supabase/RLS verification.
