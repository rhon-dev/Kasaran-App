import 'package:kasaran/domain/calculations/financial_engine.dart';
import 'package:test/test.dart';

final fixedDay = DateTime(2026, 10, 2);
LedgerEntry expense({
  String id = 'entry',
  int amount = 4000000,
  bool deleted = false,
  List<Payment> payments = const [],
  List<ScheduleItem> schedule = const [],
}) => LedgerEntry(
  id: id,
  planId: 'plan',
  category: 'attire_styling',
  supplier: 'Supplier',
  mode: PricingMode.flat,
  estimateCents: amount,
  deleted: deleted,
  payments: payments,
  schedule: schedule,
);
Pledge item(
  String id,
  List<Receipt> receipts, {
  int value = 3000000,
  String? entry = 'entry',
  PledgeStatus status = PledgeStatus.confirmed,
  bool deleted = false,
}) => Pledge(
  id: id,
  planId: 'plan',
  sponsor: id,
  role: 'family',
  type: PledgeType.item,
  valueCents: value,
  status: status,
  linkedEntryId: entry,
  receipts: receipts,
  deleted: deleted,
);
Receipt receipt(String id, int amount, {String? payment, int day = 1}) =>
    Receipt(
      id: id,
      amountCents: amount,
      receivedOn: DateTime(2026, 9, day),
      paymentId: payment,
    );
FinancialReadResult read({
  List<LedgerEntry> entries = const [],
  List<Pledge> pledges = const [],
  List<Gift> gifts = const [],
  Set<FinancialDependency> unknown = const {},
}) => const FinancialEngine().read(
  FinancialInput(
    planId: 'plan',
    budgetCents: 5000000,
    drivingGuests: 100,
    guestCap: 120,
    entries: entries,
    pledges: pledges,
    gifts: gifts,
    unknownDependencies: unknown,
  ),
  today: fixedDay,
);
void main() {
  // design.md:594; testing-plan.md:913,917 (TC-PL-46/50).
  test(
    'shared entry cap consumed by receipt date then ID, never per pledge',
    () {
      final a = item('a', [receipt('z', 3000000, day: 2)]);
      final b = item('b', [receipt('b', 1000000), receipt('a', 1000000)]);
      final r = read(entries: [expense()], pledges: [a, b]);
      expect(r.netCents, 0);
      expect(r.supportByReceipt, {'a': 1000000, 'b': 1000000, 'z': 2000000});
      expect(r.pledges!['a']!.appliedCents, 2000000);
      expect(r.pledges!['a']!.receivedCents, 3000000);
      expect(r.pledges!['a']!.displayStatus, 'received');
      expect(r.pledges!['b']!.remainingCents, 1000000);
      final reverse = read(entries: [expense()], pledges: [b, a]);
      expect(reverse.supportByReceipt, r.supportByReceipt);
    },
  );
  test(
    'deleted linked entry flags orphan and excludes support and remaining',
    () {
      final r = read(
        entries: [expense(deleted: true)],
        pledges: [
          item('a', [receipt('r', 1000000)]),
        ],
      );
      expect(r.grossCents, 0);
      expect(r.netCents, 0);
      expect(r.expectedCents, 0);
      expect(r.exposureCents, 0);
      expect(r.orphanSupportCents, 1000000);
      expect(
        r.issues.map((i) => i.constraint),
        contains('orphan_linked_entry'),
      );
    },
  );
}
