import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:kasaran/domain/calculations/financial_models.dart';
import 'package:kasaran/domain/validation/financial_validation.dart';

export 'financial_models.dart';

/// Pure, deterministic read. Callers retain all raw invalid/unknown sources;
/// issues identify exclusions, never automatic repair writes.
class FinancialEngine {
  const FinancialEngine();
  FinancialReadResult read(
    FinancialInput input, {
    required DateTime today,
    AllocationResult? allocations,
    int reminderWindowDays = 7,
  }) {
    final issues = <FinancialIssue>[];
    bool valid(String id, List<String> errors) {
      for (final error in errors) {
        issues.add(FinancialIssue(id, error));
      }
      return errors.isEmpty;
    }

    valid(input.planId, FinancialValidation.plan(input));
    final budgetValid = input.budgetCents > 0;
    final guestsValid = input.drivingGuests >= 0;
    final capValid = input.guestCap >= 0;
    final entryIds = _counts(input.entries.map((e) => e.id));
    final pledgeIds = _counts(input.pledges.map((p) => p.id));
    final sources = <String, LedgerEntry>{};
    final effectiveAmounts = <String, int?>{};
    for (final e in input.entries.where((e) => !e.deleted)) {
      final errors = FinancialValidation.entry(e, input.planId);
      if (entryIds[e.id] != 1) {
        errors.add('duplicate_entry_id');
      }
      if (!valid(e.id, errors)) {
        continue;
      }
      final components = e.components.where((c) => !c.deleted);
      final effective =
          e.actualCents ??
          (e.entryType != 'standard'
              ? components.fold<int>(
                  0,
                  (a, c) =>
                      a +
                      (c.quantity != null && c.unitRateCents != null
                          ? c.quantity! * c.unitRateCents!
                          : c.amountCents!),
                )
              : e.mode == PricingMode.perHead
              ? guestsValid
                    ? e.rateCents! * input.drivingGuests
                    : null
              : e.estimateCents!);
      sources[e.id] = e;
      effectiveAmounts[e.id] = effective;
    }
    final livePledges = <String, Pledge>{};
    for (final p in input.pledges.where((p) => !p.deleted)) {
      final errors = FinancialValidation.pledge(p, input.planId);
      if (pledgeIds[p.id] != 1) {
        errors.add('duplicate_pledge_id');
      }
      if (valid(p.id, errors)) {
        livePledges[p.id] = p;
      }
    }
    final paymentRecords = [
      // Tombstoned parents retain valid pair evidence for orphan reconciliation,
      // but never enter live entry/payment aggregates.
      for (final e in input.entries.where(
        (e) =>
            sources.containsKey(e.id) ||
            (e.deleted &&
                entryIds[e.id] == 1 &&
                FinancialValidation.entry(e, input.planId).isEmpty),
      ))
        for (final p in e.payments.where((p) => !p.deleted))
          (entry: e, payment: p),
    ];
    final receiptRecords = [
      for (final p in livePledges.values)
        for (final r in p.receipts.where((r) => !r.deleted))
          (pledge: p, receipt: r),
    ];
    final paymentIds = _counts(paymentRecords.map((p) => p.payment.id));
    final receiptIds = _counts(receiptRecords.map((r) => r.receipt.id));
    final paymentRefs = _counts(
      receiptRecords
          .where((r) => r.receipt.paymentId != null)
          .map((r) => r.receipt.paymentId!),
    );
    final validPayments = <String>{}, validReceipts = <String>{};
    for (final record in paymentRecords) {
      final e = record.entry, p = record.payment;
      final errors = FinancialValidation.payment(
        p,
        e.schedule.map((s) => s.id).toSet(),
      );
      if (paymentIds[p.id] != 1) {
        errors.add('duplicate_payment_id');
      }
      if (valid(p.id, errors)) {
        validPayments.add(p.id);
      }
    }
    for (final record in receiptRecords) {
      final r = record.receipt;
      final errors = FinancialValidation.receipt(r);
      if (receiptIds[r.id] != 1) {
        errors.add('duplicate_receipt_id');
      }
      if (valid(r.id, errors)) {
        validReceipts.add(r.id);
      }
    }
    // Resolve direct-pair validity before either side enters any financial sum.
    final invalidPayments = <String>{}, invalidReceipts = <String>{};
    for (final record in paymentRecords) {
      final payment = record.payment;
      final matches = receiptRecords
          .where((r) => r.receipt.paymentId == payment.id)
          .toList();
      if (payment.paidByPledgeId == null && matches.isEmpty) {
        continue;
      }
      final matched = matches.length == 1 ? matches.single : null;
      final good =
          matched != null &&
          paymentRefs[payment.id] == 1 &&
          validPayments.contains(payment.id) &&
          validReceipts.contains(matched.receipt.id) &&
          matched.pledge.type == PledgeType.item &&
          matched.pledge.id == payment.paidByPledgeId &&
          matched.pledge.linkedEntryId == record.entry.id &&
          payment.kind == PaymentKind.payment &&
          payment.amountCents == matched.receipt.amountCents;
      if (!good) {
        invalidPayments.add(payment.id);
        invalidReceipts.addAll(matches.map((r) => r.receipt.id));
        issues.add(FinancialIssue(payment.id, 'invalid_direct_pair'));
      }
    }
    for (final record in receiptRecords) {
      final r = record.receipt;
      if (r.paymentId != null &&
          !paymentRecords.any((p) => p.payment.id == r.paymentId)) {
        invalidReceipts.add(r.id);
        issues.add(FinancialIssue(r.id, 'invalid_direct_pair'));
      }
    }
    validPayments.removeAll(invalidPayments);
    validReceipts.removeAll(invalidReceipts);
    final entries = <String, EntryRead>{};
    final categories = {for (final c in categoryCodes) c: 0};
    for (final e in sources.values) {
      final effective = effectiveAmounts[e.id];
      entries[e.id] = _entryRead(
        e,
        effective,
        today,
        reminderWindowDays,
        validPayments,
        issues,
      );
      if (effective != null) {
        categories[e.category] = categories[e.category]! + effective;
      }
    }
    final gross = categories.values.fold<int>(0, (a, b) => a + b);
    final support = <String, int>{};
    final pledgeReads = <String, PledgeRead>{};
    var expected = 0, exposure = 0, orphan = 0;
    final capUsed = <String, int>{};
    final eligible = <({Pledge pledge, Receipt receipt})>[];
    final orphanIds = <String>{};
    for (final p in livePledges.values) {
      if (p.type == PledgeType.item &&
          p.linkedEntryId != null &&
          !entries.containsKey(p.linkedEntryId)) {
        orphanIds.add(p.id);
        orphan += p.receipts
            .where((r) => !r.deleted && validReceipts.contains(r.id))
            .fold<int>(0, (a, r) => a + r.amountCents);
        issues.add(FinancialIssue(p.id, 'orphan_linked_entry'));
        continue;
      }
      for (final r in p.receipts.where(
        (r) => !r.deleted && validReceipts.contains(r.id),
      )) {
        eligible.add((pledge: p, receipt: r));
      }
    }
    eligible.sort((a, b) {
      final dates = _day(
        a.receipt.receivedOn,
      ).compareTo(_day(b.receipt.receivedOn));
      return dates != 0 ? dates : a.receipt.id.compareTo(b.receipt.id);
    });
    for (final pair in eligible) {
      final p = pair.pledge, r = pair.receipt;
      var amount = r.amountCents;
      if (p.type == PledgeType.item && p.linkedEntryId != null) {
        final id = p.linkedEntryId!;
        final effective = entries[id]!.effectiveCents;
        if (effective == null) {
          continue;
        }
        final room = _positive(effective - (capUsed[id] ?? 0));
        amount = amount < room ? amount : room;
        capUsed[id] = (capUsed[id] ?? 0) + amount;
      }
      support[r.id] = amount;
    }
    for (final p in livePledges.values.where(
      (p) => !orphanIds.contains(p.id),
    )) {
      final receipts = p.receipts
          .where((r) => !r.deleted && validReceipts.contains(r.id))
          .toList();
      final received = receipts.fold<int>(0, (a, r) => a + r.amountCents);
      final remaining = _positive(p.valueCents - received);
      final applied = receipts.fold<int>(0, (a, r) => a + (support[r.id] ?? 0));
      if (p.status != PledgeStatus.withdrawn) {
        expected += remaining;
      }
      if (p.status == PledgeStatus.confirmed) {
        exposure += remaining;
      }
      pledgeReads[p.id] = PledgeRead(
        receivedCents: received,
        remainingCents: remaining,
        appliedCents:
            p.type == PledgeType.item &&
                entries.containsKey(p.linkedEntryId) &&
                entries[p.linkedEntryId]!.effectiveCents == null
            ? null
            : applied,
        displayStatus: p.status == PledgeStatus.withdrawn
            ? 'withdrawn'
            : receipts.isNotEmpty && received >= p.valueCents
            ? 'received'
            : p.status.name,
      );
    }
    final net = gross - support.values.fold<int>(0, (a, b) => a + b);
    final giftIds = _counts(input.gifts.map((g) => g.id));
    final liveGifts = input.gifts.where((g) => !g.deleted).where((g) {
      final errors = FinancialValidation.gift(g);
      if (giftIds[g.id] != 1) {
        errors.add('duplicate_gift_id');
      }
      return valid(g.id, errors);
    }).toList();
    final gifts = liveGifts.fold<int>(0, (a, g) => a + g.amountCents);
    final balance = entries.values.fold<int>(
      0,
      (a, e) => a + (e.balanceCents ?? 0),
    );
    final variance = allocations == null || !allocations.available
        ? null
        : {
            for (final a in allocations.categories)
              a.categoryCode: categories[a.categoryCode]! - a.effectiveCents,
          };
    final buffer = variance == null
        ? null
        : allocations!.categories.last.effectiveCents -
              variance.entries
                  .where((v) => v.key != 'buffer')
                  .fold<int>(0, (a, v) => a + _positive(v.value));
    final unknown = input.unknownDependencies;
    for (final dependency in unknown) {
      issues.add(FinancialIssue(input.planId, 'unknown_${dependency.name}'));
    }
    final ledgerSourceKnown = !unknown.contains(FinancialDependency.ledger);
    final ledgerKnown =
        ledgerSourceKnown && effectiveAmounts.values.every((v) => v != null);
    final pledgesKnown =
        ledgerSourceKnown &&
        !unknown.contains(FinancialDependency.pledges) &&
        !unknown.contains(FinancialDependency.payments);
    final paymentsKnown =
        ledgerSourceKnown &&
        !unknown.contains(FinancialDependency.payments) &&
        !unknown.contains(FinancialDependency.pledges);
    final supportKnown =
        pledgesKnown &&
        !livePledges.values.any(
          (p) =>
              p.type == PledgeType.item &&
              entries.containsKey(p.linkedEntryId) &&
              entries[p.linkedEntryId]!.effectiveCents == null,
        );
    final giftsKnown = !unknown.contains(FinancialDependency.gifts);
    final allocationKnown =
        ledgerKnown &&
        budgetValid &&
        !unknown.contains(FinancialDependency.allocation) &&
        variance != null;
    if (allocations == null || !allocations.available) {
      issues.add(FinancialIssue(input.planId, 'allocation_unavailable'));
    }
    if (allocations != null) {
      for (final issue in allocations.issues) {
        issues.add(FinancialIssue(input.planId, issue));
      }
    }
    final visibleEntries = paymentsKnown
        ? entries
        : {
            for (final e in entries.entries)
              e.key: EntryRead(
                effectiveCents: e.value.effectiveCents,
                netPaidCents: null,
                balanceCents: null,
                overpaymentCents: null,
                obligations: null,
                status: null,
                partial: null,
              ),
          };
    issues.sort((a, b) {
      final id = a.entityId.compareTo(b.entityId);
      return id != 0 ? id : a.constraint.compareTo(b.constraint);
    });
    return FinancialReadResult(
      grossCents: ledgerKnown ? gross : null,
      netCents: ledgerKnown && supportKnown ? net : null,
      categoryCents: ledgerKnown ? categories : null,
      entries: visibleEntries,
      issues: issues,
      orphanSupportCents: pledgesKnown ? orphan : null,
      paidCents: paymentsKnown
          ? entries.values.fold<int>(0, (a, e) => a + e.netPaidCents!)
          : null,
      balanceCents: ledgerKnown && paymentsKnown ? balance : null,
      expectedCents: pledgesKnown ? expected : null,
      exposureCents: pledgesKnown ? exposure : null,
      giftsCents: giftsKnown ? gifts : null,
      netAfterGiftsCents:
          !ledgerKnown || !supportKnown || !giftsKnown || liveGifts.isEmpty
          ? null
          : net - gifts,
      reconciliationCents: ledgerKnown && giftsKnown && paymentsKnown
          ? gifts - balance
          : null,
      bufferRemainingCents: allocationKnown ? buffer : null,
      bufferBreach: allocationKnown ? buffer! < 0 : null,
      headroomCents: ledgerKnown && budgetValid
          ? input.budgetCents - gross
          : null,
      overBudget: ledgerKnown && budgetValid ? gross > input.budgetCents : null,
      overCap: guestsValid && capValid
          ? input.drivingGuests > input.guestCap
          : null,
      perHeadCost: !ledgerKnown || input.drivingGuests <= 0
          ? null
          : ExactRatio(gross, input.drivingGuests),
      supportByReceipt: supportKnown ? support : null,
      pledges: pledgesKnown ? pledgeReads : null,
      varianceCents: allocationKnown ? variance : null,
    );
  }

