# domain/allocation/

**Layering rule:** Pure Dart. No Flutter, no drift, no I/O, no clock, no randomness.

Implements the `BudgetAllocator` interface (design.md §5.1). The rule-based
implementation (design.md §5.2) lives here:

1. Load baselines for the pinned ruleset version (passed in, already loaded — no DB).
2. Load region → tier, cost index, and per-category skew.
3. Apply skew, renormalise, distribute with largest-remainder rounding (REQ-AE-1 cl. 3).
4. Return `AllocationResult` with per-category amounts and opaque `explanation` JSON
   (REQ-AE-4).

**No `double` in any monetary path.** Percentages and multipliers are basis points
(`int`), so all ratio arithmetic stays integer until the final divide. This is the
constraint from design.md §1.5 — Dart's native 64-bit `int` satisfies REQ-GEN-1
directly.
