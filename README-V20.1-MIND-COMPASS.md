# mindRID V20.1 — Mind Compass: Discover · Develop · Remember

**Release type:** local-first functional prototype with optional, consent-gated AI assistance.
**Source baseline:** V20.0 Mind Compass test build, based on V19.2 preparation package.

## What changed

### Discover
- Surfaces the oldest still-open reflection as a user-controlled return point.
- Offers a first-reflection path when the user has no saved reflections.
- Finds possible connections between the user's own local reflections through transparent shared-keyword matching. It explicitly says shared words do not prove shared meaning.
- User can develop, revisit, or set aside a surfaced reflection.

### Develop
- Three-step reflection workflow: Recall, Examine, Evolve.
- A new development is appended as a version; the original is not overwritten.
- Optional AI challenge can offer an assumption, alternative perspective and open question.

### Remember
- Private Reflection Journey with original and later versions.
- Revisit, set aside, and delete controls.
- No streaks, scores, inferred mood, personality profiling, dwell-time analysis or push prompts.

## Strict privacy boundary

- Reflection data remains in browser localStorage, partitioned by signed-in user ID. This is not a security boundary against someone with access to the same browser profile.
- No Compass reflection is sent to a provider automatically.
- Each AI request requires a fresh, unchecked-by-default consent checkbox.
- Only the selected reflection and the three fields in the active Develop form are sent for that request.
- AI requests pass through an authenticated Supabase Edge Function. The provider API key is a server secret and is never placed in browser code.
- The Edge Function does not write reflection content to Supabase and does not intentionally log it.
- The AI provider still processes the text under its own terms. Do not enable the feature until the provider's current data-use, retention and free-tier terms have been reviewed.
- No provider key configured: AI assistance returns an unavailable message; Discover, Develop and Remember continue without AI.

## Local data and migration

- V20.0 local Compass data is copied into the V20.1 key on first load and normalized with an original-version entry.
- Data remains device/browser-local; there is no cross-device sync, account export integration or account-deletion integration in this prototype.
- Clearing browser storage may erase Compass data. Avoid highly sensitive information in this test build.

## Optional AI setup (not performed by this package)

1. Deploy the function directory `supabase/functions/mind-compass-assist` to the intended Supabase project.
2. Keep JWT verification enabled for the function.
3. Configure Supabase Function secret `GEMINI_API_KEY` with a provider API key. Optionally configure `GEMINI_MODEL` and `MINDRID_ALLOWED_ORIGIN`.
4. Review Google's current Gemini API data-use and retention terms and free-tier limits before enabling the feature for users.
5. Test with a deliberately non-sensitive sample account and verify that no request occurs unless the consent box is checked.

No SQL migration is required. No live Supabase project was changed. No provider key is included.

## Tests

Run from this directory:

```sh
node --check app.js
node tests/v201-mind-compass.js
node tests/v200-mind-compass.js
node tests/v184-regression.js
node tests/v183-navigation.js
node tests/v182-regression.js
node tests/audit-smoke.js
node tests/account-deletion-static-audit.mjs
node tests/delete-account-simulation.mjs
```

Static tests do not replace browser, mobile, authenticated Supabase, multi-user, provider, or production testing.
