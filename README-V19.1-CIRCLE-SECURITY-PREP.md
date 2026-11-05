# mindRID V19.1 — Circle Security Preparation

**Release type:** audit/preparation package; no application behavior change.
**Baseline:** V19.0 Account Deletion Fix (rebuilt source package).
**Purpose:** prepare a safe, evidence-based review of Circle membership visibility and membership mutations.

## Important release boundary

This package does not apply database changes, does not deploy an Edge Function, and does not alter the live Supabase project. No Circle privacy mode is introduced. The supplied schema has no `is_private`, `visibility`, invitation-mode, or approval-state column on `public.groups`; therefore a private-Circle patch cannot safely be inferred from the current schema.

## Confirmed source-level behavior

- `public.groups` contains `id`, `owner_id`, `name`, `description`, `location_country`, `location_city`, and `created_at`.
- `public.group_members` contains `group_id`, `user_id`, `role`, and `created_at`, with primary key `(group_id,user_id)`.
- The source RLS policy `group_members_select_related` permits SELECT whenever `auth.uid() IS NOT NULL`; therefore any authenticated user can read membership rows if table SELECT is granted.
- The source insert policy permits either self-insertion or owner insertion.
- `mindrid_join_group(gid)` checks authentication and group existence, then inserts the caller as a member. The supplied body does not check privacy, invitation, approval, block, or deactivated-account state.
- The Circle list UI reads membership rows for up to 80 groups to compute member counts and determine whether the current user has joined.
- The Circle detail UI reads the member roster and uses owner identity for the add-member UI. The add-member UI inserts membership rows directly.
- Circle messaging RLS checks membership. A membership policy change must preserve legitimate member messaging and owner add-member flows.

## Current live evidence supplied by the project owner

- All 26 listed `public` tables have RLS enabled; all have `rls_forced=false`; owner is `postgres`.
- `group_members` table grants previously reported: `anon SELECT`; `authenticated SELECT, INSERT, UPDATE, DELETE`; `service_role` broad privileges.
- `group_members` policy expressions and helper ACLs were supplied in the security-audit conversation. They are evidence from the user's exports, not a fresh connection to Supabase.
- The project owner has not authorized live SQL changes. None were made by this package.

## Risk assessment

1. **High — membership graph visibility:** authenticated users can enumerate membership rows across all groups. This may expose social relationships and group participation. Confirm whether this is intended product behavior.
2. **High — self-join semantics:** direct self-insertion and `mindrid_join_group` currently allow joining any existing group. This is consistent with an open/public Circle model but insufficient for private/invite-only Circles.
3. **Medium — direct writes and role assignment:** owner-side direct inserts and broad authenticated table grants should be reconciled. Verify whether a non-owner can assign `owner`/`admin` roles through permitted inserts and what UPDATE policies allow.
4. **Medium — account status and blocks:** supplied join function does not visibly check deactivated status or blocks. Decide whether either should restrict Circle joining.
5. **Medium — count/list implementation coupling:** the app currently derives Circle member counts and membership state by reading `group_members`. Restricting SELECT without a replacement count/current-membership interface will break the Circles page.

## Required decisions before an executable patch

- Are all current Circles public/open, or should private/invite-only Circles be supported now?
- May any signed-in user see the roster of a public Circle, or only its members?
- Should member counts be public, approximate, or visible only to members?
- Can owners add any account, or only connected users? Should invitees accept invitations?
- Can a member leave freely? Can an owner transfer ownership or delete/close a Circle?
- Should blocked relationships or deactivated accounts prevent joining or roster visibility?

## Recommended implementation sequence

1. Confirm the product decisions above; do not invent private-Circle semantics in SQL.
2. Design a server-side member-count/current-membership interface so the list page does not need unrestricted membership-row SELECT.
3. Separate join requests from owner invitations if private Circles are approved.
4. Restrict direct membership INSERT/UPDATE and role changes to explicit owner/admin paths; preserve the `mindrid_join_group` caller identity from `auth.uid()`.
5. Restrict roster SELECT to the approved visibility model.
6. Reconcile grants and function ACLs, including removing unnecessary `PUBLIC` execute grants.
7. Test with anonymous, unrelated authenticated, member, owner, blocked, and deactivated accounts.
8. Deploy to staging only after backup and rollback preparation; production requires separate approval.

## Test matrix

| Actor | Browse public Circle | Read roster | Join | Add member | Read/send Circle messages |
|---|---|---|---|---|---|
| Anonymous | Expected: no (current UI requires sign-in) | No | No | No | No |
| Unrelated authenticated | Confirm intended | Confirm intended | Current open join works | No | No |
| Circle member | Yes | Yes | Idempotent/no duplicate | No unless role permits | Yes |
| Circle owner | Yes | Yes | Already member | Yes, subject to approved invite rules | Yes |
| Blocked user | Decide | Decide | Decide | Decide | No unless explicitly allowed |
| Deactivated user | No | No | No | No | No |

## Validation limits

This package is based on the supplied V19.0 source archive and user-provided Supabase exports. It does not prove live deployed schema equivalence, actual HTTP/API behavior, or production security. Static inspection is not a substitute for staging tests with multiple real Supabase identities.
