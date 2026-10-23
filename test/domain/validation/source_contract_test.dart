import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:kasaran/domain/validation/financial_validation.dart';
import 'package:test/test.dart';

import '../calculations/support_gates_test.dart' as h;

void main() {
  test(
    'supplier and notes rune boundaries accept exact limit and reject overflow',
    () {
      LedgerEntry entry(String supplier, String notes) => LedgerEntry(
        id: 'entry',
        planId: 'plan',
        category: 'photo_video',
        supplier: supplier,
        mode: PricingMode.flat,
        estimateCents: 0,
        notes: notes,
      );
      final supplier = List.filled(200, '😀').join();
      final notes = List.filled(2000, '😀').join();
      expect(
        FinancialValidation.entry(entry(supplier, notes), 'plan'),
        isEmpty,
      );
      expect(
        FinancialValidation.entry(entry('$supplier😀', notes), 'plan'),
        contains('supplier_length'),
      );
      expect(
        FinancialValidation.entry(entry(supplier, '$notes😀'), 'plan'),
        contains('notes_length'),
      );
      expect(
        FinancialValidation.entry(entry('  ', notes), 'plan'),
        contains('supplier_length'),
      );
    },
  );

  test('sponsor role subrole and rune limits enforced independently', () {
    Pledge pledge({
      String? subrole,
      String role = 'family',
      String sponsor = 'Sponsor',
    }) => Pledge(
      id: 'p',
      planId: 'plan',
      sponsor: sponsor,
      role: role,
      secondarySubrole: subrole,
      type: PledgeType.cash,
      valueCents: 0,
      status: PledgeStatus.confirmed,
    );
    expect(
      FinancialValidation.pledge(
        pledge(sponsor: List.filled(200, '😀').join()),
        'plan',
      ),
      isEmpty,
    );
    expect(
      FinancialValidation.pledge(
        pledge(sponsor: List.filled(201, '😀').join()),
        'plan',
      ),
      contains('sponsor_length'),
    );
    expect(
      FinancialValidation.pledge(pledge(subrole: 'veil'), 'plan'),
      contains('secondary_subrole'),
    );
    expect(
      FinancialValidation.pledge(pledge(role: 'secondary_sponsor'), 'plan'),
      contains('secondary_subrole'),
    );
    for (final subrole in ['candle', 'veil', 'cord']) {
      expect(
        FinancialValidation.pledge(
          pledge(role: 'secondary_sponsor', subrole: subrole),
          'plan',
        ),
        isEmpty,
      );
    }
  });

  test(
    'deleted invalid children do not poison a valid parent or add money',
    () {
      final r = h.read(
        entries: [
          LedgerEntry(
            id: 'entry',
            planId: 'plan',
            category: 'photo_video',
            supplier: 'Supplier',
            mode: PricingMode.flat,
            estimateCents: 100,
            components: const [
              FeeComponent(id: '', type: 'bad', amountCents: -1, deleted: true),
            ],
            payments: [
              Payment(
                id: 'bad',
                amountCents: -1,
                kind: PaymentKind.payment,
                paidOn: h.fixedDay,
                deleted: true,
              ),
            ],
            schedule: [
              ScheduleItem(
                id: '',
                dueOn: h.fixedDay,
                amountCents: -1,
                deleted: true,
              ),
            ],
          ),
        ],
      );
      expect(r.grossCents, 100);
      expect(r.paidCents, 0);
      expect(r.entries['entry']!.obligations!.single.amountCents, 100);
      expect(r.issues.where((i) => i.entityId != 'plan'), isEmpty);
    },
  );

  test(
    'duplicate positive payments and receipts excluded without order winner',
    () {
      final payment = Payment(
        id: 'duplicate',
        amountCents: 100,
        kind: PaymentKind.payment,
        paidOn: h.fixedDay,
      );
      final r = h.read(
        entries: [
          h.expense(payments: [payment, payment]),
        ],
        pledges: [
          h.item('a', [h.receipt('same', 200), h.receipt('same', 300)]),
        ],
      );
      expect(r.paidCents, 0);
      expect(r.netCents, 4000000);
      expect(r.supportByReceipt, isEmpty);
      expect(
        r.issues.map((i) => i.constraint),
        containsAll(['duplicate_payment_id', 'duplicate_receipt_id']),
      );
    },
  );

  test(
    'invalid linked entry keeps support orphaned rather than moving to category',
    () {
      final r = h.read(
        entries: [
          LedgerEntry(
            id: 'entry',
            planId: 'plan',
            category: 'attire_styling',
            supplier: ' ',
            mode: PricingMode.flat,
            estimateCents: 4000000,
          ),
        ],
        pledges: [
          Pledge(
            id: 'p',
            planId: 'plan',
            sponsor: 'Sponsor',
            role: 'family',
            type: PledgeType.item,
            valueCents: 100,
            status: PledgeStatus.confirmed,
            linkedEntryId: 'entry',
            linkedCategory: 'photo_video',
            receipts: [h.receipt('receipt', 100)],
          ),
        ],
      );
      expect(r.grossCents, 0);
      expect(r.netCents, 0);
      expect(r.orphanSupportCents, 100);
      expect(r.expectedCents, 0);
      expect(
        r.issues.map((i) => i.constraint),
        contains('orphan_linked_entry'),
      );
    },
  );
}
