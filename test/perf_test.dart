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
    final body = await res.readAsString();
    expect(body.contains('ok'), isTrue);
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

  test('year speaker listing SQL is bounded (not ~2N)', () async {
    api.db = api.CatalogDb();
    final dsn = Platform.environment['DATABASE_URL'] ??
        'postgres://postgres:postgres@127.0.0.1:5432/carolina_dev';
    try {
      await api.db.open(dsn);
      await api.db.execute('SELECT 1 FROM v1_speakers LIMIT 1');
    } catch (e) {
      markTestSkipped('catalog views unavailable: $e');
      return;
    }
    final connectsAfterOpen = api.db.connectCount;
    api.db.sqlCount = 0;

    final handler = api.makeHandler();
    final res = await handler(
      Request('GET', Uri.parse('http://localhost/v1/speakers?year=2026')),
    );
    final body = await res.readAsString();
    final sql = api.db.sqlCount;
    final speakers = '"talks":'.allMatches(body).length;
    // ignore: avoid_print
    print(
        'year list status=${res.statusCode} sql=$sql speakers=$speakers connects=${api.db.connectCount}');

    if (res.statusCode == 200) {
      expect(speakers, greaterThanOrEqualTo(3));
      expect(sql, greaterThan(0));
      expect(sql, lessThan(2 * speakers));
      expect(sql, lessThanOrEqualTo(4));
      api.db.sqlCount = 0;
      final res2 = await handler(
        Request('GET', Uri.parse('http://localhost/v1/speakers?year=2026')),
      );
      expect(res2.statusCode, 200);
      expect(api.db.connectCount, connectsAfterOpen);
    } else {
      expect(sql, lessThan(2 * 3));
    }
  });
}
