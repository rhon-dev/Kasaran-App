import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:test/test.dart';

import '../allocation/budget_allocator_test.dart' show fixtureRules;
import 'support_gates_test.dart' as h;

void main() {
  test('overpayment is a warning, not exclusion or repaired money', () {
    final r = h.read(
      entries: [
        h.expense(
          amount: 100,
          payments: [
            Payment(
              id: 'paid',
              amountCents: 101,
              kind: PaymentKind.payment,
              paidOn: h.fixedDay,
            ),
          ],
        ),
      ],
    );
    expect(r.grossCents, 100);
    expect(r.paidCents, 101);
    expect(r.balanceCents, 0);
    expect(r.entries['entry']!.overpaymentCents, 1);
    expect(
      r.issues.map((i) => '${i.entityId}:${i.constraint}'),
      contains('entry:overpayment'),
    );
  });

  for (final dependency in FinancialDependency.values) {
    test(
      'unknown ${dependency.name} suppresses dependent nonzero figures despite valid allocation',
      () {
        final allocation = const RuleBasedAllocator().allocate(
          AllocationInput(
            totalBudgetCents: 5000000,
            regionCode: 'fixture',
            drivingGuestCount: 100,
            rulesetVersion: 'document-fixture',
          ),
          fixtureRules(),
        );
        final r = const FinancialEngine().read(
          FinancialInput(
            planId: 'plan',
            budgetCents: 5000000,
            drivingGuests: 100,
            guestCap: 120,
            entries: [
              h.expense(
                payments: [
                  Payment(
                    id: 'paid',
                    amountCents: 100,
                    kind: PaymentKind.payment,
                    paidOn: h.fixedDay,
                  ),
                ],
              ),
            ],
            pledges: [
              h.item('pledge', [h.receipt('receipt', 200)]),
            ],
            gifts: [
              Gift(
                id: 'gift',
                source: 'cash',
                amountCents: 300,
                receivedOn: h.fixedDay,
              ),
            ],
            unknownDependencies: {dependency},
          ),
          today: h.fixedDay,
          allocations: allocation,
        );
        final ledgerKnown = dependency != FinancialDependency.ledger;
        final supportKnown =
            ledgerKnown &&
            dependency != FinancialDependency.payments &&
            dependency != FinancialDependency.pledges;
        final allocationKnown =
            ledgerKnown && dependency != FinancialDependency.allocation;
        expect(r.grossCents, ledgerKnown ? 4000000 : null);
        expect(r.netCents, supportKnown ? 3999800 : null);
        expect(r.paidCents, supportKnown ? 100 : null);
        expect(r.balanceCents, supportKnown ? 3999900 : null);
        expect(r.supportByReceipt, supportKnown ? {'receipt': 200} : null);
        expect(
          r.giftsCents,
          dependency == FinancialDependency.gifts ? null : 300,
        );
        expect(r.varianceCents != null, allocationKnown);
        expect(r.bufferRemainingCents != null, allocationKnown);
        expect(r.bufferBreach, allocationKnown ? true : null);
        expect(
          r.netAfterGiftsCents,
          supportKnown && dependency != FinancialDependency.gifts
              ? 3999500
              : null,
        );
        expect(
          r.reconciliationCents,
          supportKnown && dependency != FinancialDependency.gifts
              ? -3999600
              : null,
        );
        expect(r.entries['entry']!.status != null, supportKnown);
      },
    );
  }

  test('valid direct pair counts paid and received once, not twice in net', () {
    final r = h.read(
      entries: [
        h.expense(
          payments: [
            Payment(
              id: 'paid',
              amountCents: 100,
              kind: PaymentKind.payment,
              paidOn: h.fixedDay,
              paidByPledgeId: 'pledge',
            ),
          ],
        ),
      ],
      pledges: [
        h.item('pledge', [h.receipt('receipt', 100, payment: 'paid')]),
      ],
    );
    expect(r.paidCents, 100);
    expect(r.netCents, 3999900);
    expect(r.supportByReceipt, {'receipt': 100});
    expect(r.pledges!['pledge']!.receivedCents, 100);
    expect(
      r.issues.where((i) => i.constraint == 'invalid_direct_pair'),
      isEmpty,
    );
  });

  for (final mismatch in [
    'pledge',
    'entry',
    'plan',
    'cash',
    'refund',
    'deleted-pledge',
  ]) {
    test('direct pair $mismatch mismatch excludes both monetary halves', () {
      final p = Pledge(
        id: 'pledge',
        planId: mismatch == 'plan' ? 'foreign' : 'plan',
        sponsor: 'Sponsor',
        role: 'family',
        type: mismatch == 'cash' ? PledgeType.cash : PledgeType.item,
        valueCents: 100,
        status: PledgeStatus.confirmed,
        linkedEntryId: mismatch == 'entry' ? 'other' : 'entry',
        deleted: mismatch == 'deleted-pledge',
        receipts: [h.receipt('receipt', 100, payment: 'paid')],
      );
      final r = h.read(
        entries: [
          h.expense(
            payments: [
              Payment(
                id: 'paid',
                amountCents: 100,
                kind: mismatch == 'refund'
                    ? PaymentKind.refund
                    : PaymentKind.payment,
                paidOn: h.fixedDay,
                paidByPledgeId: mismatch == 'pledge' ? 'other' : 'pledge',
              ),
            ],
          ),
        ],
        pledges: [p],
      );
      expect(r.paidCents, 0);
      expect(r.netCents, 4000000);
      expect(r.supportByReceipt, isEmpty);
      expect(
        r.issues.map((i) => i.constraint),
        contains('invalid_direct_pair'),
      );
    });
  }

  test(
    'deleted pledge excludes all receipts while unrelated gift stays live',
    () {
      final r = h.read(
        entries: [h.expense()],
        pledges: [
          h.item('deleted', [h.receipt('receipt', 100)], deleted: true),
        ],
        gifts: [
          Gift(
            id: 'gift',
            source: 'cash',
            amountCents: 300,
            receivedOn: h.fixedDay,
          ),
        ],
      );
      expect(r.netCents, 4000000);
      expect(r.expectedCents, 0);
      expect(r.exposureCents, 0);
      expect(r.supportByReceipt, isEmpty);
      expect(r.giftsCents, 300);
      expect(r.netAfterGiftsCents, 3999700);
    },
  );

  test('refund exceeding payment stays signed and reopens full balance', () {
    final r = h.read(
      entries: [
        h.expense(
          amount: 100,
          payments: [
            Payment(
              id: 'p',
              amountCents: 10,
              kind: PaymentKind.payment,
              paidOn: h.fixedDay,
            ),
            Payment(
              id: 'r',
              amountCents: 11,
              kind: PaymentKind.refund,
              paidOn: h.fixedDay,
            ),
          ],
        ),
      ],
    );
    expect(r.grossCents, 100);
    expect(r.paidCents, -1);
    expect(r.balanceCents, 101);
    expect(r.entries['entry']!.obligations!.single.allocatedCents, 0);
    expect(r.entries['entry']!.status, PaymentStatus.pending);
  });
}
