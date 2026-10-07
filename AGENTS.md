# carolina-codes-dart

Read-only v1 polyglot HTTP API. Dart + shelf in this repository, which is its own workspace. You do not need a checkout of the Elixir CMS (`../elixir`) to build, test, or run it.

This tree is a finished API, not the forkable starter layout. It does not ship `openapi.yaml`, `db/`, `images/`, `docker-compose.yml`, or `src/`. There is no local openapi.yaml. The HTTP contract is the CMS `priv/api/openapi.yaml` plus `priv/api/AGENTS.md`. Do not fold this tree into the CMS git remote.

Siblings speak ordinary JSON over the v1 REST + SQL-view contract. Do not implement Ash JSON:API (`application/vnd.api+json`).

Before an architectural change, read `DECISIONS.md` and `MEMORY.md` and keep them current. See [Decisions and memory](#decisions-and-memory).

## Purpose

The Phoenix app (`Carolina.Polyglot`) keeps at most one language API warm and reads speakers and sponsors from it. With no APIs registered, it falls back to Ash. This process must:

1. Query PostgreSQL `v1_*` views only. Never query Ash resource tables or base tables (`speakers`, `organizations`, `talks`, and the rest).
2. Expose the starter route list below. Payloads follow the CMS contract.
3. Register once on boot with the Elixir site (no heartbeat). If `CAROLINA_URL` is unset, the token is unset, or the POST fails, log and keep serving.

Handler and unit tests that use a fake catalog do not need Postgres. Live HTTP against the views uses the CMS database (Postgres 16).

## Environment

| Variable | Example | Role |
|---|---|---|
| `DATABASE_URL` | `postgres://postgres:postgres@127.0.0.1:5432/carolina_dev` | SQL views |
| `CAROLINA_URL` | `http://127.0.0.1:4000` | Elixir site (optional; registration no-ops if the CMS is down) |
| `POLYGLOT_REGISTER_TOKEN` | `dev` | Bearer token for register |
| `PUBLIC_BASE_URL` | `http://127.0.0.1:4012` | URL Elixir will call |
| `PORT` | `4012` | Listen port (Fly sets `8080`) |

GET /health does not need the database. `/` and `/health` are bound before Postgres is opened, so both answer when the catalog is unreachable.

## SQL views (query these)

`v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, `v1_year_speakers`, `v1_year_sponsors`.

Those views live in the CMS database. This server's SQL uses `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, and `v1_year_sponsors`. Year speaker membership comes from `v1_talks`. Do not `SELECT` from base tables.

Year-scoped speaker rows include `languages` and `topics`. Year-scoped sponsor rows include `tier` and `blurb`.

## Required HTTP routes

Wrap list payloads as `{ "data": [ ... ] }` unless noted. Unknown slugs return 404 `{ "error": "not_found" }`.

- `GET /health` — liveness. This server returns `{ "ok": true }` and does not open Postgres.
- `GET /` — identity (language, framework, api_version, endpoints)
- `GET /v1/years`
- `GET /v1/speakers` and `GET /v1/speakers?year=2025`
- `GET /v1/speakers/{slug}` and `GET /v1/speakers/{year}/{slug}`
- `GET /v1/sponsors` and `GET /v1/sponsors?year=2025`
- `GET /v1/sponsors/{slug}` and `GET /v1/sponsors/{year}/{slug}`

`photo_path` and `logo_path` are web paths. Return the path. This tree does not serve image bytes.

## Register on boot (once)

`POST {CAROLINA_URL}/internal/api-endpoints/register`

```
Authorization: Bearer {POLYGLOT_REGISTER_TOKEN}
Content-Type: application/json
```

Body fields: `language`, `language_version`, `api_version`, `framework`, `created_year`, `base_url` (`PUBLIC_BASE_URL`), `schema_version` (1), `endpoints`.

Do not heartbeat. Elixir keep-alives the currently warm API.

The call uses `dart:io` `HttpClient` once after listen. It does not open Postgres. If `CAROLINA_URL` or `POLYGLOT_REGISTER_TOKEN` is empty, skip it. If the POST fails (connection refused, timeout, 4xx/5xx), log and keep serving.

## This API

- Listen on IPv6 (`InternetAddress.anyIPv6`) so Fly 6PN can reach the process.
- Production image: `dart compile exe` on the pinned Dart SDK, copied into a scratch image with the SDK `/runtime` directory.
- Fly `auto_stop_machines = "suspend"` (`auto_start_machines` left on) so an idle machine resumes instead of cold-booting.
- Quality gates: `make check` runs dart test, dart analyze, osv-scanner, gitleaks, dart format, and `dart compile exe`. Gitea `.gitea/workflows/ci.yml` prepares the environment once, then runs each check as its own job.
- Install, run, and the pinned versions: `README.md`.

## Cursor Cloud specific instructions

This repository is one sibling git remote in the carolina.codes polyglot fleet. Cloud agents should treat **this repo** as the workspace root. The Phoenix CMS is a different remote (`github.com/brightball/carolina-codes`); do not assume `../elixir` or other sibling directories exist unless those remotes are attached to the same Cloud environment.

Postgres `v1_*` views live in the CMS database. Handler/unit tests that use a fake catalog do not need Postgres. For live HTTP against the views, start Postgres 16 and set:

- `DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev`
- `CAROLINA_URL=http://127.0.0.1:4000` (optional; registration no-ops if CMS is down)
- `POLYGLOT_REGISTER_TOKEN=dev`
- `PUBLIC_BASE_URL` / `PORT` as in the README

Do not query Ash tables. Do not fold this tree into the CMS git remote. Contract: CMS `priv/api/openapi.yaml` + `priv/api/AGENTS.md`.

## Decisions and memory

Dart and shelf do not keep an architecture log of their own. `pubspec.yaml` and `pubspec.lock` record dependencies. `analysis_options.yaml` records the analyzer contract. Choices that those files do not capture live in two root files:

- `AGENTS.md` (this file) is the short standing manual.
- `DECISIONS.md` is the append-only ledger. Each entry has a date, a status, a context, a decision, and alternatives or consequences. Do not rewrite a past entry. The only in-place edit is status, such as `superseded by D-...`. A changed ruling is a new entry.
- `MEMORY.md` holds durable operating facts (pins, paths, commands, workspace boundaries). Edit a fact in place when it changes. Do not paste the ledger into it.

Read both files before an architectural change, then update the one that owns the change. Do not put secrets, production credentials, private keys, or personal data in them. The public local examples `postgres:postgres` and token `dev` may stay.
