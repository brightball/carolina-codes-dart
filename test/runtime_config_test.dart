import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('fly suspends idle machines and still autostarts', () {
    final fly = File('fly.toml').readAsStringSync();
    expect(fly.contains('auto_stop_machines = "suspend"'), isTrue);
    expect(fly.contains('auto_start_machines = true'), isTrue);
    expect(RegExp('auto_stop_machines\\s*=\\s*"stop"').hasMatch(fly), isFalse);
    expect(RegExp('auto_stop_machines\\s*=\\s*"off"').hasMatch(fly), isFalse);
  });

  test('image is pinned Dart 3.9.4 AOT with no apt-get in the final stage', () {
    final docker = File('Dockerfile').readAsStringSync();
    final mise = File('mise.toml').readAsStringSync();
    expect(mise.contains('dart = "3.9.4"'), isTrue);
    expect(docker.contains('FROM dart:3.9.4'), isTrue);
    expect(docker.contains('dart:stable'), isFalse);
    expect(docker.contains('dart compile exe'), isTrue);
    final stages = docker.split(RegExp('^FROM ', multiLine: true)).skip(1);
    expect(stages, isNotEmpty);
    final finalStage = stages.last;
    expect(finalStage.contains('apt-get'), isFalse);
    expect(finalStage.contains('scratch'), isTrue);
    expect(finalStage.contains('/runtime/'), isTrue);
  });

  test('analyzer enables strict-casts, strict-inference, and strict-raw-types',
      () {
    final src = File('analysis_options.yaml').readAsStringSync();
    expect(src.contains('strict-casts: true'), isTrue);
    expect(src.contains('strict-inference: true'), isTrue);
    expect(src.contains('strict-raw-types: true'), isTrue);
  });

  test('Gitea workflow pins dart:3.9.4 and does not float dart:stable', () {
    final src = File('.gitea/workflows/ci.yml').readAsStringSync();
    expect(src.contains('docker.io/library/dart:3.9.4'), isTrue);
    expect(src.contains('dart:stable'), isFalse);
  });
}
