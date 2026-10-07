# carolina-codes-dart

Read-only v1 polyglot API for Carolina Code Conference. Dart + shelf + postgres.

Queries PostgreSQL `v1_*` views. Registers with Elixir once on boot.

## Versions and notable packages

- **Dart 3.9.4**, pinned in `mise.toml` (`dart = "3.9.4"`) and the `Dockerfile` (`FROM dart:3.9.4`). The Gitea prepare job uses the same `dart:3.9.4` image.
- **shelf 1.4.2**, from `pubspec.yaml` (`shelf: ^1.4.2`) and `pubspec.lock` (shelf 1.4.2).
- **shelf_router 1.1.4** for the route table.
- **postgres 3.5.12** (`package:postgres`) for the `v1_*` view queries.
- Production image: AOT `dart compile exe` on that SDK, then a scratch image that copies the SDK `/runtime` directory. The final stage does not install a distro with apt.
- Gate tooling pinned in `mise.toml`: osv-scanner 2.6.0 and gitleaks 8.30.1.

```bash
dart pub get
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4012 \
PORT=4012 \
dart run bin/server.dart
```

Quality gates (same commands locally, on commit, and as parallel Gitea jobs after one prepare step):

```bash
mise trust && mise install   # dart 3.9.4, gitleaks, osv-scanner
make test        # dart test
make sast        # dart analyze --fatal-infos
make vuln        # osv-scanner scan source --lockfile=pubspec.lock
make secrets     # gitleaks detect --source . --verbose --no-git
make fmt-check   # dart format --output=none --set-exit-if-changed .
make aot         # dart compile exe bin/server.dart -o build/server
make check       # all of the above
make hooks       # install local pre-commit hooks
```

Pre-commit runs the same checks (`dart test`, `dart analyze --fatal-infos`, `osv-scanner scan source --lockfile=pubspec.lock`, `gitleaks detect --source . --verbose --no-git`, `dart format --output=none --set-exit-if-changed .`, `dart compile exe bin/server.dart -o build/server`). Install once with `make hooks` (needs `pre-commit` on PATH). Emergency skip: `SKIP=test,sast,vuln,secrets,fmt,aot git commit`.

The production image compiles that same `dart compile exe` binary with Dart 3.9.4 and copies the SDK image `/runtime` (no apt-installed distro). Fly `auto_stop_machines` is `suspend`, with `auto_start_machines` left on, so an idle machine resumes instead of cold-booting. `/` and `/health` listen before Postgres is opened.
