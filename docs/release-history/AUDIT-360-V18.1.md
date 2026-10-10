# mindRID 360° UX / Functional Audit — V18.1

## Executive result
The previous V18 package was not a complete functional redesign. It mostly changed navigation and still had several perceived-responsiveness and scope-overlap problems. V18.1 applies targeted fixes and provides an explicit production verification boundary.

## 1. Action response audit
- Like: optimistic visual toggle; direct insert/delete; duplicate insert treated as already liked; state rolls back on failure.
- Memory: optimistic visual toggle; direct insert/delete; duplicate insert treated as already saved; state rolls back on failure.
- Existing Like/Memory state hydrates for feed cards and thread view; `aria-pressed` reflects state.
- Share: removed the unnecessary pre-share Whisper database fetch; native share or clipboard is attempted immediately.
- Reply: clicking Reply updates the URL to the reflection detail route; the detail screen shows a loading state immediately. Stale async results are ignored after route changes.
- Why am I seeing this?: loading modal appears before the data requests; failure produces a retry state instead of a stuck spinner.
- Report: opens a reasoned moderation dialog; submit uses explicit progress and success/error feedback. Report is not a dislike action.
- Follow discussion: new persistent subscription, immediate visual state, rollback on failure, and database-triggered notification for later replies.

## 2. Navigation overlap
- Home owns the feed and composer.
- For You, Following and Latest are modes of the same Home surface.
- Old `#for-you` and `#timeline` links redirect to Home feed modes.
- Discover is the public reflection/media/topic search surface.
- Spaces redirects to Discover because the previous topic cards duplicated Explore.
- Circles is the group/member/wall/discussion destination.
- Community redirects to Circles; its previous page duplicated the same Circle directory and links to people/following/followers.
- Messages is private conversation.
- Me is the account/profile area; My reflections and Memory remain available in secondary navigation.
- Saved redirects to Memory because both previously read the same saves table.
- Recently viewed remains distinct from Memory: opened items vs deliberately saved items.
- Connections remains distinct from Follow: mutual/accepted relationship vs one-way subscription to a person's public reflections.

## 3. Interaction semantics
- Follow person: one-way relationship, public reflections appear in Following.
- Connect: mutual relationship requiring acceptance.
- Follow discussion: receive notifications about new replies to a specific reflection.
- Memory: privately save a reflection to revisit.
- Like: lightweight positive acknowledgement.
- Reply: the correct place for agreement, disagreement, questions and development.
- Report: moderation for potential rule violations.
- Negative dislike/hate/meaningless reaction options are not recommended; the visible dislike control on replies has been removed to avoid turning discussion into negative scoring.

## 4. Mobile/desktop
- Five mobile destinations: Home, Discover, Circles, Messages, Me.
- Home feed tabs are consistent across desktop/mobile.
- Action rows wrap instead of overflowing and maintain approximately 40px touch height.
- Active mobile destination is visibly indicated.
- Existing landing-page design/copy/styles are preserved; only script cache version changed in index.html.

## 5. Security / database
- New `whisper_subscriptions` table uses user-scoped RLS for select/insert/delete.
- Insert policy checks visibility through the existing four-argument `mindrid_can_view_whisper` function.
- Subscriber notifications exclude the reply author and Whisper owner (the existing comment trigger already notifies the owner).
- Subscription rows cascade on user or Whisper deletion.
- No production database connection was available during this audit; SQL syntax/behavior must be run against a staging Supabase project before production.

## 6. Static/simulation tests
- `node --check app.js` passes.
- Route/action invariants and migration signatures pass `tests/audit-smoke.js`, including five-item mobile navigation, action-handler coverage, canonical route redirects, notification exclusions, and stale-column regression checks.
- Original landing-page HTML was compared against the prior V18 package and is unchanged; original CSS is retained as an exact prefix, with only appended signed-in action/navigation styling.
- ZIP integrity is checked with `unzip -t`.
- A Chromium DOM smoke simulation was attempted against a local mocked Supabase client, but the browser process timed out in this execution environment. It is not counted as a passing test. The static checks do not verify real Supabase RLS, storage, notification triggers, iOS share sheets, or authentication delivery.

## 7. Still requires live validation
- Run SQL migration in staging and test RLS as two separate accounts.
- Confirm insert/delete works for likes/saves and follow discussion subscriptions.
- Confirm replies notify subscribers but do not duplicate notifications to the Whisper owner.
- Test anonymous and private/selected-visibility access with non-author accounts.
- Test Safari/iOS share/copy behavior and mobile keyboard/layout.
- Verify password recovery, MFA, account deletion, inactivity sign-out, media permissions, and connection flows end-to-end.

## 8. Product narrative candidate
“Put down what you cannot safely carry alone. Meet reflections that help you see beyond your own. Keep what matters—and discover how your thinking changes.”

This is a candidate statement of intended value, not a guarantee of safety, self-knowledge, or psychological outcomes.
