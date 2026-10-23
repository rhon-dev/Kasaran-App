import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:test/test.dart';

import 'budget_allocator_test.dart' show fixtureRules;

AllocationResult allocate({
  int budget = 10000,
  Map<String, int> overrides = const {},
  Ruleset? rules,
}) => const RuleBasedAllocator().allocate(
  AllocationInput(
    totalBudgetCents: budget,
    regionCode: 'fixture',
    drivingGuestCount: 100,
    rulesetVersion: 'document-fixture',
    overrides: overrides,
  ),
  rules ?? fixtureRules(),
);

void main() {
  test('TC-AE-01 identical complete explanation operands for 100 reads', () {
    List<Object?> snapshot(AllocationResult r) => [
      r.allocatorKind,
      r.allocatorVersion,
      r.allocationDifferenceCents,
      ...r.issues,
      for (final c in r.categories)
        [
          c.categoryCode,
          c.engineCents,
          c.effectiveCents,
          c.overrideCents,
          c.explanation.ruleId,
          c.explanation.rulesetVersion,
          c.explanation.budgetCents,
          c.explanation.baselineBp,
          c.explanation.skewBp,
          c.explanation.costIndexBp,
          c.explanation.weight,
          c.explanation.totalWeight,
          c.explanation.costIndexAffectsShares,
        ],
    ];
    final expected = snapshot(allocate(budget: 10003));
    for (var i = 0; i < 100; i++) {
      expect(snapshot(allocate(budget: 10003)), expected);
    }
  });
  test('TC-AE-02 malformed explicit rulesets fail at construction', () {
    for (final baseline in [
      <int>[],
      [4000, 1500, 1000, 1000, 500, 1999],
      [-1, 1501, 1000, 1000, 500, 6000],
    ]) {
      expect(
        () => Ruleset(
          version: 'bad',
          baselines: baseline,
          regions: {'fixture': RegionRule(costIndexBp: 10000)},
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => Ruleset(
        version: 'bad',
        baselines: [4000, 1500, 1000, 1000, 500, 2000],
        regions: {
          'fixture': RegionRule(costIndexBp: 10000, skewBp: List.filled(6, 0)),
        },
      ),
      throwsArgumentError,
    );
  });
  test('TC-AE-03 integer floors and complete remainder in Buffer', () {
    // Deterministic spread across documented peso endpoints, plus odd cents
    // and the largest signed int64 input. BigInt oracle avoids int overflow.
    final budgets = <int>{
      100,
      999999900,
      1,
      101,
      9007199254740993,
      9223372036854775807,
      for (var i = 0; i < 1000; i++) 100 + (i * 999999800 ~/ 999),
    };
    const bp = [4000, 1500, 1000, 1000, 500, 2000];
    for (final budget in budgets) {
      final r = allocate(budget: budget);
      final expected = [
        for (final b in bp)
          (BigInt.from(budget) * BigInt.from(b) ~/ BigInt.from(10000)).toInt(),
      ];
      expected[5] += budget - expected.fold<int>(0, (a, b) => a + b);
      expect(r.categories.map((c) => c.effectiveCents), expected);
      expect(
        r.categories.fold<BigInt>(
          BigInt.zero,
          (a, c) => a + BigInt.from(c.effectiveCents),
        ),
        BigInt.from(budget),
      );
    }
  });
  test(
    'TC-AE-05 regional index changes explanation but not category shares',
    () {
      final a = allocate(rules: fixtureRules(index: 8500));
      final b = allocate(rules: fixtureRules(index: 12000));
      expect(
        a.categories.map((c) => c.engineCents),
        b.categories.map((c) => c.engineCents),
      );
      expect(a.categories.first.explanation.costIndexBp, 8500);
      expect(b.categories.first.explanation.costIndexBp, 12000);
    },
  );
  test('TC-AE-06 skew changes weights with exact normalization', () {
    final r = allocate(
      budget: 10003,
      rules: Ruleset(
        version: 'document-fixture',
        baselines: [4000, 1500, 1000, 1000, 500, 2000],
        regions: {
          'fixture': RegionRule(
            costIndexBp: 10000,
            skewBp: [20000, 10000, 10000, 10000, 10000, 10000],
          ),
        },
      ),
    );
    final weights = [8000, 1500, 1000, 1000, 500, 2000];
    final total = weights.fold<int>(0, (a, b) => a + b);
    final expected = [for (final w in weights) 10003 * w ~/ total];
    expected[5] += 10003 - expected.fold<int>(0, (a, b) => a + b);
    expect(r.categories.map((c) => c.engineCents), expected);
    expect(r.categories.first.explanation.weight, BigInt.from(80000000));
    expect(r.categories.first.explanation.totalWeight, BigInt.from(140000000));
  });
  test('TC-AE-08 missing or mismatched pinned ruleset stays unavailable', () {
    final input = AllocationInput(
      totalBudgetCents: 10000,
      regionCode: 'fixture',
      drivingGuestCount: 100,
      rulesetVersion: 'document-fixture',
    );
    for (final rules in [null, fixtureRules(version: 'new')]) {
      final r = const RuleBasedAllocator().allocate(input, rules);
      expect(r.available, isFalse);
      expect(r.allocationDifferenceCents, isNull);
      expect(r.expectedTotalCostCents, isNull);
      expect(r.issues, ['missing_pinned_ruleset']);
    }
  });
  test('TC-AE-10 recompute preserves overrides and selective revert', () {
    final locks = {'photo_video': 1700, 'attire_styling': 1100};
    final changed = allocate(budget: 20000, overrides: locks);
    expect(changed.categories[1].effectiveCents, 1700);
    expect(changed.categories[2].effectiveCents, 1100);
    final reverted = allocate(
      budget: 20000,
      overrides: {'attire_styling': 1100},
    );
    expect(reverted.categories[1].overrideCents, isNull);
    expect(reverted.categories[2].effectiveCents, 1100);
    expect(
      allocate(budget: 20000).categories.map((c) => c.effectiveCents),
      allocate(budget: 20000).categories.map((c) => c.engineCents),
    );
    expect(locks, {'photo_video': 1700, 'attire_styling': 1100});
  });
  test('TC-AE-11 free categories absorb remainder without altering a lock', () {
    final r = allocate(overrides: {'photo_video': 1700});
    expect(r.categories[1].effectiveCents, 1700);
    expect(r.categories.fold<int>(0, (a, c) => a + c.effectiveCents), 10000);
    expect(r.allocationDifferenceCents, 0);
  });
  test('TC-AE-11 all locked excess remains signed and unclamped', () {
    final overrides = {for (final c in categoryCodes) c: 0}
      ..['photo_video'] = 10001;
    final r = allocate(overrides: overrides);
    expect(r.categories[1].effectiveCents, 10001);
    expect(r.allocationDifferenceCents, -1);
    expect(r.issues, ['over_allocated']);
  });
  test('TC-AE-13 six zero overrides expose complete shortfall', () {
    final r = allocate(overrides: {for (final c in categoryCodes) c: 0});
    expect(r.categories.map((c) => c.effectiveCents), everyElement(0));
    expect(r.allocationDifferenceCents, 10000);
    expect(r.issues, ['under_allocated']);
  });
  test(
    'zero-weight unlocked remainder reports impossibility without division',
    () {
      final r = allocate(
        overrides: {'catering_venue': 1},
        rules: Ruleset(
          version: 'document-fixture',
          baselines: [10000, 0, 0, 0, 0, 0],
          regions: {'fixture': RegionRule(costIndexBp: 10000)},
        ),
      );
      expect(
        r.issues,
        containsAll(['no_unlocked_allocation_weight', 'under_allocated']),
      );
      expect(r.categories.first.effectiveCents, 1);
      expect(r.allocationDifferenceCents, 9999);
    },
  );
  test('invalid allocation inputs rejected without manufacturing outputs', () {
    for (final budget in [0, -1]) {
      expect(allocate(budget: budget).available, isFalse);
    }
    for (final overrides in [
      {'buffer': -1},
      {'unknown': 1},
    ]) {
      expect(allocate(overrides: overrides).issues, [
        'invalid_allocation_input',
      ]);
    }
  });
}
