import 'package:kasaran/domain/allocation/budget_allocator.dart';
import 'package:kasaran/domain/calculations/financial_models.dart';

/// Read-time invariant predicates. No repairs or writes (design §4.4, ADR-45).
abstract final class FinancialValidation {
  static List<String> plan(FinancialInput input) => [
    if (input.budgetCents <= 0) 'positive_budget_required',
    if (input.guestCap < 0) 'negative_guest_cap',
    if (input.drivingGuests < 0) 'negative_driving_guests',
  ];

  static const feeCategories = {
    'crew_meals': 'catering_venue',
    'oot_fees': 'coordination',
    'church_aircon': 'catering_venue',
    'corkage': 'catering_venue',
    'overtime': 'coordination',
    'venue_power': 'catering_venue',
  };
  static List<String> entry(LedgerEntry e, String planId) {
    final errors = <String>[];
    if (e.id.isEmpty || e.planId != planId) {
      errors.add('entry_identity');
    }
    if (!categoryCodes.contains(e.category)) {
      errors.add('invalid_category');
    }
    if (e.supplier.trim().isEmpty || e.supplier.runes.length > 200) {
      errors.add('supplier_length');
    }
    if ((e.notes?.runes.length ?? 0) > 2000) {
      errors.add('notes_length');
    }
    if (e.actualCents != null && e.actualCents! < 0) {
      errors.add('negative_actual');
    }
    if (e.mode == PricingMode.flat) {
      if (e.estimateCents == null ||
          e.estimateCents! < 0 ||
          e.rateCents != null) {
        errors.add('flat_shape');
      }
    } else {
      if (e.rateCents == null || e.rateCents! < 0 || e.estimateCents != null) {
        errors.add('per_head_shape');
      }
      if (e.manuallyValued != (e.actualCents != null)) {
        errors.add('manual_actual_shape');
      }
    }
    if (e.entryType == 'standard') {
      if (e.components.any((c) => !c.deleted)) {
        errors.add('unexpected_components');
      }
    } else {
      if (!feeCategories.containsKey(e.entryType)) {
        errors.add('unknown_fee_type');
      }
      if (feeCategories[e.entryType] != e.category) {
        errors.add('fee_category');
      }
      if (e.mode != PricingMode.flat) {
        errors.add('fee_pricing_mode');
      }
      final components = e.components.where((c) => !c.deleted).toList();
      if (components.isEmpty) {
        errors.add('missing_components');
      }
      if (e.entryType == 'church_aircon' && components.length != 1) {
        errors.add('church_aircon_singleton');
      }
      final ids = <String>{};
      for (final c in components) {
        if (c.id.isEmpty || !ids.add(c.id)) {
          errors.add('component_identity');
        }
        final quantity =
            e.entryType == 'crew_meals' || e.entryType == 'overtime';
        if (quantity) {
          if (c.quantity == null ||
              c.unitRateCents == null ||
              c.amountCents != null ||
              (c.quantity ?? 0) < 0 ||
              (c.unitRateCents ?? 0) < 0) {
            errors.add('component_quantity_rate');
          }
        } else {
          if (c.quantity != null ||
              c.unitRateCents != null ||
              c.amountCents == null ||
              (c.amountCents ?? 0) < 0) {
            errors.add('component_flat_shape');
          }
          final allowed = switch (e.entryType) {
            'oot_fees' => ['travel', 'lodging', 'per_diem'],
            'corkage' => ['cake', 'wine', 'liquor', 'lechon', 'other'],
            'venue_power' => ['generator', 'surcharge', 'electrical'],
            'church_aircon' => ['flat'],
            _ => <String>[],
          };
          if (!allowed.contains(c.type)) {
            errors.add('component_type');
          }
        }
      }
    }
    return errors;
  }

  static List<String> pledge(Pledge p, String planId) {
    final errors = <String>[];
    if (p.id.isEmpty || p.planId != planId) {
      errors.add('pledge_identity');
    }
    if (p.sponsor.trim().isEmpty || p.sponsor.runes.length > 200) {
      errors.add('sponsor_length');
    }
    if (![
      'ninong',
      'ninang',
      'family',
      'friend',
      'secondary_sponsor',
      'other',
    ].contains(p.role)) {
      errors.add('sponsor_role');
    }
    if (p.role == 'secondary_sponsor'
        ? !['candle', 'veil', 'cord'].contains(p.secondarySubrole)
        : p.secondarySubrole != null) {
      errors.add('secondary_subrole');
    }
    if (p.valueCents < 0) {
      errors.add('negative_pledge');
    }
    if (p.linkedCategory != null && !categoryCodes.contains(p.linkedCategory)) {
      errors.add('linked_category');
    }
    return errors;
  }

  static List<String> payment(Payment p, Set<String> scheduleIds) {
    final errors = <String>[];
    if (p.id.isEmpty || p.amountCents <= 0) {
      errors.add('positive_payment_required');
    }
    if (![
      'cash',
      'bank_transfer',
      'gcash',
      'maya',
      'check',
      'other',
    ].contains(p.method)) {
      errors.add('payment_method');
    }
    if (p.scheduleItemId != null && !scheduleIds.contains(p.scheduleItemId)) {
      errors.add('foreign_schedule_attribution');
    }
    return errors;
  }

  static List<String> receipt(Receipt r) => [
    if (r.id.isEmpty || r.amountCents <= 0) 'positive_receipt_required',
  ];
  static List<String> gift(Gift g) => [
    if (g.id.isEmpty || g.amountCents <= 0) 'positive_gift_required',
    if (![
      'sobre',
      'money_dance',
      'cash',
      'bank_transfer',
      'other',
    ].contains(g.source))
      'gift_source',
  ];
}
