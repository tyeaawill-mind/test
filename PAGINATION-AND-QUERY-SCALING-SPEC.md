# mindRID pagination and query-scaling specification (proposal only)

Status: **Proposed; not implemented in this package.** Do not change query behavior until the authorization/security baseline is agreed and the UI acceptance tests are approved.

## Scope

Prioritize unbounded or potentially growing lists:
1. My reflections (`listMine()` currently selects all of the signed-in user's `whispers`, ordered by `created_at DESC`, without a limit).
2. Public/For You/Latest feeds and Following feed.
3. Replies/comments, notifications, messages, Memories/saves, and profile lists after reviewing their current query paths.

## Pagination contract

- Use keyset/cursor pagination for growing feeds where possible; avoid large offset scans as data grows.
- Stable order must include a unique tie-breaker: `created_at DESC, id DESC` (or the table's stable primary key) so records sharing timestamps are not skipped or duplicated.
- Initial page target: 20 items; subsequent page size 20. Validate on staging before finalizing.
- Cursor must contain the last row's ordering values and be opaque to ordinary UI presentation. A cursor must never grant access; every page query must re-run normal authorization/RLS checks.
- Stop when the page contains fewer than the requested number of rows, or when the server indicates no next cursor. Prevent parallel duplicate requests and discard stale responses after route changes.
- Deduplicate appended rows by primary key; do not use deduplication as a substitute for correct cursor ordering.
- Keep a visible loading state, retry on failure, and an explicit end-of-list state. Do not autoplay media or automatically trigger unrelated actions.
- Preserve current empty states, visibility rules, author decoration, media hydration and interaction controls.
- For query paths where PostgREST cannot express the composite cursor cleanly without fragile filter strings, prefer a narrowly scoped SQL RPC with explicit auth checks and stable return schema; review RLS and execute ACL before adoption.

## Acceptance tests

- Seed more than 3 pages, including multiple rows with identical `created_at` timestamps.
- Traverse every page and verify each eligible row appears exactly once in the expected order.
- Insert a newer row between page requests and verify no duplicate/missing records under the documented consistency model.
- Verify private and selected-visibility rows never leak into public pages; selected recipients and owners retain only their authorized access.
- Verify anonymous, signed-in, blocked and deactivated-account cases.
- Verify route changes cancel/ignore stale responses; retries do not append duplicates.
- Verify media hydration and Like/Memory/Reply/Share/Why/Report controls continue working on appended cards.
- Measure query latency and rows scanned at realistic staging volumes before adding indexes.

## Query review rules

- Replace `select('*')` with the minimum explicit columns each view needs, after tracing all consumers of the returned object.
- Do not add indexes from guesswork. Capture slow queries and compare `EXPLAIN (ANALYZE, BUFFERS)` on representative staging data.
- For every index proposal, document the query it supports, write cost, size impact, and measured benefit.
- Keep pagination implementation separate from privacy-policy changes so regressions can be isolated and rolled back.
