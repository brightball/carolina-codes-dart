import 'dart:io';

import 'package:test/test.dart';

/// Reads the shipped markdown. A copy of the docs inside the test would not
/// fail when the repo files drift.
void main() {
  final agents = File('AGENTS.md').readAsStringSync();
  final readme = File('README.md').readAsStringSync();
  final memory = File('MEMORY.md').readAsStringSync();
  final decisions = File('DECISIONS.md').readAsStringSync();
  final docs = {
    'AGENTS.md': agents,
    'README.md': readme,
    'MEMORY.md': memory,
    'DECISIONS.md': decisions,
  };

  test('AGENTS.md keeps the starter contract and the Dart operating rules', () {
    expectContainsAll('AGENTS.md', agents, const [
      'Read-only v1',
      'ordinary JSON',
      'Ash JSON:API',
      'application/vnd.api+json',
      'v1_*',
      'Never query Ash',
      'base tables',
      'DATABASE_URL',
      'CAROLINA_URL',
      'POLYGLOT_REGISTER_TOKEN',
      'PUBLIC_BASE_URL',
      'PORT',
      'GET /health',
      'GET /',
      'GET /v1/years',
      'GET /v1/speakers',
      'GET /v1/speakers?year=2025',
      'GET /v1/speakers/{slug}',
      'GET /v1/speakers/{year}/{slug}',
      'GET /v1/sponsors',
      'GET /v1/sponsors?year=2025',
      'GET /v1/sponsors/{slug}',
      'GET /v1/sponsors/{year}/{slug}',
      'POST {CAROLINA_URL}/internal/api-endpoints/register',
      'no heartbeat',
      'keep serving',
      'GET /health does not need the database',
      'Dart + shelf',
      'own workspace',
      '../elixir',
      'finished API',
      'forkable starter layout',
      'no local openapi.yaml',
      'priv/api/openapi.yaml',
      'priv/api/AGENTS.md',
      'fake catalog',
      'do not need Postgres',
      'Live HTTP',
      'Postgres 16',
      'make check',
      'prepares the environment once',
      'dart compile exe',
      'scratch',
      '/runtime',
      'IPv6',
      'auto_stop_machines = "suspend"',
      'before Postgres',
      'Cursor Cloud',
      'workspace root',
      'MEMORY.md',
      'DECISIONS.md',
      'before an architectural change',
      'append-only',
      'HttpClient',
    ]);
  });

  test('README names Dart 3.9.4, shelf 1.4.2, and the quality-gate commands',
      () {
    expectContainsAll('README.md', readme, const [
      'Dart 3.9.4',
      'shelf 1.4.2',
      'shelf_router 1.1.4',
      'postgres 3.5.12',
      'dart compile exe',
      'scratch',
      '/runtime',
      'osv-scanner',
      'gitleaks',
      'dart test',
      'dart analyze --fatal-infos',
      'osv-scanner scan source --lockfile=pubspec.lock',
      'gitleaks detect --source . --verbose --no-git',
      'dart format --output=none --set-exit-if-changed',
      'dart compile exe bin/server.dart -o build/server',
    ]);
    expect(RegExp(r'CRaC', caseSensitive: false).hasMatch(readme), isFalse);
  });

  test('MEMORY.md and DECISIONS.md record facts and an append-only ledger', () {
    expect(memory.trim(), isNotEmpty);
    expect(decisions.trim(), isNotEmpty);

    expectContainsAll('MEMORY.md', memory, const [
      'Durable operating facts',
      'DECISIONS.md',
      'status',
      'context',
      'decision',
      'append-only',
      'Dart 3.9.4',
      'shelf 1.4.2',
      'shelf_router 1.1.4',
      'postgres 3.5.12',
      'HttpClient',
      'v1_*',
      'no heartbeat',
      'dart compile exe',
      'scratch',
      '/runtime',
      'GET /health',
      'does not need the database',
      'before Postgres',
      'prepares the environment once',
      'Postgres 16',
      'fake catalog',
      'InternetAddress.anyIPv6',
      'auto_stop_machines = "suspend"',
      'dart test',
      'dart analyze --fatal-infos',
      'osv-scanner scan source --lockfile=pubspec.lock',
      'gitleaks detect --source . --verbose --no-git',
      'dart format --output=none --set-exit-if-changed',
      'dart compile exe bin/server.dart -o build/server',
    ]);

    expectContainsAll('DECISIONS.md', decisions, const [
      'Append-only',
      'status:',
      'context:',
      'decision:',
      'alternatives:',
      'consequences:',
      'superseded',
      'shelf_router',
      'package:postgres',
      'HttpClient',
      'v1_*',
      'no heartbeat',
      'keep serving',
      'dart compile exe',
      'scratch',
      '/runtime',
      'Dart 3.9.4',
      'GET /health',
      'auto_stop_machines = "suspend"',
      'InternetAddress.anyIPv6',
      'prepares the environment once',
      'POSIX',
      'fake catalog',
      'Postgres 16',
      'MEMORY.md',
    ]);

    expect(
      'status:'.allMatches(decisions).length,
      greaterThanOrEqualTo(8),
    );
    expect(
      'context:'.allMatches(decisions).length,
      greaterThanOrEqualTo(8),
    );
    expect(
      'decision:'.allMatches(decisions).length,
      greaterThanOrEqualTo(8),
    );

    // MEMORY points at the ledger; it is not a second dated ruling list.
    expect(memory.contains('## D-'), isFalse);
  });

  test('agent docs do not carry a private key or an obvious production secret',
      () {
    final privateKey = RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----');
    final obviousSecret = RegExp(
      r'\b(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk_live_[A-Za-z0-9]+)\b',
    );
    for (final entry in docs.entries) {
      expect(
        privateKey.hasMatch(entry.value),
        isFalse,
        reason: '${entry.key} contains a private-key block',
      );
      expect(
        obviousSecret.hasMatch(entry.value),
        isFalse,
        reason: '${entry.key} contains an obvious production secret',
      );
    }
  });
}

void expectContainsAll(String label, String src, List<String> needles) {
  for (final needle in needles) {
    expect(src.contains(needle), isTrue, reason: '$label missing: $needle');
  }
}
