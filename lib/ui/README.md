# ui/

**Layering rule:** Widgets and screens only. No SQL, no business rules, no `drift` imports.

This layer may import from `domain/` (for value types and read-only results) and from
`ui/presenters/` (for formatting). It must never import from `data/`, `sync/`, or
`platform/` directly — all persistence and sync access goes through Riverpod providers
that are wired in `main.dart` or a composition root, not referenced here by type.

## Sub-packages

| Package | Responsibility |
|---|---|
| `presenters/` | Formatting only: ₱ display (REQ-GEN-2, REQ-GEN-2A), date, percentages. No business logic. |
