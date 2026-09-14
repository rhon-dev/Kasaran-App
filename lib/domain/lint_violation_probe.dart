// DELIBERATE LINT VIOLATION — for CI gate proof (phase 01, task 9).
// This file is committed on branch test/lint-gate-proof and then reverted.
// It contains the exact pattern from the exit-criteria table:
//   `final double x = 1.0;`  → triggers prefer_final_locals + no-double convention.

// ignore_for_file: unused_local_variable
void lintViolationProbe() {
  // ignore: avoid_dynamic_calls
  final double x = 1.0; // ← this is the violation: double in a domain path
  print(x); // ← also fires: avoid_print
}
