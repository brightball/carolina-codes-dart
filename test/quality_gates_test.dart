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

    expect(precommit.contains('id: test'), isTrue);
    expect(precommit.contains('id: sast'), isTrue);
    expect(precommit.contains('id: vuln'), isTrue);
    expect(precommit.contains('id: secrets'), isTrue);
    expect(precommit.contains('id: fmt'), isTrue);
    expect(precommit.contains('entry: make test'), isTrue);
    expect(precommit.contains('entry: make sast'), isTrue);
    expect(precommit.contains('entry: make vuln'), isTrue);
    expect(precommit.contains('entry: make secrets'), isTrue);
    expect(precommit.contains('entry: make fmt-check'), isTrue);

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

    final mode = File('.githooks/pre-commit').statSync().mode;
    expect(mode & 0x49, isNonZero);
  });

  test('Gitea workflow runs each check as its own parallel job', () {
    final src = File('.gitea/workflows/ci.yml').readAsStringSync();
    final jobs = giteaJobs(src);

    expect(
      jobs.keys,
      containsAll(['test', 'sast', 'vuln', 'secrets', 'fmt']),
    );
    expect(jobs.length, greaterThanOrEqualTo(5));

    for (final name in ['test', 'sast', 'vuln', 'secrets', 'fmt']) {
      expect(
        jobs[name]!.contains('needs:'),
        isFalse,
        reason: '$name must not depend on other jobs',
      );
    }

    expect(jobs['test']!.contains('dart test'), isTrue);
    expect(jobs['sast']!.contains('dart analyze --fatal-infos'), isTrue);
    expect(
      jobs['vuln']!.contains('osv-scanner scan source --lockfile=pubspec.lock'),
      isTrue,
    );
    expect(
      jobs['secrets']!
          .contains('gitleaks detect --source . --verbose --no-git'),
      isTrue,
    );
    expect(
      jobs['fmt']!.contains('dart format --output=none --set-exit-if-changed'),
      isTrue,
    );
  });
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
