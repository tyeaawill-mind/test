# mindRID V19.0 Account-Deletion Audit Report

**Scope:** Targeted correction of the account-deletion path in the V18.5 source archive. This is a source-level and simulated audit, not a live production certification.

## Initial findings

| Severity | Finding | Evidence / impact | Status |
|---|---|---|---|
| Critical | Legacy deletion RPC attempted direct deletion from `storage.objects` | The supplied live Supabase trigger `storage.protect_delete()` rejects direct table deletion unless an internal bypass setting is enabled. The old function could fail before deleting the Auth user. | Fixed in source: Storage API is used; legacy client RPC is revoked by migration. |
| High | MFA gate existed only in browser code | A valid bearer token could call the Edge Function directly without executing the browser's `ensureAAL2()` check. | Fixed in source: server checks verified TOTP factors and requires current `aal2`; MFA lookup errors fail closed. |
| High | Upload-vs-delete race | A user could potentially upload media while the function was enumerating their folder, leaving orphaned media. | Mitigated: profile is temporarily deactivated; migration blocks Storage insert/update for deactivated profiles; a second sweep catches late-arriving uploads. |
| Medium | Browser cache could retain old deletion handler | The HTML still referenced the V18.5 cache key after `app.js` changed. | Fixed: V19.0 cache key added. |
| Medium | Broad wildcard CORS | The previous handler allowed any origin to make browser requests. CORS is not authentication, but narrowing origins reduces unnecessary exposure. | Fixed in source: exact allowlist for mindRID production origins and local development origins. |

## Controls in the corrected source

- Derives the user ID only from a validated bearer token; it never accepts a client-supplied target user ID.
- Requires `POST` and an explicit `confirm: "DELETE"` request body.
- Keeps the service-role key exclusively in the Edge Function environment; static checks confirm it is absent from `app.js`.
- Enforces server-side AAL2 for accounts with a verified TOTP factor.
- Temporarily hides the profile during cleanup and restores the previous deactivation state after recoverable failures where possible.
- Enumerates only the caller's UUID folder, supports nested folders and pagination, rejects unsafe entry names, limits traversal depth to 32 and enumeration to 100,000 entries, and removes objects through the Storage API in batches of 100.
- Runs a second media sweep before Auth-user deletion.
- Does not delete the Auth user if media enumeration/removal fails.
- Revokes `PUBLIC`, `anon`, and `authenticated` execution of the legacy deletion RPC in the targeted migration.

## Test evidence

The following checks passed against the rebuilt source:

- JavaScript syntax check for `app.js` and syntax checks for the simulation/static tests.
- TypeScript type-check of the Edge adapter and `.mjs` core using local ambient stubs for Deno and the Supabase npm module. This is **not** equivalent to a real Deno/Supabase CLI compile.
- `tests/audit-smoke.js`.
- `tests/v182-regression.js`, `tests/v183-navigation.js`, and `tests/v184-regression.js` after updating their stale expectations to the current V18.5 Home contract and V19.0 cache key.
- `tests/delete-account-simulation.mjs`: unauthenticated access, explicit confirmation, server-side MFA enforcement and failure paths, profile lock/read failures, storage listing/removal failures, Auth deletion failure, nested media, pagination beyond 100 entries, batch size, late-arriving upload, unsafe entry names, HTTP method rejection, and CORS allowlist behavior.
- `tests/account-deletion-static-audit.mjs`: client call path, no browser service-role key, cache-busting, Storage API use, MFA gate, Storage write lock, and legacy RPC revocation.
- ZIP integrity check after packaging.

## Residual risks / verification still required

1. No live Supabase project was changed, and the migration has not been executed against the supplied project.
2. No actual Supabase Edge Runtime deployment/compile or staging deletion was run because this environment does not have the Supabase CLI/Deno runtime configured.
3. Simulations cannot prove the deployed Storage API's exact behavior, live RLS interactions, Auth deletion cascades, OAuth/session invalidation, or real network timeout behavior.
4. The migration assumes the confirmed `profiles.is_deactivated` column and existing policy names `mindrid_media_storage_insert` and `mindrid_media_storage_update`. It is targeted to the supplied V18.5/live-schema context; verify it is applied to the intended project only.
5. The workflow is not a single atomic transaction. If media cleanup succeeds but Auth deletion fails, the function attempts to restore the prior profile state; a rare ambiguous network result may still require operator review.
6. Accounts with more than 100,000 listed storage entries or folder nesting deeper than 32 fail closed and require a support-assisted cleanup path.

## Release recommendation

**Source package: ready for controlled staging deployment. Production status: not verified.** Deploy the Edge Function, apply the targeted migration, deploy the website, and complete a controlled deletion using a disposable staging account before enabling account deletion for real users.
