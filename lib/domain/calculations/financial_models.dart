/// Immutable integer-source financial inputs; no persistence or framework types.
library;

enum PricingMode { flat, perHead }

enum PaymentKind { payment, refund }

enum PledgeType { cash, item }

enum PledgeStatus { tentative, confirmed, withdrawn }

enum PaymentStatus { paid, pending, partiallyPaid, dueSoon, overdue }

enum FinancialDependency { ledger, payments, pledges, gifts, allocation }

class ExactRatio {
  ExactRatio(int numerator, int denominator)
    : numerator = BigInt.from(numerator),
      denominator = BigInt.from(denominator) {
    if (denominator <= 0) {
      throw ArgumentError('Positive denominator required');
    }
  }
  final BigInt numerator, denominator;
}

class FeeComponent {
  const FeeComponent({
    required this.id,
    required this.type,
    this.quantity,
    this.unitRateCents,
    this.amountCents,
    this.deleted = false,
  });
  final String id, type;
  final int? quantity, unitRateCents, amountCents;
  final bool deleted;
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.dueOn,
    required this.amountCents,
    this.sortOrder = 0,
    this.deleted = false,
  });
  final String id;
  final DateTime dueOn;
  final int amountCents, sortOrder;
  final bool deleted;
}

class Payment {
  const Payment({
    required this.id,
    required this.amountCents,
    required this.kind,
    required this.paidOn,
    this.scheduleItemId,
    this.paidByPledgeId,
    this.method = 'cash',
    this.deleted = false,
  });
  final String id;
  final PaymentKind kind;
  final int amountCents;
  final DateTime paidOn;
  final String? scheduleItemId, paidByPledgeId;
  final String method;
  final bool deleted;
}

class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.planId,
    required this.category,
    required this.supplier,
    required this.mode,
    this.entryType = 'standard',
    this.estimateCents,
    this.rateCents,
    this.actualCents,
    this.manuallyValued = false,
    this.deleted = false,
    this.notes,
    List<FeeComponent> components = const [],
    List<ScheduleItem> schedule = const [],
    List<Payment> payments = const [],
  }) : components = List.unmodifiable(components),
       schedule = List.unmodifiable(schedule),
       payments = List.unmodifiable(payments);
  final String id, planId, category, supplier, entryType;
  final PricingMode mode;
  final int? estimateCents, rateCents, actualCents;
  final bool manuallyValued, deleted;
  final String? notes;
  final List<FeeComponent> components;
  final List<ScheduleItem> schedule;
  final List<Payment> payments;
}

class Receipt {
  const Receipt({
    required this.id,
    required this.amountCents,
    required this.receivedOn,
    this.paymentId,
    this.deleted = false,
  });
  final String id;
  final int amountCents;
  final DateTime receivedOn;
  final String? paymentId;
  final bool deleted;
}

class Pledge {
  Pledge({
    required this.id,
    required this.planId,
    required this.sponsor,
    required this.role,
    required this.type,
    required this.valueCents,
    required this.status,
    this.secondarySubrole,
    this.linkedEntryId,
    this.linkedCategory,
    this.deleted = false,
    List<Receipt> receipts = const [],
  }) : receipts = List.unmodifiable(receipts);
  final String id, planId, sponsor, role;
  final String? secondarySubrole, linkedEntryId, linkedCategory;
  final int valueCents;
  final PledgeType type;
  final PledgeStatus status;
  final bool deleted;
  final List<Receipt> receipts;
}

class Gift {
  const Gift({
    required this.id,
    required this.source,
    required this.amountCents,
    required this.receivedOn,
    this.deleted = false,
  });
  final String id, source;
  final int amountCents;
  final DateTime receivedOn;
  final bool deleted;
}

