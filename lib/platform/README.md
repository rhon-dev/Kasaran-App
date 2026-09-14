# platform/

**Layering rule:** Native and platform-specific wiring only. Owns the SQLite open/
encrypt/migrate lifecycle. May be imported by `data/` and `sync/`. Must not contain
business logic, SQL queries, or sync protocol logic.

## Sub-packages

| Package | Responsibility |
|---|---|
| `db/` | SQLite open, key derivation, encryption initialisation (SQLCipher via `drift` + `sqlcipher_flutter_libs`), and the `drift` `QueryExecutor` factory. |
