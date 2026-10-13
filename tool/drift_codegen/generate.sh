#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
tool="$root/tool/drift_codegen"
mkdir -p "$tool/lib"
cp "$root/lib/data/db/app_database.dart" "$tool/lib/app_database.dart"
cp "$root/lib/data/db/schema.drift" "$tool/lib/schema.drift"
(cd "$tool" && dart pub get >/dev/null && dart run build_runner build)
cp "$tool/lib/app_database.g.dart" "$root/lib/data/db/app_database.g.dart"
