import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../bin/server.dart' as api;

void main() {
  test('listen address is IPv6 any-address, not 0.0.0.0', () {
    expect(api.listenAddress, InternetAddress.anyIPv6);
    final src = File('bin/server.dart').readAsStringSync();
    expect(src.contains("io.serve(handler, '0.0.0.0'"), isFalse);
    expect(src.contains('InternetAddress.anyIPv6'), isTrue);
  });

  test('register-once does not open Postgres or run catalog SQL', () {
    final src = File('bin/server.dart').readAsStringSync();
    final start = src.indexOf('Future<void> register(');
    expect(start, greaterThanOrEqualTo(0));
    final end = src.indexOf('Future<void> main(', start);
    final fn = src.substring(start, end == -1 ? src.length : end);
    expect(fn.contains('db.execute'), isFalse);
    expect(fn.contains('db.open'), isFalse);
    expect(fn.contains('Pool.withEndpoints'), isFalse);
  });

  test('/health does not open Postgres or run SQL', () async {
    api.db = api.CatalogDb();
    final handler = api.makeHandler();
    final res =
        await handler(Request('GET', Uri.parse('http://localhost/health')));
    expect(res.statusCode, 200);
    final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
    expect(body['ok'], isTrue);
    expect(res.headers['x-polyglot-language'], 'Dart');
    expect(api.db.sqlCount, 0);
    expect(api.db.connectCount, 0);
  });

  test('register no-ops without catalog SQL when registration env is unset',
      () async {
    expect(Platform.environment['CAROLINA_URL'] ?? '', isEmpty);
    expect(Platform.environment['POLYGLOT_REGISTER_TOKEN'] ?? '', isEmpty);
    api.db = api.CatalogDb();
    await api.register('4012');
    expect(api.db.sqlCount, 0);
    expect(api.db.connectCount, 0);
  });

  test('pooled sessions are reused across catalog requests', () async {
    api.db = api.CatalogDb();
    api.db.openHook = (_) async {};
    await api.db.open('postgres://unused');
    expect(api.db.connectCount, 1);
    final handler = api.makeHandler();
    final a =
        await handler(Request('GET', Uri.parse('http://localhost/health')));
    final b =
        await handler(Request('GET', Uri.parse('http://localhost/health')));
    expect(a.statusCode, 200);
    expect(b.statusCode, 200);
    expect(api.db.connectCount, 1);
    expect(api.db.sqlCount, 0);
  });
}
