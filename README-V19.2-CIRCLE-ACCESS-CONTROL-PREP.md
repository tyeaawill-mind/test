# mindRID V19.2 — Circle Access Control Preparation

**Release type:** product-approved access model + implementation preparation.  
**Baseline:** V19.1 Circle Security Preparation.  
**Approved product decision:** both Public and Private Circles.

## Approved behavior

- A Circle owner selects **Public** or **Private** when creating a Circle.
- **Public Circle:** discoverable to signed-in users; any signed-in, active account may join; member roster visible to signed-in users; member messaging restricted to members.
- **Private Circle:** not listed in general discovery; access is available to members and the owner; membership requires an explicit invitation and acceptance; roster, messages and member-only content are visible only to members.
- Existing Circles are migrated as **Public** to preserve current discoverability and open-join behavior. This default must be reviewed against the live inventory before applying the migration.
- The owner is the initial owner member. A normal member cannot grant owner/admin roles. Owner-only invitation and role-management operations must be server-side and identity-derived from `auth.uid()`.
- Joining/inviting must reject unauthenticated and deactivated accounts. Block handling must not be used to silently disclose private Circle membership.

## Scope of this package

This package documents the approved model, migration design, UI/API contract, security matrix and staging tests. It does **not** change `app.js`, `styles.css`, `schema.sql`, existing migrations, or the live Supabase project. This is deliberate: the live schema and deployed app call paths have not been freshly inspected, and a security-sensitive schema change must not be represented as production-ready merely because static source code is available.

## Required schema design

1. Add `groups.visibility` with values `public` / `private`, default `public`.
2. Add a `circle_invitations` table with Circle, invitee, inviter, status (`pending`, `accepted`, `declined`, `revoked`, `expired`), created/updated/expiry timestamps and uniqueness for one active invitation per Circle/invitee.
3. Enforce one owner membership per Circle and prevent direct client assignment of `owner` or `admin` roles.
4. Replace unrestricted `group_members` SELECT with policy predicates matching Circle visibility and membership.
5. Remove direct self-insert membership. Use a join RPC for public Circles and invitation-acceptance RPC for private Circles; both derive the actor from `auth.uid()`.
6. Restrict invitation creation/revocation to the Circle owner (future admin role only after explicit authorization rules).
7. Ensure Circle message SELECT/INSERT and Realtime access are membership-only for both visibility modes.
8. Replace app-side raw membership scans for counts/status with a narrow server-side interface, or a carefully scoped aggregate endpoint. Do not expose the full membership graph just to calculate counts.
9. Revoke unnecessary `PUBLIC` execution on mutation RPCs; grant only to `authenticated` where required. Review all SECURITY DEFINER functions, search_path and fully qualified object references.

## UI/API contract

- Circle creation form: required visibility choice, default **Public**, with concise explanation of discoverability and joining.
- Public Circle cards: visible in discovery; show member count without fetching the full roster.
- Private Circle cards: never appear in general discovery; reachable only through an invitation/accepted membership or an owner-controlled route.
- Private invitation: invitee sees a pending invitation with Circle name, inviter and accept/decline actions. No private description, roster, messages or content should be returned before acceptance unless the owner explicitly approves a limited invitation preview.
- Circle detail: non-members of public Circles may see the public landing details and join action; non-members of private Circles receive a generic unavailable/not-authorized state that does not confirm private existence.
- Roster: public Circles visible to signed-in users; private Circles visible only to members. Revisit if product owner changes this policy.
- Circle wall and messaging: members only. Existing wall query currently fetches public Whispers by member authors; it must not be treated as a private Circle content boundary. A future private Circle contribution feature needs explicit Circle-scoped content authorization.

## Security matrix

| Actor | Discover public | Discover private | Public roster | Private roster | Join public | Join private | Read/send messages |
|---|---:|---:|---:|---:|---:|---:|---|
| Anonymous | No | No | No | No | No | No | No |
| Signed-in non-member | Yes | No | Yes | No | Yes | No; invitation required | No |
| Public Circle member | Yes | No | Yes | No | Already member | No | Own Circle only |
| Private Circle invitee | No | No | No | No | Yes, for public | Accept invitation only | Only after acceptance |
| Private Circle member | No general discovery | No general discovery | Yes for public Circles | Yes | Yes | Already member | Own Circle only |
| Circle owner | Yes for own public Circle | Via owner route | Yes | Yes | Already member | Invite/accept rules | Own Circle only |
| Deactivated account | No | No | No | No | No | No | No |

## Migration safeguards

- Take a database backup and export current `groups`, `group_members`, relevant grants, policies, function definitions and function ACLs.
- Inventory existing groups and owners. Confirm every group has exactly one owner membership before applying constraints.
- Apply migration to staging first. Existing groups default to `public` only after explicit inventory review.
- Use transaction-safe DDL where supported; add constraints `NOT VALID` then validate after data cleanup where appropriate.
- Do not blindly replace all policies: preserve owner operations and existing legitimate membership rows.
- Do not grant table-wide INSERT/UPDATE on invitation or membership tables to clients.
- Prepare rollback that restores the prior policies/functions and removes new objects only after checking for invitations created after migration.
- Production deployment requires separate explicit approval.

## Staging acceptance tests

1. Anonymous visitor cannot discover Circles, read rosters, join, read messages or use invitation endpoints.
2. Authenticated non-member sees public Circles and may join once; repeat join is idempotent.
3. Authenticated non-member cannot discover private Circles, enumerate their IDs/names, read rosters/messages, or self-insert membership.
4. Owner can invite an eligible account to a private Circle; invitee can see only their own invitation and can accept/decline it.
5. Acceptance creates exactly one membership row; replaying acceptance does not duplicate membership or elevate role.
6. Non-owner cannot invite, revoke invitations, add members directly, or assign `admin`/`owner` roles.
7. Private non-member cannot read private Circle messages via REST, Realtime, guessed UUID, or direct table access.
8. Public and private membership visibility follow the matrix above.
9. Deactivated accounts cannot join, accept invitations, send messages, or retain active sessions where app policy requires deactivation enforcement.
10. Existing public Circles, owner membership, create/list/detail/join/add-member/messaging flows regress cleanly.
11. Counts and discovery do not require unrestricted `group_members` SELECT and do not leak private membership.
12. Run two-or-more-user tests, anon tests, RLS tests, browser/mobile tests, backup recovery and rollback rehearsal.

## Known unresolved implementation dependencies

- Confirm the exact deployed `groups` / `group_members` schema and current policy/function definitions from live Supabase immediately before migration.
- Confirm whether the product should allow owner transfer, co-admins, invitation expiry duration and whether an owner can remove members. These are not silently introduced in this release.
- Confirm whether public Circle roster is visible to all authenticated users as specified above.
- Reconcile the Circle wall's current public-Whisper query with the new privacy model; it is not private Circle publishing.

## Release boundary / verification

This package is a preparation artifact, not an implemented or deployed V19.2 application. Static regression tests validate the inherited baseline only. No live database, browser, mobile, multi-user, load, backup or production deployment tests were performed.
