# mindRID — capability and application-platform roadmap (V1)

This document records the larger capabilities requested for mindRID. It is an implementation plan, not a claim that every capability is already live.

## A. Follow graph and tagging

### Follow and follower model
- Keep following one-way and distinct from accepted Connections.
- Provide visible counts and lists for Following and Followers; include Follow/Unfollow actions on profiles and people cards.
- Feed queries must use the authenticated user's `follows` rows and only return Whispers permitted by visibility and block rules.
- Add pagination and a follow/unfollow result state. Do not fabricate follower counts or show private accounts in discovery.

### People selected for a Whisper
- Search people by display name or username, show a suggestion list, and add selected usernames as explicit recipients.
- Enforce the recipient list in the database/RLS, not only in the browser. Validate the final recipient IDs before publishing.
- This build adds the recipient typeahead UI. Existing `whisper_recipients`/visibility behavior must be verified in a real Supabase staging project before production use.

### Mention/tag consent controls
- Separate a mention from a private-recipient permission: mentioning a person must never grant them access to a Whisper.
- Add per-user Settings: `Anyone`, `People I follow`, `Connections`, `No one`; default to `People I follow` or `Connections` after founder approval.
- Add pending mention/tag records and an accept/decline workflow. A mention notification should not be sent until policy says it may be sent; rejected tags should be hidden or removed.
- Requires schema, RLS, notification logic, moderation behavior, and account settings UI. Do not treat the current inline `@` suggestion as a complete consent system.

## B. Translation, summaries and assistive scopes

Add a per-Whisper action menu with clearly labelled scopes:
1. Translate — choose target language; keep original visible and label the translation as machine-generated.
2. Summarise — concise summary with a length selector; never overwrite the original.
3. Key points — extract the main claims/questions, with uncertainty preserved.
4. Simplify — plain-language rewrite alongside original.
5. Read aloud / listen — browser speech support where available; provide a fallback when unavailable.
6. Explain context — only when useful; distinguish source text from external factual context.

Provider calls must run through a server-side Edge Function or trusted backend, with secrets kept out of browser JavaScript. Add rate limits, per-user quotas, abuse controls, privacy disclosure, timeouts, error/retry states and cost tracking. Do not send private Whispers to an external AI/translation provider without an explicit and informed choice. Google Translate or another service requires valid provider credentials/terms; a frontend button alone is not a translation service.

## C. Sign-in options

- Keep email/password and existing account recovery.
- Add Google OAuth first; consider Apple and Microsoft next according to target users and configuration capacity.
- X/Twitter, TikTok, WeChat and Yahoo may require specific provider support, OIDC configuration, app registration, redirect URLs, review/approval and maintenance. WhatsApp is primarily a messaging channel, not a general-purpose OAuth identity provider. Threads is not assumed to offer a standard consumer login flow. Do not display a provider button until its authentication round-trip has been configured and tested.
- Use Supabase Auth or a trusted identity broker. Never collect third-party passwords in mindRID forms. Test account linking and duplicate-email collisions, revocation, logout, recovery and MFA.

## D. Sharing and cross-platform distribution

- Use native Web Share where supported, with a copy-link fallback.
- Share a canonical URL and safe preview metadata; do not include private Whisper content, recipient names, identity metadata or private signed-media URLs in share previews.
- Add configurable sharing targets only where official share flows exist. Third-party app availability varies by device and installed apps.
- Add OG metadata and link-preview tests for public Whispers. Private/selected Whispers must not leak through crawlers or preview endpoints.

## E. mindRID application platform

Do not turn the public mindRID website into an uncontrolled app builder. Build a separate authenticated **Studio / App Lab** area with:
- App registry: name, owner, description, status, version, visibility and permissions.
- Templates: Circle companion, reflection journal, topic explorer, reading/listening collection, event/community space.
- A stable capability API: identity, profile, permitted Whispers, follows, notifications, media, moderation and billing/usage; every capability checked server-side.
- App scopes and consent screen; least-privilege permissions; no cross-app data access by default.
- Versioned configuration, preview, publish/unpublish, rollback, audit logs and abuse review.
- Sandboxed extensions and a reviewed SDK; no arbitrary uploaded JavaScript running in the main site origin.
- Clear boundaries between mindRID account data and third-party app data; export and deletion paths.

First release should be a no-code configuration builder based on approved blocks, not arbitrary code execution. Only build this after core navigation, follows, recipient privacy, moderation, backups and observability are stable.

## F. Suggested sequence

1. Stabilise Home/For You/Following/Latest and follow/follower behavior.
2. Verify recipient visibility and RLS; implement tag consent settings and acceptance flow.
3. Configure and test Google sign-in; add native share/copy link.
4. Add server-side translation and summary scopes with explicit privacy and cost controls.
5. Prototype App Lab with approved templates and a capability/permission registry.

## Release gate

Every feature must have: database/security rules, loading/empty/error/success states, keyboard/mobile usability, privacy review, regression tests, provider configuration instructions and staging verification. Static source tests alone do not prove live provider or Supabase behavior.
