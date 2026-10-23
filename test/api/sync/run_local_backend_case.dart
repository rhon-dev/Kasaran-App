import 'dart:io';

import 'package:test/test.dart';

/// Runs the real stdlib HTTP/Postgres case; never substitutes a simulated
/// backend or skips unavailable services. Python independently guards the
/// exact disposable project before any synthetic fixture write.
Future<void> runLocalBackendCase(String name) async {
  final workdir = Platform.environment['SUPABASE_WORKDIR'];
  expect(workdir, isNotNull, reason: 'Disposable SUPABASE_WORKDIR required');
  final config = File('$workdir/supabase/config.toml');
  expect(config.existsSync(), isTrue);
  expect(
    RegExp(
      r'^project_id\s*=\s*"kasaran_p08_disposable"\s*$',
      multiLine: true,
    ).hasMatch(await config.readAsString()),
    isTrue,
    reason: 'Only exact Phase08 disposable project may receive fixtures',
  );
  final result = await Process.run('python3', [
    File('test/api/sync/test_transport.py').absolute.path,
    'TransportTests.$name',
  ]).timeout(const Duration(seconds: 90));
  // Deliberately do not interpolate subprocess output, credentials or payloads.
  expect(
    result.exitCode,
    0,
    reason:
        'Real local backend case $name failed; run Python case for diagnostics',
  );
}
