# mindRID execution roadmap: V18 → V21

This roadmap consolidates the agreed direction and V18.1–V18.4 package work. It distinguishes existing client-side work from features requiring backend/security/provider implementation. A roadmap item is not evidence that it is already production-ready.

## Product invariant
MindRID is a thought-first social network for discovery, connection, dialogue, development and preservation of thoughts. Keep **Whisper** as the act/content label and **Reflection** as the subject being explored. Do not drift into a generic social feed. Product loop: **Express → Encounter → Develop → Preserve → Return**.

## V18 — Core interaction and navigation foundation
**Goal:** Make the core loop understandable, responsive and testable before expanding scope.
- Home composer-first layout; For You / Following / Latest feed modes.
- Five-destination mobile navigation: Home, For You, Explore, Messages, Me.
- Distinct Like and Memory actions; Reply, Share, Why this?, Report.
- Media attachment previews, selectable cover/small preview, location/feeling/idea/vibe metadata.
- Person Follow/Unfollow and post Follow/Unfollow with clear state feedback.
- Remove dead-click causes and consolidate duplicate navigation routes.
- Keep guest landing-page design intact.
- Required release gates: static regression tests; browser E2E at desktop/tablet/mobile; Supabase staging checks for RLS, auth, visibility, follows and reply notifications; accessibility and performance review.

**Status:** V18.4 contains the client-side baseline and static tests. Browser and live Supabase staging verification are still outstanding. Do not call V18 production-verified until those checks pass.

## V19 — Privacy, consent and trustworthy social graph
**Goal:** Turn visible affordances into enforceable, explainable policies.
- Verify all Whisper visibility cases (public, private, selected recipients) with database RLS.
- Complete recipient search/selection and server-enforced recipient access.
- Implement mention/tag consent settings and pending accept/decline flow. A mention must never grant access.
- Verify Follow/Unfollow idempotency, follower lists/counts, blocks, report/moderation, and notification exclusions.
- Add account data export/deletion and clear privacy controls where not already complete.
- Google OAuth only after full provider configuration, callback, account-linking and recovery tests.

**Exit gate:** automated RLS matrix plus authenticated staging tests for two or more users, anonymous/public viewers, blocked users, selected recipients and post subscribers.

## V20 — Reflection development and assistive capabilities
**Goal:** Help people develop a reflection without overwriting their original Whisper.
- Related Reflections; Develop This Thought; Has Your Thinking Changed?; Why am I seeing this?; Surprise My Mind.
- Whisper Journey / reflection history and deliberate Memory retrieval.
- Optional translate, summarise, key points, simplify and read-aloud actions.
- Translation/summarisation must run server-side with secrets protected, explicit informed consent for external processing, original preserved, machine-generated labels, rate limits, quotas, cost controls and error/retry states.
- Avoid presenting generated matches/summaries as authoritative or inventing source claims.

**Exit gate:** quality evaluation set, privacy disclosure, provider-failure simulations, cost ceiling, abuse controls and opt-out behavior.

## V21 — Governed mindRID Studio / App Lab
**Goal:** Enable bounded, safe applications built on mindRID data and capabilities.
- Start with approved no-code templates and blocks, not arbitrary uploaded JavaScript.
- App registry, ownership, descriptions, versioning, preview, publish/unpublish, rollback and audit log.
- Explicit scopes and consent; least privilege; server-side capability checks; separate app data boundaries.
- Templates could include a reflection journal, topic explorer, Circle companion, reading/listening collection and event space.
- Add SDK or extension runtime only after security review, sandboxing, abuse handling and versioning exist.

**Exit gate:** threat model, capability authorization tests, cross-app isolation, review/moderation workflow, rollback drill, deletion/export story and pilot cohort feedback.

## Cross-version release discipline
Every feature must specify: user value; acceptance criteria; UI states (loading/empty/error/success); schema/RLS changes; mobile and keyboard behavior; privacy/security review; regression tests; migration/rollback instructions; staging verification; owner and status.

Use explicit status labels: **Implemented in source**, **Static-tested**, **Staging-verified**, **Production-verified**. Never collapse these into a single “done” label.
