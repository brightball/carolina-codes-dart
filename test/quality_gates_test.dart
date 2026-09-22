import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
      'pre-commit hook and Makefile wire tests, analyze, osv-scanner, gitleaks, format',
      () {
    final hook = File('.githooks/pre-commit').readAsStringSync();
    final precommit = File('.pre-commit-config.yaml').readAsStringSync();
    final makefile = File('Makefile').readAsStringSync();

    expect(hook.contains('pre-commit run'), isTrue);
    expect(hook.contains('make test'), isTrue);
    expect(hook.contains('make sast'), isTrue);
    expect(hook.contains('make vuln'), isTrue);
    expect(hook.contains('make secrets'), isTrue);
    expect(hook.contains('make fmt-check'), isTrue);
    expect(hook.contains('make aot'), isTrue);

    expect(precommit.contains('id: test'), isTrue);
    expect(precommit.contains('id: sast'), isTrue);
    expect(precommit.contains('id: vuln'), isTrue);
    expect(precommit.contains('id: secrets'), isTrue);
    expect(precommit.contains('id: fmt'), isTrue);
    expect(precommit.contains('id: aot'), isTrue);
    expect(precommit.contains('entry: make test'), isTrue);
    expect(precommit.contains('entry: make sast'), isTrue);
    expect(precommit.contains('entry: make vuln'), isTrue);
    expect(precommit.contains('entry: make secrets'), isTrue);
    expect(precommit.contains('entry: make fmt-check'), isTrue);
    expect(precommit.contains('entry: make aot'), isTrue);

    expect(makefile.contains('dart test'), isTrue);
    expect(makefile.contains('dart analyze --fatal-infos'), isTrue);
    expect(makefile.contains('osv-scanner scan source --lockfile=pubspec.lock'),
        isTrue);
    expect(makefile.contains('gitleaks detect --source . --verbose --no-git'),
        isTrue);
    expect(
      makefile.contains('dart format --output=none --set-exit-if-changed'),
      isTrue,
    );
    expect(
      makefile.contains('dart compile exe bin/server.dart -o build/server'),
      isTrue,
    );

    final readme = File('README.md').readAsStringSync();
    expect(readme.contains('dart test'), isTrue);
    expect(readme.contains('dart analyze --fatal-infos'), isTrue);
    expect(
      readme.contains('osv-scanner scan source --lockfile=pubspec.lock'),
      isTrue,
    );
    expect(
      readme.contains('gitleaks detect --source . --verbose --no-git'),
      isTrue,
    );
    expect(
      readme.contains('dart format --output=none --set-exit-if-changed'),
      isTrue,
    );
    expect(
      readme.contains('dart compile exe bin/server.dart -o build/server'),
      isTrue,
    );

    final mode = File('.githooks/pre-commit').statSync().mode;
    expect(mode & 0x49, isNonZero);
  });

  test('Gitea workflow prepares once then each check job consumes that env',
      () {
    final src = File('.gitea/workflows/ci.yml').readAsStringSync();
    assertPrepareThenConsume(src);
  });

  test('prepare-then-consume rejects independent per-job setup copies', () {
    expect(
      () => assertPrepareThenConsume(_independentCheckJobsYaml),
      throwsA(isA<TestFailure>()),
    );
  });

  test('prepare-then-consume rejects YAML-anchor setup still run per check',
      () {
    expect(
      () => assertPrepareThenConsume(_anchorCopiedSetupYaml),
      throwsA(isA<TestFailure>()),
    );
  });

  test('YAML alias expansion makes copied setup visible in check jobs', () {
    const yaml = '''
x-setup: &setup |
  apt-get update
  git clone foo
jobs:
  test:
    steps:
      - run: *setup
''';
    final jobs = giteaJobs(yaml);
    final expanded = expandYamlAliases(yaml, jobs['test']!);
    expect(expanded.contains('apt-get'), isTrue);
    expect(expanded.contains('git clone'), isTrue);
  });
}

const checkJobNames = ['test', 'sast', 'vuln', 'secrets', 'fmt', 'aot'];

const checkCommands = {
  'test': 'dart test',
  'sast': 'dart analyze --fatal-infos',
  'vuln': 'osv-scanner scan source --lockfile=pubspec.lock',
  'secrets': 'gitleaks detect --source . --verbose --no-git',
  'fmt': 'dart format --output=none --set-exit-if-changed',
  'aot': 'dart compile exe bin/server.dart -o build/server',
};

