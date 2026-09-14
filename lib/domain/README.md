# domain/

**Layering rule:** Pure Dart only. Zero Flutter SDK imports. Zero `drift` imports.
Functions operate on plain value types (`int`, `String`, immutable data classes).

This constraint is load-bearing: it is what makes the allocation engine unit-testable
against the acceptance criteria (REQ-AE-1 clause 1) without a widget tree or a database
open. Any import of `package:flutter/...` or `package:drift/...` in this layer is a
layering violation and must be caught by `flutter analyze` via the custom-lint rule
added in phase 02.

## Sub-packages

| Package | Responsibility |
|---|---|
| `allocation/` | Pure allocation engine (design.md §5) — deterministic, explainable, ruleset-pinned. |
| `calculations/` | Gross total, net out-of-pocket, exposure, variance, buffer, per-head derived amounts. |
| `validation/` | Field-level validation rules (REQ-BS-2, REQ-LG-1). |
