# Memory

Durable operating facts for carolina-codes-dart. This file is not a second copy of the ledger.

## Maintenance

Edit a fact in place when it changes. A ruling has a status, a context, and a decision; those belong in `DECISIONS.md` and stay append-only. Past decision text is not rewritten except for status such as `superseded by D-...`.

Do not store secrets, production credentials, private keys, or personal data here. The public local database user `postgres:postgres` and register token `dev` are the starter examples and may stay.

## Workspace

- This git repo is the workspace root. `origin` is `https://github.com/brightball/carolina-codes-dart.git`. `gitea` is `https://gitea.zebra-hydra.ts.net/codes-carolina/carolina-codes-dart.git`.
- The Phoenix CMS is a different remote (`github.com/brightball/carolina-codes`). Do not assume `../elixir` is checked out.
- There is no local `openapi.yaml`. The contract is CMS `priv/api/openapi.yaml` plus `priv/api/AGENTS.md`.
- This tree does not ship `db/`, `images/`, `docker-compose.yml`, or `src/`. Implementation entry point is `bin/server.dart`.
- License is MIT (`LICENSE`).

## Versions and packages

- Dart 3.9.4 is pinned in `mise.toml` and the `Dockerfile` (`FROM dart:3.9.4`). The Gitea prepare job uses `docker.io/library/dart:3.9.4`.
- `pubspec.yaml` allows SDK `>=3.3.0 <4.0.0`. Compile and ship with 3.9.4 so the AOT binary matches `/runtime`.
- shelf 1.4.2 (`pubspec.yaml` `shelf: ^1.4.2`, `pubspec.lock` 1.4.2).
- shelf_router 1.1.4.
- postgres 3.5.12 (`package:postgres`).
- Dev dependencies include `lints` and `test`. `analysis_options.yaml` includes `package:lints/recommended.yaml` and sets `strict-casts`, `strict-inference`, and `strict-raw-types`.
- `mise.toml` also pins gitleaks 8.30.1 and osv-scanner 2.6.0.
- Identity constants in `bin/server.dart`: language `Dart`, framework `shelf`, `api_version` `0.2.0`, `created_year` 2026, `schema_version` 1. `language_version` is the first token of `Platform.version`.

## HTTP and process

- Listen address is `InternetAddress.anyIPv6`. Local default `PORT` is `4012`. Fly sets `PORT` to `8080`.
- `GET /health` returns `{ "ok": true }` and does not need the database. It does not open Postgres and does not run catalog SQL.
- `GET /` returns language, language_version, api_version, framework, created_year, schema_version, and endpoints.
- List routes wrap rows as `{ "data": [ ... ] }`. Unknown slugs return 404 `{ "error": "not_found" }`.
- Response headers include `X-Polyglot-Language: Dart` and `X-Polyglot-Framework: shelf`.
- Starter routes in service: `GET /health`, `GET /`, `GET /v1/years`, `GET /v1/speakers`, `GET /v1/speakers?year=2025`, `GET /v1/speakers/{slug}`, `GET /v1/speakers/{year}/{slug}`, `GET /v1/sponsors`, `GET /v1/sponsors?year=2025`, `GET /v1/sponsors/{slug}`, `GET /v1/sponsors/{year}/{slug}`.
- `serveApi` binds the port before Postgres is opened, then opens the catalog and registers in the background. `/` and `/health` answer while Postgres is still opening or unreachable.

## Data

- Query only `v1_*` views. Never query Ash tables or base tables.
- Statements in `bin/server.dart` read `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, and `v1_year_sponsors`.
- Year-scoped speaker rows include `languages` and `topics` taken from `v1_talks`. Year-scoped sponsor rows come from `v1_year_sponsors` and include `tier` and `blurb`.
- Pool `maxConnectionCount` is 8. `sslmode` `require`, `verify-full`, and `verify-ca` use `SslMode.require`. Any other value, including a missing parameter, uses `SslMode.disable`.
- Handler tests drive the shipped handler with a fake catalog (`executeHook` / `openHook`). Those tests do not need Postgres.
- Live HTTP uses the CMS database on Postgres 16. Local example: `DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev`.

## Register

- One `POST {CAROLINA_URL}/internal/api-endpoints/register` after listen, via `dart:io` `HttpClient`. There is no heartbeat.
- Skip when `CAROLINA_URL` or `POLYGLOT_REGISTER_TOKEN` is empty. On failure, log and keep serving.
- The register function does not open Postgres and does not run catalog SQL.
- Local example token is `dev`. `CAROLINA_URL` example is `http://127.0.0.1:4000`.
- Fly env in `fly.toml`: `CAROLINA_URL=http://carolina-codes.internal:8080`, `PUBLIC_BASE_URL=https://carolina-codes-dart.fly.dev`. The register token is not in the repo.

## Image and Fly

- Multi-stage `Dockerfile`: compile `dart compile exe bin/server.dart -o /app/server` on `dart:3.9.4`, then `FROM scratch`, `COPY --from=build /runtime/ /`, `COPY --from=build /app/server /app/server`.
- `fly.toml`: app `carolina-codes-dart`, primary region `iad`, internal port 8080, `force_https`, `auto_stop_machines = "suspend"`, `auto_start_machines = true`, `min_machines_running = 0`, HTTP check `GET /health`.

## Quality gates

Commands (README, Makefile, pre-commit, and Gitea check jobs):

- `dart test`
- `dart analyze --fatal-infos`
- `osv-scanner scan source --lockfile=pubspec.lock`
- `gitleaks detect --source . --verbose --no-git`
- `dart format --output=none --set-exit-if-changed .`
- `dart compile exe bin/server.dart -o build/server`

`make check` runs all of them. `make hooks` installs pre-commit and sets `core.hooksPath` to `.githooks`.

Gitea `.gitea/workflows/ci.yml` prepares the environment once, then jobs `test`, `sast`, `vuln`, `secrets`, `fmt`, and `aot` restore that payload and run one command each. The prepare upload script is POSIX `/bin/sh` (dash). Check jobs must not repeat apt, git clone, `dart pub get`, or tool downloads.
