# data/db/

**Layering rule:** `drift` table definitions and the database class only. No business
logic. No queries that are not directly supporting a repository method.

Contains:

- `drift` `@DataClassName` / `@TableName` table definitions that mirror the schema in
  design.md §4.
- The `AppDatabase` class (`@DriftDatabase`) with the migration `MigrationStrategy`.
- Schema migration steps — forward only, backward-compatible per deployment-plan §2.4.
  Every migration must be additive (nullable column or default, new table, new index)
  until a contract phase is explicitly scheduled.

**Money columns are `bigint` (`int64`) throughout.** No `REAL` columns for any monetary
field — REQ-GEN-1 requires signed 64-bit integer centavos, no floating point.
