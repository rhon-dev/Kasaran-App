@Tags(['local_supabase'])
library;

import 'package:test/test.dart';

import 'run_local_backend_case.dart';

void main() {
  test(
    'full batch validation rejects conflicts without partial acceptance',
    () async {
      await runLocalBackendCase('test_batch_atomicity_conflict_and_validation');
    },
  );
  test('same batch exact duplicates retain one committed event', () async {
    await runLocalBackendCase('test_same_batch_exact_duplicate_is_idempotent');
  });
  test('queued acceptance rechecks session after plan lock wait', () async {
    await runLocalBackendCase('test_waiting_push_rechecks_revoked_session');
  });
  test('direct table and anonymous RPC bypass denied', () async {
    await runLocalBackendCase('test_direct_bypass_denied');
  });
  test('removed unverified and revoked sessions denied', () async {
    await runLocalBackendCase('test_removed_unverified_and_revoked_session');
  });
  test(
    'real transactions enforce commit order and rollback reuses stamp',
    () async {
      await runLocalBackendCase(
        'test_real_transactions_commit_order_and_rollback',
      );
    },
  );
}
