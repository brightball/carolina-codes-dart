import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import '../bin/server.dart' as api;

const speakerColumns = <String>[
  'slug',
  'first_name',
  'last_name',
  'name',
  'tagline',
  'bio',
  'company',
  'location',
  'photo_path',
  'twitter_url',
  'linkedin_url',
  'website_url',
  'github_url',
  'featured',
];

const talkColumns = <String>[
  'slug',
  'title',
  'description',
  'format',
  'youtube_id',
  'year',
  'speaker_slug',
  'languages',
  'topics',
];

const sponsorColumns = <String>[
  'slug',
  'name',
  'website',
  'logo_path',
  'description',
  'twitter_url',
  'linkedin_url',
  'youtube_url',
  'instagram_url',
  'facebook_url',
];

const yearSponsorColumns = <String>[
  'slug',
  'name',
  'website',
  'logo_path',
  'description',
  'blurb',
  'tier',
  'featured',
  'year',
  'twitter_url',
  'linkedin_url',
  'youtube_url',
  'instagram_url',
  'facebook_url',
];

Map<String, Object?> speaker({
  required String slug,
  required String first,
  required String last,
}) {
  return <String, Object?>{
    'slug': slug,
    'first_name': first,
    'last_name': last,
    'name': '$first $last',
    'tagline': '$first tagline',
    'bio': '$first bio',
    'company': 'Carolina',
    'location': 'Raleigh',
    'photo_path': '/photos/$slug.jpg',
    'twitter_url': 'https://x.com/$slug',
    'linkedin_url': 'https://linkedin.com/in/$slug',
    'website_url': 'https://example.com/$slug',
    'github_url': 'https://github.com/$slug',
    'featured': slug == 'ada-lovelace',
  };
}

Map<String, Object?> talk({
  required String slug,
  required String title,
  required int year,
  required String speakerSlug,
  required List<String> languages,
  required List<String> topics,
}) {
  return <String, Object?>{
    'slug': slug,
    'title': title,
    'description': title,
    'format': 'talk',
    'youtube_id': slug,
    'year': year,
    'speaker_slug': speakerSlug,
    'languages': languages,
    'topics': topics,
  };
}

final List<Map<String, Object?>> speakers = <Map<String, Object?>>[
  speaker(slug: 'ada-lovelace', first: 'Ada', last: 'Lovelace'),
  speaker(slug: 'grace-hopper', first: 'Grace', last: 'Hopper'),
  speaker(slug: 'alan-turing', first: 'Alan', last: 'Turing'),
  speaker(slug: 'katherine-johnson', first: 'Katherine', last: 'Johnson'),
];

final List<Map<String, Object?>> talks = <Map<String, Object?>>[
  talk(
    slug: 'analytical-engine',
    title: 'The Analytical Engine',
    year: 2026,
    speakerSlug: 'ada-lovelace',
    languages: <String>['Dart'],
    topics: <String>['compilers'],
  ),
  talk(
    slug: 'notes-on-the-engine',
    title: 'Notes on the Engine',
    year: 2024,
    speakerSlug: 'ada-lovelace',
    languages: <String>['Math'],
    topics: <String>['engines'],
  ),
  talk(
    slug: 'compilers',
    title: 'Compilers',
    year: 2026,
    speakerSlug: 'grace-hopper',
    languages: <String>['Cobol'],
    topics: <String>['compilers'],
  ),
  talk(
    slug: 'machines',
    title: 'Machines',
    year: 2026,
    speakerSlug: 'alan-turing',
    languages: <String>['Crypto'],
    topics: <String>['machines'],
  ),
  talk(
    slug: 'trajectories',
    title: 'Trajectories',
    year: 2024,
    speakerSlug: 'katherine-johnson',
    languages: <String>['Fortran'],
    topics: <String>['flight'],
  ),
];

final List<Map<String, Object?>> sponsors = <Map<String, Object?>>[
  <String, Object?>{
    'slug': 'acme',
    'name': 'Acme',
    'website': 'https://acme.example',
    'logo_path': '/logos/acme.png',
    'description': 'Acme tools',
    'twitter_url': 'https://x.com/acme',
    'linkedin_url': 'https://linkedin.com/company/acme',
    'youtube_url': 'https://youtube.com/acme',
    'instagram_url': 'https://instagram.com/acme',
    'facebook_url': 'https://facebook.com/acme',
  },
];

