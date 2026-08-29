import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

const language = 'Dart';
const apiVersion = '0.2.0';
const framework = 'shelf';
const createdYear = 2026;
const schemaVersion = 1;

final languageVersion = Platform.version.split(' ').first;

const endpoints = [
  {'method': 'GET', 'path': '/', 'query': <String>[]},
  {'method': 'GET', 'path': '/health', 'query': <String>[]},
  {'method': 'GET', 'path': '/v1/years', 'query': <String>[]},
  {'method': 'GET', 'path': '/v1/speakers', 'query': ['year']},
  {'method': 'GET', 'path': '/v1/speakers/:slug', 'query': <String>[]},
  {'method': 'GET', 'path': '/v1/speakers/:year/:slug', 'query': <String>[]},
  {'method': 'GET', 'path': '/v1/sponsors', 'query': ['year']},
  {'method': 'GET', 'path': '/v1/sponsors/:slug', 'query': <String>[]},
  {'method': 'GET', 'path': '/v1/sponsors/:year/:slug', 'query': <String>[]},
];

const speakerCols =
    'slug, first_name, last_name, name, tagline, bio, company, location, '
    'photo_path, twitter_url, linkedin_url, website_url, github_url, featured';
const yearSponsorCols =
    'slug, name, website, logo_path, description, blurb, tier, featured, year, '
    'twitter_url, linkedin_url, youtube_url, instagram_url, facebook_url';
const sponsorCols =
    'slug, name, website, logo_path, description, twitter_url, linkedin_url, '
    'youtube_url, instagram_url, facebook_url';
const talkCols =
    'slug, title, description, format, youtube_id, year, speaker_slug, languages, topics';

late final Pool pool;

String env(String key, String fallback) {
  final v = Platform.environment[key];
  if (v == null || v.isEmpty) return fallback;
  return v;
}

Response jsonResponse(Object body, {int status = 200}) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json',
      'X-Polyglot-Language': language,
      'X-Polyglot-Framework': framework,
    },
  );
}

Response notFound() => jsonResponse({'error': 'not_found'}, status: 404);

List<String> strList(dynamic v) {
  if (v == null) return [];
  if (v is List) {
    return v.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  }
  return [];
}

List<String> uniq(Iterable<String> xs) {
  final seen = <String>{};
  final out = <String>[];
  for (final x in xs) {
    if (x.isEmpty || seen.contains(x)) continue;
    seen.add(x);
    out.add(x);
  }
  return out;
}

Map<String, dynamic> clean(Map<String, dynamic> row) {
  final out = <String, dynamic>{};
  row.forEach((k, v) {
    if (v is DateTime) {
      out[k] = v.toIso8601String();
    } else {
      out[k] = v;
    }
  });
  return out;
}

Future<List<Map<String, dynamic>>> talksFor(String slug, [int? year]) async {
  final Result result;
  if (year == null) {
    result = await pool.execute(
      'SELECT $talkCols FROM v1_talks WHERE speaker_slug = \$1 ORDER BY year DESC',
      parameters: [slug],
    );
  } else {
    result = await pool.execute(
      'SELECT $talkCols FROM v1_talks WHERE speaker_slug = \$1 AND year = \$2 ORDER BY year DESC',
      parameters: [slug, year],
    );
  }
  return result.map((row) {
    final m = clean(row.toColumnMap());
    m['languages'] = strList(m['languages']);
    m['topics'] = strList(m['topics']);
    return m;
  }).toList();
}

Future<List<int>> talkYears(String slug) async {
  final result = await pool.execute(
    'SELECT DISTINCT year FROM v1_talks WHERE speaker_slug = \$1 ORDER BY year DESC',
    parameters: [slug],
  );
  return result.map((r) => r[0] as int).toList();
}

Future<List<int>> sponsorYears(String slug) async {
  final result = await pool.execute(
    'SELECT DISTINCT year FROM v1_sponsorships WHERE sponsor_slug = \$1 ORDER BY year DESC',
    parameters: [slug],
  );
  return result.map((r) => r[0] as int).toList();
}

Future<List<Map<String, dynamic>>> sponsorshipsFor(String slug) async {
  final result = await pool.execute(
    'SELECT sponsor_slug, year, tier, blurb, featured FROM v1_sponsorships WHERE sponsor_slug = \$1 ORDER BY year DESC',
    parameters: [slug],
  );
  return result.map((r) => clean(r.toColumnMap())).toList();
}

