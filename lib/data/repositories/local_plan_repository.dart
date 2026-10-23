import 'package:drift/drift.dart';
import 'package:kasaran/data/db/app_database.dart';
import 'package:kasaran/platform/db/account_store_coordinator.dart';

/// Immutable, last-known encrypted-local facts, not live server authority.
final class LocalPlanSnapshot {
  const LocalPlanSnapshot(this.plan, this.member, this.alias);
  final Plan plan;
  final PlanMember member;
  final PlanMemberAliase alias;
}

/// Finite counted reads only; never discovers membership or opens a network path.
final class LocalPlanRepository {
  const LocalPlanRepository(this.coordinator);
  final AccountStoreCoordinator coordinator;

  Future<LocalPlanSnapshot?> currentActivePlan() async {
    final session = coordinator.identity.capture();
    final generation = coordinator.generation;
    void check() {
      final current = coordinator.identity.capture();
      if (session == null ||
          current == null ||
          current.userId != session.userId ||
          !identical(current.marker, session.marker) ||
          generation != coordinator.generation ||
          !coordinator.isReady) {
        throw StateError('Local plan session changed');
      }
    }

    check();
    final result = await coordinator.withAccount(
      (lease) => lease.run((db) async {
        final result = await db.transaction(() async {
          check();
          final query =
              db.select(db.plans).join([
                innerJoin(
                  db.planMembers,
                  db.planMembers.planId.equalsExp(db.plans.id),
                ),
                innerJoin(
                  db.planMemberAliases,
                  db.planMemberAliases.planId.equalsExp(db.planMembers.planId) &
                      db.planMemberAliases.userId.equalsExp(
                        db.planMembers.userId,
                      ) &
                      db.planMemberAliases.planMemberId.equalsExp(
                        db.planMembers.planMemberId,
                      ),
                ),
              ])..where(
                db.planMembers.userId.equals(session!.userId) &
                    db.plans.isActive.equals(1) &
                    db.plans.deletedAt.isNull(),
              );
          final rows = await query.get();
          check();
          final active = await (db.select(
            db.plans,
          )..where((p) => p.isActive.equals(1) & p.deletedAt.isNull())).get();
          check();
          if (active.length != rows.length || rows.length > 1) {
            throw StateError('Inconsistent local plan metadata');
          }
          if (rows.isEmpty) return null;
          final row = rows.single;
          final plan = row.readTable(db.plans);
          final member = row.readTable(db.planMembers);
          final alias = row.readTable(db.planMemberAliases);
          if (plan.id.isEmpty ||
              member.planMemberId.isEmpty ||
              plan.creatorUserId.isEmpty ||
              !{'creator', 'partner'}.contains(member.role) ||
              (member.role == 'creator') !=
                  (plan.creatorUserId == member.userId)) {
            throw StateError('Inconsistent local plan metadata');
          }
          return LocalPlanSnapshot(plan, member, alias);
        });
        check(); // Native COMMIT is an asynchronous boundary too.
        return result;
      }),
    );
    check(); // withAccount's wrapper adds another completion boundary.
    return result;
  }
}