final List<Map<String, Object?>> yearSponsors = <Map<String, Object?>>[
  <String, Object?>{
    'slug': 'acme',
    'name': 'Acme',
    'website': 'https://acme.example',
    'logo_path': '/logos/acme.png',
    'description': 'Acme tools',
    'blurb': 'Gold partner',
    'tier': 'gold',
    'featured': true,
    'year': 2026,
    'twitter_url': 'https://x.com/acme',
    'linkedin_url': 'https://linkedin.com/company/acme',
    'youtube_url': 'https://youtube.com/acme',
    'instagram_url': 'https://instagram.com/acme',
    'facebook_url': 'https://facebook.com/acme',
  },
  <String, Object?>{
    'slug': 'acme',
    'name': 'Acme',
    'website': 'https://acme.example',
    'logo_path': '/logos/acme.png',
    'description': 'Acme tools',
    'blurb': 'Silver partner',
    'tier': 'silver',
    'featured': false,
    'year': 2024,
    'twitter_url': 'https://x.com/acme',
    'linkedin_url': 'https://linkedin.com/company/acme',
    'youtube_url': 'https://youtube.com/acme',
    'instagram_url': 'https://instagram.com/acme',
    'facebook_url': 'https://facebook.com/acme',
  },
];

final List<Map<String, Object?>> sponsorships = <Map<String, Object?>>[
  <String, Object?>{
    'sponsor_slug': 'acme',
    'year': 2026,
    'tier': 'gold',
    'blurb': 'Gold partner',
    'featured': true,
  },
  <String, Object?>{
    'sponsor_slug': 'acme',
    'year': 2024,
    'tier': 'silver',
    'blurb': 'Silver partner',
    'featured': false,
  },
];

Result table(List<String> columns, List<Map<String, Object?>> records) {
  final schema = ResultSchema(<ResultSchemaColumn>[
    for (final name in columns)
      ResultSchemaColumn(typeOid: 25, type: Type.unspecified, columnName: name),
  ]);
  return Result(
    affectedRows: records.length,
    schema: schema,
    rows: <ResultRow>[
      for (final record in records)
        ResultRow(
          values: <Object?>[for (final name in columns) record[name]],
          schema: schema,
        ),
    ],
  );
}

String compact(String sql) => sql.replaceAll(RegExp(r'\s+'), ' ').trim();

int asInt(Object? value) {
  if (value is int) return value;
  throw StateError('expected int, got $value');
}

String asString(Object? value) {
  if (value is String) return value;
  throw StateError('expected string, got $value');
}

Set<String> pgTextArray(Object? value) {
  final raw = asString(value);
  if (raw.length < 2 || !raw.startsWith('{') || !raw.endsWith('}')) {
    throw StateError('bad pg array: $raw');
  }
  final inner = raw.substring(1, raw.length - 1);
  if (inner.isEmpty) return <String>{};
  return inner
      .split(',')
      .map((String part) => part.replaceAll('"', ''))
      .toSet();
}

List<Map<String, Object?>> sortedByName(List<Map<String, Object?>> rows) {
  final copy = rows.toList();
  copy.sort((Map<String, Object?> a, Map<String, Object?> b) {
    final last = asString(a['last_name']).compareTo(asString(b['last_name']));
    if (last != 0) return last;
    return asString(a['first_name']).compareTo(asString(b['first_name']));
  });
  return copy;
}

List<int> yearsForSpeaker(String slug) {
  final years = <int>{
    for (final row in talks)
      if (row['speaker_slug'] == slug) asInt(row['year']),
  }.toList()
    ..sort((int a, int b) => b.compareTo(a));
  return years;
}

List<Map<String, Object?>> talksWhere(
    bool Function(Map<String, Object?>) pred) {
  final found = talks.where(pred).toList();
  found.sort(
    (Map<String, Object?> a, Map<String, Object?> b) =>
        asInt(b['year']).compareTo(asInt(a['year'])),
  );
  return found;
}

