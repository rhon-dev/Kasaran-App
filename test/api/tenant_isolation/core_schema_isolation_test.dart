import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  test('local service-role core schema read has ledger table', () async {
    final result = await Process.run('supabase', ['status', '-o', 'json']);
    expect(result.exitCode, 0, reason: 'Local Supabase must be running');
    final settings = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final rest = settings['REST_URL'] as String;
    final serviceKey = settings['SERVICE_ROLE_KEY'] as String;
    final response = await http.get(
      Uri.parse('$rest/ledger_entries?select=id'),
      headers: {
        'apikey': serviceKey,
        'Authorization': 'Bearer $serviceKey',
      },
    );
    final errorCode = response.statusCode == 200
        ? null
        : (jsonDecode(response.body) as Map<String, dynamic>)['code'];
    expect(response.statusCode, 200,
        reason: 'Core ledger relation unavailable (code: $errorCode)');
    expect(jsonDecode(response.body), isA<List<dynamic>>());
  });
}
