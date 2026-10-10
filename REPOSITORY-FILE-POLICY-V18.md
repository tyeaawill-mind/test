# mindRID main repository file policy — V18

## Keep in the deployable website root
- `index.html`, `app.js`, `styles.css`: application entry point and current client code.
- `assets/`, `icon.svg`, `apple-touch-icon.png`, `manifest.webmanifest`: referenced UI/PWA assets.
- `CNAME`: keep for GitHub Pages custom domain deployment.
- `robots.txt`, `sitemap.xml`: keep if their host/domain and routes remain accurate.
- `schema.sql`: canonical schema reference; update whenever the schema changes.
- The currently required migration SQL files, clearly ordered and documented. Do not delete migrations merely because they have already been applied to one environment.
- `README.md`: short project overview and links to the canonical deploy guide.
- One canonical current deploy guide (`DEPLOY-V18.md`) and current release audit (`AUDIT-V18.md`).

## Move out of the website root (archive under `/docs/releases/` or release artifacts)
- Historical `AUDIT-V12.md` through `AUDIT-V17.md`.
- Historical `DEPLOY-V7.md` through `DEPLOY-V17.3.md`.
- Superseded copies of deployment instructions, old UX reviews, old changelogs, and testing scripts not needed by GitHub Pages at runtime.
- `test-landing.html` after its checks are complete, unless it is intentionally maintained as a private/manual QA fixture. It should not be a public production route by accident.

## Keep, but don't treat as live functionality
- `TRADEMARK-PLAN.md`: project/legal planning, better stored in `/docs/` or a private planning repository.
- `tests/`: keep in the repository for maintainers; it is not served as a user-facing feature. Prefer a `/tests/` folder and add a documented command to run them.

## Safety rules
1. Never delete a migration that may be needed to reproduce or upgrade an environment; archive it and keep a migration ledger.
2. Do not delete `CNAME`, PWA icons, manifest, service worker, or media assets until all references and deployment settings are checked.
3. Do not keep multiple files claiming to be the current deploy guide. Link one current guide from README.
4. Before removing `test-landing.html`, verify no deployment workflow or developer uses it.
5. Historical docs are not harmful to the running site, but a large number of competing instructions increases operational error. Archive rather than destroy them.