Future<Result> fakeExecute(String sql, List<Object?> params) async {
  final query = compact(sql);
  if (query.contains('FROM v1_years')) {
    return table(<String>[
      'year',
      'slug',
      'name',
      'status'
    ], <Map<String, Object?>>[
      <String, Object?>{
        'year': 2026,
        'slug': '2026',
        'name': 'Carolina 2026',
        'status': 'announced',
      },
    ]);
  }
  if (query.contains('FROM v1_speakers') && query.contains('WHERE slug =')) {
    final slug = asString(params[0]);
    return table(
      speakerColumns,
      speakers
          .where((Map<String, Object?> row) => row['slug'] == slug)
          .toList(),
    );
  }
  if (query.contains('FROM v1_speakers') && query.contains('slug IN')) {
    final year = asInt(params[0]);
    final slugs = <Object?>{
      for (final row in talks)
        if (row['year'] == year) row['speaker_slug'],
    };
    final found = speakers
        .where((Map<String, Object?> row) => slugs.contains(row['slug']))
        .toList();
    return table(speakerColumns, sortedByName(found));
  }
  if (query.contains('FROM v1_speakers')) {
    return table(speakerColumns, sortedByName(speakers));
  }
  if (query.contains('FROM v1_talks') && query.contains('speaker_slug = ANY')) {
    final slugs = pgTextArray(params[0]);
    final rows = <Map<String, Object?>>[];
    final ordered = slugs.toList()..sort();
    for (final slug in ordered) {
      for (final year in yearsForSpeaker(slug)) {
        rows.add(<String, Object?>{'speaker_slug': slug, 'year': year});
      }
    }
    return table(<String>['speaker_slug', 'year'], rows);
  }
  if (query.contains('SELECT DISTINCT year FROM v1_talks')) {
    final slug = asString(params[0]);
    return table(
      <String>['year'],
      <Map<String, Object?>>[
        for (final year in yearsForSpeaker(slug))
          <String, Object?>{'year': year},
      ],
    );
  }
  if (query.contains('FROM v1_talks') &&
      query.contains('speaker_slug =') &&
      query.contains('AND year =')) {
    final slug = asString(params[0]);
    final year = asInt(params[1]);
    return table(
      talkColumns,
      talksWhere(
        (Map<String, Object?> row) =>
            row['speaker_slug'] == slug && row['year'] == year,
      ),
    );
  }
  if (query.contains('FROM v1_talks') && query.contains('speaker_slug =')) {
    final slug = asString(params[0]);
    return table(
      talkColumns,
      talksWhere((Map<String, Object?> row) => row['speaker_slug'] == slug),
    );
  }
  if (query.contains('FROM v1_talks') && query.contains('WHERE year =')) {
    final year = asInt(params[0]);
    final found =
        talks.where((Map<String, Object?> row) => row['year'] == year).toList();
    found.sort((Map<String, Object?> a, Map<String, Object?> b) {
      final bySlug =
          asString(a['speaker_slug']).compareTo(asString(b['speaker_slug']));
      if (bySlug != 0) return bySlug;
      return asInt(b['year']).compareTo(asInt(a['year']));
    });
    return table(talkColumns, found);
  }
  if (query.contains('SELECT DISTINCT year FROM v1_sponsorships')) {
    final slug = asString(params[0]);
    final years = <int>{
      for (final row in sponsorships)
        if (row['sponsor_slug'] == slug) asInt(row['year']),
    }.toList()
      ..sort((int a, int b) => b.compareTo(a));
    return table(
      <String>['year'],
      <Map<String, Object?>>[
        for (final year in years) <String, Object?>{'year': year},
      ],
    );
  }
  if (query.contains('FROM v1_sponsorships')) {
    final slug = asString(params[0]);
    final found = sponsorships
        .where((Map<String, Object?> row) => row['sponsor_slug'] == slug)
        .toList();
    found.sort(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          asInt(b['year']).compareTo(asInt(a['year'])),
    );
    return table(
      <String>['sponsor_slug', 'year', 'tier', 'blurb', 'featured'],
      found,
    );
  }
  if (query.contains('FROM v1_year_sponsors') && query.contains('AND slug =')) {
    final year = asInt(params[0]);
    final slug = asString(params[1]);
    return table(
      yearSponsorColumns,
      yearSponsors
          .where(
            (Map<String, Object?> row) =>
                row['year'] == year && row['slug'] == slug,
          )
          .toList(),
    );
  }
  if (query.contains('FROM v1_year_sponsors')) {
    final year = asInt(params[0]);
    final found = yearSponsors
        .where((Map<String, Object?> row) => row['year'] == year)
        .toList();
    found.sort(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          asString(a['name']).compareTo(asString(b['name'])),
    );
    return table(yearSponsorColumns, found);
  }
  if (query.contains('FROM v1_sponsors') && query.contains('WHERE slug =')) {
    final slug = asString(params[0]);
    return table(
      sponsorColumns,
      sponsors
          .where((Map<String, Object?> row) => row['slug'] == slug)
          .toList(),
    );
  }
  if (query.contains('FROM v1_sponsors')) {
    final found = sponsors.toList();
    found.sort(
      (Map<String, Object?> a, Map<String, Object?> b) =>
          asString(a['name']).compareTo(asString(b['name'])),
    );
    return table(sponsorColumns, found);
  }
  throw StateError('unmatched sql: $query params=$params');
}

