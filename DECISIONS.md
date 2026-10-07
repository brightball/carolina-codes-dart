# Decisions

Append-only ledger of ratified choices for this Dart + shelf API. A merged commit ratifies an entry.

## Protocol

- Append a new entry for a new ruling. Do not rewrite past context, decision, alternatives, or consequences.
- The only in-place edit of an old entry is `status` (for example `superseded by D-...`).
- Each entry has a date, a status, a context, a decision, and alternatives or consequences.
- Durable operating facts that are not rulings belong in `MEMORY.md`. Edit those facts in place.
- No secrets, production credentials, private keys, or personal data. Public local examples (`postgres:postgres`, token `dev`) may stay.

Dates below are the commits that put the choice in the tree. The 2026-10-07 entry records the documentation practice itself.

## D-2026-08-28-stack — Dart, shelf, shelf_router, and package:postgres

- status: active
- date: 2026-08-28
- context: The polyglot slot is a small read-only JSON API over SQL views. The process must compile and run as one Dart program with a pinned SDK.
- decision: Implement the API with Dart, shelf 1.4.2, shelf_router 1.1.4, and package:postgres (locked at postgres 3.5.12). Routes live in `bin/server.dart`. shelf_router matches path parameters. `package:postgres` `Pool` runs the view queries.
- alternatives: A larger Dart HTTP framework (more app structure than this route list needs). Hand-rolled `dart:io` request routing (shelf_router already covers the path table). A second SQL client besides package:postgres.
- consequences: Dependency changes go through `pubspec.yaml` and `pubspec.lock`. The framework name registered with the CMS is `shelf`. The language name is `Dart`.

## D-2026-08-28-views — Ordinary JSON from v1 views

