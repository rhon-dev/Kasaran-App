import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';

/// Inject the device-local clock for deterministic past-date tests.
final setupTodayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Only in-memory data for the current authenticated account. No disk/server IO.
class SetupDraft {
  const SetupDraft({
    this.ownerId,
    this.budgetInput = '',
    this.dateInput = '',
    this.acceptedDate,
  });

  final String? ownerId;
  final String budgetInput;
  final String dateInput;
  final String? acceptedDate;

  SetupDraft copyWith({
    String? budgetInput,
    String? dateInput,
    String? acceptedDate,
  }) => SetupDraft(
    ownerId: ownerId,
    budgetInput: budgetInput ?? this.budgetInput,
    dateInput: dateInput ?? this.dateInput,
    acceptedDate: acceptedDate ?? this.acceptedDate,
  );
}

final setupDraftProvider = NotifierProvider<SetupDraftController, SetupDraft>(
  SetupDraftController.new,
);

class SetupDraftController extends Notifier<SetupDraft> {
  @override
  SetupDraft build() {
    final auth = ref.watch(authStateProvider);
    final userId = ref.watch(authUserIdProvider);
    // Rebuild from empty on *every* identity transition, including A->B->A,
    // loading, errors and sign-out. No account-keyed copy survives.
    return SetupDraft(ownerId: auth == AuthState.authenticated ? userId : null);
  }

  void setBudget(String value) {
    if (state.ownerId != null) state = state.copyWith(budgetInput: value);
  }

  void setDate(String value) {
    if (state.ownerId != null) state = state.copyWith(dateInput: value);
  }

  void acceptDate(String value) {
    if (state.ownerId != null) {
      state = state.copyWith(dateInput: value, acceptedDate: value);
    }
  }

  void restoreDate() {
    if (state.ownerId != null) {
      state = state.copyWith(dateInput: state.acceptedDate ?? '');
    }
  }
}
