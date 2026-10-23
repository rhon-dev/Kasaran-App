@Tags(['local_supabase'])
library;

import 'package:test/test.dart';

import '../sync/run_local_backend_case.dart';

void main() {
  test(
    'forged plan_id pull denies foreign and nonexistent plans identically',
    () async {
      // Python asserts B's committed own-row precondition, A's working own pull,
      // and identical status/body denials for B's plan and an absent plan.
      await runLocalBackendCase('test_forged_plan_pull');
    },
  );
}
