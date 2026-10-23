import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:test/test.dart';

final today = DateTime.utc(2026, 10, 22);
LedgerEntry entry({bool deleted = false, List<Payment> payments = const []}) =>
    LedgerEntry(
      id: 'entry',
      planId: 'plan',
      category: 'catering_venue',
      supplier: 'Venue',
      mode: PricingMode.flat,
      estimateCents: 100,
      deleted: deleted,
      payments: payments,
    );
Payment payment({int amount = 100}) => Payment(
  id: 'pay',
  amountCents: amount,
  kind: PaymentKind.payment,
  paidOn: today,
  paidByPledgeId: 'pledge',
);
Pledge pledge() => Pledge(
  id: 'pledge',
  planId: 'plan',
  sponsor: 'Sponsor',
  role: 'family',
  type: PledgeType.item,
  valueCents: 100,
  status: PledgeStatus.confirmed,
  linkedEntryId: 'entry',
  receipts: [
    Receipt(
      id: 'receipt',
      amountCents: 100,
      receivedOn: today,
      paymentId: 'pay',
    ),
  ],
);
FinancialReadResult read(
  List<LedgerEntry> entries, {
  List<Pledge> pledges = const [],
}) => const FinancialEngine().read(
  FinancialInput(
    planId: 'plan',
    budgetCents: 10000,
    drivingGuests: 1,
    guestCap: 10,
    entries: entries,
    pledges: pledges,
  ),
  today: today,
);