void expectPolyglot(Response res) {
  final headers = <String, String>{
    for (final MapEntry<String, String> entry in res.headers.entries)
      entry.key.toLowerCase(): entry.value,
  };
  expect(headers['x-polyglot-language'], 'Dart');
  expect(headers['x-polyglot-framework'], 'shelf');
}

void main() {
  late Handler handler;

  setUp(() {
    api.db = api.CatalogDb();
    api.db.executeHook = fakeExecute;
    handler = api.makeHandler();
  });

  Future<Response> send(String path) async {
    return handler(Request('GET', Uri.parse('http://localhost$path')));
  }

  Future<Map<String, dynamic>> expectOk(String path) async {
    final res = await send(path);
    expect(res.statusCode, 200, reason: path);
    expectPolyglot(res);
    final decoded = jsonDecode(await res.readAsString());
    expect(decoded, isA<Map<String, dynamic>>(), reason: path);
    return decoded as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> dataOf(Map<String, dynamic> body) {
    final data = body['data'];
    expect(data, isA<List<dynamic>>());
    return <Map<String, dynamic>>[
      for (final row in data as List<dynamic>) row as Map<String, dynamic>,
    ];
  }

  Future<void> expectNotFound(String path) async {
    final res = await send(path);
    expect(res.statusCode, 404, reason: path);
    expectPolyglot(res);
    final decoded = jsonDecode(await res.readAsString());
    expect(decoded, isA<Map<String, dynamic>>(), reason: path);
    final body = decoded as Map<String, dynamic>;
    expect(body['error'], 'not_found', reason: path);
  }

  Map<String, dynamic> rowBySlug(List<Map<String, dynamic>> rows, String slug) {
    return rows.firstWhere((Map<String, dynamic> row) => row['slug'] == slug);
  }

  test('GET / describes the shipped catalog routes', () async {
    final body = await expectOk('/');
    expect(body['language'], 'Dart');
    expect(body['framework'], 'shelf');
    final endpoints = body['endpoints'];
    expect(endpoints, isA<List<dynamic>>());
    final paths = <Object?>[
      for (final item in endpoints as List<dynamic>)
        (item as Map<String, dynamic>)['path'],
    ];
    expect(paths, <String>[
      '/',
      '/health',
      '/v1/years',
      '/v1/speakers',
      '/v1/speakers/:slug',
      '/v1/speakers/:year/:slug',
      '/v1/sponsors',
      '/v1/sponsors/:slug',
      '/v1/sponsors/:year/:slug',
    ]);
  });

  test('GET /health does no catalog connect and no catalog SQL', () async {
    final body = await expectOk('/health');
    expect(body['ok'], isTrue);
    expect(api.db.sqlCount, 0);
    expect(api.db.connectCount, 0);
  });

  test('GET /v1/years returns the catalog year', () async {
    final rows = dataOf(await expectOk('/v1/years'));
    expect(rows, hasLength(1));
    expect(rows.single['year'], 2026);
    expect(rows.single['slug'], '2026');
    expect(rows.single['name'], 'Carolina 2026');
    expect(rows.single['status'], 'announced');
  });

  test('GET /v1/speakers returns every speaker', () async {
    final rows = dataOf(await expectOk('/v1/speakers'));
    expect(
      rows.map((Map<String, dynamic> row) => row['slug']),
      containsAll(<String>[
        'ada-lovelace',
        'grace-hopper',
        'alan-turing',
        'katherine-johnson',
      ]),
    );
  });

  test('year-scoped speakers stay within four queries', () async {
    final rows = dataOf(await expectOk('/v1/speakers?year=2026'));
    expect(rows, hasLength(3));
    expect(api.db.sqlCount, lessThanOrEqualTo(4));
    expect(api.db.sqlCount, lessThan(2 * rows.length));
    expect(
      rows.map((Map<String, dynamic> row) => row['slug']),
      containsAll(<String>['ada-lovelace', 'grace-hopper', 'alan-turing']),
    );
    expect(
      rows.map((Map<String, dynamic> row) => row['slug']),
      isNot(contains('katherine-johnson')),
    );
    for (final row in rows) {
      expect(row['languages'], isA<List<dynamic>>());
      expect(row['topics'], isA<List<dynamic>>());
      expect(row['years'], isA<List<dynamic>>());
      expect(row['talks'], isA<List<dynamic>>());
    }
    final ada = rowBySlug(rows, 'ada-lovelace');
    expect(ada['year'], 2026);
    expect(ada['languages'], <String>['Dart']);
    expect(ada['topics'], <String>['compilers']);
    expect(ada['years'], <int>[2026, 2024]);
    final adaTalks = ada['talks'] as List<dynamic>;
    expect(adaTalks, hasLength(1));
    expect(
        (adaTalks.single as Map<String, dynamic>)['slug'], 'analytical-engine');
  });

  test('GET /v1/speakers/:slug includes talks and years', () async {
    final body = await expectOk('/v1/speakers/ada-lovelace');
    final speakerRow = body['data'] as Map<String, dynamic>;
    expect(speakerRow['slug'], 'ada-lovelace');
    expect(speakerRow['name'], 'Ada Lovelace');
    final speakerTalks = speakerRow['talks'] as List<dynamic>;
    expect(
      speakerTalks.map((dynamic row) => (row as Map<String, dynamic>)['slug']),
      <String>['analytical-engine', 'notes-on-the-engine'],
    );
    expect(speakerRow['years'], <int>[2026, 2024]);
  });

  test('GET /v1/speakers/:year/:slug includes other years', () async {
    final body = await expectOk('/v1/speakers/2026/ada-lovelace');
    final speakerRow = body['data'] as Map<String, dynamic>;
    expect(speakerRow['slug'], 'ada-lovelace');
    expect(speakerRow['year'], 2026);
    expect(speakerRow['years'], <int>[2026, 2024]);
    expect(speakerRow['other_years'], <int>[2024]);
    expect(speakerRow['languages'], <String>['Dart']);
    expect(speakerRow['topics'], <String>['compilers']);
    final speakerTalks = speakerRow['talks'] as List<dynamic>;
    expect(speakerTalks, hasLength(1));
    expect(
      (speakerTalks.single as Map<String, dynamic>)['title'],
      'The Analytical Engine',
    );
  });

  test('a speaker with no talk in the requested year is 404', () async {
    await expectNotFound('/v1/speakers/2024/grace-hopper');
  });

  test('GET /v1/sponsors returns the sponsor', () async {
    final rows = dataOf(await expectOk('/v1/sponsors'));
    expect(rows, hasLength(1));
    expect(rows.single['slug'], 'acme');
    expect(rows.single['name'], 'Acme');
  });

  test('GET /v1/sponsors?year= returns that year', () async {
    final rows = dataOf(await expectOk('/v1/sponsors?year=2026'));
    expect(rows, hasLength(1));
    expect(rows.single['slug'], 'acme');
    expect(rows.single['year'], 2026);
    expect(rows.single['tier'], 'gold');
    final empty = dataOf(await expectOk('/v1/sponsors?year=1999'));
    expect(empty, isEmpty);
  });

  test('GET /v1/sponsors/:slug includes sponsorships', () async {
    final body = await expectOk('/v1/sponsors/acme');
    final sponsor = body['data'] as Map<String, dynamic>;
    expect(sponsor['slug'], 'acme');
    final rows = sponsor['sponsorships'] as List<dynamic>;
    expect(rows, hasLength(2));
    expect((rows.first as Map<String, dynamic>)['year'], 2026);
    expect((rows.first as Map<String, dynamic>)['tier'], 'gold');
    expect((rows.last as Map<String, dynamic>)['year'], 2024);
  });

  test('GET /v1/sponsors/:year/:slug includes other years', () async {
    final body = await expectOk('/v1/sponsors/2026/acme');
    final sponsor = body['data'] as Map<String, dynamic>;
    expect(sponsor['slug'], 'acme');
    expect(sponsor['year'], 2026);
    expect(sponsor['tier'], 'gold');
    expect(sponsor['years'], <int>[2026, 2024]);
    expect(sponsor['other_years'], <int>[2024]);
  });

  test('missing slugs and unknown paths are JSON 404', () async {
    await expectNotFound('/v1/speakers/no-such-speaker');
    await expectNotFound('/v1/sponsors/no-such-sponsor');
    await expectNotFound('/v1/sponsors/2026/no-such-sponsor');
    await expectNotFound('/no-such-path');
    await expectNotFound('/v1/does/not/exist');
  });

  test('catalog requests do not open the pool again', () async {
    api.db.openHook = (String _) async {};
    await api.db.open('postgres://postgres:postgres@127.0.0.1:1/unused');
    expect(api.db.connectCount, 1);
    final years = await send('/v1/years');
    final people = await send('/v1/speakers?year=2026');
    expect(years.statusCode, 200);
    expect(people.statusCode, 200);
    expect(api.db.connectCount, 1);
    expect(api.db.sqlCount, greaterThan(0));
  });
}