- status: active
- date: 2026-08-28
- context: The CMS contract is v1 REST plus SQL views. Ash JSON:API is a different wire format. Base tables are not the public contract.
- decision: Query only `v1_*` views. Never query Ash resource tables or base tables (`speakers`, `organizations`, `talks`, and the rest). Responses are ordinary JSON. List payloads use `{ "data": [ ... ] }`. Unknown slugs return 404 `{ "error": "not_found" }`. The contract file is the CMS `priv/api/openapi.yaml` plus `priv/api/AGENTS.md`. This tree has no local `openapi.yaml`.
- alternatives: Implementing `application/vnd.api+json`. Selecting from Ash or base tables and shaping rows in Dart. Vendoring `openapi.yaml`, `db/`, and `images/` from the starter.
- consequences: Allowed view names are `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, `v1_year_speakers`, and `v1_year_sponsors`. This server's statements use `v1_speakers`, `v1_sponsors`, `v1_years`, `v1_talks`, `v1_sponsorships`, and `v1_year_sponsors`. Year speaker membership comes from `v1_talks`. `photo_path` and `logo_path` are returned as paths; this process does not serve image bytes.

## D-2026-08-28-register — Register once with dart:io HttpClient and keep serving

- status: active
- date: 2026-08-28
- context: Elixir keeps at most one language API warm. The starter requires one register call on boot and no heartbeat. The API must still serve when the CMS is down.
- decision: After listen, call `POST {CAROLINA_URL}/internal/api-endpoints/register` once with `dart:io` `HttpClient` (5 second connect and response timeouts). Send `Authorization: Bearer {POLYGLOT_REGISTER_TOKEN}` and a JSON body with `language`, `language_version`, `api_version`, `framework`, `created_year`, `base_url`, `schema_version` (1), and `endpoints`. Skip the call when `CAROLINA_URL` or `POLYGLOT_REGISTER_TOKEN` is empty. On connection failure, timeout, or any thrown error, log and keep serving. Do not heartbeat. The register call does not open Postgres.
- alternatives: Adding `package:http` only for this POST. Retrying or heartbeating so a down CMS blocks boot. Refusing to listen until register succeeds.
- consequences: `pubspec.yaml` has no HTTP client dependency. Registration is best-effort. A local process is useful with the CMS stopped.

## D-2026-09-01-fly-ipv6 — IPv6 listen and batched year SQL

- status: active
- date: 2026-09-01
- context: Fly 6PN reaches the app on IPv6. Per-speaker queries on year listings add a round trip for every row.
- decision: Bind with `InternetAddress.anyIPv6` (dual-stack where the OS allows). Build `GET /v1/speakers?year=` from one speaker query, one talks query, and one years query, then group in memory. Ship `fly.toml` for app `carolina-codes-dart` with `GET /health` as the HTTP check.
- alternatives: Binding `InternetAddress.anyIPv4` only (misses Fly private networking). Querying talks once per speaker.
- consequences: Local and Fly processes listen on IPv6 any-address. Year speaker listings stay on the views above. `GET /health` stays off the catalog so the Fly check does not require Postgres.

## D-2026-09-06-workspace — This repo is the workspace root

- status: active
- date: 2026-09-06
- context: Each polyglot API is its own git remote. Cloud agents were assuming a sibling `../elixir` checkout.
- decision: Treat this repository as the workspace root. The Phoenix CMS is `github.com/brightball/carolina-codes`. Do not assume `../elixir` or any other sibling directory is present. Do not fold this tree into the CMS remote.
- alternatives: A monorepo layout that vendors the CMS beside this API. Documenting a required `../elixir` path for every agent.
- consequences: Tests that use a fake catalog run with no CMS checkout and no Postgres. Live HTTP instructions point at Postgres 16 and the CMS views, and they name the CMS contract paths.

## D-2026-09-15-quality-gates — Shared local and CI gates, locked pub packages

- status: active
- date: 2026-09-15
- context: The same checks need to run on a laptop, in pre-commit, and in Gitea. osv-scanner reads a lockfile.
- decision: `make check` is the gate list: `dart test`, `dart analyze --fatal-infos`, `osv-scanner scan source --lockfile=pubspec.lock`, `gitleaks detect --source . --verbose --no-git`, `dart format --output=none --set-exit-if-changed .`, and (from D-2026-09-22-aot) `dart compile exe bin/server.dart -o build/server`. Commit `pubspec.lock`. Install the git hook with `make hooks`.
- alternatives: Different command strings in the README, the Makefile, and CI. Leaving `pubspec.lock` untracked so the advisory scan has nothing to read.
- consequences: README, Makefile, `.pre-commit-config.yaml`, and `.gitea/workflows/ci.yml` must keep those command strings. `mise.toml` pins Dart, gitleaks, and osv-scanner.

## D-2026-09-22-aot — AOT scratch image on the pinned Dart SDK

- status: active
- date: 2026-09-22
- context: The production process should be a native executable with a small final image. The compile SDK and the runtime bits have to match.
- decision: Pin Dart 3.9.4 in `mise.toml`, the `Dockerfile` (`FROM dart:3.9.4`), and the Gitea prepare image. Build with `dart compile exe bin/server.dart`. The final stage is `FROM scratch` and copies `/runtime` from that SDK image plus the executable. The final stage does not `apt-get` a distro. `analysis_options.yaml` keeps `package:lints/recommended.yaml` plus `strict-casts`, `strict-inference`, and `strict-raw-types`. `make aot` compiles the same binary.
- alternatives: A `dart run` JIT image based on the full Dart SDK. Installing runtime libraries with apt in the final stage. Compiling on a SDK tag that differs from the image that supplies `/runtime`.
- consequences: Packages must be AOT-compatible. Image changes that drop `/runtime` or retag the SDK without `mise.toml` break the binary. This is not a JVM service; do not add JVM checkpoint tooling.

## D-2026-09-22-health-before-postgres — Bind before opening the catalog

- status: active
- date: 2026-09-22
- context: An idle Fly machine uses suspend. After a host move the catalog can be unreachable while the process still needs to pass `GET /health`.
- decision: `serveApi` listens, then opens Postgres and registers in the background. `GET /` and `GET /health` do not open Postgres and do not run catalog SQL. `GET /health` returns `{ "ok": true }`. Fly `auto_stop_machines = "suspend"` with `auto_start_machines` left on and `min_machines_running = 0`.
- alternatives: Waiting for `Pool.open` before `io.serve` (health fails whenever Postgres is down). `auto_stop_machines = "stop"` (cold boot instead of resume). Changing the health body to the starter's `{ "status": "ok" }` and breaking the shipped handler.
- consequences: Catalog routes can 500 until the pool is up. `/` and `/health` stay available. Agents leave the health JSON as `{ "ok": true }`.

## D-2026-09-22-prepare-once — One CI prepare job, POSIX sh

- status: active
- date: 2026-09-22
- context: act_runner starts a new container per job and executes `run` steps with `/bin/sh` (dash). Dart images have no Node, so `actions/checkout` and `actions/upload-artifact` are not available. Repeating apt, git clone, `dart pub get`, and tool downloads in every check job wastes the runner and drifts.
- decision: `.gitea/workflows/ci.yml` prepares the environment once on `dart:3.9.4` (clone `GITHUB_SHA`, `dart pub get`, osv-scanner, gitleaks) and uploads one `ci-env` tarball through the Gitea Actions artifact API with curl. Check jobs `test`, `sast`, `vuln`, `secrets`, `fmt`, and `aot` need that prepare job, restore the tarball, and run only their command. Setup steps are not copied into check jobs, including via a YAML anchor that still executes them. The upload script is POSIX sh: digest and string work use `openssl` and other POSIX tools, not bash substring syntax.
- alternatives: One combined job that runs every gate. Independent per-job setup. YAML anchors that still run clone and `dart pub get` in every check job. Bash-only parameter expansion in the upload script.
- consequences: A new check job must `needs: prepare` and must not repeat setup fingerprints (`apt-get`, `git clone`, `dart pub get`, tool downloads). Script changes must run under dash.

## D-2026-10-07-agent-memory — Rulings and facts in two root files

- status: active
- date: 2026-10-07
- context: Dart and shelf have no framework decision store. `AGENTS.md` had drifted toward a short cloud note and did not say where choices live. One file would mix the standing manual, one-time rulings, and operating facts.
- decision: Keep `AGENTS.md` as the short standing manual and point it at the other two files. Record ratified rulings in this append-only ledger. Record durable operating facts in `MEMORY.md`. Read both before an architectural change. Update status in place only when a later entry supersedes a ruling; append the new ruling.
- alternatives: One ADR file per decision under `docs/decisions/` (easier to miss). Rewriting history inside old entries. Tool-private memory outside the repo, which does not travel with the code.
- consequences: A behavior change that revises a ruling needs a new dated entry. A pin, path, or command change is an in-place edit in `MEMORY.md` when it is not itself a new ruling. Neither file stores secrets.