const setupFingerprints = [
  'apt-get',
  'git clone',
  'git fetch',
  'git checkout',
  'dart pub get',
  'github.com/google/osv-scanner',
  'github.com/gitleaks/gitleaks',
  'osv-scanner_linux_amd64',
  'gitleaks_8.30.1_linux_x64.tar.gz',
];

void assertPrepareThenConsume(String src) {
  final jobs = giteaJobs(src);
  expect(
    jobs.keys,
    containsAll(checkJobNames),
  );

  final prepareId = jobs.keys.firstWhere(
    (name) => name == 'prepare' || name == 'setup',
    orElse: () => '',
  );
  expect(prepareId, isNotEmpty,
      reason: 'workflow must have a prepare/setup job');
  expect(jobs.length, greaterThanOrEqualTo(7));

  final prepare = jobs[prepareId]!;
  expect(prepare.contains('needs:'), isFalse,
      reason: '$prepareId must not depend on other jobs');
  expect(prepare.contains('git clone'), isTrue,
      reason: '$prepareId must check out GITHUB_SHA');
  expect(prepare.contains('dart pub get'), isTrue,
      reason: '$prepareId must install Dart packages');
  expect(prepare.contains('osv-scanner_linux_amd64'), isTrue,
      reason: '$prepareId must install osv-scanner');
  expect(prepare.contains('gitleaks_8.30.1_linux_x64.tar.gz'), isTrue,
      reason: '$prepareId must install gitleaks');

  for (final name in checkJobNames) {
    final raw = jobs[name]!;
    expect(
      jobNeeds(raw, prepareId),
      isTrue,
      reason: '$name must declare needs: $prepareId',
    );
    expect(
      raw.contains(checkCommands[name]!),
      isTrue,
      reason: '$name must run ${checkCommands[name]}',
    );

    final expanded = expandYamlAliases(src, raw);
    for (final fingerprint in setupFingerprints) {
      expect(
        expanded.contains(fingerprint),
        isFalse,
        reason: '$name must not repeat setup ($fingerprint); restore only',
      );
    }
    final restored = expanded.contains('ACTIONS_RUNTIME') ||
        expanded.contains('/artifacts') ||
        expanded.contains('ci-env') ||
        expanded.contains('tar -xz');
    expect(
      restored,
      isTrue,
      reason: '$name must restore the prepare payload',
    );
  }
}

bool jobNeeds(String body, String dep) {
  if (dep.isEmpty) {
    return false;
  }
  if (RegExp('needs:\\s*$dep\\b').hasMatch(body)) {
    return true;
  }
  if (RegExp('needs:\\s*\\[\\s*$dep\\s*]').hasMatch(body)) {
    return true;
  }
  final lines = body.split('\n');
  var inNeeds = false;
  var needsIndent = 0;
  for (final line in lines) {
    final header = RegExp(r'^(\s*)needs:\s*$').firstMatch(line);
    if (header != null) {
      inNeeds = true;
      needsIndent = header.group(1)!.length;
      continue;
    }
    if (!inNeeds) {
      continue;
    }
    if (line.trim().isEmpty) {
      continue;
    }
    final indent = line.length - line.trimLeft().length;
    if (indent <= needsIndent) {
      inNeeds = false;
      continue;
    }
    if (RegExp('^-\\s*$dep\\s*(#.*)?\$').hasMatch(line.trim())) {
      return true;
    }
  }
  return false;
}

String expandYamlAliases(String yaml, String fragment) {
  final buf = StringBuffer(fragment);
  final names = <String>{};
  for (final match in RegExp(r'\*([A-Za-z0-9_-]+)').allMatches(fragment)) {
    names.add(match.group(1)!);
  }
  for (final name in names) {
    final body = yamlAnchorRawBlock(yaml, name);
    if (body != null) {
      buf.writeln();
      buf.writeln(body);
    }
  }
  return buf.toString();
}

