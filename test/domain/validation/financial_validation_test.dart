import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:kasaran/domain/validation/financial_validation.dart';
import 'package:test/test.dart';
import '../calculations/support_gates_test.dart' as h;

void main() {
  // design.md:512 ADR-45: invalid rows preserved by caller, excluded from
  // dependent aggregates, independent eligible records remain visible.
  test(
    'negative actual and malformed mode do not contaminate independent gross',
    () {
      final bad = LedgerEntry(
        id: 'bad',
        planId: 'plan',
        category: 'attire_styling',
        supplier: 'bad',
        mode: PricingMode.flat,
        estimateCents: 500,
        actualCents: -1,
      );
      final malformed = LedgerEntry(
        id: 'mode',
        planId: 'plan',
        category: 'photo_video',
        supplier: 'bad',
        mode: PricingMode.perHead,
        estimateCents: 123,
        rateCents: 500,
      );
      final r = h.read(entries: [h.expense(), bad, malformed]);
      expect(r.grossCents, 4000000);
      expect(r.entries.keys, ['entry']);
      expect(r.issues.map((i) => i.entityId), containsAll(['bad', 'mode']));
      expect(
        FinancialValidation.entry(bad, 'plan'),
        contains('negative_actual'),
      );
      expect(bad.actualCents, -1); // gate never mutates/repairs source.
    },
  );
  test(
    'hidden fee missing pair/category/type excluded; actual cannot bypass gate',
    () {
      for (final type in [
        'crew_meals',
        'oot_fees',
        'church_aircon',
        'corkage',
        'overtime',
        'venue_power',
      ]) {
        final bad = LedgerEntry(
          id: type,
          planId: 'plan',
          category: 'buffer',
          supplier: 's',
          entryType: type,
          mode: PricingMode.flat,
          estimateCents: 0,
          actualCents: 100,
          components: const [
            FeeComponent(id: 'broken', type: 'supplier', quantity: 3),
          ],
        );
        final r = h.read(entries: [h.expense(), bad]);
        expect(r.grossCents, 4000000);
        expect(r.issues, isNotEmpty);
      }
    },
  );
  test(
    'invalid payment or same-entry attribution excluded not converted into payment',
    () {
      final payments = [
        Payment(
          id: 'negative',
          amountCents: -5,
          kind: PaymentKind.payment,
          paidOn: h.fixedDay,
        ),
        Payment(
          id: 'zero',
          amountCents: 0,
          kind: PaymentKind.refund,
          paidOn: h.fixedDay,
        ),
        Payment(
          id: 'foreign',
          amountCents: 50,
          kind: PaymentKind.payment,
          paidOn: h.fixedDay,
          scheduleItemId: 'foreign',
        ),
        Payment(
          id: 'method',
          amountCents: 50,
          kind: PaymentKind.payment,
          paidOn: h.fixedDay,
          method: 'card',
        ),
      ];
      final r = h.read(entries: [h.expense(payments: payments)]);
      expect(r.paidCents, 0);
      expect(r.balanceCents, 4000000);
      expect(r.issues.where((i) => i.entityId != 'plan').length, 4);
    },
  );
  test('invalid direct pair excludes BOTH payment and receipt', () {
    for (final amount in [3999999, 4000001]) {
      final r = h.read(
        entries: [
          h.expense(
            payments: [
              Payment(
                id: 'payment',
                amountCents: 4000000,
                kind: PaymentKind.payment,
                paidOn: h.fixedDay,
                paidByPledgeId: 'pledge',
              ),
            ],
          ),
        ],
        pledges: [
          h.item('pledge', [
            h.receipt('receipt', amount, payment: 'payment'),
          ], value: 4000000),
        ],
      );
      expect(r.netCents, 4000000);
      expect(r.paidCents, 0);
      expect(r.pledges!['pledge']!.receivedCents, 0);
      expect(
        r.issues.map((i) => i.constraint),
        contains('invalid_direct_pair'),
      );
    }
  });
  test('missing direct pair either half is excluded; no fabricated pair', () {
    final payment = Payment(
      id: 'payment',
      amountCents: 4000000,
      kind: PaymentKind.payment,
      paidOn: h.fixedDay,
      paidByPledgeId: 'pledge',
    );
    final r = h.read(
      entries: [
        h.expense(payments: [payment]),
      ],
      pledges: [h.item('pledge', [])],
    );
    expect(r.paidCents, 0);
    expect(r.netCents, 4000000);
    expect(r.issues, isNotEmpty);
    final missing = h.read(
      entries: [h.expense()],
      pledges: [
        h.item('pledge', [h.receipt('receipt', 4000000, payment: 'payment')]),
      ],
    );
    expect(missing.netCents, 4000000);
    expect(missing.issues, isNotEmpty);
  });
  test(
    'duplicate receipt payment reference rejects ambiguous pairing on both sides',
    () {
      final r = h.read(
        entries: [
          h.expense(
            payments: [
              Payment(
                id: 'p',
                amountCents: 4000000,
                kind: PaymentKind.payment,
                paidOn: h.fixedDay,
                paidByPledgeId: 'a',
              ),
            ],
          ),
        ],
        pledges: [
          h.item('a', [
            h.receipt('r1', 4000000, payment: 'p'),
            h.receipt('r2', 4000000, payment: 'p'),
          ]),
        ],
      );
      expect(r.netCents, 4000000);
      expect(r.paidCents, 0);
      expect(r.issues, isNotEmpty);
    },
  );
  test(
    'negative receipt/gift and invalid sponsor excluded, zero pledge not received',
    () {
      final r = h.read(
        entries: [h.expense()],
        pledges: [
          h.item('a', [h.receipt('bad', -1)], entry: null),
          Pledge(
            id: 'bad-role',
            planId: 'plan',
            sponsor: 'x',
            role: 'secondary_sponsor',
            type: PledgeType.cash,
            valueCents: 100,
            status: PledgeStatus.confirmed,
            receipts: [h.receipt('untrusted', 100)],
          ),
          h.item('zero', [], value: 0, entry: null),
        ],
        gifts: [
          Gift(
            id: 'g',
            source: 'card',
            amountCents: 10,
            receivedOn: h.fixedDay,
          ),
          Gift(
            id: 'negative',
            source: 'cash',
            amountCents: -100,
            receivedOn: h.fixedDay,
          ),
        ],
      );
      expect(r.netCents, 4000000);
      expect(r.giftsCents, 0);
      expect(r.pledges!['zero']!.displayStatus, 'confirmed');
      expect(r.pledges, isNot(contains('bad-role')));
      expect(r.issues, isNotEmpty);
    },
  );
  test(
    'schedule over effective is flagged without changing ledger or payment history',
    () {
      final r = h.read(
        entries: [
          h.expense(
            schedule: [
              ScheduleItem(id: 's', dueOn: h.fixedDay, amountCents: 4000001),
            ],
          ),
        ],
      );
      expect(r.grossCents, 4000000);
      expect(r.entries['entry']!.obligations, isNull);
      expect(r.entries['entry']!.status, isNull);
      expect(
        r.issues.map((i) => i.constraint),
        contains('schedule_over_total'),
      );
    },
  );
  test(
    'duplicate source IDs never silently inflate sums or choose order-dependent values',
    () {
      final r = h.read(entries: [h.expense(), h.expense()]);
      expect(r.grossCents, 0);
      expect(r.issues, isNotEmpty);
    },
  );
}
