# ui/presenters/

**Layering rule:** Formatting only — the single chokepoint where `int` centavo values
become display strings.

Implements REQ-GEN-2 (full ₱ form) and REQ-GEN-2A (constrained bento form: centavos
dropped below ₱1 M, `₱1.25M` above, truncated toward zero). No business logic lives
here; no SQL, no Flutter SDK beyond `dart:core`.

A value must never be formatted anywhere else in the codebase. The presenter is the
only place a centavo `int` becomes a `String`.