String? yamlAnchorRawBlock(String yaml, String name) {
  final header =
      RegExp('^(\\s*).*&$name\\b.*', multiLine: true).firstMatch(yaml);
  if (header == null) {
    return null;
  }
  final indent = header.group(1)!.length;
  final buf = StringBuffer(header.group(0)!);
  var i = header.end;
  if (i < yaml.length && yaml[i] == '\n') {
    i++;
  }
  while (i < yaml.length) {
    final nl = yaml.indexOf('\n', i);
    final line = nl < 0 ? yaml.substring(i) : yaml.substring(i, nl);
    i = nl < 0 ? yaml.length : nl + 1;
    if (line.trim().isEmpty) {
      buf.writeln(line);
      continue;
    }
    final leading = line.length - line.trimLeft().length;
    if (leading <= indent) {
      break;
    }
    buf.writeln(line);
  }
  return buf.toString();
}

Map<String, String> giteaJobs(String yaml) {
  final match = RegExp(r'^jobs:\n', multiLine: true).firstMatch(yaml);
  expect(match, isNotNull, reason: 'workflow has no jobs:');
  final rest = yaml.substring(match!.end);
  final jobHeader = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$', multiLine: true);
  final matches = jobHeader.allMatches(rest).toList();
  expect(matches, isNotEmpty, reason: 'workflow has no job ids');
  final out = <String, String>{};
  for (var i = 0; i < matches.length; i++) {
    final name = matches[i].group(1)!;
    final start = matches[i].end;
    final end = i + 1 < matches.length ? matches[i + 1].start : rest.length;
    out[name] = rest.substring(start, end);
  }
  return out;
}

/// Pre-change shape: five check jobs, each repeating workspace setup.
const _independentCheckJobsYaml = r'''
name: ci
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: dart pub get
      - run: dart test
  sast:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: dart pub get
      - run: dart analyze --fatal-infos
  vuln:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates curl
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: |
          curl -fsSL -o /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64
          chmod +x /usr/local/bin/osv-scanner
      - run: osv-scanner scan source --lockfile=pubspec.lock
  secrets:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates curl tar
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: |
          curl -fsSL -o /tmp/gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
          tar -xzf /tmp/gitleaks.tgz -C /usr/local/bin gitleaks
      - run: gitleaks detect --source . --verbose --no-git
  fmt:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: dart format --output=none --set-exit-if-changed .
  aot:
    runs-on: ubuntu-latest
    steps:
      - run: apt-get update -qq && apt-get install -y git ca-certificates
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          git fetch --depth 1 origin "${GITHUB_SHA}"
          git checkout --force FETCH_HEAD
      - run: dart pub get
      - run: dart compile exe bin/server.dart -o build/server
''';

/// YAML-only DRY: check jobs still execute clone/install via an alias.
const _anchorCopiedSetupYaml = r'''
x-setup: &setup |
  apt-get update -qq && apt-get install -y git ca-certificates
  git clone --depth 1 --no-checkout "https://example.invalid/repo" .
  git fetch --depth 1 origin "${GITHUB_SHA}"
  git checkout --force FETCH_HEAD
  dart pub get
  curl -fsSL -o /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64
  curl -fsSL -o /tmp/gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
jobs:
  prepare:
    runs-on: ubuntu-latest
    steps:
      - run: |
          git clone --depth 1 --no-checkout "https://example.invalid/repo" .
          dart pub get
          curl -fsSL -o /usr/local/bin/osv-scanner https://github.com/google/osv-scanner/releases/download/v2.6.0/osv-scanner_linux_amd64
          curl -fsSL -o /tmp/gitleaks.tgz https://github.com/gitleaks/gitleaks/releases/download/v8.30.1/gitleaks_8.30.1_linux_x64.tar.gz
  test:
    needs: prepare
    steps:
      - run: *setup
      - run: dart test
  sast:
    needs: prepare
    steps:
      - run: *setup
      - run: dart analyze --fatal-infos
  vuln:
    needs: prepare
    steps:
      - run: *setup
      - run: osv-scanner scan source --lockfile=pubspec.lock
  secrets:
    needs: prepare
    steps:
      - run: *setup
      - run: gitleaks detect --source . --verbose --no-git
  fmt:
    needs: prepare
    steps:
      - run: *setup
      - run: dart format --output=none --set-exit-if-changed .
  aot:
    needs: prepare
    steps:
      - run: *setup
      - run: dart compile exe bin/server.dart -o build/server
''';
