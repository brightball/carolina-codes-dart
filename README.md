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
