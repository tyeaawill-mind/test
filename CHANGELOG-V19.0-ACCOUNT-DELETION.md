# mindRID V19.0 — Account-deletion hardening

- Replaced the client-callable legacy deletion RPC with an authenticated Supabase Edge Function.
- Enforced verified-TOTP AAL2 on the server when a verified TOTP factor is enrolled; the client-side MFA prompt is no longer the only gate.
- Required an explicit `confirm: "DELETE"` request body.
- Temporarily deactivated the profile during cleanup and hardened Storage insert/update policies so new media uploads/updates are rejected while deletion is underway.
- Recursively paginated the user's UUID media folder, rejected unsafe list entries, removed files through the Storage API in batches, and performed a second sweep for late-arriving uploads.
- Restored the previous profile-deactivation state if cleanup or auth-user deletion fails, where restoration succeeds.
- Updated the app.js cache-busting query string.
- Added a dependency-injected simulation suite covering authentication, MFA, failures, pagination, nested folders, late uploads, and delete ordering.
- No production deployment or live Supabase deletion was performed.
