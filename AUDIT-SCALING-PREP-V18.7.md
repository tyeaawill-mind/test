# mindRID V18.7 scaling preparation audit

**Status:** staging candidate only. This package contains source/test/documentation changes. No live database, hosting, or production changes were made.

## Approved scope
- Correct cache invalidation and make tests verify CSS/JS release-key consistency.
- Replace brittle Home assertions with behavior/structure-oriented checks.
- Inventory schema grants, RLS policies and SECURITY DEFINER functions; prepare read-only diagnostics and a review plan, not an applied permission migration.
- Specify pagination and query-scaling behavior without implementing pagination before the security baseline is agreed.
- Define staging release gates for privacy, functional regression, performance, recovery and rollback.

## Changes in this package
1. `index.html`: CSS and JS cache keys now use `20261026-v18.7-scaling-prep`.
2. `tests/v182-regression.js`: cache-busting assertion points at the candidate release key.
3. `tests/v183-navigation.js`: Home contract checks include the Home shell, feed navigation, mobile composer trigger, composer/input and feed container; tests retain feed route and UI checks.
4. `tests/v184-regression.js`: Home structure and CSS/JS cache-key consistency checks replace exact source-string assumptions.
5. Added `DIAGNOSTIC-SUPABASE-PERMISSIONS.sql` (read-only), `PAGINATION-AND-QUERY-SCALING-SPEC.md`, and `STAGING-RELEASE-GATES.md`.

## Source-level risks found for review (not live-state conclusions)
- `schema.sql` contains `GRANT SELECT, UPDATE ON public.profiles TO authenticated`; table-wide UPDATE can undermine the intended column-level profile-edit restriction if it exists in the deployed project.
- `group_members_select_related` uses `auth.uid() IS NOT NULL`, which permits every authenticated viewer to read membership rows under that policy. Confirm whether this matches the approved Circle privacy model.
- `group_members_insert_self_or_owner` allows a user to insert their own membership row unless other constraints/triggers or policies prevent the operation; verify invite/join restrictions and Circle visibility requirements.
- `whisper_recipients_insert_owner` verifies Whisper ownership but does not visibly validate recipient eligibility, blocks or active status in its policy expression. Confirm whether other controls enforce these requirements.
- `mindrid_is_conversation_member(cid, viewer)` is SECURITY DEFINER and takes a caller-supplied viewer UUID. Review its execute ACL and all call sites to ensure it cannot be used as an unintended membership oracle.
- `schema.sql` repeats the `recommendation_feedback` table/policy/index/grant block. It may be harmless under `IF NOT EXISTS` and policy drops, but should be reconciled to keep fresh installs deterministic and maintainable.
- The schema includes multiple SECURITY DEFINER functions and explicit grants. Review every function's `search_path`, execute ACL, caller identity checks and returned data before changing privileges.
- The source has unbounded `listMine()` and multiple fixed-size feed queries; pagination is specified but deliberately not implemented in this release.

## Static test results

Run from the repository root with Node.js:

- `node tests/audit-smoke.js` — PASS, 10/10.
- `node tests/v182-regression.js` — PASS, 12/12.
- `node tests/v183-navigation.js` — PASS, Home/navigation contract assertions pass.
- `node tests/v184-regression.js` — PASS, 9/9.

These are static source assertions only. They do not prove browser rendering, live RLS behavior, production security, load capacity, or backup recovery.

## Rollback

Rollback is the prior V18.6 recovery package. V18.7 changes only the cache query keys, test assertions and documentation/diagnostic assets; it does not modify `app.js`, `styles.css`, `schema.sql`, any migration, or any live service. Revert to V18.6 if the deployed candidate has a cache or UI issue. Do not roll back or apply database changes as part of this package because none are included.
