import 'package:test/test.dart';
import 'fixture_support.dart';

void main() {
  // testing-plan.md:276–296,310,355–364: whole fixture ledger,
  // guest-priced entries plus component-valued hidden fees, no toy sum.
  test('FIX-A ledger source derives documented gross/category totals', () {
    final f = loadFixture('A');
    final r = fixtureRead(f);
    expect(r.grossCents, 68680000);
    expect(r.categoryCents!.values, [
      39480000,
      9500000,
      7000000,
      8500000,
      4200000,
      0,
    ]);
    expect(r.entries['crew']!.effectiveCents, 630000);
    expect(r.issues, isEmpty);
  });
  // testing-plan.md:581–589,613–619; design.md:495. Attribution of B's
  // later-item payment does not bypass reservation/downpayment allocation.
  test('FIX-D chronological schedule, refund and derived deposit/balance', () {
    final r = fixtureRead(loadFixture('D'));
    final venue = r.entries['venue']!;
    expect(venue.effectiveCents, 12000000);
    expect(venue.netPaidCents, 6000000);
    expect(venue.balanceCents, 6000000);
    expect(venue.obligations!.map((s) => s.allocatedCents), [
      2000000,
      4000000,
      0,
    ]);
    expect(venue.obligations!.map((s) => s.status.name), [
      'paid',
      'paid',
      'overdue',
    ]);
    expect(venue.status!.name, 'overdue');
    expect(venue.partial, isTrue);
    expect(r.paidCents, 10000000);
    expect(r.balanceCents, 21000000);
    expect(r.entries['catering']!.obligations!.single.dueOn, isNull);
    expect(r.entries['catering']!.status!.name, 'pending');
  });
  for (final letter in ['A', 'B', 'C', 'D', 'E']) {
    final f = loadFixture(letter);
    final expected = rows(f['expected']);
    for (var i = 0; i < expected.length; i++) {
      final x = expected[i];
      // Oracles transcribed independently from testing-plan.md §3.1–3.5:
      // A 306–403; B 470–485; C 540–566; D 593–628; E 647–672.
      // TC-FIX-E1 here is the pure calculation subset, not UI/I acceptance.
      test(
        'TC-FIX-$letter${letter == 'E' ? 1 : i + 1} @ ${x['guests']} document oracle',
        () {
          final r = fixtureRead(f, guests: x['guests'] as int);
          expect(r.issues, isEmpty);
          expect(r.grossCents, x['gross_cents']);
          expect(r.netCents, x['net_cents']);
          expect(r.expectedCents, x['expected_cents']);
          expect(r.exposureCents, x['exposure_cents']);
          expect(r.bufferRemainingCents, x['buffer_cents']);
          expect(r.bufferBreach, (x['buffer_cents'] as int) < 0);
          expect(r.headroomCents, x['headroom_cents']);
          expect(r.overBudget, (x['headroom_cents'] as int) < 0);
          expect(r.overCap, x['over_cap']);
          expect(
            fixtureAllocation(f).categories.map((c) => c.effectiveCents),
            f['expected_allocation_cents'],
          );
          if (x.containsKey('per_head_display_centavos')) {
            expect(halfUp(r.perHeadCost!), x['per_head_display_centavos']);
          }
          if (x.containsKey('category_cents')) {
            expect(r.categoryCents!.values, x['category_cents']);
          }
          if (x.containsKey('marginal_cents')) {
            final before = fixtureRead(f);
            expect(
              (r.grossCents! - before.grossCents!) ~/
                  ((x['guests'] as int) - (f['guests'] as int)),
              x['marginal_cents'],
            );
          }
          if (letter == 'A') {
            expect(r.entries['crew']!.effectiveCents, 630000);
          }
          if (letter == 'B') {
            expect(r.entries['crew']!.effectiveCents, 1100000);
            expect(r.entries['oot']!.effectiveCents, 13750000);
          }
          if (letter == 'D') {
            expect(r.paidCents, x['paid_cents']);
            expect(r.balanceCents, x['balance_cents']);
            expect(r.giftsCents, x['gifts_cents']);
            expect(r.netAfterGiftsCents, x['net_after_gifts_cents']);
            expect(r.reconciliationCents, x['reconciliation_cents']);
            expect(
              r.entries['venue']!.obligations!.map((s) => s.allocatedCents),
              x['venue_allocated_cents'],
            );
            expect(
              r.entries['venue']!.obligations!.map((s) => s.status.name),
              x['venue_states'],
            );
            expect(r.pledges!['withdrawn']!.displayStatus, 'withdrawn');
            expect(r.pledges!['attire-support']!.displayStatus, 'received');
          }
          expect(
            r.supportByReceipt!.values.fold<int>(0, (a, b) => a + b),
            r.grossCents! - r.netCents!,
          );
        },
      );
    }
  }
  test('TC-PL-19 FIX-C D2 regression not pre-D2 or all promises', () {
    final r = fixtureRead(loadFixture('C'));
    expect(r.netCents, 33575000);
    expect(r.netCents, isNot(anyOf(25075000, 19075000)));
  });
  test(
    'TC-AE-05 fixed documented fixtures share identical baseline percentages',
    () {
      for (final letter in ['A', 'B', 'C', 'D', 'E']) {
        final r = fixtureAllocation(loadFixture(letter));
        expect(r.categories.map((c) => c.explanation.baselineBp), [
          4000,
          1500,
          1000,
          1000,
          500,
          2000,
        ]);
        expect(
          r.categories.map((c) => c.explanation.skewBp),
          everyElement(10000),
        );
        expect(r.expectedTotalCostCents, isNull);
      }
    },
  );
}
