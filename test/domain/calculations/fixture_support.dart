import 'dart:convert';
import 'dart:io';

import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:kasaran/domain/calculations/financial_engine.dart';

Map<String, dynamic> loadFixture(String letter) =>
    jsonDecode(File('test/fixtures/FIX-$letter.json').readAsStringSync())
        as Map<String, dynamic>;
List<Map<String, dynamic>> rows(dynamic value) =>
    ((value as List<dynamic>?) ?? []).cast<Map<String, dynamic>>();
FinancialInput fixtureInput(Map<String, dynamic> f, {int? guests}) =>
    FinancialInput(
      planId: f['plan_id'] as String,
      budgetCents: f['budget_cents'] as int,
      drivingGuests: guests ?? f['guests'] as int,
      guestCap: f['guest_cap'] as int,
      entries: rows(f['entries'])
          .map(
            (e) => LedgerEntry(
              id: e['id'] as String,
              planId: e['plan_id'] as String,
              category: e['category'] as String,
              supplier: e['supplier'] as String,
              entryType: e['type'] as String,
              mode: PricingMode.values.byName(
                e['pricing_mode'] == 'per_head' ? 'perHead' : 'flat',
              ),
              estimateCents: e['estimate_cents'] as int?,
              rateCents: e['rate_cents'] as int?,
              actualCents: e['actual_cents'] as int?,
              manuallyValued: e['manually_valued'] as bool,
              components: rows(e['components'])
                  .map(
                    (c) => FeeComponent(
                      id: c['id'] as String,
                      type: c['type'] as String,
                      quantity: c['quantity'] as int?,
                      unitRateCents: c['unit_rate_cents'] as int?,
                      amountCents: c['amount_cents'] as int?,
                    ),
                  )
                  .toList(),
              schedule: rows(e['schedule'])
                  .map(
                    (s) => ScheduleItem(
                      id: s['id'] as String,
                      dueOn: DateTime.parse(s['due_on'] as String),
                      amountCents: s['amount_cents'] as int,
                      sortOrder: s['sort_order'] as int,
                    ),
                  )
                  .toList(),
              payments: rows(e['payments'])
                  .map(
                    (p) => Payment(
                      id: p['id'] as String,
                      amountCents: p['amount_cents'] as int,
                      kind: PaymentKind.values.byName(p['kind'] as String),
                      paidOn: DateTime.parse(p['paid_on'] as String),
                      scheduleItemId: p['schedule_item_id'] as String?,
                      paidByPledgeId: p['paid_by_pledge_id'] as String?,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      pledges: rows(f['pledges'])
          .map(
            (p) => Pledge(
              id: p['id'] as String,
              planId: p['plan_id'] as String,
              sponsor: p['sponsor'] as String,
              role: p['role'] as String,
              type: PledgeType.values.byName(p['type'] as String),
              valueCents: p['value_cents'] as int,
              status: PledgeStatus.values.byName(p['status'] as String),
              linkedEntryId: p['linked_entry_id'] as String?,
              receipts: rows(p['receipts'])
                  .map(
                    (r) => Receipt(
                      id: r['id'] as String,
                      amountCents: r['amount_cents'] as int,
                      receivedOn: DateTime.parse(r['received_on'] as String),
                      paymentId: r['payment_id'] as String?,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      gifts: rows(f['gifts'])
          .map(
            (g) => Gift(
              id: g['id'] as String,
              source: g['source'] as String,
              amountCents: g['amount_cents'] as int,
              receivedOn: DateTime.parse(g['received_on'] as String),
            ),
          )
          .toList(),
    );
AllocationResult fixtureAllocation(Map<String, dynamic> f) {
  final r = f['ruleset'] as Map<String, dynamic>;
  return const RuleBasedAllocator().allocate(
    AllocationInput(
      totalBudgetCents: f['budget_cents'] as int,
      regionCode: r['region_code'] as String,
      drivingGuestCount: f['guests'] as int,
      rulesetVersion: r['version'] as String,
    ),
    Ruleset(
      version: r['version'] as String,
      baselines: (r['baselines_bp'] as List<dynamic>).cast<int>(),
      regions: {
        r['region_code'] as String: RegionRule(
          costIndexBp: r['cost_index_bp'] as int,
        ),
      },
    ),
  );
}

FinancialReadResult fixtureRead(Map<String, dynamic> f, {int? guests}) =>
    const FinancialEngine().read(
      fixtureInput(f, guests: guests),
      today: DateTime.parse(f['today'] as String),
      allocations: fixtureAllocation(f),
    );
// Test-only display boundary: preserves exact domain rational until assertion.
int halfUp(ExactRatio ratio) {
  final a = ratio.numerator.abs();
  final d = ratio.denominator;
  final rounded = (a * BigInt.two + d) ~/ (d * BigInt.two);
  return (ratio.numerator.isNegative ? -rounded : rounded).toInt();
}
