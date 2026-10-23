/// Pure read-time allocation. Configuration is supplied, never fabricated.
library;

const categoryCodes = [
  'catering_venue',
  'photo_video',
  'attire_styling',
  'coordination',
  'entourage_misc',
  'buffer',
];

class RegionRule {
  RegionRule({required this.costIndexBp, List<int>? skewBp})
    : skewBp = List.unmodifiable(skewBp ?? List.filled(6, 10000));
  final int costIndexBp;
  final List<int> skewBp;
}

class Ruleset {
  Ruleset({
    required this.version,
    required List<int> baselines,
    required Map<String, RegionRule> regions,
  }) : baselines = List.unmodifiable(baselines),
       regions = Map.unmodifiable(regions) {
    if (version.isEmpty ||
        baselines.length != 6 ||
        baselines.any((e) => e < 0) ||
        baselines.fold(BigInt.zero, (a, b) => a + BigInt.from(b)) !=
            BigInt.from(10000) ||
        regions.isEmpty ||
        regions.values.any(
          (r) =>
              r.costIndexBp <= 0 ||
              r.skewBp.length != 6 ||
              r.skewBp.any((e) => e < 0) ||
              List.generate(
                    6,
                    (i) => BigInt.from(baselines[i]) * BigInt.from(r.skewBp[i]),
                  ).fold(BigInt.zero, (a, b) => a + b) ==
                  BigInt.zero,
        )) {
      throw ArgumentError('Invalid explicit ruleset');
    }
  }
  final String version;
  final List<int> baselines;
  final Map<String, RegionRule> regions;
}

class AllocationInput {
  AllocationInput({
    required this.totalBudgetCents,
    required this.regionCode,
    required this.drivingGuestCount,
    required this.rulesetVersion,
    Map<String, int> overrides = const {},
  }) : overrides = Map.unmodifiable(overrides);
  final int totalBudgetCents, drivingGuestCount;
  final String regionCode, rulesetVersion;
  final Map<String, int> overrides;
}

class Explanation {
  Explanation({
    required this.rulesetVersion,
    required this.budgetCents,
    required this.baselineBp,
    required this.skewBp,
    required this.costIndexBp,
    required this.weight,
    required this.totalWeight,
  }) : ruleId = 'ADR-10/ADR-11';
  final String ruleId, rulesetVersion;
  final int budgetCents, baselineBp, skewBp, costIndexBp;
  final BigInt weight, totalWeight;
  final bool costIndexAffectsShares = false;
}

class CategoryAllocation {
  const CategoryAllocation(
    this.categoryCode,
    this.engineCents,
    this.effectiveCents,
    this.overrideCents,
    this.explanation,
  );
  final String categoryCode;
  final int engineCents, effectiveCents;
  final int? overrideCents;
  final Explanation explanation;
}

class AllocationResult {
  AllocationResult(
    List<CategoryAllocation> categories,
    List<String> issues, {
    this.allocationDifferenceCents,
    this.allocatorKind = 'rule_based',
    this.allocatorVersion = '1',
  }) : categories = List.unmodifiable(categories),
       issues = List.unmodifiable(issues);
  final List<CategoryAllocation> categories;
  final List<String> issues;
  final String allocatorKind, allocatorVersion;
  // No benchmarks exist: absence is not an amount of zero.
  final int? expectedTotalCostCents = null;
  final int? allocationDifferenceCents;
  bool get available => categories.isNotEmpty;
}

abstract interface class BudgetAllocator {
  String get kind;
  String get version;
  AllocationResult allocate(AllocationInput input, Ruleset? ruleset);
}

class RuleBasedAllocator implements BudgetAllocator {
  const RuleBasedAllocator();
  @override
  String get kind => 'rule_based';
  @override
  String get version => '1';
  @override
  AllocationResult allocate(AllocationInput input, Ruleset? ruleset) {
    if (ruleset == null || ruleset.version != input.rulesetVersion) {
      return AllocationResult([], ['missing_pinned_ruleset']);
    }
    final region = ruleset.regions[input.regionCode];
    if (input.totalBudgetCents <= 0 ||
        input.drivingGuestCount < 0 ||
        region == null ||
        input.overrides.entries.any(
          (e) => !categoryCodes.contains(e.key) || e.value < 0,
        )) {
      return AllocationResult([], ['invalid_allocation_input']);
    }
    final weights = List.generate(
      6,
      (i) => BigInt.from(ruleset.baselines[i]) * BigInt.from(region.skewBp[i]),
    );
    final totalWeight = weights.fold(BigInt.zero, (a, b) => a + b);
    final engine = _distribute(input.totalBudgetCents, weights, [
      0,
      1,
      2,
      3,
      4,
      5,
    ]);
    final effective = [...engine];
    final overridden = input.overrides.values.fold(
      BigInt.zero,
      (a, b) => a + BigInt.from(b),
    );
    final remaining = BigInt.from(input.totalBudgetCents) - overridden;
    final free = [
      for (var i = 0; i < 6; i++)
        if (!input.overrides.containsKey(categoryCodes[i])) i,
    ];
    final issues = <String>[];
    if (remaining >= BigInt.zero && free.isNotEmpty) {
      if (free.every((i) => weights[i] == BigInt.zero)) {
        issues.add('no_unlocked_allocation_weight');
      } else {
        final redistributed = _distribute(remaining.toInt(), weights, free);
        for (final i in free) {
          effective[i] = redistributed[i];
        }
      }
    }
    for (var i = 0; i < 6; i++) {
      effective[i] = input.overrides[categoryCodes[i]] ?? effective[i];
    }
    final diff =
        input.totalBudgetCents - effective.fold<int>(0, (a, b) => a + b);
    if (diff != 0) {
      issues.add(diff < 0 ? 'over_allocated' : 'under_allocated');
    }
    return AllocationResult(
      List.generate(
        6,
        (i) => CategoryAllocation(
          categoryCodes[i],
          engine[i],
          effective[i],
          input.overrides[categoryCodes[i]],
          Explanation(
            rulesetVersion: ruleset.version,
            budgetCents: input.totalBudgetCents,
            baselineBp: ruleset.baselines[i],
            skewBp: region.skewBp[i],
            costIndexBp: region.costIndexBp,
            weight: weights[i],
            totalWeight: totalWeight,
          ),
        ),
      ),
      issues,
      allocationDifferenceCents: diff,
    );
  }

  List<int> _distribute(int amount, List<BigInt> weights, List<int> eligible) {
    final total = eligible.fold(BigInt.zero, (a, i) => a + weights[i]);
    final result = List.filled(6, 0);
    for (final i in eligible) {
      result[i] = (BigInt.from(amount) * weights[i] ~/ total).toInt();
    }
    // Buffer is always the rounding destination when unlocked; if locked,
    // remaining free categories absorb in documented stable category order.
    final sink = eligible.contains(5) ? 5 : eligible.last;
    result[sink] += amount - result.fold(0, (a, b) => a + b);
    return result;
  }
}