class FinancialInput {
  FinancialInput({
    required this.planId,
    required this.budgetCents,
    required this.drivingGuests,
    required this.guestCap,
    List<LedgerEntry> entries = const [],
    List<Pledge> pledges = const [],
    List<Gift> gifts = const [],
    Set<FinancialDependency> unknownDependencies = const {},
  }) : entries = List.unmodifiable(entries),
       pledges = List.unmodifiable(pledges),
       gifts = List.unmodifiable(gifts),
       unknownDependencies = Set.unmodifiable(unknownDependencies);
  final String planId;
  final int budgetCents, drivingGuests, guestCap;
  final List<LedgerEntry> entries;
  final List<Pledge> pledges;
  final List<Gift> gifts;
  final Set<FinancialDependency> unknownDependencies;
}

class FinancialIssue {
  const FinancialIssue(this.entityId, this.constraint);
  final String entityId, constraint;
  @override
  String toString() => '$entityId: $constraint';
}

class ObligationRead {
  const ObligationRead({
    required this.amountCents,
    required this.allocatedCents,
    required this.remainingCents,
    required this.status,
    required this.partial,
    this.scheduleItemId,
    this.dueOn,
  });
  final String? scheduleItemId;
  final DateTime? dueOn;
  final int amountCents, allocatedCents, remainingCents;
  final PaymentStatus status;
  final bool partial;
}

class EntryRead {
  EntryRead({
    required this.effectiveCents,
    required this.netPaidCents,
    required this.balanceCents,
    required this.overpaymentCents,
    required List<ObligationRead>? obligations,
    required this.status,
    required this.partial,
  }) : obligations = obligations == null
           ? null
           : List.unmodifiable(obligations);
  final int? effectiveCents;
  final int? netPaidCents, balanceCents, overpaymentCents;
  final List<ObligationRead>? obligations;
  final PaymentStatus? status;
  final bool? partial;
}

class PledgeRead {
  const PledgeRead({
    required this.receivedCents,
    required this.remainingCents,
    required this.appliedCents,
    required this.displayStatus,
  });
  final int receivedCents, remainingCents;
  final int? appliedCents;
  final String displayStatus;
}

class FinancialReadResult {
  FinancialReadResult({
    required this.grossCents,
    required this.paidCents,
    required this.balanceCents,
    required this.netCents,
    required this.expectedCents,
    required this.exposureCents,
    required this.orphanSupportCents,
    required this.giftsCents,
    required this.netAfterGiftsCents,
    required this.reconciliationCents,
    required this.bufferRemainingCents,
    required this.headroomCents,
    required this.overBudget,
    required this.bufferBreach,
    required this.overCap,
    required this.perHeadCost,
    required Map<String, int>? supportByReceipt,
    required Map<String, PledgeRead>? pledges,
    required Map<String, int>? varianceCents,
    required Map<String, int>? categoryCents,
    required Map<String, EntryRead> entries,
    required List<FinancialIssue> issues,
  }) : supportByReceipt = supportByReceipt == null
           ? null
           : Map.unmodifiable(supportByReceipt),
       pledges = pledges == null ? null : Map.unmodifiable(pledges),
       varianceCents = varianceCents == null
           ? null
           : Map.unmodifiable(varianceCents),
       categoryCents = categoryCents == null
           ? null
           : Map.unmodifiable(categoryCents),
       entries = Map.unmodifiable(entries),
       issues = List.unmodifiable(issues);
  final int? grossCents,
      paidCents,
      balanceCents,
      netCents,
      expectedCents,
      exposureCents,
      giftsCents,
      netAfterGiftsCents,
      reconciliationCents,
      bufferRemainingCents,
      headroomCents;
  final int? orphanSupportCents;
  final bool? overBudget, bufferBreach;
  final bool? overCap;
  final ExactRatio? perHeadCost;
  final Map<String, int>? supportByReceipt;
  final Map<String, PledgeRead>? pledges;
  final Map<String, int>? varianceCents;
  final Map<String, int>? categoryCents;
  final Map<String, EntryRead> entries;
  final List<FinancialIssue> issues;
}
