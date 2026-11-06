# Changelog — V19.2 Circle Access Control Preparation

## Approved
- Circle visibility supports both Public and Private modes.
- Public Circles are discoverable and open to authenticated, active users.
- Private Circles are not generally discoverable; access is invitation + acceptance.
- Private rosters and Circle messages are member-only.
- Existing Circles are proposed to remain Public for compatibility, subject to live inventory review.

## Added
- `README-V19.2-CIRCLE-ACCESS-CONTROL-PREP.md`: approved model, access matrix, UI/API contract, migration safeguards and staging acceptance tests.
- `MIGRATION-V19.2-CIRCLE-ACCESS-CONTROL-REVIEW-ONLY.sql`: commented migration outline and rollback design.

## Not changed
- No application source, styles, schema baseline or existing migrations changed.
- No live Supabase project or production deployment changed.
- No private Circle implementation is claimed.

## Validation
- Inherited static regression suite must pass from clean extraction.
- No browser, mobile, multi-user, live database, performance or production tests performed.
