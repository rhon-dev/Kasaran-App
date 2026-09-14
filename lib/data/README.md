# data/

**Layering rule:** The only layer that imports `drift` or executes SQL. Nothing above
this layer (ui/, domain/) touches a database.

Owns the persistence boundary. Repositories expose typed async methods and `Stream`s;
callers never see a raw SQL string or a `drift` `Selectable`.

## Sub-packages

| Package | Responsibility |
|---|---|
| `repositories/` | The only code that touches SQL. One repository class per aggregate root. |
| `db/` | `drift` table definitions, database class, and schema migrations. |
| `changelog/` | Append-only writer for `change_log` rows (design.md §2.1). Never updates or deletes. |
