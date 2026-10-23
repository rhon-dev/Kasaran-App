// Versioned POST contract exercised against real disposable Auth/Edge/Postgres.
// Missing services fail; these cases never satisfy CI by skipping.
@Tags(['local_supabase'])
library;

import 'package:test/test.dart';

import '../sync/run_local_backend_case.dart';

void main() {
  test(
    'POST push accepts once and exact retry returns original stamp',
    () async {
      await runLocalBackendCase('test_own_push_pull_exact_retry');
    },
  );
  test(
    'POST pull validates bounds versions auth and ordered pagination',
    () async {
      await runLocalBackendCase('test_pagination_protocol_and_auth_contract');
    },
  );
  test('pull serializes trusted historical timestamps with UTC Z', () async {
    await runLocalBackendCase(
      'test_trusted_historical_row_formats_utc_timestamp',
    );
  });
}