void main() {
  LedgerEntry aircon(List<FeeComponent> components) => LedgerEntry(
    id: 'aircon',
    planId: 'plan',
    category: 'catering_venue',
    supplier: 'Church',
    mode: PricingMode.flat,
    estimateCents: 0,
    entryType: 'church_aircon',
    components: components,
  );
  const first = FeeComponent(id: 'one', type: 'flat', amountCents: 100);
  const second = FeeComponent(id: 'two', type: 'flat', amountCents: 100);
  test('F3 church aircon rejects two live components without choosing one', () {
    final r = read([
      aircon([first, second]),
      entry(),
    ]);
    expect(
      r.issues.map((i) => i.constraint),
      contains('church_aircon_singleton'),
    );
    expect(r.entries.containsKey('aircon'), isFalse);
    expect(r.grossCents, 100);
  });
  test('F3 church aircon ignores deleted components for singleton count', () {
    final r = read([
      aircon([
        first,
        const FeeComponent(id: 'deleted', type: 'bad', deleted: true),
      ]),
    ]);
    expect(r.grossCents, 100);
    expect(r.entries['aircon']!.effectiveCents, 100);
    expect(
      r.issues.map((i) => i.constraint),
      isNot(contains('church_aircon_singleton')),
    );
  });
  test('F3 church aircon cannot have zero live components', () {
    final r = read([
      aircon([
        const FeeComponent(
          id: 'deleted',
          type: 'flat',
          amountCents: 100,
          deleted: true,
        ),
      ]),
    ]);
    expect(r.entries, isEmpty);
    expect(r.issues.map((i) => i.constraint), contains('missing_components'));
  });
  FinancialReadResult scalarRead({
    int budget = 10000,
    int guests = 1,
    int cap = 10,
    bool scaling = true,
  }) => const FinancialEngine().read(
    FinancialInput(
      planId: 'plan',
      budgetCents: budget,
      drivingGuests: guests,
      guestCap: cap,
      entries: [
        entry(),
        if (scaling)
          LedgerEntry(
            id: 'per-head',
            planId: 'plan',
            category: 'catering_venue',
            supplier: 'Meal',
            mode: PricingMode.perHead,
            rateCents: 100,
          ),
      ],
      gifts: [
        Gift(id: 'gift', source: 'cash', amountCents: 20, receivedOn: today),
      ],
    ),
    today: today,
  );
  test(
    'F2 unknown scaling preserves receipt and payment history but not applied support',
    () {
      final r = const FinancialEngine().read(
        FinancialInput(
          planId: 'plan',
          budgetCents: 10000,
          drivingGuests: -1,
          guestCap: 10,
          entries: [
            LedgerEntry(
              id: 'entry',
              planId: 'plan',
              category: 'catering_venue',
              supplier: 'Meals',
              mode: PricingMode.perHead,
              rateCents: 100,
              payments: [payment()],
            ),
          ],
          pledges: [pledge()],
        ),
        today: today,
      );
      expect(r.paidCents, 100);
      expect(r.entries['entry']!.netPaidCents, 100);
      expect(r.entries['entry']!.effectiveCents, isNull);
      expect(r.entries['entry']!.status, isNull);
      expect(r.expectedCents, 0);
      expect(r.exposureCents, 0);
      expect(r.orphanSupportCents, 0);
      expect(r.pledges!['pledge']!.receivedCents, 100);
      expect(r.pledges!['pledge']!.displayStatus, 'received');
      expect(r.pledges!['pledge']!.appliedCents, isNull);
      expect(r.supportByReceipt, isNull);
      expect(r.netCents, isNull);
    },
  );
  test('F2 actual-valued per-head sources do not depend on invalid count', () {
    final r = const FinancialEngine().read(
      FinancialInput(
        planId: 'plan',
        budgetCents: 10000,
        drivingGuests: -1,
        guestCap: 10,
        entries: [
          LedgerEntry(
            id: 'actual',
            planId: 'plan',
            category: 'catering_venue',
            supplier: 'Meals',
            mode: PricingMode.perHead,
            rateCents: 100,
            actualCents: 55,
            manuallyValued: true,
          ),
        ],
      ),
      today: today,
    );
    expect(r.grossCents, 55);
    expect(r.netCents, 55);
    expect(r.balanceCents, 55);
    expect(r.headroomCents, 9945);
    expect(r.perHeadCost, isNull);
    expect(r.overCap, isNull);
  });
  test('F2 negative driving count is unavailable not a throwing ratio', () {
    final r = scalarRead(guests: -1);
    expect(
      r.issues.map((i) => i.constraint),
      contains('negative_driving_guests'),
    );
    expect(r.grossCents, isNull);
    expect(r.netCents, isNull);
    expect(r.balanceCents, isNull);
    expect(r.categoryCents, isNull);
    expect(r.perHeadCost, isNull);
    expect(r.overCap, isNull);
    expect(r.entries['entry']!.effectiveCents, 100);
    expect(r.entries['entry']!.balanceCents, 100);
    expect(r.entries['per-head']!.effectiveCents, isNull);
    expect(r.entries['per-head']!.balanceCents, isNull);
    expect(r.paidCents, 0);
    expect(r.expectedCents, 0);
    expect(r.giftsCents, 20);
  });
  for (final budget in [0, -1]) {
    test(
      'F2 invalid budget $budget withholds only budget dependent outputs',
      () {
        final r = scalarRead(budget: budget, scaling: false);
        expect(
          r.issues.map((i) => i.constraint),
          contains('positive_budget_required'),
        );
        expect(r.headroomCents, isNull);
        expect(r.overBudget, isNull);
        expect(r.bufferRemainingCents, isNull);
        expect(r.varianceCents, isNull);
        expect(r.grossCents, 100);
        expect(r.netCents, 100);
        expect(r.balanceCents, 100);
        expect(r.overCap, isFalse);
        expect(r.perHeadCost!.numerator, BigInt.from(100));
      },
    );
  }
  test('F2 invalid cap preserves known flat and ratio readouts', () {
    final r = scalarRead(cap: -1, scaling: false);
    expect(r.issues.map((i) => i.constraint), contains('negative_guest_cap'));
    expect(r.overCap, isNull);
    expect(r.grossCents, 100);
    expect(r.headroomCents, 9900);
    expect(r.perHeadCost!.denominator, BigInt.one);
  });
  test(
    'F2 invalid count with flat sources preserves count independent totals',
    () {
      final r = scalarRead(guests: -1, scaling: false);
      expect(r.grossCents, 100);
      expect(r.netCents, 100);
      expect(r.balanceCents, 100);
      expect(r.headroomCents, 9900);
      expect(r.perHeadCost, isNull);
      expect(r.overCap, isNull);
    },
  );
  test('F2 zero guests and zero cap remain valid without a ratio', () {
    final r = scalarRead(guests: 0, cap: 0);
    expect(r.grossCents, 100);
    expect(r.entries['per-head']!.effectiveCents, 0);
    expect(r.overCap, isFalse);
    expect(r.perHeadCost, isNull);
    expect(
      r.issues.map((i) => i.constraint),
      isNot(contains('negative_driving_guests')),
    );
  });
  test('F1 invalid historical payment method cannot become orphan support', () {
    final r = read(
      [
        entry(
          deleted: true,
          payments: [
            Payment(
              id: 'pay',
              amountCents: 100,
              kind: PaymentKind.payment,
              paidOn: today,
              paidByPledgeId: 'pledge',
              method: 'invalid',
            ),
          ],
        ),
      ],
      pledges: [pledge()],
    );
    expect(r.orphanSupportCents, 0);
    expect(r.paidCents, 0);
    expect(
      r.issues.map((i) => i.constraint),
      containsAll(['payment_method', 'invalid_direct_pair']),
    );
  });
  test('F1 deleted historical payment is genuinely missing pair evidence', () {
    final r = read(
      [
        entry(
          deleted: true,
          payments: [
            Payment(
              id: 'pay',
              amountCents: 100,
              kind: PaymentKind.payment,
              paidOn: today,
              paidByPledgeId: 'pledge',
              deleted: true,
            ),
          ],
        ),
      ],
      pledges: [pledge()],
    );
    expect(r.orphanSupportCents, 0);
    expect(r.issues.map((i) => i.constraint), contains('invalid_direct_pair'));
  });
  test(
    'F1 preserved direct pair becomes orphan support after parent deletion',
    () {
      final live = read(
        [
          entry(payments: [payment()]),
        ],
        pledges: [pledge()],
      );
      expect(
        [
          live.grossCents,
          live.netCents,
          live.paidCents,
          live.orphanSupportCents,
        ],
        [100, 0, 100, 0],
      );
      final deleted = read(
        [
          entry(deleted: true, payments: [payment()]),
        ],
        pledges: [pledge()],
      );
      expect(
        [
          deleted.grossCents,
          deleted.netCents,
          deleted.paidCents,
          deleted.orphanSupportCents,
        ],
        [0, 0, 0, 100],
      );
      expect(deleted.entries, isEmpty);
      expect(deleted.supportByReceipt, isEmpty);
      expect(
        deleted.issues.map((i) => i.constraint),
        isNot(contains('invalid_direct_pair')),
      );
      expect(
        deleted.issues.map((i) => i.constraint),
        contains('orphan_linked_entry'),
      );
    },
  );
  for (final payments in <List<Payment>>[
    [],
    [payment(amount: 99)],
  ]) {
    test('F1 deleted parent rejects missing or mismatched pair $payments', () {
      final r = read(
        [entry(deleted: true, payments: payments)],
        pledges: [pledge()],
      );
      expect(r.orphanSupportCents, 0);
      expect(
        r.issues.map((i) => i.constraint),
        contains('invalid_direct_pair'),
      );
    });
  }
}