  EntryRead _entryRead(
    LedgerEntry e,
    int? effective,
    DateTime today,
    int window,
    Set<String> validPayments,
    List<FinancialIssue> issues,
  ) {
    final netPaid = e.payments
        .where((p) => !p.deleted && validPayments.contains(p.id))
        .fold<int>(
          0,
          (a, p) =>
              a +
              (p.kind == PaymentKind.refund ? -p.amountCents : p.amountCents),
        );
    if (effective == null) {
      return EntryRead(
        effectiveCents: null,
        netPaidCents: netPaid,
        balanceCents: null,
        overpaymentCents: null,
        obligations: null,
        status: null,
        partial: null,
      );
    }
    final balance = _positive(effective - netPaid);
    if (netPaid > effective) {
      issues.add(FinancialIssue(e.id, 'overpayment'));
    }
    final schedule = e.schedule.where((s) => !s.deleted).toList()
      ..sort((a, b) {
        final dates = _day(a.dueOn).compareTo(_day(b.dueOn));
        if (dates != 0) {
          return dates;
        }
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });
    final ids = <String>{};
    final invalidSchedule = schedule.any(
      (s) => s.id.isEmpty || !ids.add(s.id) || s.amountCents <= 0,
    );
    final tooMuch =
        schedule.fold<int>(0, (a, s) => a + s.amountCents) > effective;
    if (invalidSchedule || tooMuch) {
      issues.add(
        FinancialIssue(
          e.id,
          tooMuch ? 'schedule_over_total' : 'invalid_schedule',
        ),
      );
      return EntryRead(
        effectiveCents: effective,
        netPaidCents: netPaid,
        balanceCents: balance,
        overpaymentCents: _positive(netPaid - effective),
        obligations: null,
        status: null,
        partial: netPaid > 0 && balance > 0,
      );
    }
    final obligations = <ObligationRead>[];
    var room = _positive(netPaid);
    void add(String? id, DateTime? date, int amount) {
      final paid = room < amount ? room : amount;
      room -= paid;
      final remaining = amount - paid;
      final partial = paid > 0 && remaining > 0;
      final status = remaining == 0
          ? PaymentStatus.paid
          : date != null && _day(date).isBefore(_day(today))
          ? PaymentStatus.overdue
          : date != null &&
                !_day(date).isAfter(_day(today).add(Duration(days: window)))
          ? PaymentStatus.dueSoon
          : partial
          ? PaymentStatus.partiallyPaid
          : PaymentStatus.pending;
      obligations.add(
        ObligationRead(
          scheduleItemId: id,
          dueOn: date,
          amountCents: amount,
          allocatedCents: paid,
          remainingCents: remaining,
          status: status,
          partial: partial,
        ),
      );
    }

    for (final s in schedule) {
      add(s.id, s.dueOn, s.amountCents);
    }
    final residual =
        effective - schedule.fold<int>(0, (a, s) => a + s.amountCents);
    if (schedule.isEmpty || residual > 0) {
      add(null, null, residual);
    }
    final status = balance == 0
        ? PaymentStatus.paid
        : obligations.any((s) => s.status == PaymentStatus.overdue)
        ? PaymentStatus.overdue
        : obligations.any((s) => s.status == PaymentStatus.dueSoon)
        ? PaymentStatus.dueSoon
        : PaymentStatus.pending;
    return EntryRead(
      effectiveCents: effective,
      netPaidCents: netPaid,
      balanceCents: balance,
      overpaymentCents: _positive(netPaid - effective),
      obligations: obligations,
      status: status,
      partial: netPaid > 0 && balance > 0,
    );
  }
}

int _positive(int value) => value > 0 ? value : 0;
DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
Map<String, int> _counts(Iterable<String> ids) {
  final counts = <String, int>{};
  for (final id in ids) {
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}
