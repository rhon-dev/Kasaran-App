/// Local-first persistence boundary. Phase 05 defines the interface only;
/// plan-scoped implementations arrive with their entities in phase 07.
/// This contract never implies an HTTP-backed read or write.
abstract interface class Repository<Entity, Id> {
  Future<Entity?> find(Id id);
  Future<void> save(Id id, Entity value);
  Future<void> remove(Id id);
}
