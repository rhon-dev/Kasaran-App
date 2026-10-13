// Local-only, disposable Supabase integration checks. No hosted endpoints.
@Tags(['local_supabase'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

String _uuid() {
  final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
  final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
  for (var i = 0; i < 6; i++) {
    bytes[i] = (millis >> ((5 - i) * 8)) & 0xff;
  }
  bytes[6] = (bytes[6] & 15) | 0x70;
  bytes[8] = (bytes[8] & 63) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

void _status(http.Response response, Iterable<int> accepted, String operation) {
  // Never include response bodies, headers, credentials or request URIs in failures.
  expect(accepted, contains(response.statusCode), reason: operation);
}

class _Actor {
  _Actor(this.id, this.token, this.planId, this.aliasId);
  final String id;
  final String token;
  final String planId;
  final String aliasId;
}

class _Local {
  _Local(this.api, this.rest, this.anon, this.service, this.dbUrl);
  final String api;
  final String rest;
  final String anon;
  final String service;
  final String dbUrl;

  Map<String, String> headers([String? token]) => {
    'apikey': token == service ? service : anon,
    if (token != null) 'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<http.Response> request(
    String method,
    String path, {
    String? token,
    Object? body,
    bool auth = false,
  }) async {
    final url = Uri.parse('${auth ? api : rest}$path');
    final request = http.Request(method, url)..headers.addAll(headers(token));
    if (body != null) request.body = jsonEncode(body);
    final client = http.Client();
    try {
      final streamed = await client.send(request);
      return await http.Response.fromStream(streamed);
    } finally {
      client.close();
    }
  }

  Future<_Actor> provision() async {
    final email = 'core-${_uuid()}@example.test';
    final password = '${_uuid()}Aa1!';
    final created = await request(
      'POST',
      '/auth/v1/admin/users',
      auth: true,
      token: service,
      body: {'email': email, 'password': password, 'email_confirm': true},
    );
    _status(created, [200, 201], 'synthetic local account creation');
    final id =
        (jsonDecode(created.body) as Map<String, dynamic>)['id'] as String;
    final login = await request(
      'POST',
      '/auth/v1/token?grant_type=password',
      auth: true,
      body: {'email': email, 'password': password},
    );
    _status(login, [200], 'synthetic local sign-in');
    final token =
        (jsonDecode(login.body) as Map<String, dynamic>)['access_token']
            as String;
    final plan = _uuid();
    final rpc = await request(
      'POST',
      '/rpc/create_plan',
      token: token,
      body: {
        'p_id': plan,
        'p_wedding_date': '2027-06-01',
        'p_total_budget_cents': 100000,
        'p_guest_cap': 20,
        'p_region_code': 'PH-NCR',
        'p_ruleset_version': 'synthetic',
        'p_driving_rsvp_status': 'unknown',
      },
    );
    _status(rpc, [200], 'synthetic plan creation');
    expect((jsonDecode(rpc.body) as Map<String, dynamic>)['id'], plan);
    final aliases = await request(
      'GET',
      '/plan_member_aliases?select=plan_member_id&plan_id=eq.$plan',
      token: token,
    );
    _status(aliases, [200], 'own alias read');
    final rows = jsonDecode(aliases.body) as List<dynamic>;
    expect(rows, hasLength(1), reason: 'each synthetic plan needs one alias');
    return _Actor(
      id,
      token,
      plan,
      (rows.single as Map<String, dynamic>)['plan_member_id'] as String,
    );
  }

  Future<List<Map<String, dynamic>>> rows(
    String table,
    String token, {
    String? filter,
  }) async {
    final response = await request(
      'GET',
      '/$table?select=*${filter == null ? '' : '&$filter'}',
      token: token,
    );
    _status(response, [200], '$table read');
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  Future<String> localSql(String sql) async {
    // Credentials are passed in memory, never in command arguments or files.
    final uri = Uri.parse(dbUrl);
    expect(
      uri.host,
      anyOf('127.0.0.1', 'localhost'),
      reason: 'only a local database is permitted',
    );
    final result = await Process.run(
      'psql',
      [
        '-X',
        '-A',
        '-t',
        '-v',
        'ON_ERROR_STOP=1',
        '-h',
        uri.host,
        '-p',
        '${uri.port}',
        '-U',
        uri.userInfo.split(':').first,
        '-d',
        uri.pathSegments.last,
        '-c',
        sql,
      ],
      environment: {
        ...Platform.environment,
        'PGPASSWORD': Uri.decodeComponent(uri.userInfo.split(':').last),
      },
    );
    expect(
      result.exitCode,
      0,
      reason:
          'local SQL failed (syntax: ${(result.stderr as String).contains('syntax error')}, '
          'authentication: ${(result.stderr as String).contains('authentication failed')})',
    );
    return (result.stdout as String).trim();
  }

  Future<Map<String, dynamic>> policyCatalog() async {
    const sql = '''
      select json_build_object(
        'scoped', (select coalesce(json_agg(json_build_object(
          'name', c.relname, 'rls', c.relrowsecurity, 'forced', c.relforcerowsecurity,
          'member_policy', exists (
            select 1 from pg_policies p where p.schemaname = 'public'
              and p.tablename = c.relname and p.cmd = 'SELECT'
              and 'authenticated' = any(p.roles)
              and p.qual like '%identity_member%'
              and (p.qual like '%plan_id%' or
                   (c.relname = 'plans' and p.qual like '%(id)%'))
          )) order by c.relname), '[]'::json)
          from pg_class c join pg_namespace n on n.oid = c.relnamespace
          join pg_attribute a on a.attrelid = c.oid and a.attname = 'plan_id'
          where n.nspname = 'public' and c.relkind in ('r', 'p')
            and a.attnum > 0 and not a.attisdropped),
        'plans', (select json_build_object(
          'rls', c.relrowsecurity, 'forced', c.relforcerowsecurity,
          'member_policy', exists (
            select 1 from pg_policies p where p.schemaname = 'public'
              and p.tablename = 'plans' and p.cmd = 'SELECT'
              and 'authenticated' = any(p.roles)
              and p.qual like '%identity_member%'
              and p.qual like '%(id)%'
          )) from pg_class c where c.oid = 'public.plans'::regclass),
        'users', (select json_build_object(
          'rls', c.relrowsecurity, 'forced', c.relforcerowsecurity,
          'self_policy', exists (
            select 1 from pg_policies p where p.schemaname = 'public'
              and p.tablename = 'users' and p.cmd = 'SELECT'
              and 'authenticated' = any(p.roles)
              and p.qual like '%auth.uid()%'
          )) from pg_class c where c.oid = 'public.users'::regclass)
      )::text;
    ''';
    return jsonDecode(await localSql(sql)) as Map<String, dynamic>;
  }
}

Map<String, Object?> _ledger(String id, String plan) => {
  'id': id,
  'plan_id': plan,
  'category_code': 'buffer',
  'entry_type': 'standard',
  'supplier_name': 'Synthetic supplier',
  'estimated_cents': 100,
  'pricing_mode': 'flat',
  'created_at': '2026-10-12T00:00:00Z',
};

Map<String, Object?> _log(String id, String plan, String alias) => {
  'id': id,
  'plan_id': plan,
  'entity_type': 'ledger_entry',
  'entity_id': _uuid(),
  'field_name': 'estimated_cents',
  'schema_version': 2,
  'new_value': {'value': 100},
  'device_monotonic': 1,
  'device_id': _uuid(),
  'plan_member_id': alias,
  'created_at': '2026-10-12T00:00:00Z',
};

void main() {
  late _Local local;
  late _Actor a;
  late _Actor b;
  late Map<String, String> aRows;
  late Map<String, String> bRows;
  const tables = ['ledger_entries', 'change_log'];

  setUpAll(() async {
    final sampleId = _uuid();
    final encodedMillis = int.parse(
      sampleId.replaceAll('-', '').substring(0, 12),
      radix: 16,
    );
    expect(
      encodedMillis,
      closeTo(DateTime.now().toUtc().millisecondsSinceEpoch, 10000),
      reason: 'fixture IDs must carry a real UUIDv7 timestamp',
    );
    final workdir = Platform.environment['SUPABASE_WORKDIR'];
    expect(workdir, isNotNull, reason: 'Set SUPABASE_WORKDIR to local stack');
    final config = File('$workdir/supabase/config.toml');
    expect(
      config.existsSync(),
      isTrue,
      reason: 'Local Supabase workdir required',
    );
    final configText = await config.readAsString();
    expect(
      RegExp(
        r'^project_id\s*=\s*"kasaran_p07_disposable(?:_[A-Za-z0-9]+)?"\s*$',
        multiLine: true,
      ).hasMatch(configText),
      isTrue,
      reason:
          'Use a distinct disposable Supabase project, never the retained local stack',
    );
    final status = await Process.run('supabase', [
      'status',
      '-o',
      'json',
    ], workingDirectory: workdir);
    expect(status.exitCode, 0, reason: 'Local Supabase must be running');
    final settings =
        jsonDecode(status.stdout as String) as Map<String, dynamic>;
    final api = Uri.parse(settings['API_URL'] as String);
    final rest = Uri.parse(settings['REST_URL'] as String);
    for (final uri in [api, rest]) {
      expect(
        uri.host,
        anyOf('127.0.0.1', 'localhost'),
        reason: 'only local Supabase is permitted',
      );
    }
    local = _Local(
      api.toString(),
      rest.toString(),
      settings['ANON_KEY'] as String,
      settings['SERVICE_ROLE_KEY'] as String,
      settings['DB_URL'] as String,
    );
    a = await local.provision();
    b = await local.provision();
    aRows = {'ledger_entries': _uuid(), 'change_log': _uuid()};
    bRows = {'ledger_entries': _uuid(), 'change_log': _uuid()};
    for (final actor in [a, b]) {
      final ids = identical(actor, a) ? aRows : bRows;
      for (final table in tables) {
        final row = table == 'ledger_entries'
            ? _ledger(ids[table]!, actor.planId)
            : _log(ids[table]!, actor.planId, actor.aliasId);
        final seeded = await local.request(
          'POST',
          '/$table',
          token: local.service,
          body: row,
        );
        _status(seeded, [201], 'trusted fixture insert into $table');
      }
    }
    // Disposable stack: immutable log rows and their synthetic accounts are
    // intentionally retained until the stack is stopped, never reset here.
  });

  test('own ledger and log rows are visible to each plan member', () async {
    for (final table in tables) {
      for (final actor in [a, b]) {
        final expected = identical(actor, a) ? aRows[table] : bRows[table];
        expect(
          (await local.rows(
            table,
            actor.token,
            filter: 'id=eq.$expected',
          )).single['id'],
          expected,
        );
      }
    }
  });

  test('cross-tenant read hides foreign ledger and log rows', () async {
    final absent = _uuid();
    for (final table in tables) {
      for (final pair in [(a, b, bRows[table]!), (b, a, aRows[table]!)]) {
        final viewer = pair.$1;
        final foreign = pair.$2;
        final id = pair.$3;
        expect(
          (await local.rows(
            table,
            foreign.token,
            filter: 'id=eq.$id',
          )).single['id'],
          id,
          reason: 'foreign fixture must exist',
        );
        final foreignById = await local.rows(
          table,
          viewer.token,
          filter: 'id=eq.$id',
        );
        final nonexistentById = await local.rows(
          table,
          viewer.token,
          filter: 'id=eq.$absent',
        );
        expect(foreignById, nonexistentById);
        expect(foreignById, isEmpty);
        final foreignList = await local.rows(
          table,
          viewer.token,
          filter: 'plan_id=eq.${foreign.planId}',
        );
        final nonexistentList = await local.rows(
          table,
          viewer.token,
          filter: 'plan_id=eq.$absent',
        );
        expect(foreignList, nonexistentList);
        expect(foreignList, isEmpty);
        expect(
          await local.rows(table, viewer.token),
          contains(
            predicate<Map<String, dynamic>>(
              (r) =>
                  r['id'] ==
                  (identical(viewer, a) ? aRows[table] : bRows[table]),
            ),
          ),
        );
      }
    }
  });

  test('direct anon and authenticated insert update delete denied', () async {
    for (final table in tables) {
      final ownId = aRows[table]!;
      expect(
        await local.rows(table, a.token, filter: 'id=eq.$ownId'),
        hasLength(1),
        reason: 'existing target required',
      );
      for (final token in <String?>[null, a.token]) {
        final row = table == 'ledger_entries'
            ? _ledger(_uuid(), a.planId)
            : _log(_uuid(), a.planId, a.aliasId);
        for (final operation in ['POST', 'PATCH', 'DELETE']) {
          final path = operation == 'POST' ? '/$table' : '/$table?id=eq.$ownId';
          final response = await local.request(
            operation,
            path,
            token: token,
            body: operation == 'POST'
                ? row
                : operation == 'PATCH'
                ? {'created_at': '2027-01-01T00:00:00Z'}
                : null,
          );
          expect(
            response.statusCode,
            greaterThanOrEqualTo(400),
            reason: '$operation $table must be denied to direct clients',
          );
          expect(
            await local.rows(table, local.service, filter: 'id=eq.$ownId'),
            hasLength(1),
            reason: 'target must remain unchanged',
          );
          expect(
            await local.rows(
              table,
              local.service,
              filter: 'id=eq.${row['id']}',
            ),
            isEmpty,
            reason: 'direct insert must not create row',
          );
        }
      }
    }
  });

  test('cross-tenant write denies forged plan and alias binding', () async {
    for (final table in tables) {
      final original = bRows[table]!;
      expect(
        await local.rows(table, local.service, filter: 'id=eq.$original'),
        hasLength(1),
      );
      final forged = table == 'ledger_entries'
          ? _ledger(_uuid(), b.planId)
          : _log(_uuid(), b.planId, a.aliasId);
      final client = await local.request(
        'POST',
        '/$table',
        token: a.token,
        body: forged,
      );
      expect(
        client.statusCode,
        greaterThanOrEqualTo(400),
        reason: 'A cannot create a row bound to B',
      );
      expect(
        await local.rows(table, local.service, filter: 'id=eq.${forged['id']}'),
        isEmpty,
      );
      if (table == 'change_log') {
        // The trusted writer cannot attach A's alias to B's plan, even with
        // service-role grants. Test both directions of the composite FK.
        for (final pair in [(b.planId, a.aliasId), (a.planId, b.aliasId)]) {
          final invalid = _log(_uuid(), pair.$1, pair.$2);
          final result = await local.request(
            'POST',
            '/change_log',
            token: local.service,
            body: invalid,
          );
          expect(
            result.statusCode,
            greaterThanOrEqualTo(400),
            reason: 'trusted writer must reject foreign alias binding',
          );
          expect(
            await local.rows(
              table,
              local.service,
              filter: 'id=eq.${invalid['id']}',
            ),
            isEmpty,
          );
        }
      } else {
        final invalid = _ledger(_uuid(), _uuid());
        final result = await local.request(
          'POST',
          '/ledger_entries',
          token: local.service,
          body: invalid,
        );
        expect(
          result.statusCode,
          greaterThanOrEqualTo(400),
          reason: 'trusted writer cannot bind a nonexistent plan',
        );
        expect(
          await local.rows(
            table,
            local.service,
            filter: 'id=eq.${invalid['id']}',
          ),
          isEmpty,
        );
      }
    }
  });

  test('cross-tenant delete denies foreign rows', () async {
    for (final table in tables) {
      final id = bRows[table]!;
      expect(
        await local.rows(table, b.token, filter: 'id=eq.$id'),
        hasLength(1),
      );
      final response = await local.request(
        'DELETE',
        '/$table?id=eq.$id',
        token: a.token,
      );
      expect(
        response.statusCode,
        greaterThanOrEqualTo(400),
        reason: 'foreign delete must be denied, not silently affect zero',
      );
      expect(
        await local.rows(table, local.service, filter: 'id=eq.$id'),
        hasLength(1),
      );
    }
  });

  test('privileged log update and delete rejected by trigger', () async {
    final id = aRows['change_log']!;
    final before = await local.rows(
      'change_log',
      local.service,
      filter: 'id=eq.$id',
    );
    expect(before, hasLength(1));
    for (final method in ['PATCH', 'DELETE']) {
      final response = await local.request(
        method,
        '/change_log?id=eq.$id',
        token: local.service,
        body: method == 'PATCH' ? {'field_name': 'forged'} : null,
      );
      expect(
        response.statusCode,
        greaterThanOrEqualTo(400),
        reason: 'privileged $method must invoke immutability trigger',
      );
      expect(
        await local.rows('change_log', local.service, filter: 'id=eq.$id'),
        before,
        reason: 'original log row must remain byte-equivalent as JSON',
      );
    }
  });

  test('policy catalog covers every public plan-scoped table', () async {
    final catalog = await local.policyCatalog();
    final scoped = (catalog['scoped'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final names = scoped.map((r) => r['name']).toSet();
    expect(
      names,
      containsAll(<String>{
        'plan_members',
        'plan_member_aliases',
        'invites',
        'ledger_entries',
        'change_log',
      }),
    );
    final plans = catalog['plans'] as Map<String, dynamic>;
    expect(plans, containsPair('rls', true));
    expect(plans, containsPair('forced', true));
    expect(plans, containsPair('member_policy', true));
    expect(scoped, isNotEmpty);
    for (final row in scoped) {
      expect(row['rls'], isTrue, reason: '${row['name']} must enable RLS');
      expect(row['forced'], isTrue, reason: '${row['name']} must force RLS');
      // plans is plan-scoped by its id, not by a plan_id column.
      expect(
        row['member_policy'],
        isTrue,
        reason: '${row['name']} needs authenticated membership SELECT',
      );
    }
    final users = catalog['users'] as Map<String, dynamic>;
    expect(users, containsPair('rls', true));
    expect(users, containsPair('forced', true));
    expect(users, containsPair('self_policy', true));
  });

  test('removed member loses ledger and log read', () async {
    for (final table in tables) {
      expect(
        await local.rows(table, b.token, filter: 'id=eq.${bRows[table]}'),
        hasLength(1),
        reason: 'B must read own row before removal',
      );
    }
    // The Phase-06 membership table does not grant service_role REST DELETE.
    // Use the disposable local Postgres administrator; assert a real row was removed.
    final removed = await local.localSql('''
      with removed as (
        delete from public.plan_members
        where plan_id = '${b.planId}'::uuid and user_id = '${b.id}'::uuid
        returning user_id
      ) select count(*) from removed;
    ''');
    expect(removed, '1', reason: 'one live membership must be removed');
    expect(
      await local.localSql('''
        select count(*) from public.plan_members
        where plan_id = '${b.planId}'::uuid and user_id = '${b.id}'::uuid;
      '''),
      '0',
      reason: 'membership removal must persist',
    );
    for (final table in tables) {
      expect(
        await local.rows(table, local.service, filter: 'id=eq.${bRows[table]}'),
        hasLength(1),
        reason: 'row must remain after membership is removed',
      );
      expect(
        await local.rows(table, b.token, filter: 'id=eq.${bRows[table]}'),
        isEmpty,
      );
      expect(
        await local.rows(table, b.token, filter: 'plan_id=eq.${b.planId}'),
        isEmpty,
      );
    }
  });
}
