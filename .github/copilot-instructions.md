## Strapi Monorepo Snapshot
- Yarn 4 (node-modules linker) monorepo; workspaces live in `packages/*`, `examples/*`, `.github/actions/*`, `scripts/*`. Nx (`nx.json`) orchestrates builds/tests and caches artifacts.
- Core server code lives in `packages/core/strapi`, with supporting packages in `packages/core/*` (database, permissions, email, content-manager, etc.).
- The React admin app sits in `packages/core/admin/admin` (shared logic under `packages/core/admin/shared`); rollup config + test presets live beside it.
- Official plugins (`packages/plugins/*`) and providers (`packages/providers/*`) mirror the runtime extension surface. Utilities/config packages (e.g. `packages/utils/eslint-config-custom`) centralize tooling.

## Go-To Commands (from root `package.json`)
- Install + bootstrap: `yarn` then `yarn setup` (runs clean + full build via `nx run-many`).
- Build everything: `yarn build` (`build:code` + `build:types` targets across projects). For a single package use `yarn nx run <project>:build`.
- Live rebuild: `yarn watch` (Nx watch triggers `build:code`/`build:types` for touched projects).
- Formatting & linting: `yarn format` and `yarn lint`; prefer `yarn lint:fix` for autofix.

## Testing Habits
- API integration: `yarn test:api` (see `tests/scripts/run-api-tests.js` for DB matrix + app scaffolding). Ensure local Postgres/MySQL services if you override the default sqlite run.
- CLI scenarios: `yarn test:cli` (drives CLI through `tests/scripts/run-cli-tests.js`).
- E2E suites: `yarn test:e2e` (Playwright config under `playwright.base.config.js`).
- Admin/front tests: `yarn test:front` (sets `IS_EE=true` for enterprise paths; use `yarn test:front:ce` for community-only). Unit tests fall back to `yarn test:unit` or package `test:unit` targets.
- TS type checks: `yarn test:ts` fan-out across back/front/packages.

## Patterns Worth Mirroring
- Follow Nx target names (`build:code`, `build:types`, `test:unit`, etc.) when adding new tasks; defaults and cache inputs live in `nx.json`.
- New packages usually expose `src/index.ts` and maintain build output to `dist/` via Rollup/SWC configs (see `packages/core/admin/rollup.config.mjs` or any `package.json` `build:code` entry).
- Plugins share a common structure: `server/` (services, controllers, routes) + optional `admin/`. Look at `packages/plugins/users-permissions` for a full example.
- Example apps in `examples/getstarted`, `examples/kitchensink` drive docs/tests; keep CLI templates in sync when changing generators.
- Custom GitHub Actions under `.github/actions/*` are mini Node projects with their own package.json/jest config—update both code and bundled `dist/`.

## Cross-Cutting Notes
- Release tooling: `scripts/release.js` cooperates with Nx `release.projects`; check that list before adding packages that need version bumps.
- OpenAPI/helpful scripts live in `scripts/open-api` and `scripts/front`; reuse them instead of reimplementing helpers (e.g., translation utilities).
- Shared environment knobs: admin tests rely on `IS_EE`, backend tests set `STRAPI_DISABLE_EE`; check the relevant script before toggling enterprise features.
- Database configs for tests/examples default to sqlite; override via CLI flags or env if you need Postgres/MySQL (see `tests/helpers/test-app`).

## If You Need More Detail
- Start with `package.json`, `nx.json`, and the target package `package.json` to understand build/test wiring.
- Trace runtime flows beginning at `packages/core/strapi/src/index.ts` and follow service dependencies into other `packages/core/*` folders.
- Let me know if you need deeper notes on admin UI, plugin internals, or CI workflows and I can expand with concrete file references.
