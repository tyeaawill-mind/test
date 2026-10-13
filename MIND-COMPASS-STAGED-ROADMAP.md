# Mind Compass — Staged Roadmap

## Governing rule

Prepare in parallel; implement in dependency order. The Mind Compass track does not replace or reorder mindRID's approved V19–V21 roadmap.

## Stage 0 — Embryonic foundation (now)

Deliverables:
- Foundation and non-negotiable principles.
- Journey/meteor interaction model and four-direction vocabulary.
- Conceptual data and privacy contract.
- Decision register and change-control rule.
- V19 inventory checklist entries for Compass-related data flows and future requirements.

Do not:
- Add production tables or migrations yet.
- Instrument personal attention history.
- infer or store emotional states from live user content.
- introduce Compass into the existing Home UI without an explicit implementation decision.

Exit gate: Founder confirms the foundation; engineering maps it against the actual repository and live-schema evidence.

## Stage 1 — V19: trust and security prerequisites

Keep the approved V19 sequence: privacy, consent, access control, recipient visibility, mention/tag consent, blocking/reporting/notifications/follow graph, and Google sign-in verification.

Compass-specific additions to the inventory:
- Where would Compass data live, and who could read it?
- Can the user delete journeys, inferred interpretations and attention history independently?
- Are private maps excluded from public feeds, search, recommendations and analytics exports by default?
- What data leaves the system if an external AI provider is used?
- Are consent, revocation, retention and auditability supported?

Exit gate: documented data flows and verified access policies; no claims of live security based solely on source code.

## Stage 2 — V20: interactive 2D pilot

Minimum pilot:
1. Optional Compass entry point that does not disrupt ordinary mindRID use.
2. Four-direction orientation, editable by the user.
3. User-selected Whisper launches as a meteor-like visual journey.
4. Simple waypoints/branches connecting selected Whispers or resources.
5. Save, revisit, rename and delete journeys.
6. Optional user-authored reflection on a possible defence pattern; AI interpretation may be deferred until its consent and safety contract is implemented.
7. Explainable suggestions and explicit feedback controls.
8. Reduced-motion mode and accessible list alternative.

Do not include in the first pilot: public emotional profiles, automatic unconscious-motive claims, engagement scoring, covert tracking, 3D world simulation, or mandatory faith prompts.

Exit gate: usability and accessibility tests; privacy/deletion checks; evidence that the map aids orientation rather than distracting from the reflection.

## Stage 3 — V20 extensions: optional coaching and AI assistance

Only after Stage 2 is stable:
- Optional emotional-defence exploration with uncertainty and alternative hypotheses.
- User-controlled habit-awareness check-ins and intentions.
- Optional faith-oriented reflection selected by the user.
- AI summaries/translation only with transparent processing, cost controls and preservation of original content.

Exit gate: consent comprehension, interpretation-correction tests, deletion verification and evaluation for shame/coercion or harmful overconfidence.

## Stage 4 — V21: shared constellations and Studio

- Opt-in constellations around shared questions, not inferred diagnoses.
- Explicit member and content visibility controls, easy exit and reporting.
- Governed no-code templates/extensions, scoped permissions, preview/publish, versioning, rollback and audit trail.
- No arbitrary user-uploaded executable code without a reviewed isolation/security architecture.

Exit gate: threat model, moderation operations, permission tests and rollback test.

## Release gates across all stages

- Founder approval for changes to purpose or standing concept.
- No release on syntax/static checks alone: browser, database, security and accessibility tests appropriate to scope are required.
- Keep V18.5 as production rollback until a later build is independently verified.
- Record known limitations honestly; distinguish source-confirmed, test-confirmed and live-environment-dependent claims.
