import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../bin/server.dart' as api;

void main() {
  test('serveApi source binds before catalog open', () {
    final src = File('bin/server.dart').readAsStringSync();
    final start = src.indexOf('Future<HttpServer> serveApi(');
    expect(start, greaterThanOrEqualTo(0));
    final end = src.indexOf('Future<void> openCatalog(', start);
    expect(end, greaterThan(start));
    final fn = src.substring(start, end);
    final serveAt = fn.indexOf('io.serve(');
    final openAt = fn.indexOf('openCatalog(');
    expect(serveAt, greaterThanOrEqualTo(0));
    expect(openAt, greaterThan(serveAt));

    final mainStart = src.indexOf('Future<void> main(');
    final mainEnd = src.indexOf('Future<HttpServer> serveApi(', mainStart);
    final mainFn = src.substring(mainStart, mainEnd);
    expect(mainFn.contains('await db.open'), isFalse);
    expect(mainFn.contains('await openCatalog'), isFalse);
    expect(mainFn.contains('serveApi('), isTrue);
  });

  test('serves /health and / while catalog open is still blocked', () async {
    api.db = api.CatalogDb();
    final release = Completer<void>();
    final opened = Completer<void>();
    api.db.openHook = (String _) {
      if (!opened.isCompleted) opened.complete();
      return release.future;
    };
    HttpServer? server;
    try {
      server = await api
          .serveApi(
            'postgres://postgres:postgres@127.0.0.1:1/carolina_dev',
            0,
          )
          .timeout(const Duration(seconds: 3));
      await opened.future.timeout(const Duration(seconds: 2));
      final connects = api.db.connectCount;
      final sql = api.db.sqlCount;
      expect(connects, 1);
      expect(sql, 0);

      final health = await httpGet(server, '/health');
      expect(health.statusCode, 200);
      expect(health.headers['x-polyglot-language'], 'Dart');
      final healthBody = jsonDecode(health.body) as Map<String, dynamic>;
      expect(healthBody['ok'], isTrue);

      final root = await httpGet(server, '/');
      expect(root.statusCode, 200);
      expect(root.headers['x-polyglot-language'], 'Dart');
      expect(root.headers['x-polyglot-framework'], 'shelf');
      final rootBody = jsonDecode(root.body) as Map<String, dynamic>;
      expect(rootBody['language'], 'Dart');
      expect(rootBody['framework'], 'shelf');
      final endpoints = rootBody['endpoints'];
      expect(endpoints, isA<List<dynamic>>());
      final paths = <Object?>[
        for (final item in endpoints as List<dynamic>)
          (item as Map<String, dynamic>)['path'],
      ];
      expect(
        paths,
        containsAll(<String>[
          '/',
          '/health',
          '/v1/years',
          '/v1/speakers',
          '/v1/speakers/:slug',
          '/v1/speakers/:year/:slug',
          '/v1/sponsors',
          '/v1/sponsors/:slug',
          '/v1/sponsors/:year/:slug',
        ]),
      );
      expect(api.db.connectCount, connects);
      expect(api.db.sqlCount, sql);
    } finally {
      if (!release.isCompleted) release.complete();
      await server?.close(force: true);
    }
  });
}

Future<({int statusCode, Map<String, String> headers, String body})> httpGet(
  HttpServer server,
  String path,
) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.getUrl(
      Uri.parse('http://[::1]:${server.port}$path'),
    );
    final res = await req.close().timeout(const Duration(seconds: 2));
    final body = await res.transform(utf8.decoder).join();
    final headers = <String, String>{};
    res.headers.forEach((String name, List<String> values) {
      headers[name.toLowerCase()] = values.join(',');
    });
    return (statusCode: res.statusCode, headers: headers, body: body);
  } finally {
    client.close(force: true);
  }
}
