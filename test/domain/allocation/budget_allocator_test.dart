import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:test/test.dart';

// design.md:683–748; testing-plan.md:724–741. Explicit documented
// operands, not a claim that an approved production asset/version exists.
Ruleset fixtureRules({
  String version = 'document-fixture',
  int index = 10000,
}) => Ruleset(
  version: version,
  baselines: const [4000, 1500, 1000, 1000, 500, 2000],
  regions: {'fixture': RegionRule(costIndexBp: index)},
);
void main() {
  test('F4 native overflow cannot disguise an invalid baseline sum', () {
    expect(
      () => Ruleset(
        version: 'overflow',
        baselines: [9223372036854775807, 9223372036854775807, 10002, 0, 0, 0],
        regions: {'fixture': RegionRule(costIndexBp: 10000)},
      ),
      throwsArgumentError,
    );
  });
  test('F4 valid maximum native budget conserves exact allocation', () {
    final r = const RuleBasedAllocator().allocate(
      AllocationInput(
        totalBudgetCents: 9223372036854775807,
        regionCode: 'fixture',
        drivingGuestCount: 0,
        rulesetVersion: 'document-fixture',
      ),
      fixtureRules(),
    );
    expect(r.available, isTrue);
    expect(r.issues, isEmpty);
    expect(
      r.categories.fold(
        BigInt.zero,
        (sum, c) => sum + BigInt.from(c.effectiveCents),
      ),
      BigInt.parse('9223372036854775807'),
    );
    expect(r.allocationDifferenceCents, 0);
  });
  test('TC-AE-04 baseline with explanation and unavailable adequacy', () {
    final r = const RuleBasedAllocator().allocate(
      AllocationInput(
        totalBudgetCents: 35000000,
        regionCode: 'fixture',
        drivingGuestCount: 100,
        rulesetVersion: 'document-fixture',
      ),
      fixtureRules(),
    );
    expect(r.categories.map((e) => e.engineCents), [
      14000000,
      5250000,
      3500000,
      3500000,
      1750000,
      7000000,
    ]);
    expect(r.expectedTotalCostCents, isNull); // OQ-04, not zero.
    expect(r.categories.first.explanation.baselineBp, 4000);
    expect(r.categories.first.explanation.ruleId, 'ADR-10/ADR-11');
    expect(r.categories.first.explanation.budgetCents, 35000000);
    expect(r.categories.first.explanation.costIndexAffectsShares, isFalse);
    expect(r.issues, isEmpty);
  });
}
