# carolina-codes-dart

Read-only v1 polyglot API for Carolina Code Conference. Dart + shelf + postgres.

Queries PostgreSQL `v1_*` views. Registers with Elixir once on boot.

```bash
dart pub get
DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/carolina_dev \
CAROLINA_URL=http://127.0.0.1:4000 \
POLYGLOT_REGISTER_TOKEN=dev \
PUBLIC_BASE_URL=http://127.0.0.1:4012 \
PORT=4012 \
dart run bin/server.dart
```

Quality gates (same commands locally, on commit, and as parallel Gitea jobs):

```bash
mise trust && mise install   # dart, gitleaks, osv-scanner
make test        # dart test
make sast        # dart analyze --fatal-infos
make vuln        # osv-scanner scan of pubspec.lock against OSV
make secrets     # gitleaks detect --source . --no-git
make fmt-check   # dart format --set-exit-if-changed
make check       # all of the above
make hooks       # install local pre-commit hooks
```

Pre-commit runs the same five checks (`dart test`, `dart analyze`, `osv-scanner`, `gitleaks`, `dart format`). Install once with `make hooks` (needs `pre-commit` on PATH). Emergency skip: `SKIP=test,sast,vuln,secrets,fmt git commit`.
