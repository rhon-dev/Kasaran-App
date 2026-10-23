import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:test/test.dart';

import 'fixture_support.dart';
import 'support_gates_test.dart' as h;

void main() {
  // design.md:189,512: unknown-dependent views suppressed, not zero.
  for (final dependency in FinancialDependency.values) {
    test(
      'unknown ${dependency.name} gates only dependent views with explicit issue',
      () {
        final r = h.read(entries: [h.expense()], unknown: {dependency});
        expect(
          r.issues.map((i) => i.constraint),
          contains('unknown_${dependency.name}'),
        );
        if (dependency == FinancialDependency.ledger) {
          expect(r.grossCents, isNull);
          expect(r.categoryCents, isNull);
          expect(r.netCents, isNull);
          expect(r.paidCents, isNull);
          expect(r.balanceCents, isNull);
          expect(r.perHeadCost, isNull);
          expect(r.headroomCents, isNull);
          expect(
            r.entries['entry']!.effectiveCents,
            4000000,
          ); // Independent known source remains inspectable.
        } else {
          expect(r.grossCents, 4000000);
        }
        if (dependency == FinancialDependency.pledges) {
          expect(r.netCents, isNull);
          expect(r.expectedCents, isNull);
          expect(r.exposureCents, isNull);
          expect(r.supportByReceipt, isNull);
          expect(r.pledges, isNull);
        }
        if (dependency == FinancialDependency.payments) {
          expect(r.paidCents, isNull);
          expect(r.balanceCents, isNull);
          expect(r.entries['entry']!.netPaidCents, isNull);
          expect(r.entries['entry']!.obligations, isNull);
          expect(r.entries['entry']!.status, isNull);
        }
        if (dependency == FinancialDependency.gifts) {
          expect(r.giftsCents, isNull);
          expect(r.netAfterGiftsCents, isNull);
          expect(r.reconciliationCents, isNull);
          expect(r.netCents, 4000000);
        }
        if (dependency == FinancialDependency.allocation) {
          expect(r.bufferRemainingCents, isNull);
          expect(r.varianceCents, isNull);
          expect(r.netCents, 4000000);
        }
      },
    );
  }
  test('missing ruleset leaves allocation unavailable rather than zero', () {
    final r = h.read(entries: [h.expense()]);
    expect(r.bufferRemainingCents, isNull);
    expect(r.varianceCents, isNull);
    expect(
      r.issues.map((i) => i.constraint),
      contains('allocation_unavailable'),
    );
  });
  // testing-plan.md:778–789; positive refunds may exceed paid: net stays signed.
  test(
    'overpayment preserved, allocated coverage capped, no phantom obligation',
    () {
      final p = Payment(
        id: 'p',
        amountCents: 12500000,
        kind: PaymentKind.payment,
        paidOn: h.fixedDay,
      );
      final r = h.read(
        entries: [
          h.expense(
            amount: 12000000,
            payments: [p],
            schedule: [
              ScheduleItem(
                id: 's',
                dueOn: DateTime(2026),
                amountCents: 12000000,
              ),
            ],
          ),
        ],
      );
      final e = r.entries['entry']!;
      expect(e.netPaidCents, 12500000);
      expect(e.balanceCents, 0);
      expect(e.overpaymentCents, 500000);
      expect(e.obligations!.single.allocatedCents, 12000000);
      expect(e.status, PaymentStatus.paid);
    },
  );
  test(
    'fixed calendar today and endpoint inclusive; residual undated last',
    () {
      final r = h.read(
        entries: [
          h.expense(
            amount: 1000,
            payments: [
              Payment(
                id: 'p',
                amountCents: 100,
                kind: PaymentKind.payment,
                paidOn: h.fixedDay,
              ),
            ],
            schedule: [
              ScheduleItem(
                id: 'endpoint',
                dueOn: DateTime(2026, 10, 9),
                amountCents: 200,
              ),
              ScheduleItem(
                id: 'today',
                dueOn: DateTime(2026, 10, 2),
                amountCents: 200,
              ),
              ScheduleItem(
                id: 'beyond',
                dueOn: DateTime(2026, 10, 10),
                amountCents: 200,
              ),
            ],
          ),
        ],
      );
      final e = r.entries['entry']!;
      expect(e.obligations!.map((s) => s.scheduleItemId), [
        'today',
        'endpoint',
        'beyond',
        null,
      ]);
      expect(e.obligations!.map((s) => s.status), [
        PaymentStatus.dueSoon,
        PaymentStatus.dueSoon,
        PaymentStatus.pending,
        PaymentStatus.pending,
      ]);
      expect(e.obligations!.first.partial, isTrue);
      expect(e.obligations!.last.amountCents, 400);
    },
  );
  test(
    'exact rational per-head half boundary never modifies gross or stored rate',
    () {
      final e = LedgerEntry(
        id: 'r',
        planId: 'plan',
        category: 'photo_video',
        supplier: 's',
        mode: PricingMode.flat,
        estimateCents: 1,
      );
      final r = const FinancialEngine().read(
        FinancialInput(
          planId: 'plan',
          budgetCents: 100,
          drivingGuests: 2,
          guestCap: 5,
          entries: [e],
        ),
        today: h.fixedDay,
      );
      expect(r.grossCents, 1);
      expect(r.perHeadCost!.numerator, BigInt.one);
      expect(r.perHeadCost!.denominator, BigInt.two);
      expect(halfUp(r.perHeadCost!), 1);
      expect(halfUp(ExactRatio(-1, 2)), -1);
      expect(halfUp(ExactRatio(1, 3)), 0);
      expect(halfUp(ExactRatio(2, 3)), 1);
    },
  );
  test(
    'zero guests suppress ratio, actual per-head stops scaling, no-rate zero stays exact',
    () {
      final input = FinancialInput(
        planId: 'plan',
        budgetCents: 1000,
        drivingGuests: 0,
        guestCap: 0,
        entries: [
          LedgerEntry(
            id: 'r',
            planId: 'plan',
            category: 'photo_video',
            supplier: 's',
            mode: PricingMode.perHead,
            rateCents: 7,
            actualCents: 123,
            manuallyValued: true,
          ),
          LedgerEntry(
            id: 'auto',
            planId: 'plan',
            category: 'photo_video',
            supplier: 's',
            mode: PricingMode.perHead,
            rateCents: 1,
          ),
        ],
      );
      final r = const FinancialEngine().read(input, today: h.fixedDay);
      expect(r.grossCents, 123);
      expect(r.perHeadCost, isNull);
      expect(r.overCap, isFalse);
    },
  );
  test(
    'negative net and net-after-gifts never floored; withdrawn receives historical support',
    () {
      final cash = Pledge(
        id: 'p',
        planId: 'plan',
        sponsor: 'p',
        role: 'family',
        type: PledgeType.cash,
        valueCents: 60000000,
        status: PledgeStatus.withdrawn,
        receipts: [h.receipt('r', 60000000)],
      );
      final r = h.read(
        entries: [h.expense(amount: 50000000)],
        pledges: [cash],
        gifts: [
          Gift(id: 'g', source: 'cash', amountCents: 1, receivedOn: h.fixedDay),
        ],
      );
      expect(r.netCents, -10000000);
      expect(r.netAfterGiftsCents, -10000001);
      expect(r.expectedCents, 0);
      expect(r.exposureCents, 0);
    },
  );
  test(
    'int64 source above binary-exact boundary multiplied without intermediate wrap',
    () {
      final r = const FinancialEngine().read(
        FinancialInput(
          planId: 'plan',
          budgetCents: 9223372036854775807,
          drivingGuests: 3,
          guestCap: 3,
          entries: [
            LedgerEntry(
              id: 'big',
              planId: 'plan',
              category: 'photo_video',
              supplier: 's',
              mode: PricingMode.perHead,
              rateCents: 3002399751580331,
            ),
          ],
        ),
        today: h.fixedDay,
      );
      expect(r.grossCents, 9007199254740993);
      expect(r.perHeadCost!.numerator, BigInt.parse('9007199254740993'));
    },
  );
  test(
    '1000 derived centavo lines aggregate without rounding back from display',
    () {
      final r = const FinancialEngine().read(
        FinancialInput(
          planId: 'plan',
          budgetCents: 10000,
          drivingGuests: 3,
          guestCap: 5,
          entries: List.generate(
            1000,
            (i) => LedgerEntry(
              id: '$i',
              planId: 'plan',
              category: 'photo_video',
              supplier: 's',
              mode: PricingMode.perHead,
              rateCents: 1,
            ),
          ),
        ),
        today: h.fixedDay,
      );
      expect(r.grossCents, 3000);
      expect(r.perHeadCost!.numerator, BigInt.from(3000));
    },
  );
}
