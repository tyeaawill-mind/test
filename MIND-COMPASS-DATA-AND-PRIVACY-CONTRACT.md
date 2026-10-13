# Mind Compass — Conceptual Data and Privacy Contract

**This is a logical contract, not a database migration.** Validate against the repository and live schema before implementation.

## Conceptual entities

- `compass_preferences`: chosen labels/order/enabled state for directions; private to the owner.
- `compass_journey`: user-owned journey metadata, title, selected direction, creation/update timestamps and lifecycle status.
- `journey_waypoint`: ordered reference to a canonical Whisper or resource, plus user-authored note and branch relationships.
- `journey_link`: an explicit connection between waypoints/journeys, with provenance (user-created, content relationship, or AI-suggested).
- `reflection_hypothesis`: optional interpretation of a possible threat/vulnerability/defence/protection/cost, with source, uncertainty, alternative explanations, user feedback and processing provenance.
- `habit_checkin`: optional user-entered intention/observation; not a direct dopamine measurement.
- `compass_consent`: purpose-specific consent and revocation records for optional AI processing, personal analytics and sharing.
- `compass_event`: only minimal operational events needed for reliability/security; avoid creating a surveillance event stream by default.

Names are illustrative. Do not create these tables without schema mapping and a reviewed migration plan.

## Provenance rules

Every displayed statement should be distinguishable as one of:
- Directly written or explicitly selected by the user.
- Derived from public or user-selected content.
- AI-generated hypothesis.
- User-confirmed interpretation.

AI-generated material must not overwrite the original Whisper. Store enough provenance to show when and why an interpretation was produced, which model/provider processed it where applicable, and whether the user accepted, corrected or rejected it.

## Access and sharing

- Personal map, journeys, attention history, check-ins and emotional interpretations are private by default.
- Public visibility of an original Whisper does not automatically make a user's private Compass notes or inferred interpretations public.
- Sharing a journey must be a separate, clear action with a preview of exactly what will be shared.
- Shared constellations show only information participants have intentionally contributed or consented to share.
- Never expose another person's private interpretation to them or to third parties without a clear, legitimate and consented basis.

## AI processing

- Explain what content is processed and whether a third-party provider receives it.
- Ask for consent before sensitive optional processing; make refusal non-punitive.
- Minimise the payload and avoid sending unrelated profile, identity or history.
- Provide correction, rejection and deletion paths.
- Do not claim clinical validity or certainty about unconscious motives.
- Do not use emotional vulnerability estimates to target advertising, increase compulsive use, or manipulate religious behaviour.

## Retention and deletion

Users should be able to delete individual hypotheses, journeys, check-ins and the full Compass history. Deletion semantics must include derived copies, caches, search indexes and AI-provider retention where technically applicable and contractually supported. State any unavoidable backup-retention window honestly. Provide export where feasible.

## Analytics limits

- No default inference of sensitive traits.
- No use of dwell time as proof of interest or emotional state.
- Do not call interaction metrics dopamine data.
- Prefer voluntary check-ins and explicit preference controls.
- Any later personal analytics must be purpose-limited, inspectable, pausable, resettable and deletable.

## Security gates before implementation

1. Map current auth identity and ownership keys.
2. Inspect actual RLS policies and grants in the deployed Supabase project.
3. Map storage policies for any media linked to journeys.
4. Verify export/delete paths and cascading dependencies.
5. Threat-model cross-user access, anonymous content, AI-provider transfer, logs, caches and shared constellation membership.
6. Write and test migrations in staging, including rollback or forward-fix plan.