Map<String, dynamic> speakerRow(ResultRow row) => clean(row.toColumnMap());

Handler makeHandler() {
  final router = Router();

  router.get('/', (Request _) {
    return jsonResponse({
      'language': language,
      'language_version': languageVersion,
      'api_version': apiVersion,
      'framework': framework,
      'created_year': createdYear,
      'schema_version': schemaVersion,
      'endpoints': endpoints,
    });
  });

  router.get('/health', (Request _) => jsonResponse({'ok': true}));

  router.get('/v1/years', (Request _) async {
    final result = await pool.execute(
      'SELECT year, slug, name, status FROM v1_years ORDER BY year DESC',
    );
    return jsonResponse({
      'data': result.map((r) => clean(r.toColumnMap())).toList(),
    });
  });

  router.get('/v1/speakers', (Request req) async {
    final yearRaw = req.url.queryParameters['year'];
    if (yearRaw != null && yearRaw.isNotEmpty) {
      final year = int.parse(yearRaw);
      final result = await pool.execute(
        'SELECT $speakerCols FROM v1_speakers '
        'WHERE slug IN (SELECT speaker_slug FROM v1_talks WHERE year = \$1) '
        'ORDER BY last_name, first_name',
        parameters: [year],
      );
      final speakers = <Map<String, dynamic>>[];
      for (final row in result) {
        final sp = speakerRow(row);
        final talks = await talksFor(sp['slug'] as String, year);
        speakers.add({
          ...sp,
          'year': year,
          'talks': talks,
          'languages': uniq(talks.expand((t) => strList(t['languages']))),
          'topics': uniq(talks.expand((t) => strList(t['topics']))),
          'years': await talkYears(sp['slug'] as String),
        });
      }
      return jsonResponse({'data': speakers});
    }
    final result = await pool.execute(
      'SELECT $speakerCols FROM v1_speakers ORDER BY last_name, first_name',
    );
    return jsonResponse({
      'data': result.map((r) => speakerRow(r)).toList(),
    });
  });

  router.get('/v1/speakers/<year>/<slug>', (Request _, String year, String slug) async {
    if (int.tryParse(year) == null) {
      return notFound();
    }
    final y = int.parse(year);
    final result = await pool.execute(
      'SELECT $speakerCols FROM v1_speakers WHERE slug = \$1',
      parameters: [slug],
    );
    if (result.isEmpty) return notFound();
    final talks = await talksFor(slug, y);
    if (talks.isEmpty) return notFound();
    final years = await talkYears(slug);
    final speaker = speakerRow(result.first);
    speaker['year'] = y;
    speaker['years'] = years;
    speaker['other_years'] = years.where((n) => n != y).toList();
    speaker['talks'] = talks;
    speaker['languages'] = uniq(talks.expand((t) => strList(t['languages'])));
    speaker['topics'] = uniq(talks.expand((t) => strList(t['topics'])));
    return jsonResponse({'data': speaker});
  });

  router.get('/v1/speakers/<slug>', (Request _, String slug) async {
    final result = await pool.execute(
      'SELECT $speakerCols FROM v1_speakers WHERE slug = \$1',
      parameters: [slug],
    );
    if (result.isEmpty) return notFound();
    final speaker = speakerRow(result.first);
    speaker['talks'] = await talksFor(slug);
    speaker['years'] = await talkYears(slug);
    return jsonResponse({'data': speaker});
  });

  router.get('/v1/sponsors', (Request req) async {
    final yearRaw = req.url.queryParameters['year'];
    if (yearRaw != null && yearRaw.isNotEmpty) {
      final year = int.parse(yearRaw);
      final result = await pool.execute(
        'SELECT $yearSponsorCols FROM v1_year_sponsors WHERE year = \$1 ORDER BY name',
        parameters: [year],
      );
      return jsonResponse({
        'data': result.map((r) => clean(r.toColumnMap())).toList(),
      });
    }
    final result = await pool.execute(
      'SELECT $sponsorCols FROM v1_sponsors ORDER BY name',
    );
    return jsonResponse({
      'data': result.map((r) => clean(r.toColumnMap())).toList(),
    });
  });

  router.get('/v1/sponsors/<year>/<slug>', (Request _, String year, String slug) async {
    if (int.tryParse(year) == null) return notFound();
    final y = int.parse(year);
    final result = await pool.execute(
      'SELECT $yearSponsorCols FROM v1_year_sponsors WHERE year = \$1 AND slug = \$2',
      parameters: [y, slug],
    );
    if (result.isEmpty) return notFound();
    final sponsor = clean(result.first.toColumnMap());
    final years = await sponsorYears(slug);
    sponsor['years'] = years;
    sponsor['other_years'] = years.where((n) => n != y).toList();
    return jsonResponse({'data': sponsor});
  });

  router.get('/v1/sponsors/<slug>', (Request _, String slug) async {
    final result = await pool.execute(
      'SELECT $sponsorCols FROM v1_sponsors WHERE slug = \$1',
      parameters: [slug],
    );
    if (result.isEmpty) return notFound();
    final sponsor = clean(result.first.toColumnMap());
    sponsor['sponsorships'] = await sponsorshipsFor(slug);
    return jsonResponse({'data': sponsor});
  });

  router.all('/<ignored|.*>', (Request _) => notFound());
  return router.call;
}

Endpoint parseEndpoint(String dsn) {
  var s = dsn;
  if (s.startsWith('postgres://')) {
    s = s.replaceFirst('postgres://', 'http://');
  } else if (s.startsWith('postgresql://')) {
    s = s.replaceFirst('postgresql://', 'http://');
  }
  final uri = Uri.parse(s);
  final userInfo = uri.userInfo.split(':');
  final user = userInfo.isNotEmpty ? Uri.decodeComponent(userInfo.first) : 'postgres';
  final password = userInfo.length > 1
      ? Uri.decodeComponent(userInfo.sublist(1).join(':'))
      : '';
  final database = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : 'postgres';
  return Endpoint(
    host: uri.host.isEmpty ? '127.0.0.1' : uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: database,
    username: user,
    password: password,
  );
}

SslMode sslModeFor(String dsn) {
  final q = Uri.tryParse(dsn)?.queryParameters['sslmode'];
  switch (q) {
    case 'require':
    case 'verify-full':
    case 'verify-ca':
      return SslMode.require;
    default:
      return SslMode.disable;
  }
}

Future<void> register(String port) async {
  final url = Platform.environment['CAROLINA_URL'];
  final token = Platform.environment['POLYGLOT_REGISTER_TOKEN'];
  if (url == null || url.isEmpty || token == null || token.isEmpty) return;
  final base = env('PUBLIC_BASE_URL', 'http://127.0.0.1:$port');
  final body = jsonEncode({
    'language': language,
    'language_version': languageVersion,
    'api_version': apiVersion,
    'framework': framework,
    'created_year': createdYear,
    'schema_version': schemaVersion,
    'base_url': base,
    'endpoints': endpoints,
  });
  final uri = Uri.parse('${url.replaceAll(RegExp(r'/$'), '')}/internal/api-endpoints/register');
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    final req = await client.postUrl(uri);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(body));
    final resp = await req.close().timeout(const Duration(seconds: 5));
    stderr.writeln('registered with elixir: ${resp.statusCode}');
    client.close(force: true);
  } catch (e) {
    stderr.writeln('register: $e');
  }
}

Future<void> main() async {
  final dsn = env(
    'DATABASE_URL',
    'postgres://postgres:postgres@127.0.0.1:5432/carolina_dev',
  );
  final port = int.parse(env('PORT', '4012'));
  pool = Pool.withEndpoints(
    [parseEndpoint(dsn)],
    settings: PoolSettings(
      maxConnectionCount: 8,
      sslMode: sslModeFor(dsn),
    ),
  );

  final handler = Pipeline()
      .addMiddleware((inner) {
        return (req) async {
          final res = await inner(req);
          return res.change(headers: {
            'X-Polyglot-Language': language,
            'X-Polyglot-Framework': framework,
          });
        };
      })
      .addHandler(makeHandler());

  final server = await io.serve(handler, '0.0.0.0', port);
  stderr.writeln('carolina-codes-dart listening on :${server.port}');
  register('$port');
}
